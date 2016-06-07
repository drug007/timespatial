import test_viewer: TestViewer;

import data_provider: DataProvider, TimeSpatial;
import data_layout: IDataLayout, DataLayout, DataLayout2;
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


auto makeDataLayout1(string title)
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
    auto data_layout1 = makeDataLayout1("Widget1");
    auto data_layout2 = new DataLayout2("Widget2", data4D);

    IDataLayout[] data_layout;
    data_layout ~= data_layout1;
    data_layout ~= data_layout2;

    auto dprovider = DataProvider([data4D], data_layout);

    auto gui = new TestViewer(width, height, "Test gui", dprovider);
    auto max_value = dprovider.box.max;
    auto min_value = dprovider.box.min;
    gui.setMatrices(max_value, min_value);
    gui.run();
    gui.close();
    destroy(gui);

    return 0;
}
