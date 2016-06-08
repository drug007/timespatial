module test_viewer;

import data_viewer: DataViewer;
import data_provider: DataProvider;
import data_item: timeToStringz;

class TestViewer : DataViewer
{
    this(int width, int height, string title, ref DataProvider dprovider)
    {
        import imgui_helpers: igGetStyle;

        with(igGetStyle())
        {
            FrameRounding = 4.0;
            GrabRounding  = 4.0;
        }

        super(width, height, title, dprovider);
    }

    /// Override rendering to embed imgui
    override void draw()
    {
        import gfm.opengl;  
        import derelict.imgui.imgui;

        {
            igSetNextWindowSize(ImVec2(400,600), ImGuiSetCond_FirstUseEver);
            igBegin("Settings", &show_settings);
            const old_value = max_point_counts;
            igSliderInt("Max point counts", &max_point_counts, 1, 32);
            if(old_value != max_point_counts)
            {
                _data_provider.setElementCount(max_point_counts);
                invalidate();
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
                    invalidate();
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
        }

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

        /// if during imgui phase some data has been changed
        /// update data
        if(_data_provider.drawGui())
            invalidate();

        // Rendering
        // Only clearing specifig color here because imgui and timespatial objects rendering is built-in in BaseViewer
        auto ds = _imgui_io.DisplaySize;
        glViewport(0, 0, cast(int) ds.x, cast(int) ds.y);
        glClearColor(clear_color[0], clear_color[1], clear_color[2], 0);
        glClear(GL_COLOR_BUFFER_BIT);
    }

private:

    bool show_test_window    = false;
    bool show_another_window = false;
    bool show_settings       = true;

    int max_point_counts = 2;

    float[3] clear_color = [0.3f, 0.4f, 0.8f];
}