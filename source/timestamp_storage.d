module timestamp_storage;

struct TimestampStorage
{
	import std.array: array;
	import std.range: ElementType, isInputRange;

	private
	{
	    long[] _timestamp;
	    long   _idx;
	}

    invariant
    {
        assert(_idx >= 0);
        if(_timestamp.length)
            assert(_idx < _timestamp.length);
    }

    this(R)(R r) if(isInputRange!R && is(ElementType!R == long))
    {
        _timestamp = r.array;
    }

    auto addTimestamps(R)(R r) if(isInputRange!R)
    {
    	import std.array: array;
    	import std.algorithm: sort, uniq;

    	auto buf = (_timestamp ~ r.array).sort().uniq().array;
    	_timestamp = buf;
    }

    auto current()
    {
        return _timestamp[_idx];
    }

    auto currIndex()
    {
        return _idx;
    }

    auto timeByIndex(long idx)
    {
        return _timestamp[idx];
    }

    auto length()
    {
        return _timestamp.length;
    }

    auto set(long value)
    {        
        move(value - current);
    }

    auto setIndex(long idx)
    {        
        assert(_timestamp.length && idx >= 0);
        if(_timestamp.length)
            assert(idx < _timestamp.length);
        _idx = idx;
    }

    auto moveNext()
    {
        if(_idx < _timestamp.length - 1)
            _idx++;
    }

    auto movePrev()
    {
        if(_idx > 0)
            _idx--;
    }

    auto move(long delta)
    {
        long lim = current + delta;

        if(delta > 0)
        {
            while((current() < lim) && (_idx < _timestamp.length - 1))
                moveNext();
        }
        else
        {
            while((current() > lim) && (_idx > 0))
                movePrev(); 
        }
    }
}

unittest
{   
    import std.range: iota;
    import std.array: array;

    auto s = TimestampStorage(1.iota(10L).array);

    assert(s.current == 1);
    s.movePrev();
    assert(s.current == 1);
    s.moveNext();
    assert(s.current == 2);
    s.moveNext();
    assert(s.current == 3);
    s.move(3);
    assert(s.current == 6);
    s.move(2);
    assert(s.current == 8);
    s.move(5);
    assert(s.current == 9);
    s.move(-2);
    assert(s.current == 7);
    s.move(-3);
    assert(s.current == 4);
    s.move(-6);
    assert(s.current == 1);
}
