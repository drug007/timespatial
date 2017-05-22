module default_viewer;

import std.conv: text;
import std.container: Array;

import gfm.math: box3f, vec3f, vec2f;
import gfm.sdl2: SDL_Event;

import base_viewer: BaseViewer;
import data_item: timeToStringz, BaseDataItem, buildDataItemArray;
import timestamp_storage: TimestampStorage;
import data_provider: IRenderableData, RenderableData, updateBoundingBox;
import vertex_provider : VertexProvider;
import data_layout: IDataLayout, DataLayout;
import color_table: ColorTable;
import rtree;

class DefaultViewer(HData, HDataIndex) : BaseViewer
{
    enum settingsFilename = "settings.json";

    alias DataSet = HDataIndex.DataSet;
    alias Color = typeof(color_table(0));

    this(int width, int height, string title, ref HData data, ref HDataIndex data_index, ColorTable color_table, FullScreen fullscreen = FullScreen.no)
    {
        import imgui_helpers: igGetStyle;

        with(igGetStyle())
        {
            FrameRounding = 4.0;
            GrabRounding  = 4.0;
        }

        super(width, height, title, fullscreen);

        show_settings = true;
        max_point_counts = 2;
        clear_color = color_table(0); // "нулевой" цвет это цвет фона

        box = box3f(
            vec3f(float.max, float.max, float.max),
            vec3f(float.min_normal, float.min_normal, float.min_normal),
        );

        timestamp_storage_start  = TimestampStorage((long[]).init);
        timestamp_storage_finish = TimestampStorage((long[]).init);
                
        onMaxPointChange = () {
            assert(timestamp_storage_start.current <= timestamp_storage_finish.current, text(timestamp_storage_start.current, " ", timestamp_storage_finish.current));
            foreach(ref e; renderable_data)
            {
                e.setTimeWindow(timestamp_storage_start.current, timestamp_storage_finish.current);
                e.setMaxCount(max_point_counts);
            }
        };

        onCurrentTimestampChange = () {
            assert(timestamp_storage_start.current <= timestamp_storage_finish.current, text(timestamp_storage_start.current, " ", timestamp_storage_finish.current));
            foreach(ref e; renderable_data)
            {
                e.setTimeWindow(timestamp_storage_start.current, timestamp_storage_finish.current);                
                e.setMaxCount(max_point_counts);
            }
        };

        pointsRtree = new RTree(":memory:");

        distance_from = vec3f(0, 0, 0);

        this.color_table = color_table;
        this.data_index = &data_index;
        this.data = &data;

        {
            // benchmarking of data index creating
            import std.datetime : StopWatch;
            StopWatch sw;
            sw.start();

            addData();

            sw.stop();
            import std.stdio : writefln;
            writefln("Data adding took %s ms", sw.peek().msecs);
        }

        makeDataLayout(); // генерируем неграфические данные

        about_closing = false;

        import std.json : JSONValue, parseJSON, JSON_TYPE;
        import std.format : format;
        import std.file : exists, readText;

        if (settingsFilename.exists)
        {
            float json_size;
            vec3f pos;
            scope(success)
            {
                setCameraSize(json_size);
                setCameraPosition(pos);
            }

            try
            {
                string s = readText(settingsFilename);
                JSONValue jv = parseJSON(s);
                if (jv["size"].type == JSON_TYPE.INTEGER)
                    json_size = jv["size"].integer;
                else if (jv["size"].type == JSON_TYPE.FLOAT)
                    json_size = jv["size"].floating;
                else
                    json_size = 10_000;

                foreach(i; 0..3)
                {
                    if (jv["position"][i].type == JSON_TYPE.INTEGER)
                        pos[i] = jv["position"][i].integer;
                    else if (jv["position"][i].type == JSON_TYPE.FLOAT)
                        pos[i] = jv["position"][i].floating;
                    else
                        pos[i] = 0;
                }

                long timestamp_idx;
                // start time
                if (jv["start_timestamp_idx"].type == JSON_TYPE.INTEGER)
                    timestamp_idx = jv["start_timestamp_idx"].integer;

                auto max_idx = timestamp_storage_start.length-1;
                if (timestamp_idx > max_idx)
                    timestamp_idx = 0;
                timestamp_storage_start.setIndex(timestamp_idx);

                // finish time
                if (jv["finish_timestamp_idx"].type == JSON_TYPE.INTEGER)
                    timestamp_idx = jv["finish_timestamp_idx"].integer;
                else
                    timestamp_idx = 0;
                if (timestamp_idx > max_idx)
                    timestamp_idx = 0;
                timestamp_storage_finish.setIndex(timestamp_idx);

                if (jv["max_point"].type == JSON_TYPE.INTEGER)
                    max_point_counts = cast(int) jv["max_point"].integer;

                onMaxPointChange();
            }
            catch(Exception e)
            {
            }
        }
        else
            centerCamera();
    }

