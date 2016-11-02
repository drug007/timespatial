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
    min_x NOT NULL,
    max_x NOT NULL,
    min_y NOT NULL,
    max_y NOT NULL,
    min_z NOT NULL,
    max_z NOT NULL,
    start_time NOT NULL,
    end_time NOT NULL
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
                min_x,
                max_x,
                min_y,
                max_y,
                min_z,
                max_z,
                start_time,
                end_time
            )
            VALUES
            (
                :id,
                :min_x,
                :max_x,
                :min_y,
                :max_y,
                :min_z,
                :max_z,
                :start_time,
                :end_time
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
                min_x,
                max_x,
                min_y,
                max_y,
                min_z,
                max_z,
                start_time,
                end_time,
                payload
            FROM "~spatialIndexTable~"
            JOIN "~payloadsTable~" USING(id)
            WHERE
                min_x >= :min_x AND max_x <= :max_x AND
                min_y >= :min_y AND max_y <= :max_y AND
                min_z >= :min_z AND max_z <= :max_z AND
                start_time >= :start_time AND end_time <= :end_time
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
            q.bind(":min_x", v.bbox.spatial.min.x);
            q.bind(":max_x", v.bbox.spatial.max.x);
            q.bind(":min_y", v.bbox.spatial.min.y);
            q.bind(":max_y", v.bbox.spatial.max.y);
            q.bind(":min_z", v.bbox.spatial.min.z);
            q.bind(":max_z", v.bbox.spatial.max.z);
            q.bind(":start_time", v.bbox.startTime);
            q.bind(":end_time", v.bbox.endTime);

            q.execute;
            assert(db.changes() == 1);
            q.reset();
        }
    }

    Value[] getValues(BoundingBox bbox)
    {
        alias q = getValuesStatement;

        q.bind(":min_x", bbox.spatial.min.x);
        q.bind(":max_x", bbox.spatial.max.x);
        q.bind(":min_y", bbox.spatial.min.y);
        q.bind(":max_y", bbox.spatial.max.y);
        q.bind(":min_z", bbox.spatial.min.z);
        q.bind(":max_z", bbox.spatial.max.z);
        q.bind(":start_time", bbox.startTime);
        q.bind(":end_time", bbox.endTime);

        auto answer = q.execute;

        Value[] ret;

        foreach(row; answer)
        {
            Value v;
            v.id = row["id"].as!long;
            v.payload = row["payload"].as!(ubyte[]);

            v.bbox.spatial.min.x = row["min_x"].as!float;
            v.bbox.spatial.max.x = row["max_x"].as!float;
            v.bbox.spatial.min.y = row["min_y"].as!float;
            v.bbox.spatial.max.y = row["max_y"].as!float;
            v.bbox.spatial.min.z = row["min_z"].as!float;
            v.bbox.spatial.max.z = row["max_z"].as!float;
            v.bbox.startTime = row["start_time"].as!float;
            v.bbox.endTime = row["end_time"].as!float;

            ret ~= v;
        }

        q.reset();

        return ret;
    }
}

struct BoundingBox
{
    box3f spatial;
    float startTime;
    float endTime;
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
        t1.payload = [0x11, 0x22, 0x33, 0x44];

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
    assert(r[0].payload == t.payload);

    destroy(s);
}
