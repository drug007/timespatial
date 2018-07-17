module data_layout;

import std.traits : isInstanceOf;

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

/// Создает иерархию виджетов, позволяющих исследовать данные
class DataLayout(Range) : IDataLayout
{
	private Range _range;
	private string header;
	private bool _uncollapsed;

	// used to convert data to textual form
    // before passing to imgui widget for rendering
    // because all wigdets are rendered in consequece
    // it's safe to have one static buffer for all
    static char[128] buffer;

    this(string header, Range r)
	{
		this.header  = header ~ "\0";
		_uncollapsed = true;
		_range = r;
	}

	override bool draw()
	{
		import derelict.imgui.imgui;

		igSetNextWindowSize(ImVec2(400,600), ImGuiCond_FirstUseEver);
		igBegin(header.ptr, &_uncollapsed);
		version(widget_clipping_enabled)
		{
			import imgui_helpers: ImGuiListClipper;
			
			auto clipper = ImGuiListClipper(cast(int)_range.length, igGetTextLineHeightWithSpacing());
			size_t start = clipper.DisplayStart;
			size_t end = clipper.DisplayEnd;
		}
		else
		{
			size_t start = 0;
			size_t end = _range.length;
		}
		foreach(size_t i; start..end)
		{
			import taggedalgebraic : get;
			import tests : Data, Bar, Foo;
			import data_item : generateDraw;
				
	        alias Kind = typeof(_range[i].kind);
	        final switch(_range[i].kind)
	        {
	            case Kind._data:
	                mixin (generateDraw!(Data*, "_range[i].get!(Data*)", 1));
	            break;
	            case Kind._bar:
	                mixin (generateDraw!(Bar*, "_range[i].get!(Bar*)", 1));
	            break;
	            case Kind._foo:
	                mixin (generateDraw!(Foo*, "_range[i].get!(Foo*)", 1));
	            break;
	        }
		}
		version(widget_clipping_enabled) clipper.End();
		igEnd();

		return false;
	}
}
