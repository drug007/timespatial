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
	Data* Data_;
	Bar*  Bar_;
	Foo*  Foo_;
}

struct Leaf
{
	size_t no;
	size_t[] indices;

	this(size_t no, size_t[] indices)
	{
		this.no = no;
		this.indices = indices;
	}
}

struct Node
{
	import std.algorithm : copy;
	import std.variant : Algebraic;
	size_t no;
	alias Child = Algebraic!(Leaf*, Node*);
	Child[] childs;

	//this(size_t no, size_t[] indices)
	//{
	//	this.no = no;
	//	childs.length = indices.length;
	//	copy(indices, childs);
	//}

	this(size_t no, Node[] nodes)
	{
		this.no = no;
		childs.length = nodes.length;
		import std.algorithm : map;
		copy(nodes.map!((ref a) { return &a; }), childs);
	}

	this(size_t no, Leaf[] nodes)
	{
		this.no = no;
		childs.length = nodes.length;
		import std.algorithm : map;
		copy(nodes.map!((ref a) { return &a; }), childs);
	}

	static struct Range
	{
		private
		{
			Child[] range;
		
			this(ref Node node)
			{
				this.range = node.childs;
			}
		}

		@property
		auto front()
		{
			import std.array : front;
			return range.front();
		}

		void popFront()
		{
			import std.array : popFront;
			range.popFront();
		}

		@property
		bool empty()
		{
			import std.array : empty;
			return range.empty();
		}
	}

	auto opSlice()
	{
		return Range(this);
	}
}

alias HData = TaggedAlgebraic!(Base);

auto indices()
{
	auto leaf1_126 = Leaf(126, [ 1, 3, 6, 8, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37, 39, 41, 43, 45, 47, 49, 51, 53, 55, 57, 59, ]);
	auto leaf12_89 = Leaf( 89, [ 2, 5, 7, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, ]);
	auto leaf29_1  = Leaf(  1, [ 61, 63, 65, 67, 69, 71, 73, 75, 77, 79, 81, 83, 85, 87, 89, 91, 93, 95, 97, 99, 101, 103, 105, 107, 109, 111, 113, 115, 117, ]);
	auto leaf29_2  = Leaf(  2, [ 62, 64, 66, 68, 70, 72, 74, 76, 78, 80, 82, 84, 86, 88, 90, 92, 94, 96, 98, 100, 102, 104, 106, 108, 110, 112, 114, 116, 118, ]);

	auto node1  = Node( 1, [leaf1_126]);
	auto node12 = Node(12, [leaf12_89]);
	auto node29 = Node(29, [leaf29_1, leaf29_2]);

	auto root = Node(0, [ node1, node12, node29, ]);

	return root;
}

