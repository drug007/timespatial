module rtree;

import rtree.sqlite_storage;
import gfm.math: vec3f, box3f;
import data_provider: Id;

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
    void addPoint(Id externalId, vec3f coords)
    {
        Point p;
        p.coords = coords;
        p.externalId = externalId;

        addPoint(p);
    }

    /// ditto
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

        v.payload = point.payload.toBlob;

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
            ret[i].payload.fromBlob(f.payload);

            // для точек в RTree можно брать координаты любого угла их BBox
            ret[i].coords = f.bbox.spatial.min;
        }

        return ret;
    }

    /// ditto
    Point[] searchPoints(in box3f searchBox)
    {
        BoundingBox bb;
        bb.spatial = searchBox;

        return searchPoints(bb);
    }
}

struct Payload
{
    Id externalId;

    auto toBlob() const pure
    {
        ubyte[Payload.sizeof] ret;

        Payload* payload = cast(Payload*) &ret;
        *payload = this;

        return ret;
    }

    void fromBlob(ubyte[Payload.sizeof] blob)
    {
        this = *cast(Payload*) &blob;
    }

    void fromBlob(ubyte[] blob)
    {
        assert(blob.length == Payload.sizeof);

        fromBlob(blob[0..Payload.sizeof]);
    }
}

struct Point
{
    vec3f coords;
    Payload payload;

    alias payload this;
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
                Point p;
                p.coords = vec3f(x, y, z);
                p.externalId.source = x;
                p.externalId.no = y;

                s.addPoint(p);
            }
        }
    }

    BoundingBox searchBox;
    searchBox.spatial.min = vec3f(-2, -2, -2);
    searchBox.spatial.max = vec3f(2, 2, 2);

    auto points = s.searchPoints(searchBox);

    assert(points.length == 5 * 5 * 5);

    destroy(s);
}

unittest
{
    auto s = new RTree(":memory:");

    import test_data; // в папке source лежит файл с тестовыми данными
    import std.algorithm.iteration: map;
    import std.algorithm: equal;

    foreach(id, e; testData)
        s.addPoint(e.id, vec3f(e.x, e.y, e.z));

    auto box = box3f(vec3f(1000, 1000, -10), vec3f(20000, 20000, 10));
    auto points = s.searchPoints(box);

    assert(points.length == 12);

    auto mm = points.map!("a.externalId.no");
    assert(equal(mm, [126, 1, 126, 1, 126, 1, 126, 1, 126, 1, 126, 1]));

    destroy(s);
}
