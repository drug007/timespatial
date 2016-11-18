import tests: heterogeneousData, filterGraphicData, prepareData;

auto makeDataLayout(R)(string title, R hdata)
{
    import data_layout: DataLayout;
    import tests: Bar, Foo, Data;
    import taggedalgebraic: get;

    auto data_layout = new DataLayout(title);

    foreach(ref e; hdata)
    {
        alias Kind = typeof(e.kind);
        final switch(e.kind)
        {
            case Kind._data:
                auto header = "Data\0";
                data_layout.addGroup!Data(e.get!Data, header);
            break;
            case Kind._bar:
                auto header = "-----------Bar\0";
                data_layout.addGroup!Bar(e.get!Bar, header);
            break;
            case Kind._foo:
                auto header = "**************************Foo\0";
                data_layout.addGroup!Foo(e.get!Foo, header);
            break;
        }
    }

    return data_layout;
}

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
    gui.addData(heterogeneousData.filterGraphicData.prepareData);
    auto dl = makeDataLayout("Heterogeneous data", heterogeneousData);
    gui.addDataLayout(dl);
    gui.centerCamera();
    gui.run();
    gui.close();
    destroy(gui);

    return 0;
}
