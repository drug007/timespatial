module data_index;
import color_table : ColorTable;

struct DataIndex(DataRange, DataObjectType)
{
	DataObjectType[uint][uint] idata;

    alias idata this;

	this(DataRange hdata, ref const(ColorTable) color_table)
	{
        import std.conv : text;
        import std.range : ElementType;
        import std.traits : isInstanceOf;
        import taggedalgebraic : TaggedAlgebraic;
        import vertex_provider : VertexSlice;

        alias ValueType = typeof(ElementType!DataRange.value);

        static assert(isInstanceOf!(TaggedAlgebraic, ValueType));

        alias DataElement = DataObjectType.DataElement;

        uint element_index;
        foreach(e; hdata)
        {
            final switch(e.value.kind)
            {
                case ValueType.Kind._data:
                {
                    auto s = idata.get(e.value.id.source, null);

                    auto clr = color_table(e.value.id.source);

                    if(s is null)
                    {
                        idata[e.value.id.source] = (DataObjectType[uint]).init;
                    }

                    if((s is null) || (e.value.id.no !in s))
                    {
                        import gfm.math: box3f;
                        idata[e.value.id.source][e.value.id.no] = DataObjectType(
                            e.value.id.no, 
                            text(e.value.id.no, "\0"),
                            true, // visible
                            box3f(e.value.x, e.value.y, e.value.z, e.value.x, e.value.y, e.value.z), 
                            VertexSlice.Kind.LineStrip, 
                            [DataElement(cast(uint)e.index, cast(uint)e.index, e.value.x, e.value.y, e.value.z, clr.r, clr.g, clr.b, clr.a, e.value.timestamp)]);
                    }
                    else
                    {
                        s[e.value.id.no].elements ~= DataElement(cast(uint)e.index, cast(uint)e.index, e.value.x, e.value.y, e.value.z, clr.r, clr.g, clr.b, clr.a, e.value.timestamp);
                        import data_provider: updateBoundingBox;
                        import gfm.math: vec3f;
                        auto vec = vec3f(e.value.x, e.value.y, e.value.z);
                        updateBoundingBox(s[e.value.id.no].box, vec);
                    }
                    break;
                }
                case ValueType.Kind._bar:
                {
                    break;
                }
                case ValueType.Kind._foo:
                {
                    break;
                }
            }
        }
    }
}