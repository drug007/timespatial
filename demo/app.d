import gfm.math: box3f;

import tests: heterogeneousData;
import default_viewer: DefaultViewer;
import color_table: ColorTable;

struct DataElement
{
    @("Disabled")
    uint no;
    @("Disabled")
    uint ref_id;
    float x, y, z;
    @("Disabled")
    float r, g, b, a;
    @("Timestamp")
    long timestamp;
}

struct DataObjectImpl(E)
{
    alias DataElement = E;
    @("Disabled")
    uint no;
    @("Disabled")
    string header;
    @("Disabled")
    bool visible;
    @("Disabled")
    box3f box;

    import vertex_provider: VertexSlice;
    @("Disabled")
    VertexSlice.Kind kind;
    DataElement[] elements;
}

alias DataObject = DataObjectImpl!DataElement;

class GuiImpl(T, DataObjectType) : DefaultViewer!(T, DataObjectType)
{
    import gfm.sdl2: SDL_Event;

    this(int width, int height, string title, T hdata, ColorTable color_table, FullScreen fullscreen = FullScreen.no)
    {
        super(width, height, title, hdata, color_table, fullscreen);
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

alias Gui = GuiImpl!(typeof(heterogeneousData()), DataObject);

int main(string[] args)
{
    import derelict.imgui.imgui: DerelictImgui;

    version(Windows)
        DerelictImgui.load("cimgui.dll");
    else
        DerelictImgui.load("DerelictImgui/cimgui/cimgui/cimgui.so");

    int width = 1800;
    int height = 768;

    auto gui = new Gui(width, height, "Test gui", heterogeneousData(), ColorTable([0, 1, 12, 29]), Gui.FullScreen.yes);
    gui.run();
    gui.close();
    destroy(gui);

    return 0;
}
