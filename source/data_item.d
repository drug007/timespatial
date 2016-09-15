module data_item;

import std.conv: text;
import std.string: toStringz;
import std.typecons: scoped;
import std.traits: FieldNameTuple, isArray, isPointer, isBasicType, isSomeString, Unqual; 

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

/// return type of field
/// if field type is pointer it's pointer target type
/// else it's field type itself
mixin template defineType(AggregateType, alias string FieldName)
{
    mixin("
        static if(isPointer!(typeof(AggregateType." ~ FieldName ~ ")))
            alias Type = Unqual!(PointerTarget!(typeof(AggregateType." ~ FieldName ~ ")));
        else
            alias Type = Unqual!(typeof(AggregateType." ~ FieldName ~ "));
    ");
}

enum Kind : uint { Regular, Timestamp, Disabled, }

class DataItem(TT, alias Kind kind = Kind.Regular) : BaseDataItem
{
    @disable
    this();

    alias T = Unqual!TT;

    const(T)* ptr;
    string header;

    static if(kind != Kind.Disabled)
    {
        mixin(build!T);
    }

    this(ref const(T) value, string header = "")
    {
        ptr = &value;
        this.header = header;

        static if(kind != Kind.Disabled)
        {
            mixin(init!T);
        }
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

    static auto build(T)()
    {
        static if(is(T == struct))
        {
            size_t counter;
            foreach(FieldName; FieldNameTuple!T)
            {
                static if(isFieldPublic!(T, FieldName))
                {
                    mixin defineType!(T, FieldName);
                    
                    static if(is(Type == struct)  ||
                                isBasicType!Type  || 
                                isSomeString!Type ||
                                isArray!Type)
                    {
                        counter++;
                    }
                    else static assert(0, "Type '" ~ Type.stringof ~ "' is not supported");
                }
            }

            return "BaseDataItem[" ~ counter.text ~ "] di;";
        }
        else static if(
            isBasicType!T  || 
            isSomeString!T ||
            isArray!T)
        {
            return "BaseDataItem[] di;";
        }
        else static assert(0, "Type '" ~ T.stringof ~ "' is not supported");
    }

    static auto init(T)()
    {
        static if(is(T == struct))
        {
            string code = "";
            
            foreach(counter, FieldName; FieldNameTuple!T)
            {
                static if(isFieldPublic!(T, FieldName))
                {
                    mixin defineType!(T, FieldName);
                    
                    static if(is(Type == struct)  ||
                                isBasicType!Type  || 
                                isSomeString!Type ||
                                isArray!Type)
                    {
                        import std.traits: hasUDA;
                        static if(hasUDA!(mixin("T." ~ FieldName), "Disabled"))
                        {
                            code ~= "di[" ~ counter.text ~ "] = new DataItem!(typeof(value." ~ FieldName ~ "), Kind.Disabled)(value." ~ FieldName ~ ");\n";
                        }
                        else
                        static if(hasUDA!(mixin("T." ~ FieldName), "Timestamp"))
                        {
                            code ~= "di[" ~ counter.text ~ "] = new DataItem!(typeof(value." ~ FieldName ~ "), Kind.Timestamp)(value." ~ FieldName ~ ");\n";
                        }
                        else
                        {
                            code ~= "di[" ~ counter.text ~ "] = new DataItem!(typeof(value." ~ FieldName ~ "))(value." ~ FieldName ~ ");\n";
                        }
                    }
                    else static assert(0, "Type '" ~ Type.stringof ~ "' is not supported");
                }
            }

            return code;
        }
        else static if(isBasicType!T)
        {
            return "";
        }
        else static if(isSomeString!T)
        {
            return "";
        }
        else static if(isArray!T)
        {
            string code = "
            di.length = value.length;
            alias Type = typeof(value[0]);
            foreach(i; 0..di.length)
                di[i] = new DataItem!(Type)(value[i]);
            ";
            return code;
        }
        else static assert(0, "Type '" ~ T.stringof ~ "' is not supported");
    }
}