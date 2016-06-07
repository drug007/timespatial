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
    import std.datetime: SysTime;

    return timestamp.SysTime.toUTC.toISOExtString[$-9..$];
}

interface IDataItem
{
public:
    bool draw();
}

class DataItem(TT) : IDataItem if(is(TT == struct))
{
    @disable
    this();

    alias T = Unqual!TT;

    const(T)* ptr;
    string header;

    this(ref const(T) value, string header = "")
    {
        ptr = &value;
        this.header = header;
    }

    bool draw()
    {
        if(header.length == 0)
            header = T.stringof;
        auto r = igTreeNodePtr(cast(void*)ptr, header.ptr, null);
        if(r)
        {
            foreach(count, E; FieldNameTuple!T)
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
                    
                    static if(is(Type == struct))
                    {
                        mixin("
                            auto local_info = scoped!(DataItem!Type)(ptr." ~ E ~ ");
                            local_info.draw();
                        ");
                    }
                    else static if(isBasicType!Type)
                    {
                        static if(E == "timestamp")
                            mixin("auto txt = \"" ~ E ~ ": \" ~ ptr." ~ E ~ ".timeToString;");
                        else
                            mixin("auto txt = \"" ~ E ~ ": \" ~ ptr." ~ E ~ ".text;");
                            
                        igText(txt.toStringz);
                    }
                    else static if(isSomeString!Type)
                    {
                        mixin("auto txt = \"" ~ E ~ ": \" ~ ptr." ~ E ~ ";");
                            
                        igText(txt.toStringz);
                    }
                    else static if(isArray!Type)
                    {
                        import std.utf: validate, UTFException;

                        mixin("
                        	if(igTreeNodePtr(cast(void*)ptr, \"" ~ E ~ "\".toStringz, null))
                        	{
                                foreach(size_t i, e; ptr." ~ E ~ ")
	                            {
                                    import std.range: ElementType;
                                    alias ElType = Unqual!(ElementType!Type);
                                    static if(is(ElType == struct))
                                    {
                                        import std.format: sformat;
                                        char[1024] header;
                                        sformat(header, \"%s[%d]\\0\", ElType.stringof, i);
                                        auto local_info = scoped!(DataItem!ElType)(e, cast(string) header[]);
                                        local_info.draw();
                                    }
                                    else
                                    {
    	                                auto txt = e.text;
    	                                try
    	                                {
    	                                
    	                                    validate(txt);
    	                                    igText(txt.toStringz);
    	                                }
    	                                catch(UTFException e)
    	                                {
    	                                    igText(\"" ~ E ~ ": non utf text\");
    	                                }
                                    }
	                            }
	                            igTreePop();
	                        }
                        ");
                    }
                    else static if(is(Type == string))
                    {
                        mixin("auto txt = \"" ~ E ~ ": \" ~ ptr." ~ E ~ ";");
                        igText(txt.toStringz);
                    }
                    else static assert(0, "Type '" ~ Type.stringof ~ "' is not supported");
                }
            }
            igTreePop();
        }
        return r;
    }
}