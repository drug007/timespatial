module data_index;

@nogc
struct Index(K, V)
{
    alias Key = K;
    alias Value = V;
    import containers.treemap: TreeMap;
    import std.experimental.allocator.mallocator: Mallocator;
    
    alias Idx = TreeMap!(Key, Value, Mallocator, "a<b", false);
    public
    {
        Idx idx = void;
    }

    alias idx this;

    int opApply(int delegate(ref Key k, ref Value v) dg)
    {
        return idx.opApply(dg);
    }
}

@nogc
struct DataIndexImpl(DataSourceHeader, DataSetHeader, DataElement, Allocator, alias ProcessElementMethod)
{
    import std.algorithm : move;

    import std.experimental.allocator.mallocator : Mallocator;
    import std.experimental.allocator : make;

    import containers.dynamicarray: DynamicArray;
    
    mixin ProcessElementMethod;

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
            processElement(e);
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

    void toMsgpack(Packer)(ref Packer packer) //const
    {
        packer.beginArray(idx.length);
        foreach(ref DataSourceIndex.Key source_no, ref DataSourceIndex.Value datasource; idx)
        {
            packer.pack(source_no, datasource.header);
            packer.beginArray(datasource.length);
            foreach(DataSetIndex.Key dataset_no, DataSetIndex.Value dataset; *datasource)
            {
                packer.pack(dataset_no, dataset.header);
                packer.beginArray(dataset.length);
                foreach(ref e; *dataset)
                {
                    packer.pack(e);
                }
            }
        }
    }

    void fromMsgpack(Unpacker)(ref Unpacker unpacker)
    {
        auto source_count = unpacker.beginArray();
        foreach(_; 0..source_count)
        {
            DataSourceIndex.Key datasource_no;
            DataSourceHeader datasource_header;

            // распаковываем номер источника и его заголовок
            unpacker.unpack(datasource_no, datasource_header);
            // создаем соответствующий источник
            auto datasource = allocator.make!DataSource(*allocator.make!DataSetIndex(), datasource_header);
            // вносим в контейнер
            idx[datasource_no] = datasource;
            // распаковываем вложенные наборы данных
            auto dataset_count = unpacker.beginArray();
            foreach(_1; 0..dataset_count)
            {
                DataSetIndex.Key dataset_no;
                DataSetHeader dataset_header;
                // считываем номер и заголовок набора данных
                unpacker.unpack(dataset_no, dataset_header);
                // создаем соответствующий набор данных
                auto dataset = allocator.make!DataSet(*allocator.make!DataElementIndex(), dataset_header);
                // вносим в источник данных
                datasource.idx[dataset_no] = dataset;
                // распаковываем вложенные наборы данных
                auto element_count = unpacker.beginArray();
                foreach(_2; 0..element_count)
                {
                    DataElement de;
                    unpacker.unpack(de);
                    dataset.insert(de);
                }
            }
        }
    }
}

private mixin template ProcessElement()
{
    void processElement(U)(ref U e)
    {
        import taggedalgebraic : hasType;
        import tests : Data;
        
        if(e.value.hasType!(Data))
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
        }
    }
}

unittest
{
    import std.algorithm : map;
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
    alias DataIndex = DataIndexImpl!(DataSource, DataSet, DataElement, Allocator, ProcessElement);
    
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

struct DataIndex(DataRange, DataSetHeader, DataElement, alias ProcessElementMethod)
{
    import std.experimental.allocator.mallocator : Mallocator;
    import std.experimental.allocator.building_blocks : Region, StatsCollector, Options;

    import tests : Data;

    alias BaseAllocator = Region!Mallocator;
    alias Allocator = StatsCollector!(BaseAllocator, Options.all, Options.all);
    alias DataIndex = DataIndexImpl!(uint, DataSetHeader, DataElement, Allocator, ProcessElementMethod);
    Allocator allocator;
    DataIndex didx;

    alias Key = DataIndex.Key;
    alias Value = DataIndex.Value;

	this(DataRange hdata)
	{
        allocator = Allocator(BaseAllocator(16 * 1024 * 1024));
        didx = DataIndex(allocator, hdata);
    }

    auto opApply(int delegate(ref Key k, ref Value v) dg)
    {
        return didx.opApply(dg);
    }
}