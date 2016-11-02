module rtree;

import rtree.sqlite_storage;
import gfm.math: vec3f, box3f;

class RTree
{
    private Storage storage;
    private long idCounter;

    this(string fileName)
    {
        // TODO: сделать автоматический выбор подходящей директории
        // с помощью пакетов типа xdgpaths или standardpaths

        storage = new Storage(fileName);
        idCounter = storage.getMaxID;
    }

    ~this()
    {
        destroy(storage);
    }

    /// Сохраняет точку (вершину) в хранилище
    void addPoint(Point point)
    {
        Value v;

        idCounter++;
        v.id = idCounter,

        // При хранении точек BBox имеет размер 1 точка,
        // поэтому min и max совпадают
        v.bbox.spatial.min.x = point.coords.x;
        v.bbox.spatial.max.x = point.coords.x;
        v.bbox.spatial.min.y = point.coords.y;
        v.bbox.spatial.max.y = point.coords.y;
        v.bbox.spatial.min.z = point.coords.z;
        v.bbox.spatial.max.z = point.coords.z;

        // Та же ситуация и для точек во времени
        v.bbox.startTime = point.time;
        v.bbox.endTime = point.time;

        v.payload = point.payload;

        storage.addValue(v);
    }

    /// Находит все точки, которые лежат внутри и на заданных координатах
    Point[] searchPoints(in BoundingBox searchBox)
    {
        auto found = storage.getValues(searchBox);

        Point[] ret;
        ret.length = found.length;

        foreach(i, f; found)
        {
            ret[i].payload = f.payload;

            // для точек в RTree можно брать координаты любого угла их BBox
            ret[i].coords = f.bbox.spatial.min;

            // для времени это тоже справедливо
            ret[i].time = f.bbox.startTime;
        }

        return ret;
    }
}

struct Point
{
    vec3f coords;
    float time;
    ubyte[] payload;
}

unittest
{
    auto s = new RTree("__unittest_rtree.db");

    Point p1;
    p1.coords = vec3f(1,2,3);
    p1.time = 4;
    p1.payload = [0xDE, 0xAD, 0xBE, 0xEF];

    s.addPoint(p1);

    BoundingBox searchBox;
    searchBox.spatial.min = vec3f(0, 0, 0);
    searchBox.spatial.max = vec3f(9, 9, 9);
    searchBox.startTime = 0;
    searchBox.endTime = 9;

    auto points = s.searchPoints(searchBox);
    assert(points.length == 1);
    assert(points[0] == p1);

    destroy(s);
}
