module data_provider;

import std.algorithm: map;

import gfm.math: vec3f, vec4f, box3f;

import data_item: DataItem, Attr;
import vertex_provider: VertexProvider;

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

ref box3f updateBoundingBox(ref box3f one, ref const(box3f) another)
{
    if(one.min.x > another.min.x)
        one.min.x = another.min.x;
    if(one.min.y > another.min.y)
        one.min.y = another.min.y;
    if(one.min.z > another.min.z)
        one.min.z = another.min.z;

    if(one.max.x < another.max.x)
        one.max.x = another.max.x;
    if(one.max.y < another.max.y)
        one.max.y = another.max.y;
    if(one.max.z < another.max.z)
        one.max.z = another.max.z;

    return one;
}

ref box3f updateBoundingBox(ref box3f one, ref const(vec3f) another)
{
    if(one.min.x > another.x)
        one.min.x = another.x;
    if(one.min.y > another.y)
        one.min.y = another.y;
    if(one.min.z > another.z)
        one.min.z = another.z;

    if(one.max.x < another.x)
        one.max.x = another.x;
    if(one.max.y < another.y)
        one.max.y = another.y;
    if(one.max.z < another.z)
        one.max.z = another.z;

    return one;
}

struct DataElement
{
    @("Disabled")
    uint no;
    float x, y, z;
    @("Disabled")
    float r, g, b, a;
    @("Timestamp")
    long timestamp;
}

struct DataObject
{
    @("Disabled")
    uint no;
    @("Disabled")
    bool visible;
    @("Disabled")
    box3f box;

    import vertex_provider: VertexSlice;
    @("Disabled")
    VertexSlice.Kind kind;
    DataElement[] elements;
}

interface IRenderableData
{
    long[] getTimestamps();
    void setTimeWindow(long min, long max);
    void setMaxCount(long count);
}

/// Дополнительные данные, позволяют добавить к данным доп. информацию
/// без необходимости затрагивать исходные данные.
struct Auxillary
{
    uint no;
    VertexProvider[] vp;
}


class RenderableData(R) : IRenderableData
{
    // Ограничивающий параллелепипед
    box3f box;

    uint no;
    R data;
    Auxillary[] aux;

    this(uint no, R r, uint delegate() generateUniqId)
    {
        import std.range: ElementType, walkLength;

        static if(is(ElementType!R == DataObject))
        {
            import std.array: array;
            
            this.no = no;
            data = r;
            aux = data.map!(a=>Auxillary(a.no, [])).array;

            box = box3f(
                vec3f(float.max, float.max, float.max),
                vec3f(float.min_normal, float.min_normal, float.min_normal),
            );

            import std.range: lockstep;
            import vertex_provider: Vertex, VertexSlice;
            foreach(ref d, ref a; lockstep(data, aux))
            {
                updateBoundingBox(box, d.box);

                auto vertices = d.elements.map!(a=>Vertex(
                    vec3f(a.x, a.y, a.z),      // position
                    vec4f(a.r, a.g, a.b, a.a), // color
                )).array;

                auto uniq_id = generateUniqId();
                a.vp ~= new VertexProvider(uniq_id, vertices, [VertexSlice(d.kind, 0, vertices.length)]);
            }

        }
        else
            static assert(0, "Supported only ranges with DataObjects element type, not '" ~ (ElementType!R).stringof ~ "' (type of the range is '" ~ R.stringof ~ "'");
    }

    long[] getTimestamps()
    {
        import std.algorithm: sort, uniq;
        import std.array: array;

        long[] times;
        foreach(e; data)
            times ~= e.elements.map!(a=>a.timestamp).array;
        return times.sort().uniq().array;
    }

    /// Устанавливает временное окно, доступными становятся только
    /// данные внутри этого окна
    void setTimeWindow(long min, long max)
    {
        import std.algorithm: find;
        import std.array: back, empty, front;
        import std.range: enumerate, lockstep;
        import vertex_provider: VertexSlice;

        foreach(ref d, a; lockstep(data, aux))
        {
            // важным инвариантом является отсортированность данных по временным отметкам
            // поэтому данные, попавшие во временное окно представляют собой также упорядоченную
            // последовательность без пропусков по сравнению с исходными данными
            //auto filtered = d.elements.filter!(a => a.timestamp > min && a.timestamp <= max);
            auto filtered = d.elements.enumerate(0).find!((a,b)=>a.value.timestamp >= b)(min);
            uint start, length;
            if(!filtered.empty)
                start = filtered.front.index;
            else
                start = 0;
            filtered = d.elements.enumerate(1).find!((a,b)=>a.value.timestamp >= b)(max);
            if(!filtered.empty)
                length = filtered.front.index - start;
            else
                length = cast(uint) d.elements.length - start;

            auto s  = VertexSlice(VertexSlice.Kind.LineStrip, start, length);
            a.vp.front.currSlices = [s]; // FIXME почему слайс приваивается только первому vertex provider'у?
        }
    }

    /// Ограничивает размер срезов не больше заданного
    void setMaxCount(long count)
    {
        foreach(ref a; aux)
        {
            foreach(ref vp; a.vp)
                foreach(ref s; vp.currSlices)
                    if(s.length > count)
                    {
                        s.start = s.start + s.length - count;
                        s.length = count;
                    }
        }
    }
}

auto makeRenderableData(R, D)(uint no, R r, D d)
{
    return new RenderableData!(R)(no, r, d);
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
