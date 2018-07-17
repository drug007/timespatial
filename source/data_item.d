module data_item;

import std.container: Array;
import std.conv: text;
import std.string: toStringz;
import std.typecons: scoped;
import std.traits: FieldNameTuple, isArray, isPointer, isBasicType, isSomeString, 
    Unqual, hasUDA, getUDAs, ReturnType;
                        
import derelict.imgui.imgui: igTreeNodePtr, igText, igIndent, igUnindent, igTreePop;

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

abstract class BaseDataItem
{
public:
    bool draw();

    // определяет порядок сортировки при выводе в виде DataLayout, для смены сортировки необходимо изменить данное поле
    // и отсортировать конейнер, содержащий BaseDataItem по возрастанию/убыванию
    uint order_no;

    bool visible;

    this()
    {
        visible = true;
    }
}

// Определяет способ вывода на экран
// по умолчанию
// как время
// не выводить
// преобразовать в другой тип
enum Kind : uint { Regular, Timestamp, Disabled, Converted}

struct Attr(alias F)
{
    alias func = F;
}

class DataItem(TT, alias Kind kind = Kind.Regular) : BaseDataItem
{
    @disable
    this();

    alias T = Unqual!TT;

    const(T)* data_ptr;
    // used to convert data to textual form
    // before passing to imgui widget for rendering
    // because all wigdets are rendered in consequece
    // it's safe to have one static buffer for all
    static char[128] buffer;

    string header;

    this(ref const(TT) data, string header = "")
    {
        data_ptr = &data;

        if (header == "")
            this.header = T.stringof ~ "\0";
        else
            this.header = header ~ "\0";
    }

    static auto make(T, alias Kind K = Kind.Regular)(ref const(T) t, string header = "")
    {
        return new DataItem!(T, K)(t, header);
    }

    override bool draw()
    {
        import std.format : sformat;
        import core.exception : RangeError;

        if (data_ptr is null)
            return false;

        mixin (generateDraw!(T*, "data_ptr"));
    }
}

/// Для каждого элемента диапазона создает DataItem(T) соответствующего типа
Array!BaseDataItem buildDataItemArray(R)(R range)
{
    import std.range: ElementType;
    import std.traits: isInstanceOf, FieldTypeTuple, FieldNameTuple, isPointer, PointerTarget;

    import taggedalgebraic: TaggedAlgebraic, get;

    alias Element = ElementType!R;
    alias Kind = Element.Kind;
    alias Base = Element.Union;

    Array!BaseDataItem result;
    foreach(e; range)
    {
    	final switch(e.kind)
        {
            foreach(i, T; FieldTypeTuple!Base)
            {
                mixin("case Kind." ~ FieldNameTuple!Base[i] ~ ":");
                    alias Type = typeof(*e.get!T);
                    result ~= new DataItem!Type(*e.get!T);
                break;
            }
        }
    }

    return result;
}

unittest
{
    import taggedalgebraic;

    union Base
    {
        int* i;
        float* f;
    }

    auto i = 1;
    auto f = 2.0f;

    auto ta = [
          TaggedAlgebraic!Base(&i)
        , TaggedAlgebraic!Base(&f)
    ];
    auto di = buildDataItemArray(ta);

    assert(di.length == ta.length);
}

/// OriginFieldType is type of a field being drawing
/// field_name is a name of the field
/// level is number of nesting (with 0 as the upper level)
auto generateDraw(OriginFieldType, string field_name, int level = 0)()
{
    import std.traits: FieldTypeTuple, FieldNameTuple, PointerTarget;
    import std.array : appender;

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
        {";

    static if(is(FieldType == struct))
    {
        code ~= "
            auto r" ~ l ~ " = igTreeNodePtr(cast(void*) " ~ ptr ~ ", " ~ l ~ " ? \"" ~ FieldType.stringof ~ "\".toStringz : header.ptr, null);
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
            auto r" ~ l ~ " = igTreeNodePtr(cast(void*) " ~ ptr ~ ", " ~ l ~ " ? \"" ~ FieldType.stringof ~ "\".toStringz : header.ptr, null);
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

unittest
{
    import tests;

    auto hd = heterogeneousData();

    {
        import std.stdio;

        writeln(generateDraw!(Data*, "data_ptr"));
    }
}