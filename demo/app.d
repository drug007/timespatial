import test_gui: TestGui;

import data_provider: DataProvider, TimeSpatial;
import datawidget: DataWidget;
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


auto makeDataWidget1()
{
    bar = Bar(100, "some text");
    foo = Foo([bar, bar, bar, bar], "other text", size_t.min);
    foo_bar = FooBar(foo, [foo, foo, foo], "another text", int.max);

    auto data_widget = new DataWidget("Widget1");
    data_widget.add!FooBar(foo_bar, "header");

    return data_widget;
}

auto makeDataWidget2(TimeSpatial data)
{
    import std.conv: text;

    auto data_widget = new DataWidget("Widget2");

    foreach(ref ds; data.dataset)
        data_widget.add(ds, ds.no.text ~ "\0");

    return data_widget;
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
    auto data_widget1 = makeDataWidget1();
    auto data_widget2 = makeDataWidget2(data4D);

    auto dprovider = DataProvider([data4D], [data_widget1, data_widget2]);

    auto gui = new TestGui(width, height, dprovider);
    auto max_value = dprovider.box.max;
    auto min_value = dprovider.box.min;
    gui.setMatrices(max_value, min_value);
    gui.run();
    gui.close();
    destroy(gui);

    return 0;
}
