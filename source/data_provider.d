module data_provider;

import std.algorithm: map;

import gfm.math: vec3f, vec4f, box3f;

import data_item: DataItem, Attr;
import vertex_provider: VertexProvider;

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

interface IRenderableData
{
    long[] getTimestamps();
    void setTimeWindow(long min, long max);
    void setMaxCount(long count);
    Auxillary[] getAuxillary();
    uint getNo();
    void setVisibility(bool value);
    bool getVisibility();
}

/// Дополнительные данные, позволяют добавить к данным доп. информацию
/// без необходимости затрагивать исходные данные.
struct Auxillary
{
    uint no;
    VertexProvider[] vp;
}


class RenderableData(DataSet) : IRenderableData
{
    import vertex_provider: VertexProvider;

    // Ограничивающий параллелепипед
    box3f box;

    uint no;
    DataSet*[] data; // TODO transfer dataset pointer to Auxillary struct 
    Auxillary[] aux;
    private bool _visibility;

    this(uint no)
    {
        this.no = no;
        _visibility = true;
    }

    auto addDataSet(ref DataSet dataset, VertexProvider vp)
    {
        data ~= &dataset;
        aux ~= Auxillary(dataset.header.no, [vp]);
        updateBoundingBox(box, dataset.header.box);
    }

    long[] getTimestamps()
    {
        import std.algorithm: sort, uniq;
        import std.array: array;

        long[] times;
        foreach(e; data)
            times ~= e.idx[].map!(a=>a.timestamp).array;
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
            // последовательность без пропусков
            auto filtered = d.idx[].enumerate(0).find!((a,b)=>a.value.timestamp >= b)(min);
            uint start, length;
            if (filtered.empty)
            {
                // there is no any element with bigger than / equal to the minimal one, so
                // the window is empty
                start = 0;
                length = 0;
            }
            else
            {
                // start is equal to the index of first element that is bigger or equal to the minimal element
                start = filtered.front.index;
            
                filtered = d.idx[].enumerate(0).find!((a,b)=>a.value.timestamp >= b)(max);
                if(!filtered.empty)
                    // start+length is equal to index of first element that is bigger or equal to the maximal one
                    length = filtered.front.index - start;
                else
                    // нет элемента больше/равного максимальному, значит
                    // start+length должны равнятся индексу последнего элемента
                    // if there is no element bigger or equal to the maximal element
                    // then start+length = the last element index
                    length = cast(uint) d.idx[].length - 1 - start;
            }

            foreach(vp; a.vp)
            {
                foreach(ref slice; vp.currSlices)
                {
                    slice.start  = start;
                    slice.length = length;
                }
            }
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

    Auxillary[] getAuxillary()
    {
        return aux;
    }

    uint getNo()
    {
        return no;
    }

    void setVisibility(bool value)
    {
        _visibility = value;
        foreach(a; aux)
            foreach(vp; a.vp)
                vp.visible = value;
    }

    bool getVisibility()
    {
        return _visibility;
    }
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
