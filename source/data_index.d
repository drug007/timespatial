module data_index;

/// allocates memory using an allocator and create a struct given type
///
/// allocator.make / emplace doesn't work with structs, those fields
/// are not copyable (@disable this();)
auto create(T, Allocator, Args...)(ref Allocator allocator, auto ref Args args)
{
    static if (is(T==struct))
    {
        // manually allocate memory
        auto m = allocator.allocate(T.sizeof);
        assert (m.ptr !is null);
        scope(failure) allocator.deallocate(m);

        auto obj = cast(T*) m.ptr;
        // construct the object
        import std.algorithm.mutation : move;
        static assert(args.length);
        *obj = T(move(args));

        return obj;
    }
    else static if (is(T==class))
    {
        import std.algorithm.mutation : move;

        enum classSize = __traits(classInstanceSize, T);

        // manually allocate memory
        auto m = allocator.allocate(classSize);
        assert (m.ptr !is null);
        scope(failure) allocator.deallocate(m);

        m[0 .. classSize] = typeid(T).initializer[];
        auto result = cast(T) m.ptr;
        result.__ctor(move(args));

        return result;
    }
    else
        static assert (is (T == struct) || is (T == class), "Only structures or classes can be used with " ~ __PRETTY_FUNCTION__);
}

@nogc
struct Index(Key, Value)
{
    import containers.treemap: TreeMap;
    import std.experimental.allocator.mallocator: Mallocator;

    TreeMap!(Key, Value, Mallocator, "a<b", false) idx;

    alias idx this;
}

@nogc
struct DataIndexImpl(DataSourceHeader, DataSetHeader, DataElementType, Allocator, alias ProcessElementMethod)
{
    import std.algorithm : move;

    import std.experimental.allocator.mallocator : Mallocator;
    import std.experimental.allocator : make;

    import containers.dynamicarray: DynamicArray;

    mixin ProcessElementMethod;

    alias DataElement = DataElementType;

    static class DataSet
    {
        alias Header = DataSetHeader;

        Header header;
        DataElementIndex idx;

        alias idx this;

        this(Header header)
        {
            this.idx = DataElementIndex();
            this.header = move(header);
        }
    }

    static class DataSource
    {
        alias Header = DataSourceHeader;

        Header header;
        DataSetIndex idx;

        alias idx this;

        @disable
        this();

        this(Header header)
        {
            this.idx = DataSetIndex();
            this.header = move(header);
        }
    }

    alias DataElementIndex = DynamicArray!(DataElement, Mallocator, false);
    alias DataSetIndex = Index!(uint, DataSet);
    alias DataSourceIndex = Index!(uint, DataSource);

    Allocator* allocator;
    DataSourceIndex idx;
    alias idx this;

    @disable
    this();

    this(ref Allocator allocator)
    {
        this.allocator = &allocator;
    }

    this(R)(ref Allocator allocator, R hs)
    {
        this.allocator = &allocator;
        idx = DataSourceIndex();
        build(hs);
    }

    void build(R)(R hs)
    {
        foreach(ref e; hs)
        {
            processElement(e);
        }
    }

    ~this()
    {
        debug
        {
            import std.stdio : File;

            auto f = "stats_collector.txt";
            Allocator.reportPerCallStatistics(File(f, "w"));
            allocator.reportStatistics(File(f, "a"));
        }
    }

    DataSource opIndex(uint source_no)
    {
        return idx[source_no];
    }

    DataSet opIndex(uint source_no, uint dataset_no)
    {
        return idx[source_no][dataset_no];
    }

    DataElement opIndex(uint source_no, uint dataset_no, size_t element_no)
    {
        return idx[source_no][dataset_no].idx[element_no];
    }