    void centerCamera()
    {
        // camera initialization
        // camera looks to the center of the bounding box
        auto pos = (box.max + box.min)/2.;
        pos.z = 0;
        setCameraPosition(pos);

        // size of field of view is defined by
        // largest side of the bounding box
        import std.algorithm: max;
        pos = box.max - box.min;
        auto size = max(pos.x, pos.y)/2.;
        setCameraSize(size);
    }

    ~this()
    {
        import std.format : format;
        import std.file : write;

        string json, pre_json = "{
  \"position\": [
    %f,
    %f,
    %f
  ],
  \"size\": %f,
  \"start_timestamp_idx\": %d,
  \"finish_timestamp_idx\": %d,
  \"max_point\": %d
}";
        with(_camera_pos) 
        json = format(pre_json, x, y, z, size, 
            timestamp_storage_start.currIndex,
            timestamp_storage_finish.currIndex,
            max_point_counts
        );
        write(settingsFilename, json);

        destroy(pointsRtree);
    }

    abstract void makeDataLayout();
    abstract VertexProvider makeVertexProvider(ref const(DataSet) dataset, ref const(Color) clr);
    abstract void addDataSetLayout(DataLayout dl, ref const(DataSet) dataset);

    void addData()
    {
        import vertex_provider: VertexProvider;
        import data_layout: Dummy;

        auto dl = new DataLayout("test");
        data_layout ~= dl;
        
        foreach(ref source_no, ref datasource; *data_index)
        {
            auto dummy = new Dummy(); // делаем пустышку, но пустышка должна иметь уникальный адрес, поэтому на куче, не на стеке
            dl.addGroup!Dummy(*dummy, text(source_no, "\0"));

            // for each source create correspondence RenderableData
            auto rd = new RenderableData!(DataSet)(source_no);
            auto clr = color_table(source_no);
            foreach(ref dataset_no, ref dataset; datasource)
            {
                auto vp = makeVertexProvider(dataset, clr);
                rd.addDataSet(dataset, vp);

                addDataSetLayout(dl, dataset);

                foreach(ref e; dataset)
                {
                    import msgpack: pack;
                    pointsRtree.addPoint(e.no, vec3f(e.x, e.y, e.z), e.ref_id.pack);
                }
            }
            
            auto ts = rd.getTimestamps();
            timestamp_storage_start.addTimestamps(ts);
            timestamp_storage_finish.addTimestamps(ts);

            updateBoundingBox(box, rd.box);

            foreach(a; rd.aux)
                setVertexProvider(a.vp);

            renderable_data ~= rd;
        }
        onCurrentTimestampChange();
    }

    /// Конвертация экранной координаты в точку на поверхности Земли
    private vec3f screenCoords2gndPoint(in vec2f screenCoords)
    {
        import gfm.math.shapes;

        triangle3f ground = triangle3f(vec3f(0, 0, 0), vec3f(1, 0, 0), vec3f(0, 1, 0));
        ray3f pickRay;

        pickRay.orig = _camera_pos;
        pickRay.dir = screenPoint2worldRay(screenCoords);

        float t, u, v;
        pickRay.intersect(ground, t, u, v);

        vec3f groundPoint = (1.0f - u - v) * ground.a + u * ground.b + v * ground.c;

        //assert(groundPoint.z == 0); // z должен быть равен нулю

        return groundPoint;
    }

    /// Находит ближайшую точку по координатам в окне
    /// Если такой точки нет то возвращает null
    /// Возвращённое значение обслуживается GC
    auto pickPoint(in vec2f screenCoords)
    {
        box3f searchBox;

        {
            const radius = width > height ? width/300 : height/300; /// радиус поиска точек в пикселях
            auto expander = vec2f(radius, radius);

            searchBox.min = projectWindowToPlane0(screenCoords - expander);
            searchBox.max = projectWindowToPlane0(screenCoords + expander);

            // установка возможных высот
            searchBox.min.z = -20000.0f;
            searchBox.max.z = 20000.0f;
        }

        return pointsRtree.searchPoints(searchBox);
    }

    void addDataLayout(DataLayout dl)
    {
        data_layout ~= dl;
    }

    /// Проекция оконной координаты в точку на плоскости z = 0
    private vec3f projectWindowToPlane0(in vec2f winCoords)
    {
        double x = void, y = void;
        const aspect_ratio = width/cast(double)height;
        if(width > height) 
        {
            auto factor_x = 2.0f * size / width * aspect_ratio;
            auto factor_y = 2.0f * size / height;

            x = winCoords.x * factor_x + _camera_pos.x - size * aspect_ratio;
            y = winCoords.y * factor_y + _camera_pos.y - size;
        }
        else
        {
            auto factor_x = 2.0f * size / width;
            auto factor_y = 2.0f * size / height * aspect_ratio;

            x = winCoords.x * factor_x + _camera_pos.x - size;
            y = winCoords.y * factor_y + _camera_pos.y - size * aspect_ratio;
        }

        return vec3f(x, y, 0.0f);
    }

    void delegate() onMaxPointChange;
    void delegate() onCurrentTimestampChange;

    /// Override rendering to embed imgui
    override void draw()
    {
        import gfm.opengl;  
        import derelict.imgui.imgui;

        {
            // Главное глобальное окно для перехвата пользовательского ввода вне других окон
            // (т.е. весь пользовательских ввод, который не попал в другие окна, будет обработан
            // данным окном)
            igSetNextWindowPos(ImVec2(0, 0), ImGuiSetCond_FirstUseEver);
            igSetNextWindowSize(ImVec2(width,height), ImGuiSetCond_FirstUseEver);
            // Окно без заголовка, неизменяемое, неперемещаемое, без настроек и не выносится на передний 
            // план если получает фокус ввода
            auto flags = ImGuiWindowFlags_NoTitleBar 
                | ImGuiWindowFlags_NoResize 
                | ImGuiWindowFlags_NoMove
                | ImGuiWindowFlags_NoSavedSettings
                | ImGuiWindowFlags_NoBringToFrontOnFocus;
			// делаем окно прозрачным как слеза младенца
            igPushStyleColor(ImGuiCol_WindowBg, ImVec4(0.0, 0.0, 0.0, 0.0));
            igBegin("main", null, flags);
            is_hovered = igIsWindowHovered();
            auto is_lmb_clicked = igIsMouseClicked(0);
            igEnd();
            igPopStyleColor(1);

            igSetNextWindowSize(ImVec2(400,600), ImGuiSetCond_FirstUseEver);
            igBegin("Settings", &show_settings);
            const old_value = max_point_counts;
            igSliderInt("Max point counts", &max_point_counts, 1, 32);
            if(old_value != max_point_counts && onMaxPointChange !is null)
            {
                onMaxPointChange();
            }
            import std.datetime: convert;
            enum minimalTimeWindowWidth = 1.convert!("minutes", "hnsecs");
            with(timestamp_storage_start)
            {
                int curr_idx = cast(int) currIndex;
                int min = 0;
                int max = cast(int)(length)-1;
                igSliderInt("Timestamp##start\0", &curr_idx, min, max);
                if(curr_idx != currIndex)
                {
                    setIndex(curr_idx);
                    if(current > (timestamp_storage_finish.current - minimalTimeWindowWidth))
                    {
                        timestamp_storage_finish.move(current - timestamp_storage_finish.current + minimalTimeWindowWidth);
                    }
                    if(onCurrentTimestampChange !is null)
                        onCurrentTimestampChange();
                }
                igText("Min time");
                igSameLine();
                igText(timeByIndex(min).timeToStringz);
                igSameLine();
                igText("Current time");
                igSameLine();
                igText(current.timeToStringz);
                igSameLine();
                igText("Max time");
                igSameLine();
                igText(timeByIndex(max).timeToStringz);
            }
            with(timestamp_storage_finish)
            {
                int curr_idx = cast(int) currIndex;
                int min = 0;
                int max = cast(int)(length)-1;
                igSliderInt("Timestamp##finish", &curr_idx, min, max);
                if(curr_idx != currIndex)
                {
                    setIndex(curr_idx);
                    if(current < (timestamp_storage_start.current + minimalTimeWindowWidth))
                    {
                        timestamp_storage_start.move(current - timestamp_storage_start.current - minimalTimeWindowWidth);
                    }
                    if(onCurrentTimestampChange !is null)
                        onCurrentTimestampChange();
                }
                igText("Min time");
                igSameLine();
                igText(timeByIndex(min).timeToStringz);
                igSameLine();
                igText("Current time");
                igSameLine();
                igText(current.timeToStringz);
                igSameLine();
                igText("Max time");
                igSameLine();
                igText(timeByIndex(max).timeToStringz);

                igText("Box: (%f, %f)(%f, %f)", box.min.x, box.max.x, box.min.y, box.max.y);
                igText("Mouse coords x=%d y=%d", mouse_x, mouse_y);
                auto world = projectWindowToPlane0(vec2f(mouse_x, mouse_y));
                igText("World coords x=%f y=%f", world.x, world.y);
            	igText("_camera_pos: x=%f y=%f", _camera_pos.x, _camera_pos.y);
            	igText("size: %f", size);
            	auto distance = distanceTo(world);
            	igText("distance from (%.1f, %.1f, %.1f) to mouse pointer: %.2f\0", 
                distance_from.x, distance_from.y, distance_from.z, distance);
            }

            if(about_closing)
            {
                igOpenPopup("Question?\0".ptr);
            }

            if (igBeginPopupModal("Question?\0".ptr, null, ImGuiWindowFlags_AlwaysAutoResize))
            {
                igText("Do you really want to exit?\0");

                if (igButton("OK##AboutClosing\0", ImVec2(120, 40)) || _imgui_io.KeysDown[ImGuiKey_Enter])
                {
                    igCloseCurrentPopup(); 
                    running = false; 
                    about_closing = false;
                    _imgui_io.KeysDown[ImGuiKey_Enter] = 0;
                }
                igSameLine();
                if (igButton("Cancel##AboutClosing\0", ImVec2(120, 40)) || _imgui_io.KeysDown[ImGuiKey_Escape])
                {
                    igCloseCurrentPopup(); 
                    about_closing = false;
                    _imgui_io.KeysDown[ImGuiKey_Escape] = 0;
                }
                igEndPopup();
            }

            import std.algorithm: each;
            import std.array: empty;

            // выводим popup menu в этом окне (а не главном) по той причине, что главное окно прозрачное и вывод в нем
            // приводит к изменениями внешнего вида пользовательского интерфейса.
            if (is_hovered && is_lmb_clicked)
            {
                igOpenPopup("Popup\0".ptr);

                ditem.each!(a=>a.destroy);
                ditem.clear;
                ditem = makePopupDataItems();
            }

            if (!ditem.empty && igBeginPopup("Popup\0".ptr))
            {
                ditem.each!(a=>a.draw);
                
                igEndPopup();
            }
            igEnd();

            {
                // TODO all this block is hack
                import std.algorithm: min, swap;

                enum Count = 256u;
                static bool[Count] state;
                const Amount = min(renderable_data.length, Count);
                bool changed = false;

                igSetNextWindowSize(ImVec2(width/10, height/3), ImGuiSetCond_FirstUseEver);
                igBegin("Visibility", null);
                
                foreach(uint n; 0..Amount)
                {
                    import std.conv: text;
                    const no = renderable_data[n].getNo;
                    auto clr = color_table(no);
                    with(clr) igPushStyleColor(ImGuiCol_Text, ImVec4(r, g, b, a));
                    state[n] = renderable_data[n].getVisibility();
                    igSelectableEx(text(state[n] ? " (on) " : "(off) ", no, "\0").ptr, &state[n]);
                    renderable_data[n].setVisibility(state[n]);
                    igPopStyleColor();

                    if (igIsItemActive() && !igIsItemHovered())
                    {
                        ImVec2 drag;
                        igGetMouseDragDelta(&drag, 0);
                        if (drag.y < 0.0f && n > 0)
                        {
                            swap(renderable_data[n], renderable_data[n-1]);
                            changed = true;
                        }
                        else if (drag.y > 0.0f && n < Amount-1)
                        {
                            swap(renderable_data[n], renderable_data[n+1]);
                            changed = true;
                        }
                        igResetMouseDragDelta();
                    }
                }
                if(changed)
                {
                    size_t curr_idx;
                    uint[] reference;
                    // rearrange vertex providers
                    foreach(rd; renderable_data)
                    {
                        foreach(a; rd.getAuxillary())
                        {
                            foreach(vp; a.vp)
                            {
                                size_t new_idx = _rdata.length;
                                // find index of the current vertex provider by its no
                                foreach(i; curr_idx.._rdata.length)
                                {
                                    if(_rdata[i].v.no == vp.no)
                                    {
                                        new_idx = i;
                                        break;
                                    }
                                }
                                // it should exist
                                assert(new_idx != _rdata.length);
                                if(curr_idx != new_idx)
                                {
                                    // if old and new indices of the vertex provider 
                                    // are not equal change its position to reflect this fact
                                    swap(_rdata[curr_idx], _rdata[new_idx]);
                                }
                                curr_idx++;
                            }

                        }
                    }
                }
                igEnd();

                auto wh = height * 0.025;
                igSetNextWindowPos(ImVec2(0, height - wh), ImGuiSetCond_FirstUseEver);
                igSetNextWindowSize(ImVec2(width, wh), ImGuiSetCond_FirstUseEver);
                // Окно без заголовка, неизменяемое, неперемещаемое и без настроек
                flags = ImGuiWindowFlags_NoTitleBar 
                    | ImGuiWindowFlags_NoResize 
                    | ImGuiWindowFlags_NoMove
                    | ImGuiWindowFlags_NoSavedSettings;
                igBegin("toolbar", null, flags);
                auto btn_size = wh * 0.8; // TODO implement automatic size calculation
                
                if (igButton("C0", ImVec2(btn_size, btn_size)))
                {
                    centerCamera();
                }
                igSameLine();
                // open input dialog to allow user to input coordinates of the center
                if (igButton("C1", ImVec2(btn_size, btn_size)))
                {
                    igOpenPopup("Center1\0".ptr);
                }

                if (igBeginPopupModal("Center1\0".ptr, null, ImGuiWindowFlags_AlwaysAutoResize))
                {
                    igText("Enter coordinates\0");
                    enum bufferSize = 64;
                    static char[bufferSize] xbuf, ybuf;

                    igInputText("X", xbuf.ptr, bufferSize, ImGuiInputTextFlags_CharsDecimal);
                    igInputText("Y", ybuf.ptr, bufferSize, ImGuiInputTextFlags_CharsDecimal);

                    if (igButton("OK##Centering\0", ImVec2(120, 40)))
                    {
                        scope(exit) igCloseCurrentPopup();
                        
                        try
                        {
                            import std.conv : to;
                            import std.exception : enforce;
                            import std.math : isNaN;
                            import std.string : fromStringz;

                            auto x = xbuf.ptr.fromStringz.to!float;
                            auto y = ybuf.ptr.fromStringz.to!float;
                            enforce(!x.isNaN);
                            enforce(!y.isNaN);

                            auto pos = vec3f(x, y, 0);
                            setCameraPosition(pos);
                        }
                        catch(Exception e)
                        {
                            igOpenPopup("Wrong input!\0".ptr);
                        }
                    }
                    igSameLine();
                    if (igButton("Cancel##Centering\0", ImVec2(120, 40)))
                    {
                        igCloseCurrentPopup();
                    }

                    if (igBeginPopupModal("Wrong input!\0".ptr, null, ImGuiWindowFlags_AlwaysAutoResize))
                    {
                        igText("Wrong input!\0");
                        igButton("OK", ImVec2(120, 40));
                        igEndPopup();
                    }
                    igEndPopup();
                }
                igEnd();
            }
        }

        foreach(ref dw; data_layout)
            dw.draw();

        // Rendering
        // Only clearing specific color here because imgui and timespatial objects rendering is built-in in BaseViewer
        auto ds = _imgui_io.DisplaySize;
        glViewport(0, 0, cast(int) ds.x, cast(int) ds.y);
        glClearColor(clear_color.r, clear_color.g, clear_color.b, clear_color.a);
        glClear(GL_COLOR_BUFFER_BIT);
    }

    Array!BaseDataItem makePopupDataItems()
    {
        import std.algorithm: map;
        import msgpack: unpack;

        auto curr_id = pickPoint(vec2f(mouse_x, mouse_y));
        return buildDataItemArray(curr_id.map!((a) {
            auto id = unpack!uint(a.payload);
            return (*data)[id].value;
        }));
    }

    override public void processMouseWheel(ref const(SDL_Event) event)
    {
        if(is_hovered)
        {
            super.processMouseWheel(event);
        }
    }

    override public void processMouseUp(ref const(SDL_Event) event)
    {
        if(is_hovered)
        {
            distance_from = projectWindowToPlane0(vec2f(mouse_x, mouse_y));
            super.processMouseUp(event);
        }
    }

    override public void processMouseDown(ref const(SDL_Event) event)
    {
        if(is_hovered)
        {
            super.processMouseDown(event);
        }
    }

    override void onKeyUp(ref const(SDL_Event) event)
    {
        import gfm.sdl2: SDLK_ESCAPE, SDLK_RETURN, SDLK_SPACE;
        import derelict.imgui.types: ImGuiKey_Enter, ImGuiKey_Escape;

        if(event.key.keysym.sym == SDLK_ESCAPE)
        {
            {
                // hack, it's used to imitate keyboard control of about closing box
                // (cancel closing application if ESCAPE was pressed)
                if(about_closing)
                    _imgui_io.KeysDown[ImGuiKey_Escape] = 1;
                else
                    _imgui_io.KeysDown[ImGuiKey_Escape] = 0;
            }
            about_closing = true;
        }

        {
            // hack, it's used to imitate keyboard control of about closing box
            // (closing application if ENTER was pressed)
            if (about_closing)
            {
                if(event.key.keysym.sym == SDLK_RETURN)
                    _imgui_io.KeysDown[ImGuiKey_Enter] = 1;
                if(about_closing && event.key.keysym.sym == SDLK_SPACE) // it allows to close the app using space beside enter button
                    _imgui_io.KeysDown[ImGuiKey_Enter] = 1;

            }
        }
    }

    override bool aboutQuit()
    {
        about_closing = true; // call modal pop up to ask user about quitting

        return false; // cancel default behavior
    }

    float distanceTo(ref const(vec3f) distance_to)
    {
        return (distance_to - distance_from).length;
    }

