import tests: heterogeneousData;
import default_viewer: DefaultViewer;

class GuiImpl(T) : DefaultViewer!T
{
    import gfm.sdl2: SDL_Event;
    import data_provider: DataObject, Data;

    this(int width, int height, string title, T hdata)
    {
        super(width, height, title, hdata);
    }

    auto filterGraphicData()
    {
        import tests: fgd = filterGraphicData;

        return hdata.fgd;
    }

    override DataObject[uint][uint] prepareData()
    {
        import tests: pd = prepareData;

        return filterGraphicData.pd;
    }

    override void makeDataLayout()
    {
        import std.algorithm: map;
        import data_layout: DataLayout;
        import tests: Bar, Foo, Data;
        import taggedalgebraic: get;

        auto data_layout = new DataLayout("Heterogeneous data");

        foreach(ref e; hdata)
        {
            alias Kind = typeof(e.value.kind);
            final switch(e.value.kind)
            {
                case Kind._data:
                    auto header = "Data\0";
                    data_layout.addGroup!Data(e.value.get!Data, header);
                break;
                case Kind._bar:
                    auto header = "-----------Bar\0";
                    data_layout.addGroup!Bar(e.value.get!Bar, header);
                break;
                case Kind._foo:
                    auto header = "**************************Foo\0";
                    data_layout.addGroup!Foo(e.value.get!Foo, header);
                break;
            }
        }

        addDataLayout(data_layout);
    }
};

alias Gui = GuiImpl!(typeof(heterogeneousData()));

int main(string[] args)
{
    import derelict.imgui.imgui: DerelictImgui;

    version(Windows)
        DerelictImgui.load("cimgui.dll");
    else
        DerelictImgui.load("DerelictImgui/cimgui/cimgui/cimgui.so");

    int width = 1800;
    int height = 768;

    auto gui = new Gui(width, height, "Test gui", heterogeneousData());
    gui.centerCamera();
    gui.run();
    gui.close();
    destroy(gui);

    return 0;
}
