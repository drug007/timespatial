module data_index;
import color_table : ColorTable;

struct Index(K, V)
{
    alias Key = K;
    alias Value = V;
    import containers.treemap: TreeMap;
    import std.experimental.allocator.mallocator: Mallocator;
    
    alias Idx = TreeMap!(Key, Value, Mallocator, "a<b", false);
    private
    {
        Idx idx = void;
    }

    alias idx this;
}

struct DataIndex0
{
    import std.typecons : AliasSeq;
    import tests : heterogeneousData, Data;
    import containers.dynamicarray: DynamicArray;

    import std.experimental.allocator.mallocator : Mallocator;
    import std.experimental.allocator.building_blocks : Region;
    import std.experimental.allocator : make;

    alias AllowableType = AliasSeq!(Data);
    alias ByElementIndex = DynamicArray!(ulong, Mallocator, false);
    alias ByTrackIndex = Index!(uint, ByElementIndex*);
    alias BySourceIndex = Index!(uint, ByTrackIndex*);
    
    Region!Mallocator allocator;
    BySourceIndex idx;
    alias idx this;

    this(R)(R hs)
    {
        allocator = Region!Mallocator(1024 * 1024);
        idx = BySourceIndex();
        size_t order_no;
        foreach(ref e; hs)
        {
            import taggedalgebraic: hasType;

            foreach(T; AllowableType)
            {
                if(e.hasType!(T))
                {
                    ByTrackIndex* track_idx; 
                    if (!idx.containsKey(e.id.source))
                    {
                        track_idx = allocator.make!ByTrackIndex();
                        idx[e.id.source] = track_idx;
                    }
                    else
                    {
                        track_idx = idx[e.id.source];
                    }
                    if(!track_idx.containsKey(e.id.no))
                    {
                        (*track_idx)[e.id.no] = allocator.make!ByElementIndex();    
                    }
                    (*track_idx)[e.id.no].insert(order_no);

                    break;
                }
            }
            order_no++;
        }
    }
}

unittest
{
    import std.algorithm : map;
    import tests : heterogeneousData, Data;

    auto hs  = heterogeneousData().map!(a=>a.value);
    auto idx = DataIndex0(hs);

    version(none)
    {
        import std.stdio;
        foreach(ref DataIndex0.BySourceIndex.Key k, ref DataIndex0.BySourceIndex.Value v; idx)
        {
            writeln(k, ": ", v);
            foreach(ref DataIndex0.ByTrackIndex.Key k2, ref DataIndex0.ByTrackIndex.Value v2; *v)
            {
                writeln("\t", k2, ": ", v2);
                foreach(ref e; *v2)
                {
                    writeln("\t\t", e);
                }
            }
        }
    }

    assert(!idx.containsKey(999)); // не существует источника номер 999
    assert(idx.containsKey(29));   // источник номер 29 существует

    auto src = idx[29]; // выбираем источник номер 29
    assert(src.length == 2);  // у источника номер 29 имеется два набора данных

    assert(!src.containsKey(888)); // источник номер 29 не содержит набор данных с номером 888
    assert(src.containsKey(1));    // источник номер 29 содержит набор данных с номером 1

    // выбираем набор данных с номером 1
    auto ds0 = (*src)[1];     // один вариант выбора набора данных с номером 1
    auto ds = src.opIndex(1); // другой вариант выбора набора данных с номером 1
    assert(ds0 is ds);        // оба варианты дают один и тот же результат
    assert(ds.length == 29);  // набор данных имеет 29 элементов

    import std.algorithm: equal;
    assert((*ds)[].equal([61, 63, 65, 67, 69, 71, 73, 75, 77, 79, 81, 83, 85, 87, 89, 91, 93, 95, 97, 99, 101, 103, 105, 107, 109, 111, 113, 115, 117]));

    import tests: Id;
    assert(hs[ds.opIndex(1)].id == Id(29, 1));
    assert(hs[ds.opIndex(1)].state == Data.State.Middle);
}

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