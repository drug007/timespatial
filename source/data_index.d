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
        static if (Args.length)
            result.__ctor(move(args));
        else
            result.__ctor();

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
