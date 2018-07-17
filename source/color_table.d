module color_table;

import std.experimental.color.hsx : HSL;
import std.experimental.color : RGBAf32;
import std.random : uniform;
import std.math : fmod;

struct ColorTable
{
	RGBAf32[uint] tbl;

	this(uint[] numbers)
	{
		// Первый цвет фиксированный (без учета кол-ва цветов)
		{
			auto hue = 2/3.;
			auto saturation = 0.9;
			auto lightness = 0.03;

			auto rgba = cast(RGBAf32) HSL!float(hue, saturation, lightness);
			rgba.a = 1.0;
			tbl[numbers[0]] = rgba;
		}
		// Обрабатываем остальные цвета
		const l = numbers.length;
		foreach(i; 1..l)
		{
			auto hue = fmod(2/3. + (i + 1.5) / cast(float) l, 1.0);
			auto saturation = 0.8 + uniform(0, 20)/100.0;
			auto lightness = 0.5 + uniform(0, 20)/100.0;

			auto rgba = cast(RGBAf32) HSL!float(hue, saturation, lightness);
			rgba.a = 1.0;
			tbl[numbers[i]] = rgba;
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