auto heterogeneousData()
{
	import std.array: array;
	import std.range: enumerate;

	static data = [
	   Data(Id( 1, 126), 3135.29,  668.659, 0, 10000000, Data.State.Begin), 
	   Data(Id(12,  89), 2592.73,  29898.1, 0, 20000000, Data.State.Begin), 
	   Data(Id( 1, 126),  4860.4, -85.6403, 0, 110000000, Data.State.Middle), 
	   Data(Id(12,  89), 4718.28,  30201.3, 0, 120000000, Data.State.Middle), 
	   Data(Id( 1, 126), 7485.96, -190.656, 0, 210000000, Data.State.Middle), 
	   Data(Id(12,  89), 7217.78,  31579.6, 0, 220000000, Data.State.Middle), 
	   Data(Id( 1, 126), 9361.67,   2587.7, 0, 310000000, Data.State.Middle), 
	   Data(Id(12,  89), 8803.98,  31867.5, 0, 320000000, Data.State.Middle), 
	   Data(Id( 1, 126), 10817.4,  2053.81, 0, 410000000, Data.State.Middle), 
	   Data(Id(12,  89), 10319.9,  32846.7, 0, 420000000, Data.State.Middle), 
	   Data(Id( 1, 126), 12390.7,  2317.39, 0, 510000000, Data.State.Middle), 
	   Data(Id(12,  89), 12101.3,  33290.6, 0, 520000000, Data.State.Middle), 
	   Data(Id( 1, 126), 15186.9,  4456.81, 0, 610000000, Data.State.Middle), 
	   Data(Id(12,  89),   15099,    34126, 0, 620000000, Data.State.Middle), 
	   Data(Id( 1, 126),   15811,  4352.42, 0, 710000000, Data.State.Middle), 
	   Data(Id(12,  89), 15750.3,  34418.7, 0, 720000000, Data.State.Middle), 
	   Data(Id( 1, 126), 18040.1,  4411.44, 0, 810000000, Data.State.Middle), 
	   Data(Id(12,  89),   18450,  35493.3, 0, 820000000, Data.State.Middle), 
	   Data(Id( 1, 126), 20886.9,  4700.86, 0, 910000000, Data.State.Middle), 
	   Data(Id(12,  89), 20338.8,  36117.9, 0, 920000000, Data.State.Middle), 
	   Data(Id( 1, 126), 22232.5,  6572.29, 0, 1010000000, Data.State.Middle), 
	   Data(Id(12,  89), 22569.5,    36753, 0, 1020000000, Data.State.Middle), 
	   Data(Id( 1, 126), 23841.5,     7520, 0, 1110000000, Data.State.Middle), 
	   Data(Id(12,  89), 23030.3,  37399.1, 0, 1120000000, Data.State.Middle), 
	   Data(Id( 1, 126), 25883.6,  8127.31, 0, 1210000000, Data.State.Middle), 
	   Data(Id(12,  89), 26894.2,  38076.8, 0, 1220000000, Data.State.Middle), 
	   Data(Id( 1, 126),   27827,  9057.05, 0, 1310000000, Data.State.Middle), 
	   Data(Id(12,  89), 27829.2,  38624.7, 0, 1320000000, Data.State.Middle), 
	   Data(Id( 1, 126), 29128.5,  9154.44, 0, 1410000000, Data.State.Middle), 
	   Data(Id(12,  89), 30832.9,  39502.2, 0, 1420000000, Data.State.Middle), 
	   Data(Id( 1, 126), 31602.9,   9282.4, 0, 1510000000, Data.State.Middle), 
	   Data(Id(12,  89), 31785.5,  39910.8, 0, 1520000000, Data.State.Middle), 
	   Data(Id( 1, 126), 33973.6,  8615.77, 0, 1610000000, Data.State.Middle), 
	   Data(Id(12,  89), 34543.4,  39246.4, 0, 1620000000, Data.State.Middle), 
	   Data(Id( 1, 126), 37100.9,  8723.32, 0, 1710000000, Data.State.Middle), 
	   Data(Id(12,  89), 36346.9,  38694.4, 0, 1720000000, Data.State.Middle), 
	   Data(Id( 1, 126), 38716.1,  8272.56, 0, 1810000000, Data.State.Middle), 
	   Data(Id(12,  89), 38273.6,    38011, 0, 1820000000, Data.State.Middle), 
	   Data(Id( 1, 126), 40968.5,  6778.36, 0, 1910000000, Data.State.Middle), 
	   Data(Id(12,  89), 39485.8,    37357, 0, 1920000000, Data.State.Middle), 
	   Data(Id( 1, 126), 41736.1,   6818.2, 0, 2010000000, Data.State.Middle), 
	   Data(Id(12,  89),   42242,  36425.5, 0, 2020000000, Data.State.Middle), 
	   Data(Id( 1, 126), 44605.6,  6152.04, 0, 2110000000, Data.State.Middle), 
	   Data(Id(12,  89), 43082.6,  36391.4, 0, 2120000000, Data.State.Middle), 
	   Data(Id( 1, 126), 46346.3,  5509.49, 0, 2210000000, Data.State.Middle), 
	   Data(Id(12,  89), 47068.2,  34976.8, 0, 2220000000, Data.State.Middle), 
	   Data(Id( 1, 126), 47749.2,  4449.36, 0, 2310000000, Data.State.Middle), 
	   Data(Id(12,  89), 48361.4,  34596.8, 0, 2320000000, Data.State.Middle), 
	   Data(Id( 1, 126), 50347.4,  3547.09, 0, 2410000000, Data.State.Middle), 
	   Data(Id(12,  89), 50459.5,  34002.1, 0, 2420000000, Data.State.Middle), 
	   Data(Id( 1, 126), 52208.5,  2735.65, 0, 2510000000, Data.State.Middle), 
	   Data(Id(12,  89), 53024.4,  33244.2, 0, 2520000000, Data.State.Middle), 
	   Data(Id( 1, 126), 54349.9,  2661.61, 0, 2610000000, Data.State.Middle), 
	   Data(Id(12,  89), 54822.9,  32615.2, 0, 2620000000, Data.State.Middle), 
	   Data(Id( 1, 126), 57004.1,  2121.54, 0, 2710000000, Data.State.Middle), 
	   Data(Id(12,  89), 56916.5,    31945, 0, 2720000000, Data.State.Middle), 
	   Data(Id( 1, 126), 58742.9,  849.437, 0, 2810000000, Data.State.End), 
	   Data(Id(12,  89), 59601.7,  31186.4, 0, 2820000000, Data.State.End), 
	   Data(Id(29,   1), 3135.29,  668.659, 0, 10000000, Data.State.Begin), 
	   Data(Id(29,   2), 2592.73,  29898.1, 0, 20000000, Data.State.Begin), 
	   Data(Id(29,   1),  4860.4, -85.6403, 0, 110000000, Data.State.Middle), 
	   Data(Id(29,   2), 4718.28,  30201.3, 0, 120000000, Data.State.Middle), 
	   Data(Id(29,   1), 7485.96, -190.656, 0, 210000000, Data.State.Middle), 
	   Data(Id(29,   2), 7217.78,  31579.6, 0, 220000000, Data.State.Middle), 
	   Data(Id(29,   1), 9361.67,   2587.7, 0, 310000000, Data.State.Middle), 
	   Data(Id(29,   2), 8803.98,  31867.5, 0, 320000000, Data.State.Middle), 
	   Data(Id(29,   1), 10817.4,  2053.81, 0, 410000000, Data.State.Middle), 
	   Data(Id(29,   2), 10319.9,  32846.7, 0, 420000000, Data.State.Middle), 
	   Data(Id(29,   1), 12390.7,  2317.39, 0, 510000000, Data.State.Middle), 
	   Data(Id(29,   2), 12101.3,  33290.6, 0, 520000000, Data.State.Middle), 
	   Data(Id(29,   1), 15186.9,  4456.81, 0, 610000000, Data.State.Middle), 
	   Data(Id(29,   2),   15099,    34126, 0, 620000000, Data.State.Middle), 
	   Data(Id(29,   1),   15811,  4352.42, 0, 710000000, Data.State.Middle), 
	   Data(Id(29,   2), 15750.3,  34418.7, 0, 720000000, Data.State.Middle), 
	   Data(Id(29,   1), 18040.1,  4411.44, 0, 810000000, Data.State.Middle), 
	   Data(Id(29,   2),   18450,  35493.3, 0, 820000000, Data.State.Middle), 
	   Data(Id(29,   1), 20886.9,  4700.86, 0, 910000000, Data.State.Middle), 
	   Data(Id(29,   2), 20338.8,  36117.9, 0, 920000000, Data.State.Middle), 
	   Data(Id(29,   1), 22232.5,  6572.29, 0, 1010000000, Data.State.Middle), 
	   Data(Id(29,   2), 22569.5,    36753, 0, 1020000000, Data.State.Middle), 
	   Data(Id(29,   1), 23841.5,     7520, 0, 1110000000, Data.State.Middle), 
	   Data(Id(29,   2), 23030.3,  37399.1, 0, 1120000000, Data.State.Middle), 
	   Data(Id(29,   1), 25883.6,  8127.31, 0, 1210000000, Data.State.Middle), 
	   Data(Id(29,   2), 26894.2,  38076.8, 0, 1220000000, Data.State.Middle), 
	   Data(Id(29,   1),   27827,  9057.05, 0, 1310000000, Data.State.Middle), 
	   Data(Id(29,   2), 27829.2,  38624.7, 0, 1320000000, Data.State.Middle), 
	   Data(Id(29,   1), 29128.5,  9154.44, 0, 1410000000, Data.State.Middle), 
	   Data(Id(29,   2), 30832.9,  39502.2, 0, 1420000000, Data.State.Middle), 
	   Data(Id(29,   1), 31602.9,   9282.4, 0, 1510000000, Data.State.Middle), 
	   Data(Id(29,   2), 31785.5,  39910.8, 0, 1520000000, Data.State.Middle), 
	   Data(Id(29,   1), 33973.6,  8615.77, 0, 1610000000, Data.State.Middle), 
	   Data(Id(29,   2), 34543.4,  39246.4, 0, 1620000000, Data.State.Middle), 
	   Data(Id(29,   1), 37100.9,  8723.32, 0, 1710000000, Data.State.Middle), 
	   Data(Id(29,   2), 36346.9,  38694.4, 0, 1720000000, Data.State.Middle), 
	   Data(Id(29,   1), 38716.1,  8272.56, 0, 1810000000, Data.State.Middle), 
	   Data(Id(29,   2), 38273.6,    38011, 0, 1820000000, Data.State.Middle), 
	   Data(Id(29,   1), 40968.5,  6778.36, 0, 1910000000, Data.State.Middle), 
	   Data(Id(29,   2), 39485.8,    37357, 0, 1920000000, Data.State.Middle), 
	   Data(Id(29,   1), 41736.1,   6818.2, 0, 2010000000, Data.State.Middle), 
	   Data(Id(29,   2),   42242,  36425.5, 0, 2020000000, Data.State.Middle), 
	   Data(Id(29,   1), 44605.6,  6152.04, 0, 2110000000, Data.State.Middle), 
	   Data(Id(29,   2), 43082.6,  36391.4, 0, 2120000000, Data.State.Middle), 
	   Data(Id(29,   1), 46346.3,  5509.49, 0, 2210000000, Data.State.Middle), 
	   Data(Id(29,   2), 47068.2,  34976.8, 0, 2220000000, Data.State.Middle), 
	   Data(Id(29,   1), 47749.2,  4449.36, 0, 2310000000, Data.State.Middle), 
	   Data(Id(29,   2), 48361.4,  34596.8, 0, 2320000000, Data.State.Middle), 
	   Data(Id(29,   1), 50347.4,  3547.09, 0, 2410000000, Data.State.Middle), 
	   Data(Id(29,   2), 50459.5,  34002.1, 0, 2420000000, Data.State.Middle), 
	   Data(Id(29,   1), 52208.5,  2735.65, 0, 2510000000, Data.State.Middle), 
	   Data(Id(29,   2), 53024.4,  33244.2, 0, 2520000000, Data.State.Middle), 
	   Data(Id(29,   1), 54349.9,  2661.61, 0, 2610000000, Data.State.Middle), 
	   Data(Id(29,   2), 54822.9,  32615.2, 0, 2620000000, Data.State.Middle), 
	   Data(Id(29,   1), 57004.1,  2121.54, 0, 2710000000, Data.State.Middle), 
	   Data(Id(29,   2), 56916.5,    31945, 0, 2720000000, Data.State.Middle), 
	   Data(Id(29,   1), double.nan, double.nan, double.nan, 2810000000, Data.State.End), 
	   Data(Id(29,   2), double.nan, double.nan, double.nan, 2820000000, Data.State.End)
	];

	static bar = [
	   Bar("string #1", long.min, 9000000),
	   Bar("string #2", 0, 110005000)
	];

	static foo = [
	   Foo([666, 777, 1], 310200000),
	];

	return [
	   HData(&bar[0]),
	   HData(&data[0]), 
	   HData(&data[1]), 
	   HData(&data[2]), 
	   HData(&bar[1]),
	   HData(&data[3]), 
	   HData(&data[4]), 
	   HData(&data[5]), 
	   HData(&data[6]), 
	   HData(&foo[0]),
	   HData(&data[7]), 
	   HData(&data[8]), 
	   HData(&data[9]), 
	   HData(&data[10]), 
	   HData(&data[11]), 
	   HData(&data[12]), 
	   HData(&data[13]), 
	   HData(&data[14]), 
	   HData(&data[15]), 
	   HData(&data[16]), 
	   HData(&data[17]), 
	   HData(&data[18]), 
	   HData(&data[19]), 
	   HData(&data[20]), 
	   HData(&data[21]), 
	   HData(&data[22]), 
	   HData(&data[23]), 
	   HData(&data[24]), 
	   HData(&data[25]), 
	   HData(&data[26]), 
	   HData(&data[27]), 
	   HData(&data[28]), 
	   HData(&data[29]), 
	   HData(&data[30]), 
	   HData(&data[31]), 
	   HData(&data[32]), 
	   HData(&data[33]), 
	   HData(&data[34]), 
	   HData(&data[35]), 
	   HData(&data[36]), 
	   HData(&data[37]), 
	   HData(&data[38]), 
	   HData(&data[39]), 
	   HData(&data[40]), 
	   HData(&data[41]), 
	   HData(&data[42]), 
	   HData(&data[43]), 
	   HData(&data[44]), 
	   HData(&data[45]), 
	   HData(&data[46]), 
	   HData(&data[47]), 
	   HData(&data[48]), 
	   HData(&data[49]), 
	   HData(&data[50]), 
	   HData(&data[51]), 
	   HData(&data[52]), 
	   HData(&data[53]), 
	   HData(&data[54]), 
	   HData(&data[55]), 
	   HData(&data[56]), 
	   HData(&data[57]), 
	   HData(&data[58]), 
	   HData(&data[59]), 
	   HData(&data[60]), 
	   HData(&data[61]), 
	   HData(&data[62]), 
	   HData(&data[63]), 
	   HData(&data[64]), 
	   HData(&data[65]), 
	   HData(&data[66]), 
	   HData(&data[67]), 
	   HData(&data[68]), 
	   HData(&data[69]), 
	   HData(&data[70]), 
	   HData(&data[71]), 
	   HData(&data[72]), 
	   HData(&data[73]), 
	   HData(&data[74]), 
	   HData(&data[75]), 
	   HData(&data[76]), 
	   HData(&data[77]), 
	   HData(&data[78]), 
	   HData(&data[79]), 
	   HData(&data[80]), 
	   HData(&data[81]), 
	   HData(&data[82]), 
	   HData(&data[83]), 
	   HData(&data[84]), 
	   HData(&data[85]), 
	   HData(&data[86]), 
	   HData(&data[87]), 
	   HData(&data[88]), 
	   HData(&data[89]), 
	   HData(&data[90]), 
	   HData(&data[91]), 
	   HData(&data[92]), 
	   HData(&data[93]), 
	   HData(&data[94]), 
	   HData(&data[95]), 
	   HData(&data[96]), 
	   HData(&data[97]), 
	   HData(&data[98]), 
	   HData(&data[99]), 
	   HData(&data[100]), 
	   HData(&data[101]), 
	   HData(&data[102]), 
	   HData(&data[103]), 
	   HData(&data[104]), 
	   HData(&data[105]), 
	   HData(&data[106]), 
	   HData(&data[107]), 
	   HData(&data[108]), 
	   HData(&data[109]), 
	   HData(&data[110]), 
	   HData(&data[111]), 
	   HData(&data[112]), 
	   HData(&data[113]), 
	   HData(&data[114]), 
	   HData(&data[115])
	];
}
