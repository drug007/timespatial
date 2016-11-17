import test_data: testData;
import data_provider: prepareData;

int main(string[] args)
{
    import derelict.imgui.imgui: DerelictImgui;

    version(Windows)
        DerelictImgui.load("cimgui.dll");
    else
        DerelictImgui.load("DerelictImgui/cimgui/cimgui/cimgui.so");

    int width = 1800;
    int height = 768;

    import default_viewer: DefaultViewer;
    
    auto gui = new DefaultViewer(width, height, "Test gui");
    gui.addData(testData.prepareData);
    gui.addDataToRTree(testData);
    gui.centerCamera();
    gui.run();
    gui.close();
    destroy(gui);

    return 0;
}