protected:
    import data_layout: IDataLayout;

    bool show_settings;
    int max_point_counts;
    Color clear_color;
    TimestampStorage timestamp_storage_start, timestamp_storage_finish;
    IDataLayout[] data_layout;
    box3f box;
    IRenderableData[] renderable_data;
    HDataIndex* data_index;
    HData* data;
    bool about_closing;
    RTree pointsRtree;
    Array!BaseDataItem ditem;
    bool is_hovered; // defines if mouse pointer is hovered under the main window (and not under child ones)
    ColorTable color_table;
    vec3f distance_from; // start point to calculate distance from it

    void __performanceTest()
    {
        import std.array: empty;
        import std.random;
        import std.datetime;
        import std.stdio: writefln;

        import dstats: MeanSD;

        setCameraSize(30_000);

        const aspect_ratio = width/cast(double)height;
        float w, h;
        if(width < height)
        {
            w = size;
            h = size * aspect_ratio;
        }
        else
        {
            h = size;
            w = size * aspect_ratio;
        }

        box.min = vec3f(-w, -h, -w);
        box.max = vec3f(+w, +h, +w);
        centerCamera();
        
        foreach(j; 1..6)
        {
            enum pointsDelta = 100_000;

            foreach(i; 0..pointsDelta)
            {
                auto x = uniform(-w, w);
                auto y = uniform(-h, h);
                auto z = 0;

                pointsRtree.addPoint(j*pointsDelta + i, vec3f(x, y, z), [0]);
            }

            //ищем 100 случайных точек, замеряем по каждому поиску время
            enum n = 100;

            /// длительность поиска в наносекундах
            MeanSD timings;

            foreach(i; 0..n)
            {
                StopWatch sw;

                sw.start();
                auto point_id = pickPoint(vec2f(uniform(0, width), uniform(0, height)));
                sw.stop();

                auto t = sw.peek().nsecs/1000_000.;
                timings.put(t);
            }

            writefln("Points amount: %s, times in ms", j*pointsDelta);
            writefln("\tmean: %s, stdev: %s, count: %s", timings.mean, timings.stdev, timings.N);
        }
    }
}
