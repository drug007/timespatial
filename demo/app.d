import test_gui: TestGui;

import data_provider: DataProvider, TimeSpatial;
import datawidget: IDataWidget, DataWidget, DataWidget2;
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


auto makeDataWidget1(string title)
{
    bar = Bar(100, "some text");
    foo = Foo([bar, bar, bar, bar], "other text", size_t.min);
    foo_bar = FooBar(foo, [foo, foo, foo], "another text", int.max);

    auto data_widget = new DataWidget(title);
    data_widget.add!FooBar(foo_bar, "header");

    return data_widget;
}

auto makeDataWidget2(string title, TimeSpatial data)
{
    import std.conv: text;

    auto data_widget = new DataWidget2(title);

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
    auto data_widget1 = makeDataWidget1("Widget1");
    auto data_widget2 = new DataWidget2("Widget2", data4D);

    IDataWidget[] data_widget;
    data_widget ~= data_widget1;
    data_widget ~= data_widget2;

    auto dprovider = DataProvider([data4D], data_widget);

    auto gui = new TestGui(width, height, dprovider);
    auto max_value = dprovider.box.max;
    auto min_value = dprovider.box.min;
    gui.setMatrices(max_value, min_value);
    gui.run();
    gui.close();
    destroy(gui);

    return 0;
}
