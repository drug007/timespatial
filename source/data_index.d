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

struct DataIndex0(DataSource, DataSet, DataElement, AllowableTypes...)
{
    import containers.dynamicarray: DynamicArray;

    import std.experimental.allocator.mallocator : Mallocator;
    import std.experimental.allocator.building_blocks : Region, StatsCollector, Options;
    import std.experimental.allocator : make;

    static struct ByDataSet
    {
        ByElementIndex* idx_ptr;
        DataSet dataset;

        this(ByElementIndex* idx_ptr, ref const(DataSet) dataset)
        {
            this.idx_ptr = idx_ptr;
            this.dataset = dataset;
        }
    }

    static struct BySource
    {
        BySetIndex* idx_ptr;
        DataSource source;

        this(BySetIndex* idx_ptr, const(DataSource) source)
        {
            this.idx_ptr = idx_ptr;
            this.source = source;
        }
    }

    alias ByElementIndex = DynamicArray!(DataElement, Mallocator, false);
    alias BySetIndex = Index!(uint, ByDataSet);
    alias BySourceIndex = Index!(uint, BySource);
    
    alias Allocator = StatsCollector!(Region!Mallocator, Options.all, Options.all);
    Allocator allocator;
    BySourceIndex idx;
    alias idx this;

    this(R)(R hs)
    {
        allocator = Allocator(Region!Mallocator(1024 * 1024));
        idx = BySourceIndex();
        foreach(ref e; hs)
        {
            import taggedalgebraic: hasType;

            foreach(T; AllowableTypes)
            {
                if(e.value.hasType!(T))
                {
                    BySource by_source;
                    if (!idx.containsKey(e.value.id.source))
                    {
                        by_source = BySource(allocator.make!BySetIndex(), DataSource(e.value.id.source));
                        idx[e.value.id.source] = by_source;
                    }
                    else
                    {
                        by_source = idx[e.value.id.source];
                    }
                    if(!by_source.idx_ptr.containsKey(e.value.id.no))
                    {
                        auto dataset = DataSet(e.value.id.no, e.value);
                        (*by_source.idx_ptr)[e.value.id.no] = ByDataSet(allocator.make!ByElementIndex(), dataset);
                    }
                    (*by_source.idx_ptr)[e.value.id.no].idx_ptr.insert(DataElement(e.index, e.value));

                    break;
                }
            }
        }
    }

    ~this()
    {
        debug
        {
            import std.file : remove;
            import std.stdio : File;

            auto f = "stats_collector.txt";
            Allocator.reportPerCallStatistics(File(f, "w"));
            allocator.reportStatistics(File(f, "a"));
        }
    }
}

unittest
{
    import std.algorithm : map;
    import std.typecons : AliasSeq;
    import tests : heterogeneousData, Data;

    static struct DataElement
    {
        size_t no;
        this(T)(size_t no, ref const(T) data)
        {
            this.no = no;
        }
    }

    static struct DataSet
    {
        size_t no;
        this(T)(size_t no, ref const(T) data)
        {
            this.no = no;
        }
    }

    static struct DataSource
    {
        size_t no;
        this(size_t no)
        {
            this.no = no;
        }
    }

    auto hs  = heterogeneousData();
    alias DataIndex = DataIndex0!(DataSource, DataSet, DataElement, AliasSeq!(Data));
    auto idx = DataIndex(hs);

    version(none)
    {
        import std.stdio;
        foreach(ref DataIndex.BySourceIndex.Key k, ref DataIndex.BySourceIndex.Value v; idx)
        {
            writeln(k, ": ", v);
            foreach(ref DataIndex.BySetIndex.Key k2, ref DataIndex.BySetIndex.Value v2; *v.idx_ptr)
            {
                writeln("\t", k2, ": ", v2);
                foreach(ref e; *v2.idx_ptr)
                {
                    writeln("\t\t", e);
                }
            }
        }
    }

    assert(!idx.containsKey(999)); // не существует источника номер 999
    assert(idx.containsKey(29));   // источник номер 29 существует

    auto src = idx[29]; // выбираем источник номер 29
    assert(src.idx_ptr.length == 2);  // у источника номер 29 имеется два набора данных

    assert(!src.idx_ptr.containsKey(888)); // источник номер 29 не содержит набор данных с номером 888
    assert(src.idx_ptr.containsKey(1));    // источник номер 29 содержит набор данных с номером 1

    // выбираем набор данных с номером 1
    auto ds0 = (*src.idx_ptr)[1];     // один вариант выбора набора данных с номером 1
    auto ds = src.idx_ptr.opIndex(1); // другой вариант выбора набора данных с номером 1
    assert(ds0 is ds);        // оба варианты дают один и тот же результат
    assert(ds.idx_ptr.length == 29);  // набор данных имеет 29 элементов

    import std.algorithm: equal;
    assert((*ds.idx_ptr)[].map!"a.no".equal([61, 63, 65, 67, 69, 71, 73, 75, 77, 79, 81, 83, 85, 87, 89, 91, 93, 95, 97, 99, 101, 103, 105, 107, 109, 111, 113, 115, 117]));

    import tests: Id;
    assert(hs[ds.idx_ptr.opIndex(1).no].value.id == Id(29, 1));
    assert(hs[ds.idx_ptr.opIndex(1).no].value.state == Data.State.Middle);
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