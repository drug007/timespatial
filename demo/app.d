import gfm.math: box3f;

import tests: heterogeneousData, indices, Data, HData;
import default_viewer: DefaultViewer;
import color_table: ColorTable;

class GuiImpl(D, Index) : DefaultViewer!(D, Index)
{
    import vertex_provider : VertexProvider;

    this(int width, int height, string title, ref D data, ref Index data_index, ColorTable color_table, FullScreen fullscreen = FullScreen.no)
    {
        super(width, height, title, data, data_index, color_table, fullscreen);
    }

    override void makeDataLayout()
    {
        import std.range : iota;
        import std.array : array;
        import data_layout: DataLayout;

        auto payload = DataSet(*data, data.length.iota.array);
        alias Payload = typeof(payload);

        auto data_layout = new DataLayout!Payload("Heterogeneous data", payload);

        addDataLayout(data_layout);
    }

    override VertexProvider makeVertexProvider(ref DataSet dataset, ref const(Color) clr)
    {
        import std.algorithm : map;
        import std.array : array;
        import gfm.math : vec3f, vec4f;
        import vertex_provider : Vertex, VertexSlice;

        auto vertices = dataset.map!(
            a=>Vertex(a.position, vec4f(clr.r, clr.g, clr.b, clr.a))
        ).array;

        auto uniq_id = genVertexProviderHandle();
        return new VertexProvider(uniq_id, vertices, [
            VertexSlice(VertexSlice.Kind.LineStrip, 0, vertices.length),
            VertexSlice(VertexSlice.Kind.Points, 0, vertices.length),
        ]);
    }

   override void addDataSetLayout(DataLayoutType)(DataLayoutType dl, ref const(DataSet) dataset)
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
}

mixin template ProcessElement()
{
   void processElement(U)(ref U e)
   {
       import taggedalgebraic : hasType;
       import tests : Data;
        
       if(e.value.hasType!(Data*))
       {
           DataSource datasource;
           if (!idx.containsKey(e.value.id.source))
           {
               auto datasource_header = DataSourceHeader(e.value.id.source);
               datasource = allocator.make!DataSource(datasource_header);
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
               dataset = allocator.make!DataSet(dataset_header);
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

import std.traits : ReturnType;
import tests : Index;

alias DataType = ReturnType!heterogeneousData;
alias IndexType = Index;
alias Gui = GuiImpl!(DataType, IndexType);

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
    import std.experimental.allocator : theAllocator;
    auto data_index = indices(theAllocator, hdata);
    auto gui = new Gui(width, height, "Test gui", hdata, data_index, ColorTable([0, 1, 12, 29]), Gui.FullScreen.no);
    gui.run();
    gui.close();
    destroy(gui);

    return 0;
}
