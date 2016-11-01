module rtree;

import rtree.sqlite_storage;
import gfm.math: vec3f;

class RTree
{
    private Storage storage;

    this(string fileName)
    {
        // TODO: сделать автоматический выбор подходящей директории
        // с помощью пакетов типа xdgpaths или standardpaths

        storage = new Storage(fileName);
    }

    /// Сохраняет точку (вершину) в хранилище
    void addPoint(long id, vec3f coords, float time, ubyte[] payload)
    {
        Value v;
        v.id = id,

        // При хранении точек R*Tree BBox имеет размер 1 точка,
        // поэтому min и max совпадают
        v.bbox.dim1.min = coords.x;
        v.bbox.dim1.max = coords.x;
        v.bbox.dim2.min = coords.y;
        v.bbox.dim2.max = coords.y;
        v.bbox.dim3.min = coords.z;
        v.bbox.dim3.max = coords.z;

        // Та же ситуация и для точек во времени
        v.bbox.dim4.min = time;
        v.bbox.dim4.max = time;

        v.payload = payload;

        storage.addValue(v);
    }
}

unittest
{
    auto s = new RTree("__unittest_rtree.db");

    s.addPoint(100, vec3f(1,2,3), 4, [0xDE, 0xAD, 0xBE, 0xEF]);
}
