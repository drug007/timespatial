module hstorage.hstorage;

import std.typecons: AliasSeq;

import taggedalgebraic: TaggedAlgebraic;

string camelCaseToUnderscores(string sym)
{
	import std.string: toLower, toUpper;

	string result;

	foreach (c; sym[0..1]) // не смог по другому в компайл-тайме преобразовать первый символ
	{
		result ~= toLower(c);
	}

	foreach (c; sym[1..$])
	{
		if (c == '!' || c == '(' || c == ')')
		{
			// skip it
		}
		else
		if (c == toUpper(c))
		{
			result ~= '_';
			result ~= toLower(c);
		}
		else
			result ~= c;
	}
	return result;
}

mixin template generateBaseUnionBody(U...)
{
	// импорт добавлен чтобы обеспечить использование
	// данного миксина из других модулей
	import hstorage.hstorage: camelCaseToUnderscores;

	mixin template impl(T...)
	{
		static if(T.length)
		{
			alias Type = T[0];
			mixin("Type " ~ Type.stringof.camelCaseToUnderscores ~ "_;");
			mixin impl!(T[1..$]);
		}
	}

	mixin impl!(U);
}

struct HStorage(Types...)
{
	import std.experimental.allocator.mallocator: Mallocator;

	import taggedalgebraic: Void, get;
	import containers.treemap: TreeMap;
	import containers.dynamicarray: DynamicArray;

	static union Base
	{
		mixin generateBaseUnionBody!(AliasSeq!(Void, Types));
	}

	alias Key = long;
	alias Value = TaggedAlgebraic!Base;
	alias Storage = DynamicArray!(Value, Mallocator, false);

	Storage storage;

	Key add(T)(T t)
	{
		storage.put(Value(t));

		return storage.length-1;
	}

	Key add(ref Value value)
	{
		storage.put(value);

		return storage.length-1;
	}

	T get(T)(Key id)
	{
		template isSame(U)
		{
			import std.traits: allSameType;
			enum isSame = allSameType!(T, U);
		}

		import std.meta: Filter;
		import std.conv: text;
		import taggedalgebraic: hasType;
		import std.exception: enforce;

		static assert(Filter!(isSame, Types).length, text("Type '", T.stringof, "' cannot be stored in a ", typeof(this).stringof));		

		assert(id >= 0 && id < storage.length);
		auto value = storage[id];
		assert(value.hasType!(T, Base), text("Incompatible types '", T.stringof, "' and '", value.kind, "'"));
		return value.get!T;
	}

	Value getValue(Key id)
	{
		return storage[id];
	}

	alias opIndex = getValue;

	auto length()
	{
		return storage.length;
	}
}

struct IdIndex1(Storage, V, AllowableType...)
{
	static struct Key
	{
		uint src, no;

		int opCmp(ref const Key other) const nothrow
	    {
	      if(src < other.src)
	          return -1;
	      if(src > other.src)
	          return 1;

	      if(no < other.no)
	          return -1;
	      if(no > other.no)
	          return 1;

	      return 0;
	    }
	}
	alias Value = V;

	import containers.treemap: TreeMap;
	import std.experimental.allocator.mallocator: Mallocator;
	
	alias Idx = TreeMap!(Key, Value, Mallocator, "a<b", false);
	private
	{
		Idx idx = void;
		Storage* storage;
	}

	alias idx this;

	this(ref Storage storage)
	{
		this.storage = &storage;
		idx = Idx();
		foreach(i, ref e; storage[])
		{
			import taggedalgebraic: hasType;

			foreach(T; AllowableType)
			{
				if(e.hasType!(T))
				{
					auto nk = Key(e.src, e.no);
					idx[nk] = i;
					break;
				}
			}
		}
	}
}

struct IdIndex2(Storage, V, AllowableType...)
{
	alias Key = long;
	static struct Value
	{
		long src;
		Idx2* idx2;
		alias idx2 this;
	}

	import containers.treemap: TreeMap;
	import containers.dynamicarray: DynamicArray;
	import std.experimental.allocator.mallocator: Mallocator;
	
	alias Idx1 = TreeMap!(Key, Value, Mallocator, "a<b", true);
	alias Idx2 = TreeMap!(Key, Value2, Mallocator, "a<b", true);
	alias Payload = DynamicArray!(V, Mallocator, false);
	alias Value2 = Payload*;
	public
	{
		Idx1 idx1 = void;
		Storage* storage;
	}

	alias idx1 this;

	this(ref Storage storage)
	{
		this.storage = &storage;
		idx1 = Idx1();
		foreach(i, ref e; storage[])
		{
			import taggedalgebraic: hasType;

			foreach(T; AllowableType)
			{
				if(e.hasType!(T))
				{
					if(!idx1.containsKey(e.id.source))
					{
						idx1[e.id.source] = Value(e.id.source, new Idx2()); // TODO убрать отсюда сборщик мусора
					}

					if(!idx1[e.id.source].idx2.containsKey(e.id.no))
					{
						idx1[e.id.source].insert(new Payload(), e.id.no); // TODO убрать отсюда сборщик мусора
					}

					(*idx1[e.id.source])[e.id.no].put(i);
					
					break;
				}
			}
		}

		foreach(ref Key k, ref Value v; idx1)
		{
			foreach(ref Key k2, ref Value2 v2; *v.idx2)
			{
				import std.algorithm: sort, copy;
				
				copy((*v2)[], (*v2)[].sort!((a, b)=> storage[a].timestamp<storage[b].timestamp));
			}
		}
	}
}

unittest
{
	import std.math: approxEqual;
	import std.typecons: AliasSeq;

	import taggedalgebraic: get;

	static struct Foo
	{
		int i;
	}
	
	static struct Bar
	{
		string s;
	}

	alias Types = AliasSeq!(Foo, Bar);
	auto hs = HStorage!Types();

	auto id = hs.add(Foo(100));
	assert(id == 0);
	assert(hs[id] == Foo(100));
	
	id = hs.add(Bar("string"));
	assert(id == 1);
	assert(hs[id] == Bar("string"));

	{
		auto foo = hs.get!Foo(0);
		version(none) auto i2 = hs.get!int(9); // should fail because there is no key '9'
		version(none) auto l = hs.get!long(2); // static assert about inappropriate type 'long'
	}

	assert(hs.length == 2);
}
