module tests;

import std.typecons: AliasSeq;
import taggedalgebraic: TaggedAlgebraic;
import color_table: ColorTable;

struct Id
{
    uint source;
    uint no;

    int opCmp(ref const(Id) other)
    {
    	if(source < other.source)
    		return -1;
    	if(source > other.source)
    		return 1;
    	if(no < other.no)
    		return -1;
    	if(no > other.no)
    		return 1;
    	return 0;
    }
}

struct Data
{
    enum State { Begin, Middle, End, }

    Id id;
    double x, y, z;
    @("Timestamp")
    long timestamp;
    State state;
}

struct Bar
{
	string str;
	long value;
	@("Timestamp")
	long timestamp;
}

struct Foo
{
	uint[3] ui;
	long timestamp;
}

union Base
{
	Data _data;
	Bar  _bar;
	Foo  _foo;
}

alias HData = TaggedAlgebraic!(Base);

auto heterogeneousData()
{
	import std.array: array;
	import std.range: enumerate;

	return [
	   HData(Bar("string #1", long.min, 9000000)),
	   HData(Data(Id( 1, 126), 3135.29,  668.659, 0, 10000000, Data.State.Begin)), 
	   HData(Data(Id(12,  89), 2592.73,  29898.1, 0, 20000000, Data.State.Begin)), 
	   HData(Data(Id( 1, 126),  4860.4, -85.6403, 0, 110000000, Data.State.Middle)), 
	   HData(Bar("string #2", 0, 110005000)),
	   HData(Data(Id(12,  89), 4718.28,  30201.3, 0, 120000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 7485.96, -190.656, 0, 210000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 7217.78,  31579.6, 0, 220000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 9361.67,   2587.7, 0, 310000000, Data.State.Middle)), 
	   HData(Foo([666, 777, 1], 310200000)),
	   HData(Data(Id(12,  89), 8803.98,  31867.5, 0, 320000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 10817.4,  2053.81, 0, 410000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 10319.9,  32846.7, 0, 420000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 12390.7,  2317.39, 0, 510000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 12101.3,  33290.6, 0, 520000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 15186.9,  4456.81, 0, 610000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89),   15099,    34126, 0, 620000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126),   15811,  4352.42, 0, 710000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 15750.3,  34418.7, 0, 720000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 18040.1,  4411.44, 0, 810000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89),   18450,  35493.3, 0, 820000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 20886.9,  4700.86, 0, 910000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 20338.8,  36117.9, 0, 920000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 22232.5,  6572.29, 0, 1010000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 22569.5,    36753, 0, 1020000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 23841.5,     7520, 0, 1110000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 23030.3,  37399.1, 0, 1120000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 25883.6,  8127.31, 0, 1210000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 26894.2,  38076.8, 0, 1220000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126),   27827,  9057.05, 0, 1310000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 27829.2,  38624.7, 0, 1320000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 29128.5,  9154.44, 0, 1410000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 30832.9,  39502.2, 0, 1420000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 31602.9,   9282.4, 0, 1510000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 31785.5,  39910.8, 0, 1520000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 33973.6,  8615.77, 0, 1610000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 34543.4,  39246.4, 0, 1620000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 37100.9,  8723.32, 0, 1710000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 36346.9,  38694.4, 0, 1720000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 38716.1,  8272.56, 0, 1810000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 38273.6,    38011, 0, 1820000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 40968.5,  6778.36, 0, 1910000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 39485.8,    37357, 0, 1920000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 41736.1,   6818.2, 0, 2010000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89),   42242,  36425.5, 0, 2020000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 44605.6,  6152.04, 0, 2110000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 43082.6,  36391.4, 0, 2120000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 46346.3,  5509.49, 0, 2210000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 47068.2,  34976.8, 0, 2220000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 47749.2,  4449.36, 0, 2310000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 48361.4,  34596.8, 0, 2320000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 50347.4,  3547.09, 0, 2410000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 50459.5,  34002.1, 0, 2420000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 52208.5,  2735.65, 0, 2510000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 53024.4,  33244.2, 0, 2520000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 54349.9,  2661.61, 0, 2610000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 54822.9,  32615.2, 0, 2620000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 57004.1,  2121.54, 0, 2710000000, Data.State.Middle)), 
	   HData(Data(Id(12,  89), 56916.5,    31945, 0, 2720000000, Data.State.Middle)), 
	   HData(Data(Id( 1, 126), 58742.9,  849.437, 0, 2810000000, Data.State.End)), 
	   HData(Data(Id(12,  89), 59601.7,  31186.4, 0, 2820000000, Data.State.End)), 
	   HData(Data(Id(29,   1), 3135.29,  668.659, 0, 10000000, Data.State.Begin)), 
	   HData(Data(Id(29,   2), 2592.73,  29898.1, 0, 20000000, Data.State.Begin)), 
	   HData(Data(Id(29,   1),  4860.4, -85.6403, 0, 110000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 4718.28,  30201.3, 0, 120000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 7485.96, -190.656, 0, 210000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 7217.78,  31579.6, 0, 220000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 9361.67,   2587.7, 0, 310000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 8803.98,  31867.5, 0, 320000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 10817.4,  2053.81, 0, 410000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 10319.9,  32846.7, 0, 420000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 12390.7,  2317.39, 0, 510000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 12101.3,  33290.6, 0, 520000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 15186.9,  4456.81, 0, 610000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2),   15099,    34126, 0, 620000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1),   15811,  4352.42, 0, 710000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 15750.3,  34418.7, 0, 720000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 18040.1,  4411.44, 0, 810000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2),   18450,  35493.3, 0, 820000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 20886.9,  4700.86, 0, 910000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 20338.8,  36117.9, 0, 920000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 22232.5,  6572.29, 0, 1010000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 22569.5,    36753, 0, 1020000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 23841.5,     7520, 0, 1110000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 23030.3,  37399.1, 0, 1120000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 25883.6,  8127.31, 0, 1210000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 26894.2,  38076.8, 0, 1220000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1),   27827,  9057.05, 0, 1310000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 27829.2,  38624.7, 0, 1320000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 29128.5,  9154.44, 0, 1410000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 30832.9,  39502.2, 0, 1420000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 31602.9,   9282.4, 0, 1510000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 31785.5,  39910.8, 0, 1520000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 33973.6,  8615.77, 0, 1610000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 34543.4,  39246.4, 0, 1620000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 37100.9,  8723.32, 0, 1710000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 36346.9,  38694.4, 0, 1720000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 38716.1,  8272.56, 0, 1810000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 38273.6,    38011, 0, 1820000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 40968.5,  6778.36, 0, 1910000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 39485.8,    37357, 0, 1920000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 41736.1,   6818.2, 0, 2010000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2),   42242,  36425.5, 0, 2020000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 44605.6,  6152.04, 0, 2110000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 43082.6,  36391.4, 0, 2120000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 46346.3,  5509.49, 0, 2210000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 47068.2,  34976.8, 0, 2220000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 47749.2,  4449.36, 0, 2310000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 48361.4,  34596.8, 0, 2320000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 50347.4,  3547.09, 0, 2410000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 50459.5,  34002.1, 0, 2420000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 52208.5,  2735.65, 0, 2510000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 53024.4,  33244.2, 0, 2520000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 54349.9,  2661.61, 0, 2610000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 54822.9,  32615.2, 0, 2620000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), 57004.1,  2121.54, 0, 2710000000, Data.State.Middle)), 
	   HData(Data(Id(29,   2), 56916.5,    31945, 0, 2720000000, Data.State.Middle)), 
	   HData(Data(Id(29,   1), double.nan, double.nan, double.nan, 2810000000, Data.State.End)), 
	   HData(Data(Id(29,   2), double.nan, double.nan, double.nan, 2820000000, Data.State.End))
	].enumerate(0).array;
}

