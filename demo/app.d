import gfm.math: box3f;

import tests: heterogeneousData, Data;
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

    this(uint no, ref const(Data) data)
    {
        this.no = no;
        ref_id = no;
        x = data.x;
        y = data.y;
        z = data.z;
        timestamp = data.timestamp;
    }

    this(uint no, const(Data) data)
    {
        this(no, data);
    }

    this(T)(uint no, ref const(T) t)
    {
        import taggedalgebraic: get, hasType;

        if (t.hasType!Data)
        {
            this(no, t.get!Data);
            return;
        }
        assert(0);
    }
}

struct DataObjectImpl(E)
{
    alias DataElement = E;
    @("Disabled")
    uint no;
    @("Disabled")
    string title;
    @("Disabled")
    bool visible;
    @("Disabled")
    box3f box;

    import vertex_provider: VertexSlice;
    @("Disabled")
    VertexSlice.Kind kind;
    DataElement[] elements;

    this(uint no)
    {
        import std.conv : text;

        this.no = no;
        title = text(no, "\0");
        visible = true;
        box = box3f.init;
        kind = VertexSlice.Kind.LineStrip;
        elements = elements.init;
    }

    auto add(ref DataElement de)
    {
        elements ~= de;
    }

    this(const(this) other)
    {
        this.no       = other.no;
        this.title   = other.title.dup;
        this.visible  = other.visible;
        this.box      = other.box;
        this.kind     = other.kind;
        this.elements = other.elements.dup;
    }
}

alias DataObject = DataObjectImpl!DataElement;

class GuiImpl(T, DataObjectType, DataElement) : DefaultViewer!(T, DataObjectType, DataElement)
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

alias Gui = GuiImpl!(typeof(heterogeneousData()), DataObject, DataElement);

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
