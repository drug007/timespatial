module tests;

import std.meta : AliasSeq;
import taggedalgebraic : TaggedAlgebraic;
import color_table : ColorTable;

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

    @property
    position()
    {
    	import gfm.math : vec3f;
    	
    	return vec3f(x, y, z);
    }
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
	Data* _data;
	Bar*  _bar;
	Foo*  _foo;
}

alias HData = TaggedAlgebraic!(Base);

auto heterogeneousData()
{
	import std.array: array;
	import std.range: enumerate;

	return [
	   HData(new Bar("string #1", long.min, 9000000)),
	   HData(new Data(Id( 1, 126), 3135.29,  668.659, 0, 10000000, Data.State.Begin)), 
	   HData(new Data(Id(12,  89), 2592.73,  29898.1, 0, 20000000, Data.State.Begin)), 
	   HData(new Data(Id( 1, 126),  4860.4, -85.6403, 0, 110000000, Data.State.Middle)), 
	   HData(new Bar("string #2", 0, 110005000)),
	   HData(new Data(Id(12,  89), 4718.28,  30201.3, 0, 120000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 7485.96, -190.656, 0, 210000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 7217.78,  31579.6, 0, 220000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 9361.67,   2587.7, 0, 310000000, Data.State.Middle)), 
	   HData(new Foo([666, 777, 1], 310200000)),
	   HData(new Data(Id(12,  89), 8803.98,  31867.5, 0, 320000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 10817.4,  2053.81, 0, 410000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 10319.9,  32846.7, 0, 420000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 12390.7,  2317.39, 0, 510000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 12101.3,  33290.6, 0, 520000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 15186.9,  4456.81, 0, 610000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89),   15099,    34126, 0, 620000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126),   15811,  4352.42, 0, 710000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 15750.3,  34418.7, 0, 720000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 18040.1,  4411.44, 0, 810000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89),   18450,  35493.3, 0, 820000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 20886.9,  4700.86, 0, 910000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 20338.8,  36117.9, 0, 920000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 22232.5,  6572.29, 0, 1010000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 22569.5,    36753, 0, 1020000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 23841.5,     7520, 0, 1110000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 23030.3,  37399.1, 0, 1120000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 25883.6,  8127.31, 0, 1210000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 26894.2,  38076.8, 0, 1220000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126),   27827,  9057.05, 0, 1310000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 27829.2,  38624.7, 0, 1320000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 29128.5,  9154.44, 0, 1410000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 30832.9,  39502.2, 0, 1420000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 31602.9,   9282.4, 0, 1510000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 31785.5,  39910.8, 0, 1520000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 33973.6,  8615.77, 0, 1610000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 34543.4,  39246.4, 0, 1620000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 37100.9,  8723.32, 0, 1710000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 36346.9,  38694.4, 0, 1720000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 38716.1,  8272.56, 0, 1810000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 38273.6,    38011, 0, 1820000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 40968.5,  6778.36, 0, 1910000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 39485.8,    37357, 0, 1920000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 41736.1,   6818.2, 0, 2010000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89),   42242,  36425.5, 0, 2020000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 44605.6,  6152.04, 0, 2110000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 43082.6,  36391.4, 0, 2120000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 46346.3,  5509.49, 0, 2210000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 47068.2,  34976.8, 0, 2220000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 47749.2,  4449.36, 0, 2310000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 48361.4,  34596.8, 0, 2320000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 50347.4,  3547.09, 0, 2410000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 50459.5,  34002.1, 0, 2420000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 52208.5,  2735.65, 0, 2510000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 53024.4,  33244.2, 0, 2520000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 54349.9,  2661.61, 0, 2610000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 54822.9,  32615.2, 0, 2620000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 57004.1,  2121.54, 0, 2710000000, Data.State.Middle)), 
	   HData(new Data(Id(12,  89), 56916.5,    31945, 0, 2720000000, Data.State.Middle)), 
	   HData(new Data(Id( 1, 126), 58742.9,  849.437, 0, 2810000000, Data.State.End)), 
	   HData(new Data(Id(12,  89), 59601.7,  31186.4, 0, 2820000000, Data.State.End)), 
	   HData(new Data(Id(29,   1), 3135.29,  668.659, 0, 10000000, Data.State.Begin)), 
	   HData(new Data(Id(29,   2), 2592.73,  29898.1, 0, 20000000, Data.State.Begin)), 
	   HData(new Data(Id(29,   1),  4860.4, -85.6403, 0, 110000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 4718.28,  30201.3, 0, 120000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 7485.96, -190.656, 0, 210000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 7217.78,  31579.6, 0, 220000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 9361.67,   2587.7, 0, 310000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 8803.98,  31867.5, 0, 320000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 10817.4,  2053.81, 0, 410000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 10319.9,  32846.7, 0, 420000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 12390.7,  2317.39, 0, 510000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 12101.3,  33290.6, 0, 520000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 15186.9,  4456.81, 0, 610000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2),   15099,    34126, 0, 620000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1),   15811,  4352.42, 0, 710000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 15750.3,  34418.7, 0, 720000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 18040.1,  4411.44, 0, 810000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2),   18450,  35493.3, 0, 820000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 20886.9,  4700.86, 0, 910000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 20338.8,  36117.9, 0, 920000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 22232.5,  6572.29, 0, 1010000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 22569.5,    36753, 0, 1020000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 23841.5,     7520, 0, 1110000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 23030.3,  37399.1, 0, 1120000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 25883.6,  8127.31, 0, 1210000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 26894.2,  38076.8, 0, 1220000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1),   27827,  9057.05, 0, 1310000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 27829.2,  38624.7, 0, 1320000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 29128.5,  9154.44, 0, 1410000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 30832.9,  39502.2, 0, 1420000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 31602.9,   9282.4, 0, 1510000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 31785.5,  39910.8, 0, 1520000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 33973.6,  8615.77, 0, 1610000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 34543.4,  39246.4, 0, 1620000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 37100.9,  8723.32, 0, 1710000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 36346.9,  38694.4, 0, 1720000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 38716.1,  8272.56, 0, 1810000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 38273.6,    38011, 0, 1820000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 40968.5,  6778.36, 0, 1910000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 39485.8,    37357, 0, 1920000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 41736.1,   6818.2, 0, 2010000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2),   42242,  36425.5, 0, 2020000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 44605.6,  6152.04, 0, 2110000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 43082.6,  36391.4, 0, 2120000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 46346.3,  5509.49, 0, 2210000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 47068.2,  34976.8, 0, 2220000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 47749.2,  4449.36, 0, 2310000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 48361.4,  34596.8, 0, 2320000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 50347.4,  3547.09, 0, 2410000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 50459.5,  34002.1, 0, 2420000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 52208.5,  2735.65, 0, 2510000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 53024.4,  33244.2, 0, 2520000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 54349.9,  2661.61, 0, 2610000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 54822.9,  32615.2, 0, 2620000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), 57004.1,  2121.54, 0, 2710000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   2), 56916.5,    31945, 0, 2720000000, Data.State.Middle)), 
	   HData(new Data(Id(29,   1), double.nan, double.nan, double.nan, 2810000000, Data.State.End)), 
	   HData(new Data(Id(29,   2), double.nan, double.nan, double.nan, 2820000000, Data.State.End))
	].enumerate(0).array;
}
