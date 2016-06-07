module data_layout;

import data_provider: IDataLayout, TimeSpatial;
import data_item: DataItem, BaseDataItem;

struct DataItemGroup
{
	BaseDataItem self;
	BaseDataItem[] child;
}

/// Создает иерархию виджетов, позволяющих исследовать данные
class DataLayout : IDataLayout
{
	private DataItemGroup[] _info;
	bool visible;
	private string _title;

	this(string title)
	{
		visible = true;
		_title  = title ~ "\0";
	}

	override bool draw()
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

		return false;
	}

	auto addGroup(T)(ref const(T) value, string header)
	{
		_info ~= DataItemGroup(
			new DataItem!(T)(value, header),
			null,
		);
	}

	auto addGroup(T)(const(T) value, string header)
	{
		add!T(value, header);
	}

	auto add(T)(ref const(T) value, string header) if(is(T==struct))
	{
		_info ~= DataItemGroup(
			new DataItem!(T)(value, header),
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

		_info.back.child ~= new DataItem!T(value);
	}

	auto add(T)(const(T) value) if(is(T==struct))
	{
		add!T(value);
	}
}

struct DataItemV // V means visability
{
	BaseDataItem self;
	bool visible;
}

struct DataItemGroupV // V means visability
{
	DataItemV self;
	DataItemV[] child;
}

/// Создает иерархию виджетов с возможностью включения/
/// выключения видимости данных
class DataLayout2 : IDataLayout
{
	private DataItemGroupV[] _info;
	bool visible;
	private string _title;
	private TimeSpatial _timespatial;

	this(string title, TimeSpatial timespatial)
	{
		import std.conv: text;

		visible = true;
		_title  = title ~ "\0";
		_timespatial = timespatial;

		foreach(ref r; _timespatial.record)
			add(r.dataset, r.dataset.no.text ~ "\0");
	}

	override bool draw()
	{
		import derelict.imgui.imgui;

		auto invalidated = false;

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
				if(old)
				{
					_timespatial.record[i].visible = false;
				}
				else
				{
					_timespatial.record[i].visible = true;
				}
				invalidated = true;
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

		return invalidated;
	}

	auto add(T)(ref const(T) value, string header) if(is(T==struct))
	{
		_info ~= DataItemGroupV(
			DataItemV(new DataItem!(T)(value, header), true),
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

		_info.back.child ~= DataItemV(new DataItem!T(value), true);
	}

	auto add(T)(const(T) value) if(is(T==struct))
	{
		add!T(value);
	}
}
