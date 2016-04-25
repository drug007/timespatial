module test_gui;

import gfm.opengl: glClearColor, glViewport, glClear, GL_COLOR_BUFFER_BIT;
import gfm.sdl2: SDL_Event;

import base_gui: BaseGui;
import data_provider: DataProvider;
import infoof: timeToStringz;

class TestGui : BaseGui
{
    this(int width, int height, ref DataProvider dprovider)
    {
        import std.array: back;
        import imgui_helpers: imguiInit, igGetStyle;

        imguiInit(window);
        with(igGetStyle())
        {
            FrameRounding = 4.0;
            GrabRounding  = 4.0;
        }

        _data_provider = dprovider;
        super(width, height, "Title");
        _data_provider.updateTimeWindow();
        _data_provider.setElementCount(max_point_counts);
        updateGlData();
    }

    private auto updateGlData()
    {
        // TODO очень топорное решение - после обновления данных нужно пробежаться
        // по всем VertexProvider'ам, собрать в один массив и передать в BaseGui для
        // обновления/создания соответствующих GLProvider
        import vertex_provider: VertexProvider;
        
        VertexProvider[] vp;
        foreach(dd; _data_provider.timeSpatial)
            vp ~= dd.vertexProvider;
        setVertexProvider(vp);
    }

    void close()
    {
        import imgui_helpers: shutdown;

        _data_provider.close();

        shutdown();
    }

    /// Override rendering to embed imgui
    override void draw()
    {
        import derelict.imgui.imgui: igText, igButton, igBegin, igEnd, igRender, igGetIO,
            igSliderFloat, igColorEdit3, igTreePop, igTreeNode, igSameLine, igSmallButton,
            ImGuiIO, igSetNextWindowSize, igSetNextWindowPos, igTreeNodePtr, igShowTestWindow,
            ImVec2, ImGuiSetCond_FirstUseEver, igSliderInt, igGetTextLineHeightWithSpacing,
            igIndent, igUnindent;
		import imgui_helpers: imguiNewFrame;
        
        ImGuiIO* io = igGetIO();

        imguiNewFrame(window);

        {
            bool invalidated = false;
            igSetNextWindowSize(ImVec2(400,600), ImGuiSetCond_FirstUseEver);
            igBegin("Settings", &show_settings);
            const old_value = max_point_counts;
            igSliderInt("Max point counts", &max_point_counts, 1, 32);
            if(old_value != max_point_counts)
            {
                _data_provider.setElementCount(max_point_counts);
                invalidated = true;
            }

            with(_data_provider.timeslider)
            {
                int curr_idx = cast(int) currIndex;
                int min = 0;
                int max = cast(int)(length)-1;
                igSliderInt("Timestamp", &curr_idx, min, max);
                if(curr_idx != currIndex)
                {
                    setIndex(curr_idx);
                    _data_provider.updateTimeWindow();
                    _data_provider.setElementCount(max_point_counts);
                    invalidated = true;
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
            igEnd();
            if(invalidated)
                updateGlData();
        }

        _data_provider.drawGui();

        // 1. Show a simple window
        // Tip: if we don't call ImGui::Begin()/ImGui::End() the widgets appears in a window automatically called "Debug"
        {
            static float f = 0.0f;
            igText("Hello, world!");
            igSliderFloat("float", &f, 0.0f, 1.0f);
            igColorEdit3("clear color", clear_color);
            if (igButton("Test Window")) show_test_window ^= 1;
            if (igButton("Another Window")) show_another_window ^= 1;
            igText("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / igGetIO().Framerate, igGetIO().Framerate);
        }
        
        // 2. Show another simple window, this time using an explicit Begin/End pair
        if (show_another_window)
        {
            igSetNextWindowSize(ImVec2(200,100), ImGuiSetCond_FirstUseEver);
            igBegin("Another Window", &show_another_window);
            igText("Hello");
            if (igTreeNode("Tree"))
            {
                for (size_t i = 0; i < 5; i++)
                {
                    if (igTreeNodePtr(cast(void*)i, "Child %d", i))
                    {
                        igText("blah blah");
                        igSameLine();
                        igSmallButton("print");
                        igTreePop();
                    }
                }
                igTreePop();
            }
            igEnd();
        }
        
        // 3. Show the ImGui test window. Most of the sample code is in ImGui::ShowTestWindow()
        if (show_test_window)
        {
            igSetNextWindowPos(ImVec2(650, 20), ImGuiSetCond_FirstUseEver);
            igShowTestWindow(&show_test_window);
        }

        // Rendering
        glViewport(0, 0, cast(int)io.DisplaySize.x, cast(int)io.DisplaySize.y);
        glClearColor(clear_color[0], clear_color[1], clear_color[2], 0);
        glClear(GL_COLOR_BUFFER_BIT);

        program.uniform("mvp_matrix").set(mvp_matrix);
        program.use();
        drawObjects();
        program.unuse();

        igRender();

        window.swapBuffers();
    }
private:
    DataProvider _data_provider;

    bool show_test_window    = false;
    bool show_another_window = false;
    bool show_settings       = true;

    int max_point_counts = 2;

    float[3] clear_color = [0.3f, 0.4f, 0.8f];
}