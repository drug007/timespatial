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

template isFieldPublic(AggregateType, alias string FieldName)
{
    mixin("enum s = __traits(getProtection, AggregateType." ~ FieldName ~ ");");
    enum isFieldPublic = (s == "public") ? true : false;
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

import std.experimental.allocator.mallocator : Mallocator;
import std.experimental.allocator.building_blocks.stats_collector : StatsCollector, Options;

alias Allocator = StatsCollector!(Mallocator, Options.all, Options.all);

static Allocator allocator;

static ~this()
{
    debug
    {
        import std.stdio : File;

        auto f = "stats_collector.txt";
        Allocator.reportPerCallStatistics(File(f, "w"));
        allocator.reportStatistics(File(f, "a"));
    }
}

//class DataItem(TT, alias Kind kind = Kind.Regular) : BaseDataItem
//{
//    @disable
//    this();

//    alias T = Unqual!TT;

//    const(T)* ptr;
//    string header;

//    static if(kind == Kind.Converted)
//    {
//        const(T) the_copy;
//    }

//    static if(kind != Kind.Disabled)
//    {
//        mixin build!T;
//    }

//    static auto make(T, alias Kind K = Kind.Regular)(ref const(T) t, string header = "")
//    {
//        import std.conv : emplace;
        
//        enum Size = __traits(classInstanceSize, DataItem!(T, K));
//        auto buffer = allocator.allocate(Size);

//        return emplace!(DataItem!(T, K))(buffer, t, header);
//    }

//    this(ref const(T) value, string header = "")
//    {
//        static if(kind == Kind.Converted)
//        {
//            the_copy = value;
//            ptr = &the_copy;
//        }
//        else
//        {
//            ptr = &value;
//        }
//        this.header = header;

//        static if(kind != Kind.Disabled)
//        {
//            mixin defineInitFunction!T;
//            initFunction();
//        }
//    }

//    this(const(T)* ptr)
//    {

//        this(*ptr);
//    }

//    override bool draw()
//    {
//        static if(kind != Kind.Disabled)
//        {
//            if(header.length == 0)
//                header = T.stringof;

//            static if(isBasicType!T)
//            {
//                static if(kind == Kind.Timestamp)
//                {
//                    auto txt = (*ptr).timeToStringz;
//                }
//                else
//                {
//                    auto txt = (*ptr).text.toStringz;
//                }
//                igText(txt);
//                return false;
//            }
//            else static if(isSomeString!T)
//            {
//                igText((*ptr).toStringz);
//                return false;
//            }
//            else static if(is(T == struct) || isArray!T)
//            {
//                auto r = igTreeNodePtr(cast(void*)ptr, header.ptr, null);
//                if(r)
//                {
//                    foreach(ref e; di)
//                    {
//                        assert(e);
//                        e.draw();
//                    }

//                    igTreePop();
//                }
//                return r;
//            }
//            else static assert(0, "Type '" ~ T.stringof ~ "' is not supported");
//        }
//        else
//        {
//            return false;
//        }
//    }

//    mixin template build(T)
//    {
//        static if(is(T == struct))
//        {
//            mixin("BaseDataItem[" ~ (FieldNameTuple!T).length.text ~ "] di;");
//        }
//        else static if(isBasicType!T  || isSomeString!T)
//        {
//            mixin("BaseDataItem[] di;");
//        }        
//        else static if(isArray!T)
//        {
//            mixin("BaseDataItem[] di;");
//        }
//        else static assert(0, "Type '" ~ T.stringof ~ "' is not supported");
//    }

//    mixin template defineInitFunction(T)
//    {
//        static if(is(T == struct))
//        {
//            mixin template generateInitializationCode(Args...)
//            {
//                void initFunction()
//                {
//                    foreach(idx, FieldName; Args)
//                    {
//                        static if(isFieldPublic!(T, FieldName))
//                        {
//                            import std.traits : PointerTarget;
//                            /// return type of field
//                            /// if field type is pointer it's pointer target type
//                            /// else it's field type itself
//                            mixin("
//                                static if(isPointer!(typeof(T." ~ FieldName ~ ")))
//                                    alias Type = Unqual!(PointerTarget!(typeof(T." ~ FieldName ~ ")));
//                                else
//                                    alias Type = Unqual!(typeof(T." ~ FieldName ~ "));
//                            ");
                            
//                            static if(is(Type == struct)  ||
//                                        isBasicType!Type  || 
//                                        isSomeString!Type ||
//                                        isArray!Type)
//                            {
//                                import std.traits: TemplateOf, ReturnType;
//                                import std.typetuple: TypeTuple;
                                
//                                alias ATTR = TypeTuple!(__traits(getAttributes, mixin("T." ~ FieldName)));
//                                static if(ATTR.length && __traits(compiles, __traits(isSame, TemplateOf!(ATTR[0]), Attr))) // TODO Attr ожидается только первым аргументом
//                                {
//                                    static if(__traits(isSame, TemplateOf!(ATTR[0]), Attr))
//                                    {
//                                        alias FieldType = ReturnType!(ATTR[0].func);
//                                        auto converted_value = ATTR[0].func(mixin("value." ~ FieldName));
//                                        di[idx] = DataItem!(FieldType, Kind.Converted).make(converted_value);
//                                    }
//                                }
//                                else static if(hasUDA!(mixin("T." ~ FieldName), "Disabled"))
//                                {
//                                    mixin("di[idx] = DataItem!(Type, Kind.Disabled).make(value." ~ FieldName ~ ");");
//                                }
//                                else static if(hasUDA!(mixin("T." ~ FieldName), "Timestamp"))
//                                {
//                                    mixin("di[idx] = DataItem!(Type, Kind.Timestamp).make(value." ~ FieldName ~ ");");
//                                }
//                                else static if(!isBasicType!T  && !isSomeString!T)
//                                {
//                                    static if(isArray!Type)
//                                    {
//                                        mixin("const length = value." ~ FieldName ~ ".length;");
//                                        auto header = text(Type.stringof[0..$-1] // remove closing bracket
//                                            , length                             // insert length
//                                            , "]\0");                            // add closing bracket and terminal 0
//                                        mixin("di[idx] = DataItem!Type.make(value." ~ FieldName ~ ", header);");
//                                    }
//                                    else
//                                        mixin("di[idx] = DataItem!Type.make(value." ~ FieldName ~ ");");
//                                }
//                            }
//                            else static assert(0, "Type '" ~ Type.stringof ~ "' is not supported");
//                        }
//                    }
//                }
//            }

//            mixin generateInitializationCode!(FieldNameTuple!T);
//        }
//        else static if(isBasicType!T)
//        {
//            // do nothing
//            void initFunction()
//            {
//            }
//        }
//        else static if(isSomeString!T)
//        {
//            // do nothing
//            void initFunction()
//            {
//            }
//        }
//        else static if(isArray!T)
//        {
//            void initFunction()
//            {
//                di.length = value.length;
//                alias Type = typeof(value[0]);
//                foreach(i; 0..di.length)
//                    di[i] = DataItem!(Type).make(value[i], text(Unqual!Type.stringof, "(", i, ")\0"));
//            }
//        }
//        else static assert(0, "Type '" ~ T.stringof ~ "' is not supported");
//    }
//}

class DataItem(TT, alias Kind kind = Kind.Regular) : BaseDataItem
{
    import tests;
    const(Data)* data_ptr;
    static char[6] buffer;

    @disable
    this();

    this(ref const(TT) data, string str = "")
    {
        static if (is (TT == Data))
            data_ptr = &data;
        else
            data_ptr = null;
    }

    override bool draw()
    {
        if (data_ptr is null)
            return false;

        mixin (generateDraw!(Data, 0, "data_ptr", Data*));
    }
}

///// Для каждого элемента диапазона создает DataItem(T) соответствующего типа
//Array!BaseDataItem buildDataItemArray(R)(R range)
//{
//    import std.range: ElementType;
//    import std.traits: isInstanceOf, FieldTypeTuple, FieldNameTuple, isPointer, PointerTarget;

//    import taggedalgebraic: TaggedAlgebraic, get;

//    alias Element = ElementType!R;
//    alias Kind = Element.Kind;
//    alias Base = Element.Union;

//    Array!BaseDataItem result;
//    foreach(e; range)
//    {
//    	final switch(e.kind)
//        {
//            foreach(i, T; FieldTypeTuple!Base)
//            {
//                mixin("case Kind." ~ FieldNameTuple!Base[i] ~ ":");
//                    alias Type = typeof(*e.get!T);
//                    result ~= DataItem!Type.make(*e.get!T);
//                break;
//            }
//        }
//    }

//    return result;
//}

//unittest
//{
//    import taggedalgebraic;

//    union Base
//    {
//        int* i;
//        float* f;
//    }

//    auto i = 1;
//    auto f = 2.0f;

//    auto ta = [
//          TaggedAlgebraic!Base(&i)
//        , TaggedAlgebraic!Base(&f)
//    ];
//    auto di = buildDataItemArray(ta);

//    assert(di.length == ta.length);
//}

// draw
auto generateDraw(DrawType, int level, string this_name, ThisType)()
{
    import std.traits: FieldTypeTuple, FieldNameTuple;

    // used to distinct nested levels
    auto l = level.text;

    static if (isPointer!ThisType)
    {
        enum ptr =       this_name;
    }
    else
        enum ptr = "&" ~ this_name;
    

    string code = "
        import std.format : sformat;
        import core.exception : RangeError;

        buffer[0] = 0;
        auto r" ~ l ~ " = igTreeNodePtr(cast(void*) " ~ ptr ~ ", buffer.ptr, null);
        if(r" ~ l ~ ")
        {";

    foreach(i, Type; FieldTypeTuple!DrawType)
    {
        alias Name = FieldNameTuple!DrawType[i];
        enum field_name = this_name ~ "." ~ Name;
        static if(is(Type == struct)  ||
                    isArray!Type)
        {
            import std.string, std.range, std.algorithm, std.conv, std.traits;
            
            code ~= generateDraw!(Type, level+1, field_name, Type).splitLines.joiner("\n\t").array.to!string;
        }
        else static if(isBasicType!Type  || 
                       isSomeString!Type)
        {
            code ~= "
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
    }

    code ~= "

            igTreePop();
        }";

    // if 0 level then add return operator
    if (!level)
        code ~= "
        return r" ~ l ~ ";";

    return code;
}

unittest
{
    import tests;

    auto hd = heterogeneousData();

    {
        import std.stdio;

        writeln(generateDraw!(Data, 0, "data_ptr", Data*));
    }
}