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

auto makeDataItem(U, alias func)(U u)
{
    alias R = ReturnType!func;
    return new DataItem!(R, kind.Converted)(u.func);
}

class DataItem(TT, alias Kind kind = Kind.Regular) : BaseDataItem
{
    @disable
    this();

    alias T = Unqual!TT;

    const(T)* ptr;
    string header;

    static if(kind == Kind.Converted)
    {
        const(T) the_copy;
    }

    static if(kind != Kind.Disabled)
    {
        mixin build!T;
    }

    this(ref const(T) value, string header = "")
    {

        static if(kind == Kind.Converted)
        {
            the_copy = value;
            ptr = &the_copy;
        }
        else
        {
            ptr = &value;
        }
        this.header = header;

        static if(kind != Kind.Disabled)
        {
            mixin defineInitFunction!T;
            initFunction();
        }
    }

    this(const(T)* ptr)
    {

        this(*ptr);
    }

    override bool draw()
    {
        static if(kind != Kind.Disabled)
        {
            if(header.length == 0)
                header = T.stringof;

            static if(isBasicType!T)
            {
                static if(kind == Kind.Timestamp)
                {
                    auto txt = (*ptr).timeToStringz;
                }
                else
                {
                    auto txt = (*ptr).text.toStringz;
                }
                igText(txt);
                return false;
            }
            else static if(isSomeString!T)
            {
                igText((*ptr).toStringz);
                return false;
            }
            else static if(is(T == struct) || isArray!T)
            {
                auto r = igTreeNodePtr(cast(void*)ptr, header.ptr, null);
                if(r)
                {
                    foreach(ref e; di)
                    {
                        assert(e);
                        e.draw();
                    }

                    igTreePop();
                }
                return r;
            }
            else static assert(0, "Type '" ~ T.stringof ~ "' is not supported");
        }
        else
        {
            return false;
        }
    }

    mixin template build(T)
    {
        static if(is(T == struct))
        {
            mixin("BaseDataItem[" ~ (FieldNameTuple!T).length.text ~ "] di;");
        }
        else static if(isBasicType!T  || isSomeString!T)
        {
            mixin("BaseDataItem[] di;");
        }        
        else static if(isArray!T)
        {
            mixin("BaseDataItem[] di;");
        }
        else static assert(0, "Type '" ~ T.stringof ~ "' is not supported");
    }

    mixin template defineInitFunction(T)
    {
        static if(is(T == struct))
        {
            mixin template generateInitializationCode(Args...)
            {
                void initFunction()
                {
                    foreach(idx, FieldName; Args)
                    {
                        static if(isFieldPublic!(T, FieldName))
                        {
                            import std.traits : PointerTarget;
                            /// return type of field
                            /// if field type is pointer it's pointer target type
                            /// else it's field type itself
                            mixin("
                                static if(isPointer!(typeof(T." ~ FieldName ~ ")))
                                    alias Type = Unqual!(PointerTarget!(typeof(T." ~ FieldName ~ ")));
                                else
                                    alias Type = Unqual!(typeof(T." ~ FieldName ~ "));
                            ");
                            
                            static if(is(Type == struct)  ||
                                        isBasicType!Type  || 
                                        isSomeString!Type ||
                                        isArray!Type)
                            {
                                import std.traits: TemplateOf, ReturnType;
                                import std.typetuple: TypeTuple;
                                
                                alias ATTR = TypeTuple!(__traits(getAttributes, mixin("T." ~ FieldName)));
                                static if(ATTR.length && __traits(compiles, __traits(isSame, TemplateOf!(ATTR[0]), Attr))) // TODO Attr ожидается только первым аргументом
                                {
                                    static if(__traits(isSame, TemplateOf!(ATTR[0]), Attr))
                                    {
                                        alias FieldType = ReturnType!(ATTR[0].func);
                                        auto converted_value = ATTR[0].func(mixin("value." ~ FieldName));
                                        di[idx] = new DataItem!(FieldType, Kind.Converted)(converted_value);
                                    }
                                }
                                else static if(hasUDA!(mixin("T." ~ FieldName), "Disabled"))
                                {
                                    mixin("di[idx] = new DataItem!(Type, Kind.Disabled)(value." ~ FieldName ~ ");");
                                }
                                else static if(hasUDA!(mixin("T." ~ FieldName), "Timestamp"))
                                {
                                    mixin("di[idx] = new DataItem!(Type, Kind.Timestamp)(value." ~ FieldName ~ ");");
                                }
                                else static if(!isBasicType!T  && !isSomeString!T)
                                {
                                    static if(isArray!Type)
                                    {
                                        mixin("const length = value." ~ FieldName ~ ".length;");
                                        auto header = text(Type.stringof[0..$-1] // remove closing bracket
                                            , length                             // insert length
                                            , "]\0");                            // add closing bracket and terminal 0
                                        mixin("di[idx] = new DataItem!Type(value." ~ FieldName ~ ", header);");
                                    }
                                    else
                                        mixin("di[idx] = new DataItem!Type(value." ~ FieldName ~ ");");
                                }
                            }
                            else static assert(0, "Type '" ~ Type.stringof ~ "' is not supported");
                        }
                    }
                }
            }

            mixin generateInitializationCode!(FieldNameTuple!T);
        }
        else static if(isBasicType!T)
        {
            // do nothing
            void initFunction()
            {
            }
        }
        else static if(isSomeString!T)
        {
            // do nothing
            void initFunction()
            {
            }
        }
        else static if(isArray!T)
        {
            void initFunction()
            {
                di.length = value.length;
                alias Type = typeof(value[0]);
                foreach(i; 0..di.length)
                    di[i] = new DataItem!(Type)(value[i], text(Unqual!Type.stringof, "(", i, ")\0"));
            }
        }
        else static assert(0, "Type '" ~ T.stringof ~ "' is not supported");
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
        int i;
        float f;
    }

    auto ta = [
          new TaggedAlgebraic!Base(2.0)
        , new TaggedAlgebraic!Base(1)
    ];
    auto di = buildDataItemArray(ta);

    assert(di.length == ta.length);
}