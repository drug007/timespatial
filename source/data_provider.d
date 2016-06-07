module data_provider;

import std.algorithm: map;

import gfm.math: vec3f, vec4f, box3f;

import infoof: InfoOf, IInfoOf;
import vertex_provider: VertexProvider;

struct TimestampSlider
{
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

    this(long[] timestamp)
    {
        assert(timestamp.length);
        _timestamp = timestamp;
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

    auto set(ulong value)
    {        
        move(value - current);
    }

    auto setIndex(ulong idx)
    {        
        assert(idx >= 0);
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

    auto s = TimestampSlider(1.iota(10L).array);

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
    long timestamp;
    State state;
}

struct Point
{
    vec3f xyz;
    long timestamp;
    Data.State state;
}

struct Path
{
    uint no;
    Point[] point;
}

struct Dataset
{
	// dataset no
	uint no;
	Path[] path;
}

class TimeSpatial
{
	// Ограничивающий параллелепипед
	box3f _box;

    static struct Record
    {
        Dataset dataset;
        bool visible;
        VertexProvider[] vertex_provider;
    }

    Record[] record;

    long[] times;

    this(Data[] data)
    {
        import std.algorithm: map, sort, uniq;
        import std.array: array;

        assert(data.length);
    	prepareData(data);
        times = data.map!("a.timestamp").array;
    }

    /// Освобождает ресурсы
    void close()
    {
    }

    ref const(box3f) box() const return
    {
        return _box;
    }

    /// Устанавливает ограничение на максимальное количество доступных
    /// элементов данных. Позволяет обрабатывать не больше заданного 
    /// числа элементов
    void setElementCount(long n)
    {
    	foreach(ref nested; record.map!"a.vertex_provider")
    		foreach(ref vp; nested)
                vp.setElementCount(n);
    }

    /// Устанавливает временное окно, доступными становятся только
    /// данные внутри этого окна
    void setTimeWindow(long min, long max)
	{
		import std.algorithm: filter;
	    import std.array: array, back;
	    import std.math: isNaN;
	    import vertex_provider: Vertex, VertexSlice;

	    Vertex[] vertices, vertices2;
	    VertexSlice[] slices, slices2;

	    foreach(ref r; record)
	    {
            r.vertex_provider = null;
	        foreach(ref path; r.dataset.path)
	        {
	        	auto s  = VertexSlice(VertexSlice.Kind.LineStrip, vertices.length, 0);
	            auto s2 = VertexSlice(VertexSlice.Kind.Triangles, vertices.length*3, 0);
	            auto filtered_points = path.point.filter!(a => a.timestamp > min && a.timestamp <= max);
                auto color = sourceToColor(r.dataset.no);
	            auto buf = intermediateToTarget(color, filtered_points).array;
                if(!buf.length)
                    continue;
                
                vertices ~= buf;
	            color = vec4f(0.1, 0.99, 0.2, 1);
	            vertices2 ~= intermediateToTriangle(color, filtered_points).array;
	            s.length = vertices.length - s.start;
	            s2.length = 3*s.length;
	            
                slices ~= s;
                slices2 ~= s2;

                if(vertices.length)
                    r.vertex_provider ~= new VertexProvider(vertices, slices, _box.min, _box.max);
                if(vertices2.length)
                   r.vertex_provider  ~= new VertexProvider(vertices2, slices2, _box.min, _box.max);
	        }
	    }
    }

private:

    private void prepareData(Data[] data)
	{
		import std.algorithm: filter, sort, map;
	    import std.array: array, back;
	    import std.math: isNaN;
	    import vertex_provider: Vertex, VertexSlice;

	    _box = box3f(
            vec3f(float.max, float.max, float.max),
            vec3f(float.min_normal, float.min_normal, float.min_normal),
        );

	    Path[uint][uint] idata;

	    foreach(e; data)
	    {
	        auto s = idata.get(e.id.source, null);

	        if((s is null) || (e.id.no !in s))
	        {
	            idata[e.id.source][e.id.no] = Path(e.id.no, [Point(vec3f(e.x, e.y, e.z), e.timestamp, e.state)]);
	        }
	        else
	        {
	            s[e.id.no].point ~= Point(vec3f(e.x, e.y, e.z), e.timestamp, e.state);
	        }

            // finding minimal and maximum values of bounding box
            if(!e.x.isNaN)
            {
                if(e.x > _box.max.x)
                    _box.max.x = e.x;
                if(e.x < _box.min.x)
                    _box.min.x = e.x;
            }

            if(!e.y.isNaN)
            {
                if(e.y > _box.max.y)
                    _box.max.y = e.y;
                if(e.y < _box.min.y)
                    _box.min.y = e.y;
            }

            if(!e.z.isNaN)
            {
                if(e.z > _box.max.z)
                    _box.max.z = e.z;
                if(e.z < _box.min.z)
                    _box.min.z = e.z;
            }
        }

        foreach(dataset_no; idata.byKey)
        {
            Dataset ds;
            ds.no = dataset_no;
            foreach(ref path; idata[dataset_no])
            {
                ds.path ~= path;
            }
            record ~= Record(ds, true, null);
        }
    }

    static auto intermediateToTarget(T)(ref const(vec4f) color, ref T points)
    {
    	import std.algorithm: map;
	    import vertex_provider: Vertex;

        return points.map!(a => Vertex(
                a.xyz,
                color,
            ));
    }

    static auto intermediateToTriangle(T)(ref const(vec4f) color, ref T points)
    {
    	import std.algorithm: map;
        import std.math: sqrt, sin, PI, tan;
	    import vertex_provider: Vertex;

        enum h = 500.;

        Vertex[] flatten;
        auto c = h*tan(PI/6);
        auto b = h*sin(PI/3) - c;

        foreach(a; points)
        {
        	flatten ~= Vertex(
                a.xyz + vec3f(0, c, 0),
                color,
            );
            flatten ~= Vertex(
                a.xyz + vec3f(-h/2, -b, 0),
                color,
            );
            flatten ~= Vertex(
                a.xyz + vec3f(+h/2, -b, 0),
                color,
            );
        }

        return flatten;
    }
}

interface IDataLayout
{
    /// return true if during gui phase data has been changed
    /// and updating is requiring
    abstract bool draw();
}

struct DataProvider
{
public:

    this(TimeSpatial[] timespatial, IDataLayout[] data_widget)
    {
    	import std.algorithm: map, sort, uniq;
	    import std.array: array, back;

        _timespatial = timespatial;

        _box = box3f(
            vec3f(float.max, float.max, float.max),
            vec3f(float.min_normal, float.min_normal, float.min_normal),
        );

        long[] times;
        foreach(dd; _timespatial)
        {
            times ~= dd.times;
            version(none)
            {
                // here we can dispose allocated memory if `times` aren't
                // needed more
                dd.times = []; 
            }
            updateBoundingBox(dd.box);
        }
        times = times.sort().uniq().array;
        _timeslider = TimestampSlider(times);

        _data_layout = data_widget;
    }

    auto box() const
    {
        return _box;
    }

    void updateTimeWindow()
    {
        foreach(dd; _timespatial)
        {
            dd.setTimeWindow(long.min, _timeslider.current);
        }
    }

    void setElementCount(long count)
    {
        foreach(dd; _timespatial)
        {
            dd.setElementCount(count);
        }
    }

    auto timeSpatial()
    {
        return _timespatial;
    }

    ref auto timeslider() return
    {
        return _timeslider;
    }

    auto close()
    {
        // do nothing
    }

    bool drawGui()
    {
        auto invalidated = false;
        foreach(ref dw; _data_layout)
            if(dw.draw())
                invalidated = true;
        return invalidated;
    }

private:

    void updateBoundingBox(ref const(box3f) other)
    {
        if(_box.min.x > other.min.x)
            _box.min.x = other.min.x;
        if(_box.min.y > other.min.y)
            _box.min.y = other.min.y;
        if(_box.min.z > other.min.z)
            _box.min.z = other.min.z;

        if(_box.max.x < other.max.x)
            _box.max.x = other.max.x;
        if(_box.max.y < other.max.y)
            _box.max.y = other.max.y;
        if(_box.max.z < other.max.z)
            _box.max.z = other.max.z;
    }

    box3f _box;

    TimeSpatial[] _timespatial;

    TimestampSlider _timeslider;
    
    IDataLayout[]  _data_layout;
}

auto sourceToColor(uint source)
{
    auto colors = [
          1:vec4f(1.0, 0.0, 0.0, 1.0), 
          2:vec4f(0.0, 1.0, 0.0, 1.0), 
          3:vec4f(0.0, 0.0, 1.0, 1.0), 
          4:vec4f(1.0, 1.0, 0.5, 1.0), 
          5:vec4f(1.0, 0.5, 0.5, 1.0), 
          6:vec4f(1.0, 1.0, 0.5, 1.0), 
          7:vec4f(1.0, 1.0, 0.5, 1.0), 
          8:vec4f(1.0, 1.0, 0.5, 1.0), 
          9:vec4f(1.0, 1.0, 0.5, 1.0), 
         10:vec4f(1.0, 1.0, 0.5, 1.0), 
         11:vec4f(1.0, 1.0, 0.5, 1.0), 
         12:vec4f(1.0, 1.0, 0.5, 1.0), 
         13:vec4f(1.0, 1.0, 0.5, 1.0), 
         14:vec4f(1.0, 1.0, 0.5, 1.0), 
         15:vec4f(1.0, 1.0, 0.5, 1.0), 
         16:vec4f(1.0, 1.0, 0.5, 1.0), 
         17:vec4f(1.0, 1.0, 0.5, 1.0), 
         29:vec4f(0.6, 0.9, 0.5, 1.0),
         31:vec4f(1.0, 1.0, 0.5, 1.0),
        777:vec4f(0.9, 0.5, 0.6, 1.0),
        999:vec4f(1.0, 1.0, 1.0, 1.0),
     16_834:vec4f(1.0, 1.0, 1.0, 1.0),
    ];

    return colors.get(source, vec4f(1, 0, 1, 1));
}
