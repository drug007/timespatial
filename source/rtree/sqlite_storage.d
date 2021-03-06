module rtree.sqlite_storage;

package:

import d2sqlite3;
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
    max_z NOT NULL
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
                max_z
            )
            VALUES
            (
                :id,
                :min_x,
                :max_x,
                :min_y,
                :max_y,
                :min_z,
                :max_z
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
                payload
            FROM "~spatialIndexTable~"
            JOIN "~payloadsTable~" USING(id)
            WHERE
                min_x >= :min_x AND max_x <= :max_x AND
                min_y >= :min_y AND max_y <= :max_y AND
                min_z >= :min_z AND max_z <= :max_z
        ");
    }

    ~this()
    {
        db.close;
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
            q.bind(":min_x", v.bbox.min.x);
            q.bind(":max_x", v.bbox.max.x);
            q.bind(":min_y", v.bbox.min.y);
            q.bind(":max_y", v.bbox.max.y);
            q.bind(":min_z", v.bbox.min.z);
            q.bind(":max_z", v.bbox.max.z);

            q.execute;
            assert(db.changes() == 1);
            q.reset();
        }
    }

    Value[] getValues(ref const(box3f) bbox)
    {
        alias q = getValuesStatement;

        q.bind(":min_x", bbox.min.x);
        q.bind(":max_x", bbox.max.x);
        q.bind(":min_y", bbox.min.y);
        q.bind(":max_y", bbox.max.y);
        q.bind(":min_z", bbox.min.z);
        q.bind(":max_z", bbox.max.z);

        auto answer = q.execute;

        Value[] ret;

        foreach(row; answer)
        {
            Value v;
            v.id = row["id"].as!long;
            v.payload = row["payload"].as!(ubyte[]);

            v.bbox.min.x = row["min_x"].as!float;
            v.bbox.max.x = row["max_x"].as!float;
            v.bbox.min.y = row["min_y"].as!float;
            v.bbox.max.y = row["max_y"].as!float;
            v.bbox.min.z = row["min_z"].as!float;
            v.bbox.max.z = row["max_z"].as!float;

            ret ~= v;
        }

        q.reset();

        return ret;
    }
}

struct Value
{
    long id;
    box3f bbox;
    ubyte[] payload;
}

unittest
{
    auto s = new Storage(":memory:");

    assert(s.tableIsEmpty(spatialIndexTable));

    Value t;
    t.id = 123;
    t.bbox.min.x = 1;
    t.bbox.max.x = 2;
    t.bbox.min.y = 1;
    t.bbox.max.y = 2;
    t.bbox.min.z = 1;
    t.bbox.max.z = 2;
    t.payload = [0xDE, 0xAD, 0xBE, 0xEF];

    s.addValue(t);

    {
        Value t1;
        t1.id = 256;
        t1.bbox.min.x = 10;
        t1.bbox.max.x = 20;
        t1.bbox.min.y = 10;
        t1.bbox.max.y = 20;
        t1.bbox.min.z = 10;
        t1.bbox.max.z = 20;
        t1.payload = [0x11, 0x22, 0x33, 0x44];

        s.addValue(t1);
    }

    assert(s.getMaxID() == 256);

    box3f searchBox;
    searchBox.min.x = 0;
    searchBox.max.x = 3;
    searchBox.min.y = 0;
    searchBox.max.y = 3;
    searchBox.min.z = 0;
    searchBox.max.z = 3;

    auto r = s.getValues(t.bbox);
    assert(r.length == 1);
    assert(r[0].id == t.id);
    assert(r[0].bbox == t.bbox);
    assert(r[0].payload == t.payload);

    destroy(s);
}
