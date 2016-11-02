module rtree.sqlite_storage;

package:

import d2sqlite3;
import std.file: remove;
import gfm.math: box3f;

private enum spatialIndexTable = "spatial";
private enum payloadsTable = "payloads";

private enum sqlCreateSchema =
`CREATE VIRTUAL TABLE IF NOT EXISTS `~spatialIndexTable~` USING rtree
(
    id NOT NULL,
    dim1_min NOT NULL,
    dim1_max NOT NULL,
    dim2_min NOT NULL,
    dim2_max NOT NULL,
    dim3_min NOT NULL,
    dim3_max NOT NULL,
    dim4_min NOT NULL,
    dim4_max NOT NULL
);

CREATE TABLE IF NOT EXISTS `~payloadsTable~`
(
    id INTEGER NOT NULL PRIMARY KEY,
    payload BLOB NOT NULL
)
`;

class Storage
{
    private const string filePath;
    private Database db;
    private Statement addValueToIndexStatement;
    private Statement addValueToPayloadsStatement;
    private Statement getValuesStatement;

    this(in string filePath)
    {
        this.filePath = filePath;
        db = Database(filePath);
        db.run(sqlCreateSchema);

        addValueToIndexStatement = db.prepare("
            INSERT INTO "~spatialIndexTable~"
            (
                id,
                dim1_min,
                dim1_max,
                dim2_min,
                dim2_max,
                dim3_min,
                dim3_max,
                dim4_min,
                dim4_max
            )
            VALUES
            (
                :id,
                :dim1_min,
                :dim1_max,
                :dim2_min,
                :dim2_max,
                :dim3_min,
                :dim3_max,
                :dim4_min,
                :dim4_max
            )
        ");

        addValueToPayloadsStatement = db.prepare("
            INSERT INTO "~payloadsTable~"
            (
                id,
                payload
            )
            VALUES (?, ?)
        ");

        getValuesStatement = db.prepare("
            SELECT
                id,
                dim1_min,
                dim1_max,
                dim2_min,
                dim2_max,
                dim3_min,
                dim3_max,
                dim4_min,
                dim4_max,
                payload
            FROM "~spatialIndexTable~"
            JOIN "~payloadsTable~" USING(id)
            WHERE
                dim1_min >= :dim1_min AND dim1_max <= :dim1_max AND
                dim2_min >= :dim2_min AND dim2_max <= :dim2_max AND
                dim3_min >= :dim3_min AND dim3_max <= :dim3_max AND
                dim4_min >= :dim4_min AND dim4_max <= :dim4_max
        ");
    }

    ~this()
    {
        db.close;
        remove(filePath);
    }

    private bool tableIsEmpty(string spatialIndexTable)
    {
        return db.execute("SELECT * FROM "~spatialIndexTable~" LIMIT 1").empty;
    }

    /// Возвращает самый большой ID. Используется при вычислении следующего ID.
    long getMaxID()
    {
        auto res = db.execute("SELECT id FROM "~payloadsTable~" ORDER BY id DESC LIMIT 1");

        if(res.empty)
            return 0;
        else
            return res.front.peek!long(0);
    }

    void addValue(in Value v)
    {
        // Adding payload
        {
            alias q = addValueToPayloadsStatement;

            q.bindAll(v.id, v.payload);
            q.execute;
            assert(db.changes() == 1);
            q.reset();
        }

        // Adding to index
        {
            alias q = addValueToIndexStatement;

            q.bind(":id", v.id);
            q.bind(":dim1_min", v.bbox.spatial.min.x);
            q.bind(":dim1_max", v.bbox.spatial.max.x);
            q.bind(":dim2_min", v.bbox.spatial.min.y);
            q.bind(":dim2_max", v.bbox.spatial.max.y);
            q.bind(":dim3_min", v.bbox.spatial.min.z);
            q.bind(":dim3_max", v.bbox.spatial.max.z);
            q.bind(":dim4_min", v.bbox.startTime);
            q.bind(":dim4_max", v.bbox.endTime);

            q.execute;
            assert(db.changes() == 1);
            q.reset();
        }
    }

    Value[] getValues(BoundingBox bbox)
    {
        alias q = getValuesStatement;

        q.bind(":dim1_min", bbox.spatial.min.x);
        q.bind(":dim1_max", bbox.spatial.max.x);
        q.bind(":dim2_min", bbox.spatial.min.y);
        q.bind(":dim2_max", bbox.spatial.max.y);
        q.bind(":dim3_min", bbox.spatial.min.z);
        q.bind(":dim3_max", bbox.spatial.max.z);
        q.bind(":dim4_min", bbox.startTime);
        q.bind(":dim4_max", bbox.endTime);

        auto answer = q.execute;

        Value[] ret;

        foreach(row; answer)
        {
            Value v;
            v.id = row["id"].as!long;
            v.payload = row["payload"].as!(ubyte[]);

            v.bbox.spatial.min.x = row["dim1_min"].as!float;
            v.bbox.spatial.max.x = row["dim1_max"].as!float;
            v.bbox.spatial.min.y = row["dim2_min"].as!float;
            v.bbox.spatial.max.y = row["dim2_max"].as!float;
            v.bbox.spatial.min.z = row["dim3_min"].as!float;
            v.bbox.spatial.max.z = row["dim3_max"].as!float;
            v.bbox.startTime = row["dim4_min"].as!float;
            v.bbox.endTime = row["dim4_max"].as!float;

            ret ~= v;
        }

        q.reset();

        return ret;
    }
}

struct BoundingBox
{
    box3f spatial;
    long startTime;
    long endTime;
}

struct Value
{
    long id;
    BoundingBox bbox;
    ubyte[] payload;
}

unittest
{
    import std.file: tempDir;

    auto s = new Storage(tempDir ~ "/__unittest_sqlite.db"); // FIXME: что сделать с юниксовым слэшем чтобы тест и в виндах работал?

    assert(s.tableIsEmpty(spatialIndexTable));

    Value t;
    t.id = 123;
    t.bbox.spatial.min.x = 1;
    t.bbox.spatial.max.x = 2;
    t.bbox.spatial.min.y = 1;
    t.bbox.spatial.max.y = 2;
    t.bbox.spatial.min.z = 1;
    t.bbox.spatial.max.z = 2;
    t.bbox.startTime = 1;
    t.bbox.endTime = 2;
    t.payload = [0xDE, 0xAD, 0xBE, 0xEF];

    s.addValue(t);

    {
        Value t1;
        t1.id = 256;
        t1.bbox.spatial.min.x = 10;
        t1.bbox.spatial.max.x = 20;
        t1.bbox.spatial.min.y = 10;
        t1.bbox.spatial.max.y = 20;
        t1.bbox.spatial.min.z = 10;
        t1.bbox.spatial.max.z = 20;
        t1.bbox.startTime = 10;
        t1.bbox.endTime = 20;
        t1.payload = [0xDE, 0xAD, 0xBE, 0xEF];

        s.addValue(t1);
    }

    assert(s.getMaxID() == 256);

    BoundingBox searchBox;
    searchBox.spatial.min.x = 0;
    searchBox.spatial.max.x = 3;
    searchBox.spatial.min.y = 0;
    searchBox.spatial.max.y = 3;
    searchBox.spatial.min.z = 0;
    searchBox.spatial.max.z = 3;
    searchBox.startTime = 0;
    searchBox.endTime = 3;

    auto r = s.getValues(t.bbox);
    assert(r.length == 1);
    assert(r[0].id == t.id);
    assert(r[0].bbox == t.bbox);

    delete s;
}
