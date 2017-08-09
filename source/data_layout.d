module data_layout;

import std.traits : isInstanceOf;

auto timeToStringz(long timestamp)
{
    import std.string: toStringz;

    return timestamp.timeToString.toStringz;
}

auto timeToString(long timestamp)
{
    import std.algorithm: min;
    import std.datetime: SysTime;
    import std.string: lastIndexOf;

    auto str = timestamp.SysTime.toUTC.toISOExtString;
    auto idx = lastIndexOf(str, ".");
    if(idx == -1)
        return str;
    
    return str[0..min(idx + 3, $)];
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

		igSetNextWindowSize(ImVec2(400,600), ImGuiSetCond_FirstUseEver);
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
        mixin (generateDraw!"_range[start..end]");
		version(widget_clipping_enabled) clipper.End();
		igEnd();

		return false;
	}
}

/// OriginFieldType is type of a field being drawing
/// field_name is a name of the field
/// level is number of nesting (with 0 as the upper level)
auto generateDraw(OriginFieldType, string field_name, int level = 0)()
{
	import std.traits: FieldTypeTuple, FieldNameTuple, PointerTarget, isArray, 
		isPointer, isBasicType, isSomeString, Unqual;
    import std.array : appender;
    import std.conv : text;

    // textual representation of current level
    enum l = level.text;

    // igTreeNodePtr need the first argument to be pointer
    // so if the field is pointer passes it directly otherwise
    // pass a pointer to the field
    //
    // ptr is a pointer to the field, if the field is a pointer use it directly
    // FieldType is a type of the pointer target 
    static if (isPointer!OriginFieldType)
    {
        enum ptr =       field_name;
        alias FieldType = Unqual!(PointerTarget!OriginFieldType);
    }
    else
    {
        enum ptr = "&" ~ field_name;
        alias FieldType = Unqual!OriginFieldType;
    }

    auto code = appender!string;
    code ~= "
        import std.format : sformat;
        import core.exception : RangeError;
        import std.conv : text;
            
        {";

    static if(is(FieldType == struct))
    {
        code ~= "
            auto r" ~ l ~ " = igTreeNodePtr(cast(void*) " ~ ptr ~ ", " ~ l ~ " ? \"" ~ FieldType.stringof ~ "\\0\" : header.ptr, null);
            if(r" ~ l ~ ")
            {";

        foreach(i, fname; FieldNameTuple!FieldType)
        {
            enum sub_field_name = field_name ~ "." ~ fname;
            alias SubFieldType = FieldTypeTuple!FieldType[i];

            version(none)
            {
                // Could be used to make output more human readable but can
                // take huge memory during compilation
                import std.string, std.range, std.algorithm, std.conv, std.traits;
                code ~= generateDraw!(SubFieldType, sub_field_name, level+1).splitLines.joiner("\n\t").array.to!string;
            }
            else
                code ~= generateDraw!(SubFieldType, sub_field_name, level+1);
        }

        code ~= "

                igTreePop();
            }";
    }
    else static if(isBasicType!FieldType  || 
                   isSomeString!FieldType ||
                   isPointer!FieldType)
    {
        code ~= "
            auto r" ~ l ~ " = false;
            try
            {
                buffer.sformat(\"%s\\0\", " ~ field_name ~ ");
            }
            catch (RangeError re)
            {
                buffer.sformat(\"%s\\0\", " ~ field_name ~ ".text[0..buffer.length-1]);
            }
            igText(buffer.ptr);";
    }
    else static if(isArray!FieldType)
    {
        import std.range : ElementType;
        import std.conv : to;

        code ~= "
            auto r" ~ l ~ " = igTreeNodePtr(cast(void*) " ~ ptr ~ ", " ~ l ~ " ? \"" ~ FieldType.stringof ~ "\\0\" : header.ptr, null);
            if(r" ~ l ~ ")
            {
                foreach(ref const e" ~ l ~ "; " ~ field_name ~ ")
                {
                    " ~ generateDraw!(Unqual!(ElementType!FieldType), "e" ~ l, level+1).to!string ~ "
                }

                igTreePop();
            }";
    }
    else
        static assert(0, "Unsupported type: " ~ FieldType.stringof);


    // if 0 level then add return operator
    static if (!level)
        code ~= "
            return r" ~ l ~ ";
        }";
    else
        code ~= "
        }";

    return code.data;
}

/// generates cases for each data type nested in TaggedAlgebraic templated type
auto generateDraw(alias string RangeStringOf)()
{
	return "
    import std.range : isInputRange;
    static assert (isInputRange!(typeof(" ~ RangeStringOf ~ ")));
    foreach(ref e; " ~ RangeStringOf ~ ")
    {
        final switch(e.kind)
        {
    		import taggedalgebraic : get;
            import std.traits : FieldTypeTuple, FieldNameTuple;
            
            alias Kind = typeof(e.kind);
            alias U = typeof(e).Union;
            foreach(j, FieldName; FieldNameTuple!U)
            {
                enum TypeName = FieldTypeTuple!U[j].stringof;
                mixin(\"
                    case Kind.\" ~ FieldName ~ \":
                        alias T = typeof(U.\" ~ FieldName ~ \");
                        mixin (generateDraw!(T, \\\"e.get!(T)\\\", 1));
                    break;
                \");
            }
        }
    }";
}

auto generateGettingTimestamp(alias string RangeStringOf)()
{
    return 
    RangeStringOf ~ ".map!((e)
    {
        import std.range : isInputRange;
        static assert (isInputRange!(typeof(" ~ RangeStringOf ~ ")));

        final switch(e.kind)
        {
            import taggedalgebraic : get;
            import std.traits : FieldTypeTuple, FieldNameTuple;
            
            alias Kind = typeof(e.kind);
            alias U = typeof(e).Union;
            foreach(j, FieldName; FieldNameTuple!U)
            {
                enum TypeName = FieldTypeTuple!U[j].stringof;
                mixin(\"
                    case Kind.\" ~ FieldName ~ \":
                        alias T = typeof(U.\" ~ FieldName ~ \");
                    return e.get!(T).timestamp;
                \");
            }
        }
    });";
}