auto filterGraphicData(R)(R hdata)
{
	import std.algorithm: filter, map;
	import std.array: front;
	import std.typecons: tuple;
	import taggedalgebraic: get;

	return hdata.filter!((a) {
		if(a.value.kind == typeof(heterogeneousData().front).value.Kind._data)
			return true;
		return false;
	}).map!(a=>tuple!("index", "value")(a.index, a.value.get!Data));
}

auto prepareData(DataObject, R)(R data, ref const(ColorTable) color_table)
{
    import std.algorithm: filter, sort, map;
    import std.array: array, back;
    import std.math: isNaN;
    import std.conv: text;
    import vertex_provider: Vertex, VertexSlice;

    alias DataElement = DataObject.DataElement;

    DataObject[uint][uint] idata;

    foreach(e; data)
    {
        auto s = idata.get(e.value.id.source, null);

        auto clr = color_table(e.value.id.source);

        if((s is null) || (e.value.id.no !in s))
        {
            import gfm.math: box3f;
            idata[e.value.id.source][e.value.id.no] = DataObject(
                e.value.id.no, 
                text(e.value.id.no, "\0"),
                true, // visible
                box3f(e.value.x, e.value.y, e.value.z, e.value.x, e.value.y, e.value.z), 
                VertexSlice.Kind.LineStrip, 
                [DataElement(cast(uint)e.index, e.value.x, e.value.y, e.value.z, clr.r, clr.g, clr.b, clr.a, e.value.timestamp)]);
        }
        else
        {
            s[e.value.id.no].elements ~= DataElement(cast(uint)e.index, e.value.x, e.value.y, e.value.z, clr.r, clr.g, clr.b, clr.a, e.value.timestamp);
            import data_provider: updateBoundingBox;
            import gfm.math: vec3f;
            auto vec = vec3f(e.value.x, e.value.y, e.value.z);
            updateBoundingBox(s[e.value.id.no].box, vec);
        }
    }
    
    return idata;
}

