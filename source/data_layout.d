module data_layout;

import data_item: DataItem, BaseDataItem;

struct DataItemGroup
{
	BaseDataItem self;
	BaseDataItem[] child;
}

interface IDataLayout
{
    /// return true if during gui phase data has been changed
    /// and updating is requiring
    bool draw();
}

/// Используется как пустышка при создании групп виджетов
struct Dummy {};

/// Создает иерархию виджетов, позволяющих исследовать данные
class DataLayout : IDataLayout
{
	private DataItemGroup[] _info;
	private string _title;
	private bool _uncollapsed;

	this(string title)
	{
		_title  = title ~ "\0";
		_uncollapsed = true;
	}

	override bool draw()
	{
		import derelict.imgui.imgui;

		igSetNextWindowSize(ImVec2(400,600), ImGuiSetCond_FirstUseEver);
		igBegin(_title.ptr, &_uncollapsed);
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
		addGroup!T(value, header);
	}

	auto add(T)(ref const(T) value, string header = "")
	{
	    import std.array: back;

		_info.back.child ~= new DataItem!T(value, header);
	}

	auto add(T)(const(T) value, string header = "")
	{
		add!T(value, header);
	}
}

///// specialized data layout for Timespatial with ability
///// to control of visibility
//class TimeSpatialLayout : DataLayout
//{
//	private TimeSpatial _timespatial;
//	public bool visible;

//	this(string title, TimeSpatial timespatial)
//	{
//		import std.conv: text;

//		super(title);

//		visible = true;
//		_timespatial = timespatial;

//		foreach(ref r; _timespatial.record)
//			add(r.dataset, r.dataset.no.text ~ "\0");
//	}

//	override bool draw()
//	{
//		import derelict.imgui.imgui;

//		auto invalidated = false;

//		igSetNextWindowSize(ImVec2(400,600), ImGuiSetCond_FirstUseEver);
//		igBegin(_title.ptr, &visible);
//		version(widget_clipping_enabled)
//		{
//			import imgui_helpers: ImGuiListClipper;
			
//			auto clipper = ImGuiListClipper(cast(int)_info.length, igGetTextLineHeightWithSpacing());
//			size_t start = clipper.DisplayStart;
//			size_t end = clipper.DisplayEnd;
//		}
//		else
//		{
//			size_t start = 0;
//			size_t end = _info.length;
//		}
//		foreach(size_t i; start..end)
//		{
//			auto old = _info[i].self.visible;
//			igPushIdInt(cast(int) i);
//			igCheckbox("", &_info[i].self.visible);
//			igPopId();
//			igSameLine();

//			if(old != _info[i].self.visible)
//			{
//				if(old)
//				{
//					_timespatial.record[i].visible = false;
//				}
//				else
//				{
//					_timespatial.record[i].visible = true;
//				}
//				invalidated = true;
//			}

//			auto r = _info[i].self.draw();
//			if(r)
//			{
//				igIndent();
//				foreach(ref c; _info[i].child)
//					c.draw();
//				igUnindent();
//			}
//		}
//		version(widget_clipping_enabled) clipper.End();
//		igEnd();

//		return invalidated;
//	}
//}
