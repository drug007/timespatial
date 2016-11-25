module color_table;

import std.experimental.color.hsx : HSL;
import std.experimental.color.rgb : RGBAf32;

struct ColorTable
{
	RGBAf32[uint] tbl;

	this(uint[] numbers)
	{
		uint i;
		foreach(n; numbers)
		{
			auto hue = 2.0 / 3.0 + i++ / cast(float) numbers.length;
		    auto saturation = 0.9;
		    auto lightness = 0.6;

		    auto rgba = cast(RGBAf32) HSL!float(hue, saturation, lightness);
		    rgba.a = 1.0;
		    tbl[n] = rgba;
		}
	}

	auto opCall(uint n) const
	{
		auto clr = n in tbl;
		if(clr)
			return *clr;

		return RGBAf32(1, 0, 0, 1);
	}
}