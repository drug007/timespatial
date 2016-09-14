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

class DataItem(TT) : BaseDataItem
{
    @disable
    this();

    alias T = Unqual!TT;

    const(T)* ptr;
    string header;

    mixin(build!T);

    this(ref const(T) value, string header = "")
    {
        ptr = &value;
        this.header = header;

        mixin(init!T);
    }

    override bool draw()
    {
        if(header.length == 0)
            header = T.stringof;

        static if(isBasicType!T)
        {
            auto txt = (*ptr).text;
            igText(txt.toStringz);
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

    static auto build(T)()
    {
        static if(is(T == struct))
        {
            size_t counter;
            foreach(E; FieldNameTuple!T)
            {
                mixin("enum s = __traits(getProtection, T." ~ E ~ ");");
                static if(s == "public")
                {
                    mixin("
                        static if(isPointer!(typeof(T." ~ E ~ ")))
                            alias Type = Unqual!(PointerTarget!(typeof(T." ~ E ~ ")));
                        else
                            alias Type = Unqual!(typeof(T." ~ E ~ "));
                    ");
                    
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
            
            foreach(counter, E; FieldNameTuple!T)
            {
                mixin("enum s = __traits(getProtection, T." ~ E ~ ");");
                static if(s == "public")
                {
                    mixin("
                        static if(isPointer!(typeof(T." ~ E ~ ")))
                            alias Type = Unqual!(PointerTarget!(typeof(T." ~ E ~ ")));
                        else
                            alias Type = Unqual!(typeof(T." ~ E ~ "));
                    ");
                    
                    static if(is(T == struct)  ||
                                isBasicType!T  || 
                                isSomeString!T ||
                                isArray!T)
                    {
                        code ~= "di[" ~ counter.text ~ "] = new DataItem!(typeof(value." ~ E ~ "))(value." ~ E ~ ");\n";
                    }
                    else static assert(0, "Type '" ~ T.stringof ~ "' is not supported");
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