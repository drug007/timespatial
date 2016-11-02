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
        delete storage;
    }

    /// Сохраняет точку (вершину) в хранилище
    void addPoint(Point point)
    {
        Value v;

        idCounter++;
        v.id = idCounter,

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

    /// Находит все точки, которые лежат внутри и на заданных координатах
    Point[] searchPoints(box3f bbox, float startTime, float endTime)
    {
        BoundingBox searchBox;
        searchBox.dim1.min = bbox.min.x;
        searchBox.dim1.max = bbox.max.x;
        searchBox.dim2.min = bbox.min.y;
        searchBox.dim2.max = bbox.max.y;
        searchBox.dim3.min = bbox.min.z;
        searchBox.dim3.max = bbox.max.z;
        searchBox.dim4.min = startTime;
        searchBox.dim4.max = endTime;

        auto found = storage.getValues(searchBox);

        Point[] ret;
        ret.length = found.length;

        foreach(i, f; found)
        {
            ret[i].payload = f.payload;

            // для точек в RTree можно брать координаты любого угла их BBox
            ret[i].coords.x = f.bbox.dim1.min;
            ret[i].coords.y = f.bbox.dim2.min;
            ret[i].coords.z = f.bbox.dim3.min;
            ret[i].time = f.bbox.dim4.min;
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

    auto points = s.searchPoints(box3f(vec3f(0, 0, 0), vec3f(9, 9, 9)), 0, 9);
    assert(points.length == 1);
    assert(points[0] == p1);

    delete s;
}
