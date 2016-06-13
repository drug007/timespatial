import test_viewer: TestViewer;

import data_provider: DataProvider, TimeSpatial;
import data_layout: IDataLayout, DataLayout, TimeSpatialLayout;
import test_data: testData;

struct Bar
{
    uint u;
    string str;
}

struct Foo
{
    Bar[] bar;
    string text;
    size_t l;
}

struct FooBar
{
    Foo foo;
    Foo[] foo_array;
    string str;
    int i;
}

Bar bar;
Foo foo;
FooBar foo_bar;


auto makeDataLayout(string title)
{
    bar = Bar(100, "some text");
    foo = Foo([bar, bar, bar, bar], "other text", size_t.min);
    foo_bar = FooBar(foo, [foo, foo, foo], "another text", int.max);

    auto data_layout = new DataLayout(title);
    data_layout.add!FooBar(foo_bar, "header");

    return data_layout;
}

int main(string[] args)
{
    import derelict.imgui.imgui;

    version(Windows)
        DerelictImgui.load("cimgui.dll");
    else
        DerelictImgui.load("DerelictImgui/cimgui/cimgui/cimgui.so");

    int width = 1800;
    int height = 768;

    auto data4D = new TimeSpatial(testData);
    auto data_layout = makeDataLayout("DataLayout");
    auto timespatial_layout = new TimeSpatialLayout("TimeSpatial", data4D);

    IDataLayout[] layout;
    layout ~= data_layout;
    layout ~= timespatial_layout;

    auto dprovider = DataProvider([data4D], layout);

    auto gui = new TestViewer(width, height, "Test gui", dprovider);
    auto max_value = dprovider.box.max;
    auto min_value = dprovider.box.min;
    {
        // camera initialization
        import gfm.math: vec3f;
        vec3f pos;
        
        pos.x = (max_value.x - min_value.x)/2.;
        pos.y = (max_value.y - min_value.y)/2.;
        gui.setCameraPosition(pos);

        import std.algorithm: max;
        auto size = max(pos.x, pos.y);
        gui.setCameraSize(size);
    }
    gui.run();
    gui.close();
    destroy(gui);

    return 0;
}
