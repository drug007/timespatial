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

    /// sort the contents by BaseDataItem.order_no
    void sort();
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

	auto addGroup(T)(ref const(T) value, string header) if (!isInstanceOf!(DataItem, T))
	{
		_info ~= DataItemGroup(
			new DataItem!(T)(value, header),
			null,
		);
	}

	auto addGroup(T)(const(T) value, string header) if (!isInstanceOf!(DataItem, T))
	{
		addGroup!T(value, header);
	}

	auto add(T)(ref const(T) value, string header = "") if (!isInstanceOf!(DataItem, T))
	{
	    import std.array: back;

	    _info.back.child ~= new DataItem!T(value, header);
	}

	auto add(T)(const(T) value, string header = "") if (!isInstanceOf!(DataItem, T))
	{
		add!T(value, header);
	}

	auto addGroupRaw(T)(ref T value)
	{
		import std.array: back;

		_info ~= value;
	}

	auto addItemRaw(T)(ref T value)
	{
		import std.array: back;

		_info.back.child ~= value;
	}

	void sort()
	{
		// Сортируем трассы по номеру цели, а не внутреннему номеру
        import std.algorithm : sort;
        import std.array : array;
        
        foreach(ref group; _info)
        {
            auto tmp = group.child.sort!((a,b)=>a.order_no < b.order_no).array;
            group.child = tmp;
        }
	}
}