/** Исходные данные в виде контейнера HStorage массива разнородных данных TaggedAlgebraic!(SomeTypes...)
*
* По HStorage строится индекс неграфических данных. Неграфические данные выводятся как есть.
* По HStorage строятся графические данные. По ним строится индекс графических данных и другие.
* Индекс графических данных это дерево, узлами которого являются деревья, узлами которых являются массивы DataElement.
* DataElement это графическая вершина с необходимыми атрибутами для отображения средствами opengl плюс необходимые пользовательские данные.
* DataElement фиксированный шаблон и доступен пользователю библиотеки. Формирование графических данных на основе 
* разнородных данных лежит на пользователе.
*
*/

unittest
{
    import std.typecons: AliasSeq;
    import hstorage.hstorage: HStorage, IdIndex2;

    alias Types = AliasSeq!(Data);
    auto hs = HStorage!Types();

    foreach(ref e; heterogeneousData().filterGraphicData)
        hs.add(e.value);
    
    alias Index2 = IdIndex2!(typeof(hs.storage), typeof(hs).Key, Data);
    auto idx2 = Index2(hs.storage);
    assert(idx2.length == 3); // Всего три источника данных

    version(none)
    {
        import std.stdio;
        hs.storage[].writeln;
        foreach(ref Index2.Key k, ref Index2.Value v; idx2)
        {
            writefln("%s:", k);
            foreach(ref Index2.Key k2, ref Index2.Value2 v2; *v.idx2)
            {
                writefln("\t%s: %s", k2, v2);
                foreach(idx; *v2)
                    writefln("\t\t%s: %s", idx, hs.storage[idx]);
            }
        }
    }

    assert(!idx2.containsKey(999)); // не существует источника номер 999
    assert(idx2.containsKey(29));   // источник номер 29 существует

    auto src = idx2[29]; // выбираем источник номер 29
    assert(src.length);  // у источника номер 29 имеется два набора данных

    assert(!src.containsKey(888)); // источник номер 29 не содержит набор данных с номером 888
    assert(src.containsKey(1));    // источник номер 29 содержит набор данных с номером 1

    // выбираем набор данных с номером 1
    auto ds0 = (*src)[1];     // один вариант выбора набора данных с номером 1
    auto ds = src.opIndex(1); // другой вариант выбора набора данных с номером 1
    assert(ds0 is ds);        // оба варианты дают один и тот же результат
    assert(ds.length == 29);  // набор данных имеет 29 элементов

    size_t[] values;
    foreach(k, v; *ds)
        values ~= v;

    import std.algorithm: equal;
    assert(values.equal([58, 60, 62, 64, 66, 68, 70, 72, 74, 76, 78, 80, 82, 84, 86, 88, 90, 92, 94, 96, 98, 100, 102, 104, 106, 108, 110, 112, 114]));

    assert(hs.storage[ds.opIndex(1)].id == Id(29, 1));
    assert(hs.storage[ds.opIndex(1)].state == Data.State.Middle);
}

unittest
{
	import gfm.math: box3f, vec3f;
	import rtree: RTree;

    auto s = new RTree(":memory:");

    import std.algorithm.iteration: map;
    import std.algorithm: equal;

    foreach(e; heterogeneousData().filterGraphicData)
        s.addPoint(e.index, vec3f(e.value.x, e.value.y, e.value.z));

    auto box = box3f(vec3f(1000, 1000, -10), vec3f(20000, 20000, 10));
    auto point_id = s.searchPoints(box);

    assert(point_id.equal([19, 15, 8, 67, 11, 69, 13, 71, 73, 17, 75, 77]));

    destroy(s);
}