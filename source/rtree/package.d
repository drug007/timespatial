module rtree;

import rtree.sqlite_storage;
import gfm.math: vec3f, box3f;

class RTree
{
    private Storage storage;

    this(string fileName)
    {
        // TODO: сделать автоматический выбор подходящей директории
        // с помощью пакетов типа xdgpaths или standardpaths

        storage = new Storage(fileName);
    }

    ~this()
    {
        destroy(storage);
    }

    /// Сохраняет точку (вершину) в хранилище
    void addPoint(long id, vec3f coords, ubyte[] payload)
    {
        Value v;

        v.id = id,

        // При хранении точек BBox имеет размер 1 точка,
        // поэтому min и max совпадают
        v.bbox.min.x = coords.x;
        v.bbox.max.x = coords.x;
        v.bbox.min.y = coords.y;
        v.bbox.max.y = coords.y;
        v.bbox.min.z = coords.z;
        v.bbox.max.z = coords.z;

        v.payload = payload;

        storage.addValue(v);
    }

    /// Находит все точки, которые лежат внутри и на границах bounding box
    auto searchPoints(in box3f searchBox)
    {
        import std.algorithm: map;
        import std.array: array;

        return storage.getValues(searchBox);
    }
}

unittest
{
    auto s = new RTree(":memory:");

    size_t id;
    foreach(z; -5..5)
    {
        foreach(y; -5..5)
        {
            foreach(x; -5..5)
            {
                s.addPoint(id++, vec3f(x, y, z), [0]);
            }
        }
    }

    box3f searchBox;
    searchBox.min = vec3f(-2, -2, -2);
    searchBox.max = vec3f(2, 2, 2);

    auto points = s.searchPoints(searchBox);

    assert(points.length == 5 * 5 * 5);

    destroy(s);
}
