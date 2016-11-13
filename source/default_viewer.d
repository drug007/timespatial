module default_viewer;

import std.conv: text;

import gfm.math: box3f, vec3f, vec2f;
import gfm.sdl2;

import base_viewer: BaseViewer;
import data_item: timeToStringz;
import timestamp_storage: TimestampStorage;
import data_provider: DataObject, IRenderableData, RenderableData, makeRenderableData, updateBoundingBox;
import data_layout: IDataLayout, DataLayout;
import rtree;
import data_provider: Data;

class DefaultViewer : BaseViewer
{
    this(int width, int height, string title)
    {
        import imgui_helpers: igGetStyle;

        with(igGetStyle())
        {
            FrameRounding = 4.0;
            GrabRounding  = 4.0;
        }

        super(width, height, title);

        show_settings = true;
        max_point_counts = 2;
        clear_color = [0.3f, 0.4f, 0.8f];

        box = box3f(
            vec3f(float.max, float.max, float.max),
            vec3f(float.min_normal, float.min_normal, float.min_normal),
        );

        timestamp_storage = TimestampStorage((long[]).init);
                
        onMaxPointChange = () {
            foreach(ref e; renderable_data)
            {
                e.setTimeWindow(long.min, timestamp_storage.current);
                e.setMaxCount(max_point_counts);
            }
        };

        onCurrentTimestampChange = () {
            foreach(ref e; renderable_data)
            {
                e.setTimeWindow(long.min, timestamp_storage.current);
                e.setMaxCount(max_point_counts);
            }
        };

        pointsRtree = new RTree(":memory:");
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
        destroy(pointsRtree);
    }

    void addData(DataObject[uint][uint] data_objects)
    {
        import data_layout: Dummy;

        auto dl = new DataLayout("test");
        data_layout ~= dl;
        
        // На основании исходных данных генерируем полных набор
        // данных для рендеринга
        foreach(k; data_objects.byKey)
        {
            auto dobj = data_objects[k].values; // TODO неэффективно, так как динамический массив будет удерживаться в памяти
                                                // так как на него будет ссылаться DataLayout
            auto rd = makeRenderableData(k, dobj, &genVertexProviderHandle);
            timestamp_storage.addTimestamps(rd.getTimestamps());
            updateBoundingBox(box, rd.box);
            foreach(a; rd.aux)
                setVertexProvider(a.vp);
            renderable_data ~= rd;

            // data layout
            assert(dobj.length);
            auto dummy = new Dummy(); // делаем пустышку, но пустышка должна иметь уникальный адрес, поэтому на куче, не на стеке
            dl.addGroup!Dummy(*dummy, k.text ~ "\0");
            import std.algorithm: sort;
            foreach(ref e2; dobj.sort!((a,b)=>a.no<b.no))
                dl.add!DataObject(e2, e2.no.text ~ "\0");
        }
        onCurrentTimestampChange();
    }

    /// Добавляет данные в RTree
    public void addDataToRTree(Data[] data) //FIXME: isn't need to be public
    {
        foreach(id, e; data)
            pointsRtree.addPoint(e.id, vec3f(e.x, e.y, e.z));
    }

    /// Находит ближайшие в радиусе не менее radius точки по координатам в окне
    /// Для упрощения подразумевается что вид на точки направлен строго сверху
    private Point[] pickPoints(in vec2f screenCoords, float radius)
    {
        vec3f expander = vec3f(radius, radius, radius);
        box3f searchBox = box3f(_camera_pos - expander, _camera_pos + expander);

        return pointsRtree.searchPoints(searchBox);
    }

