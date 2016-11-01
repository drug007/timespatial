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
    void addPoint(Point point)
    {
        Value v;
        v.id = point.id,

        // При хранении точек R*Tree BBox имеет размер 1 точка,
        // поэтому min и max совпадают
        v.bbox.dim1.min = point.coords.x;
        v.bbox.dim1.max = point.coords.x;
        v.bbox.dim2.min = point.coords.y;
        v.bbox.dim2.max = point.coords.y;
        v.bbox.dim3.min = point.coords.z;
        v.bbox.dim3.max = point.coords.z;

        // Та же ситуация и для точек во времени
        v.bbox.dim4.min = point.time;
        v.bbox.dim4.max = point.time;

        v.payload = point.payload;

        storage.addValue(v);
    }
}

struct Point
{
    long id;
    vec3f coords;
    float time;
    ubyte[] payload;
}

unittest
{
    auto s = new RTree("__unittest_rtree.db");

    Point p1;
    p1.id = 100;
    p1.coords = vec3f(1,2,3);
    p1.time = 4;
    p1.payload = [0xDE, 0xAD, 0xBE, 0xEF];

    s.addPoint(p1);
}
