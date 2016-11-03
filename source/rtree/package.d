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
        v.bbox.setTimeInterval(point.time, point.time);

        v.payload = point.payload;

        storage.addValue(v);
    }

    /// Находит все точки, которые лежат внутри и на границах bounding box
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
    long time;
    ubyte[] payload;
}

unittest
{
    auto s = new RTree(":memory:");

    foreach(z; -5..5)
    {
        foreach(y; -5..5)
        {
            foreach(x; -5..5)
            {
                foreach(time; 0..10)
                {
                    Point p;
                    p.coords = vec3f(x, y, z);
                    p.time = time;
                    p.payload = [0xDE, 0xAD, 0xBE, 0xEF];

                    s.addPoint(p);
                }
            }
        }
    }

    BoundingBox searchBox;
    searchBox.spatial.min = vec3f(-2, -2, -2);
    searchBox.spatial.max = vec3f(2, 2, 2);
    searchBox.setTimeInterval(3, 5);

    auto points = s.searchPoints(searchBox);

    assert(points.length == 5 * 5 * 5 * 3);
    assert(points[100].payload == [0xDE, 0xAD, 0xBE, 0xEF]);

    destroy(s);
}
