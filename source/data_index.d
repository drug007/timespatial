module data_index;
import color_table : ColorTable;

@nogc
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

    auto opApply(int delegate(ref K k, ref V v) dg)
    {
        return idx.opApply(dg);
    }
}

@nogc
struct DataIndex0(DataSourceHeader, DataSetHeader, DataElement, Allocator, AllowableTypes...)
{
    import std.algorithm : move;

    import std.experimental.allocator.mallocator : Mallocator;
    import std.experimental.allocator : make;

    import containers.dynamicarray: DynamicArray;

    static struct DataSet
    {
        DataSetHeader header;
        DataElementIndex idx;

        alias idx this;

        this(ref DataElementIndex idx, ref const(DataSetHeader) header)
        {
            this.idx = move(idx);
            this.header = DataSetHeader(header);
        }
    }

    static struct DataSource
    {
        DataSourceHeader header;
        DataSetIndex idx;

        alias idx this;

        this(ref DataSetIndex idx, ref const(DataSourceHeader) header)
        {
            this.idx = move(idx);
            this.header = header;
        }
    }

    alias DataElementIndex = DynamicArray!(DataElement, Mallocator, false);
    alias DataSetIndex = Index!(uint, DataSet*);
    alias DataSourceIndex = Index!(uint, DataSource*);
    
    Allocator* allocator;
    DataSourceIndex idx;
    alias idx this;

    this(R)(ref Allocator allocator, R hs)
    {
        this.allocator = &allocator;
        idx = DataSourceIndex();
        foreach(ref e; hs)
        {
            import taggedalgebraic: hasType;

            foreach(T; AllowableTypes)
            {
                if(e.value.hasType!(T))
                {
                    DataSource* datasource;
                    if (!idx.containsKey(e.value.id.source))
                    {
                        auto datasource_header = DataSourceHeader(e.value.id.source);
                        datasource = allocator.make!DataSource(*allocator.make!DataSetIndex(), datasource_header);
                        idx[e.value.id.source] = datasource;
                    }
                    else
                    {
                        datasource = idx[e.value.id.source];
                    }
                    DataSet* dataset;
                    if(!datasource.containsKey(e.value.id.no))
                    {
                        auto dataset_header = DataSetHeader(e.value.id.no);
                        dataset = allocator.make!DataSet(*allocator.make!DataElementIndex(), dataset_header);
                        datasource.idx[e.value.id.no] = dataset;
                    }
                    else
                    {
                        dataset = datasource.idx[e.value.id.no];
                    }
                    auto de = DataElement(e.index, e.value);
                    dataset.insert(de);
                    dataset.header.add(de);

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
        this(size_t no)
        {
            this.no = no;
        }

        this(const(this) other)
        {
            this.no = other.no;
        }

        void add(T)(T t)
        {
            
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

    import std.experimental.allocator.mallocator : Mallocator;
    import std.experimental.allocator.building_blocks : Region, StatsCollector, Options;
    
    alias BaseAllocator = Region!Mallocator;
    alias Allocator = StatsCollector!(BaseAllocator, Options.all, Options.all);
    alias DataIndex = DataIndex0!(DataSource, DataSet, DataElement, Allocator, AliasSeq!(Data));
    
    auto allocator = Allocator(BaseAllocator(1024 * 1024));
    
    auto hs  = heterogeneousData();
    auto idx = DataIndex(allocator, hs);

    version(none)
    {
        import std.stdio;
        foreach(DataIndex.BySourceIndex.Key source_no, DataIndex.BySourceIndex.Value dataset; idx)
        {
            writeln(source_no, ": ", dataset);
            foreach(DataIndex.BySetIndex.Key dataset_no, DataIndex.BySetIndex.Value elements; *dataset)
            {
                writeln("\t", dataset_no, ": ", elements);
                foreach(ref e; *elements)
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
    auto ds0 = src.idx[1];     // один вариант выбора набора данных с номером 1
    auto ds = src.opIndex(1); // другой вариант выбора набора данных с номером 1
    assert(ds0 is ds);        // оба варианты дают один и тот же результат
    assert(ds.length == 29);  // набор данных имеет 29 элементов

    import std.algorithm: equal;
    assert(ds.idx[].map!"a.no".equal([61, 63, 65, 67, 69, 71, 73, 75, 77, 79, 81, 83, 85, 87, 89, 91, 93, 95, 97, 99, 101, 103, 105, 107, 109, 111, 113, 115, 117]));
    assert((*ds)[].map!"a.no".equal([61, 63, 65, 67, 69, 71, 73, 75, 77, 79, 81, 83, 85, 87, 89, 91, 93, 95, 97, 99, 101, 103, 105, 107, 109, 111, 113, 115, 117]));

    import tests: Id;
    assert(hs[ds.idx[1].no].value.id == Id(29, 1));
    assert(hs[(*ds)[1].no].value.id == Id(29, 1));
    
    assert(hs[ds.idx[1].no].value.state == Data.State.Middle);
    assert(hs[(*ds)[1].no].value.state == Data.State.Middle);
}

struct DataIndex(DataRange, DataSet, DataElement)
{
    import std.typecons : AliasSeq;
    import std.experimental.allocator.mallocator : Mallocator;
    import std.experimental.allocator.building_blocks : Region, StatsCollector, Options;

    import tests : Data;

    alias BaseAllocator = Region!Mallocator;
    alias Allocator = StatsCollector!(BaseAllocator, Options.all, Options.all);
    alias DataIndex = DataIndex0!(uint, DataSet, DataElement, Allocator, AliasSeq!(Data));
    Allocator allocator;
    DataIndex didx;

    alias Key = DataIndex.Key;
    alias Value = DataIndex.Value;

	this(DataRange hdata, ref const(ColorTable) color_table)
	{
        allocator = Allocator(BaseAllocator(1024 * 1024));
        didx = DataIndex(allocator, hdata);
    }

    auto opApply(int delegate(ref Key k, ref Value v) dg)
    {
        return didx.opApply(dg);
    }
}