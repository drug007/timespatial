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
    @("Timestamp")
    long timestamp;
    @property
    position()
    {
        import gfm.math : vec3f;
        return vec3f(x, y, z);
    }

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

        if (t.hasType!(Data*))
        {
            this(no, *t.get!(Data*));
            return;
        }
        assert(0);
    }
}

struct DataSetHeader
{
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

    this(uint no)
    {
        import std.conv : text;

        this.no = no;
        title   = text(no, "\0");
        visible = true;
        box     = box3f.init;
        kind    = VertexSlice.Kind.LineStrip;
    }
}

struct DataSourceHeader
{
    uint no;

    this(uint no)
    {
        this.no = no;
    }
}

import data_index : DataIndex;

alias HDataRange = typeof(heterogeneousData());
alias HDataIndex = DataIndex!(HDataRange, DataSourceHeader, DataSetHeader, DataElement, ProcessElement);

class GuiImpl(HData, HDataIndex) : DefaultViewer!(HData, HDataIndex)
{
    import gfm.sdl2 : SDL_Event;
    import vertex_provider : VertexProvider;
    import data_layout : DataLayout;

    this(int width, int height, string title, ref HData data, ref HDataIndex data_index, ColorTable color_table, FullScreen fullscreen = FullScreen.no)
    {
        super(width, height, title, data, data_index, color_table, fullscreen);
    }

    override void makeDataLayout()
    {
        import std.algorithm: map;
        import data_layout: DataLayout;
        import tests: Bar, Foo, Data;
        import taggedalgebraic: get;

        auto data_layout = new DataLayout("Heterogeneous data");

        foreach(ref e; *data)
        {
            alias Kind = typeof(e.value.kind);
            final switch(e.value.kind)
            {
                case Kind._data:
                    auto header = "Data\0";
                    data_layout.addGroup(*e.value.get!(Data*), header);
                break;
                case Kind._bar:
                    auto header = "-----------Bar\0";
                    data_layout.addGroup(*e.value.get!(Bar*), header);
                break;
                case Kind._foo:
                    auto header = "**************************Foo\0";
                    data_layout.addGroup(*e.value.get!(Foo*), header);
                break;
            }
        }

        addDataLayout(data_layout);
    }

    override VertexProvider makeVertexProvider(ref const(DataSet) dataset, ref const(Color) clr)
    {
        import std.algorithm : map;
        import std.array : array;
        import gfm.math : vec3f, vec4f;
        import vertex_provider : Vertex, VertexSlice;

        auto vertices = dataset.idx[].map!(a=>Vertex(
            vec3f(a.x, a.y, a.z),              // position
            vec4f(clr.r, clr.g, clr.b, clr.a), // color
        )).array;

        auto uniq_id = genVertexProviderHandle();
        return new VertexProvider(uniq_id, vertices, [
            VertexSlice(dataset.header.kind, 0, vertices.length),
            VertexSlice(VertexSlice.Kind.Points, 0, vertices.length),
        ]);
    }

    override void addDataSetLayout(DataLayout dl, ref const(DataSet) dataset)
    {
        import std.conv : text;
        import data_item : BaseDataItem, DataItem, timeToString;

        static class CustomDataItem : BaseDataItem
        {
            string header;
            BaseDataItem[] di;

            override bool draw()
            {
                import derelict.imgui.imgui: igTreeNodePtr, igText, igIndent, igUnindent, igTreePop;

                auto r = igTreeNodePtr(cast(void*)this, header.ptr, null);
                if(r)
                {
                    igIndent();
                    foreach(e; di)
                    {
                        assert(e);
                        e.draw();
                    }
                    igUnindent();

                    igTreePop();
                }
                return r;
            }
        }

        auto cdi = new CustomDataItem();
        cdi.header = text(dataset.header.no, "\0");
        foreach(ref e; dataset)
            cdi.di ~= new DataItem!DataElement(e, e.timestamp.timeToString);

        dl.addItemRaw!CustomDataItem(cdi);
    }
};

mixin template ProcessElement()
{
    void processElement(U)(ref U e)
    {
        import taggedalgebraic : hasType;
        import data_index : create;
        import tests : Data;
        
        if(e.value.hasType!(Data*))
        {
            DataSource datasource;
            if (!idx.containsKey(e.value.id.source))
            {
                auto datasource_header = DataSourceHeader(e.value.id.source);
                datasource = allocator.create!DataSource(datasource_header);
                idx[e.value.id.source] = datasource;
            }
            else
            {
                datasource = idx[e.value.id.source];
            }
            DataSet dataset;
            if(!datasource.containsKey(e.value.id.no))
            {
                auto dataset_header = DataSetHeader(e.value.id.no);
                dataset = allocator.create!DataSet(dataset_header);
                datasource.idx[e.value.id.no] = dataset;
            }
            else
            {
                dataset = datasource.idx[e.value.id.no];
            }
            auto de = DataElement(e.index, e.value);
            dataset.insert(de);
        }
    }
}

alias Gui = GuiImpl!(HDataIndex.DataRange, HDataIndex.DataIndex);

int main(string[] args)
{
    import derelict.imgui.imgui: DerelictImgui;

    version(Windows)
        DerelictImgui.load("cimgui.dll");
    else
        DerelictImgui.load(["DerelictImgui/cimgui/cimgui/cimgui.so", "/usr/local/lib/cimgui.so", "/usr/lib/x86_64-linux-gnu/cimgui.so"]);

    int width = 1800;
    int height = 768;

    auto hdata = heterogeneousData();
    auto data_index = HDataIndex(hdata);
    auto gui = new Gui(width, height, "Test gui", hdata, data_index.didx, ColorTable([0, 1, 12, 29]), Gui.FullScreen.yes);
    gui.run();
    gui.close();
    destroy(gui);

    return 0;
}