    void toMsgpack(Packer)(ref Packer packer) //const
    {
        packer.beginArray(idx.length);
        foreach(ref DataSourceIndex.Key source_no, ref DataSourceIndex.Value datasource; idx)
        {
            packer.pack(source_no, datasource.header);
            packer.beginArray(datasource.length);
            foreach(DataSetIndex.Key dataset_no, DataSetIndex.Value dataset; datasource)
            {
                packer.pack(dataset_no, dataset.header);
                packer.beginArray(dataset.length);
                foreach(ref e; dataset)
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
            auto datasource = allocator.create!DataSource(datasource_header);
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
                auto dataset = allocator.make!DataSet(dataset_header);
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

        if(e.value.hasType!(Data*))
        {
            DataSource datasource;
            if (!idx.containsKey(e.value.id.source))
            {
                auto datasource_header = DataSourceHeader(e.value.id.source);
                datasource = allocator.make!DataSource(datasource_header);
                idx[e.value.id.source] = datasource;
            }
            else
            {
                datasource = idx[e.value.id.source];
            }
            DataSet dataset;
            if(!datasource.containsKey(e.value.id.no))
            {
                auto dataset_header = DataSetHeader(e.value.id.no);
                dataset = allocator.make!DataSet(dataset_header);
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

    static struct Dataset
    {
        alias Id = uint;
        alias Element = Data*;

        Id id;
        import containers.dynamicarray: DynamicArray;
        import std.experimental.allocator.mallocator : Mallocator;
        DynamicArray!(Element, Mallocator) data;
        alias data this;

        this(Id id)
        {
            this.id = id;
        }

        auto opSlice()
        {
            return data[];
        }

        void toString(scope void delegate(const(char)[]) sink) const
        {
            import std.conv : text;
            sink(typeof(this).stringof);
            sink("(");
            sink(typeof(id).stringof);
            sink(": ");
            sink(id.text);
            sink(", ");
            sink(typeof(data).stringof);
            sink(": ");
            sink(data[].text);
            sink(")");
        }
    }

    static struct Source
    {
        alias Id = uint;
        alias Element = Dataset;

        Id id;
        import containers.treemap: TreeMap;
        import std.experimental.allocator.mallocator: Mallocator;

        TreeMap!(Id, Element*, Mallocator, "a<b", false) data;
        alias data this;

        this(Id id)
        {
            this.id = id;
        }

        auto opSlice()
        {
            return data[];
        }

        void toString(scope void delegate(const(char)[]) sink) const
        {
            import std.conv : text;
            sink(typeof(this).stringof);
            sink("(");
            sink(typeof(id).stringof);
            sink(": ");
            sink(id.text);
            sink(", ");
            sink(typeof(data).stringof);
            sink(": ");
            sink(data[].text);
            sink(")");
        }
    }

    import std.experimental.allocator.mallocator : Mallocator;
    import std.experimental.allocator.building_blocks : Region, StatsCollector, Options;

    alias BaseAllocator = Region!Mallocator;
    alias Allocator = StatsCollector!(BaseAllocator, Options.all, Options.all);

    auto allocator = Allocator(BaseAllocator(1024 * 1024));

    auto hs  = heterogeneousData();

    import containers.treemap: TreeMap;
    import std.experimental.allocator.mallocator: Mallocator;
    import std.experimental.allocator : make;
    import tests : HData, Data, Id;
    import taggedalgebraic : get;
    TreeMap!(Id.Source, Source*, Mallocator, "a<b", false) root;

    foreach(ref e; hs)
    {
        final switch(e.kind) with(HData.Kind)
        {
            case Data_:
                auto id = e.get!(Data*).id;
                if (!root.containsKey(id.source))
                    root[id.source] = allocator.make!Source(id.source);
                Source* source = root[id.source];
                
                if (!source.containsKey(id.no))
                    source.data[id.no] = allocator.make!Dataset(id.no);
                Dataset* dataset = source.data[id.no];

                dataset.data ~= e.get!(Data*);
            break;
            case Bar_:
            break;
            case Foo_:
            break;
        }
    }
    import std.conv : text;
    import std.stdio;
    foreach(ref source; root[])
    {
        writeln("Source: ", source.id);
        foreach(ref dataset; source.data[])
        {
            writeln("\tDataset: ", dataset.id);
            foreach(e; dataset.data[])
                writeln("\t\t", *e);
        }
    }

    assert(!root.containsKey(999)); // не существует источника номер 999
    assert(root.containsKey(29));   // источник номер 29 существует

    auto src = root[29]; // выбираем источник номер 29
    assert(src.length == 2);  // у источника номер 29 имеется два набора данных

    assert(!src.containsKey(888)); // источник номер 29 не содержит набор данных с номером 888
    assert(src.containsKey(1));    // источник номер 29 содержит набор данных с номером 1

    // выбираем набор данных с номером 1
    auto ds0 = src.data[1];   // один вариант выбора набора данных с номером 1
    auto ds = src.opIndex(1); // другой вариант выбора набора данных с номером 1
    assert(ds0 is ds);        // оба варианты дают один и тот же результат
    assert(ds.length == 29);  // набор данных имеет 29 элементов

    import std.algorithm: equal;
    
    auto arr = [Data(Id(29, 1), 3135.29, 668.659, 0, 10000000, Data.State.Begin), Data(Id(29, 1), 4860.4, -85.6403, 0, 110000000, Data.State.Middle), Data(Id(29, 1), 7485.96, -190.656, 0, 210000000, Data.State.Middle), Data(Id(29, 1), 9361.67, 2587.7, 0, 310000000, Data.State.Middle), Data(Id(29, 1), 10817.4, 2053.81, 0, 410000000, Data.State.Middle), Data(Id(29, 1), 12390.7, 2317.39, 0, 510000000, Data.State.Middle), Data(Id(29, 1), 15186.9, 4456.81, 0, 610000000, Data.State.Middle), Data(Id(29, 1), 15811, 4352.42, 0, 710000000, Data.State.Middle), Data(Id(29, 1), 18040.1, 4411.44, 0, 810000000, Data.State.Middle), Data(Id(29, 1), 20886.9, 4700.86, 0, 910000000, Data.State.Middle), Data(Id(29, 1), 22232.5, 6572.29, 0, 1010000000, Data.State.Middle), Data(Id(29, 1), 23841.5, 7520, 0, 1110000000, Data.State.Middle), Data(Id(29,1), 25883.6, 8127.31, 0, 1210000000, Data.State.Middle), Data(Id(29, 1), 27827, 9057.05, 0, 1310000000, Data.State.Middle), Data(Id(29, 1), 29128.5, 9154.44, 0, 1410000000, Data.State.Middle), Data(Id(29, 1), 31602.9, 9282.4, 0, 1510000000, Data.State.Middle), Data(Id(29, 1), 33973.6, 8615.77, 0, 1610000000, Data.State.Middle), Data(Id(29, 1), 37100.9, 8723.32, 0, 1710000000, Data.State.Middle), Data(Id(29, 1), 38716.1, 8272.56, 0, 1810000000, Data.State.Middle), Data(Id(29, 1), 40968.5, 6778.36, 0, 1910000000, Data.State.Middle), Data(Id(29, 1), 41736.1, 6818.2, 0, 2010000000, Data.State.Middle), Data(Id(29, 1), 44605.6, 6152.04, 0, 2110000000, Data.State.Middle), Data(Id(29, 1), 46346.3, 5509.49, 0, 2210000000, Data.State.Middle), Data(Id(29, 1), 47749.2, 4449.36, 0, 2310000000, Data.State.Middle), Data(Id(29,1), 50347.4, 3547.09, 0, 2410000000, Data.State.Middle), Data(Id(29, 1), 52208.5, 2735.65, 0, 2510000000, Data.State.Middle), Data(Id(29, 1), 54349.9, 2661.61, 0, 2610000000, Data.State.Middle), Data(Id(29, 1), 57004.1, 2121.54, 0, 2710000000, Data.State.Middle)];
    
    // сравниваем эталон и результат за исключением последнего элемента
    assert(ds.data[0..$-1].equal!"*a==b"(arr));
    assert(ds.data[].length == arr.length+1);

    // проверяем последний элемент (из-за double.nan делаем проверку отдельно)
    auto last = Data(Id(29, 1), double.nan, double.nan, double.nan, 2810000000, Data.State.End);
    assert(ds.data[$-1].id == last.id);
    assert(ds.data[$-1].timestamp == last.timestamp);
    assert(ds.data[$-1].state == last.state);
}

struct DataIndex(DataRange_, DataSourceHeader, DataSetHeader, DataElement, alias ProcessElementMethod)
{
    import std.experimental.allocator.mallocator : Mallocator;
    import std.experimental.allocator.building_blocks : Region, StatsCollector, Options;

    alias BaseAllocator = Region!Mallocator;
    alias Allocator = StatsCollector!(BaseAllocator, Options.all, Options.all);
    alias DataIndex = DataIndexImpl!(DataSourceHeader, DataSetHeader, DataElement, Allocator, ProcessElementMethod);
    alias DataRange = DataRange_;
    Allocator allocator;
    DataIndex didx;
    DataRange data;

    alias Key = DataIndex.Key;
    alias Value = DataIndex.Value;

	this(DataRange data)
	{
        allocator = Allocator(BaseAllocator(16 * 1024 * 1024));
        didx = DataIndex(allocator, data);
        this.data = data;
    }

    auto opApply(int delegate(ref const(Key) k, ref Value v) dg)
    {
        foreach(ref e; didx.byKeyValue)
        {
            auto result = dg(e.key, e.value);
            if (result) return result;
        }
        return 0;
    }
}
