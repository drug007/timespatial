module datawidget;

import data_provider: IDataWidget;
import infoof: IInfoOf, InfoOf;

struct InfoOfFrame
{
	IInfoOf self;
	IInfoOf[] child;
}

/// Создает иерархию виджетов, позволяющих исследовать данные
class DataWidget : IDataWidget
{
	private InfoOfFrame[] _info;
	bool visible;
	private string _title;

	this(string title)
	{
		visible = true;
		_title  = title ~ "\0";
	}

	override void draw()
	{
		import derelict.imgui.imgui;

		igSetNextWindowSize(ImVec2(400,600), ImGuiSetCond_FirstUseEver);
		igBegin(_title.ptr, &visible);
		version(widget_clipping_enabled)
		{
			import imgui_helpers: ImGuiListClipper;
			
			auto clipper = ImGuiListClipper(cast(int)_info.length, igGetTextLineHeightWithSpacing());
			size_t start = clipper.DisplayStart;
			size_t end = clipper.DisplayEnd;
		}
		else
		{
			size_t start = 0;
			size_t end = _info.length;
		}
		foreach(size_t i; start..end)
		{
			auto r = _info[i].self.draw();
			if(r)
			{
				igIndent();
				foreach(ref c; _info[i].child)
					c.draw();
				igUnindent();
			}
		}
		version(widget_clipping_enabled) clipper.End();
		igEnd();
	}

	auto add(T)(ref const(T) value, string header) if(is(T==struct))
	{
		_info ~= InfoOfFrame(
			new InfoOf!(T)(value, header),
			null,
		);
	}

	auto add(T)(const(T) value, string header) if(is(T==struct))
	{
		add!T(value, header);
	}

	auto add(T)(ref const(T) value) if(is(T==struct))
	{
	    import std.array: back;

		_info.back.child ~= new InfoOf!T(value);
	}

	auto add(T)(const(T) value) if(is(T==struct))
	{
		add!T(value);
	}
}

struct InfoOfV // V means visability
{
	IInfoOf self;
	bool visible;
}

struct InfoOfFrameV // V means visability
{
	InfoOfV self;
	InfoOfV[] child;
}

/// Создает иерархию виджетов с возможностью включения/
/// выключения видимости данных
class DataWidget2 : IDataWidget
{
	private InfoOfFrameV[] _info;
	bool visible;
	private string _title;

	this(string title)
	{
		visible = true;
		_title  = title ~ "\0";
	}

	override void draw()
	{
		import derelict.imgui.imgui;

		igSetNextWindowSize(ImVec2(400,600), ImGuiSetCond_FirstUseEver);
		igBegin(_title.ptr, &visible);
		version(widget_clipping_enabled)
		{
			import imgui_helpers: ImGuiListClipper;
			
			auto clipper = ImGuiListClipper(cast(int)_info.length, igGetTextLineHeightWithSpacing());
			size_t start = clipper.DisplayStart;
			size_t end = clipper.DisplayEnd;
		}
		else
		{
			size_t start = 0;
			size_t end = _info.length;
		}
		foreach(size_t i; start..end)
		{
			auto old = _info[i].self.visible;
			igPushIdInt(cast(int) i);
			igCheckbox("", &_info[i].self.visible);
			igPopId();
			igSameLine();

			if(old != _info[i].self.visible)
			{
				import std.stdio;
				writeln(123);
			}

			auto r = _info[i].self.self.draw();
			if(r)
			{
				igIndent();
				foreach(ref c; _info[i].child)
					c.self.draw();
				igUnindent();
			}
		}
		version(widget_clipping_enabled) clipper.End();
		igEnd();
	}

	auto add(T)(ref const(T) value, string header) if(is(T==struct))
	{
		_info ~= InfoOfFrameV(
			InfoOfV(new InfoOf!(T)(value, header), true),
			null,
		);
	}

	auto add(T)(const(T) value, string header) if(is(T==struct))
	{
		add!T(value, header);
	}

	auto add(T)(ref const(T) value) if(is(T==struct))
	{
	    import std.array: back;

		_info.back.child ~= InfoOfV(new InfoOf!T(value), true);
	}

	auto add(T)(const(T) value) if(is(T==struct))
	{
		add!T(value);
	}
}