    /// Находит ближайшую точку по координатам в окне
    /// Если такой точки нет то возвращает null
    /// Возвращённое значение обслуживается GC
    Point* pickPoint(in vec2f screenCoords)
    {
        enum radius = 100.0f;
        auto found = pickPoints(screenCoords, radius);

        vec3f cameraRay = screenPoint2worldRay(screenCoords);
        Point* nearest;
        real minDistance = real.infinity;

        foreach(point; found)
        {
            auto camRelative = point.coords - _camera_pos;
            auto distance = cameraRay.distanceTo(camRelative);

            if(distance < minDistance) // найдена точка ближе?
            {
                if(nearest is null) nearest = new Point;

                minDistance = distance;
                *nearest = point;
            }
        }

        return nearest;
    }

    /// Проекция оконной координаты в точку на плоскости z = 0
    private vec3f projectWindowToPlane0(in vec2f winCoords)
    {
        import gfm.math.shapes;

        triangle3f ground = triangle3f(vec3f(-10, 0, 0), vec3f(10000000, 0, 0), vec3f(-10, 10000000, 0));

        double x = void, y = void;
        const aspect_ratio = width/cast(double)height;
        if(width > height) 
        {
            auto factor_x = 2 * size / cast(double) width * aspect_ratio;
            auto factor_y = 2 * size / cast(double) height;

            x = winCoords.x * factor_x + _camera_pos.x - size * aspect_ratio;
            y = winCoords.y * factor_y + _camera_pos.y - size;
        }
        else
        {
            auto factor_x = 2 * size / cast(double) width;
            auto factor_y = 2 * size / cast(double) height * aspect_ratio;

            x = winCoords.x * factor_x + _camera_pos.x - size;
            y = winCoords.y * factor_y + _camera_pos.y - size * aspect_ratio;
        }

        auto projected = vec3f(x, y, 0.0f);
        
        return projected;
    }

    override public void onMouseDown(ref const(SDL_Event) event)
    {
        super.onMouseDown(event);
        auto point = pickPoint(vec2f(mouse_x, mouse_y));

        if(point !is null)
            pickedPoint = (*point).toString;
    }

    void delegate() onMaxPointChange;
    void delegate() onCurrentTimestampChange;

    /// Override rendering to embed imgui
    override void draw()
    {
        import gfm.opengl;  
        import derelict.imgui.imgui;
        import std.string: toStringz;

        {
            igSetNextWindowSize(ImVec2(400,600), ImGuiSetCond_FirstUseEver);
            igBegin("Settings", &show_settings);
            const old_value = max_point_counts;
            igSliderInt("Max point counts", &max_point_counts, 1, 32);
            if(old_value != max_point_counts && onMaxPointChange !is null)
            {
                onMaxPointChange();
            }
            with(timestamp_storage)
            {
                int curr_idx = cast(int) currIndex;
                int min = 0;
                int max = cast(int)(length)-1;
                igSliderInt("Timestamp", &curr_idx, min, max);
                if(curr_idx != currIndex)
                {
                    setIndex(curr_idx);
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

                igText("Mouse coords x=%d y=%d", mouse_x, mouse_y);
                igText("Picked point %s", pickedPoint.toStringz);
            }
            igEnd();
        }

        foreach(ref dw; data_layout)
            dw.draw();

        // Rendering
        // Only clearing specific color here because imgui and timespatial objects rendering is built-in in BaseViewer
        auto ds = _imgui_io.DisplaySize;
        glViewport(0, 0, cast(int) ds.x, cast(int) ds.y);
        glClearColor(clear_color[0], clear_color[1], clear_color[2], 0);
        glClear(GL_COLOR_BUFFER_BIT);
    }

    RTree pointsRtree;
    string pickedPoint;

public:
    import data_layout: IDataLayout;

    bool show_settings;
    int max_point_counts;
    float[3] clear_color;
    TimestampStorage timestamp_storage;
    IDataLayout[] data_layout;
    box3f box;
    IRenderableData[] renderable_data;
}

private string toString(in Point p)
{
    import std.conv: to;

    return "id="~p.externalId.to!string~" x="~p.coords.x.to!string~" y="~p.coords.y.to!string;
}
