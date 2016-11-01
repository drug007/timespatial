module rtree.sqlite_storage;

import d2sqlite3;
import std.file: remove;

private enum tableName = "spatial";

private enum sqlCreateSchema =
`CREATE VIRTUAL TABLE IF NOT EXISTS `~tableName~` USING rtree
(
    id NOT NULL,
    dim1_0 NOT NULL,
    dim1_1 NOT NULL,
    dim2_0 NOT NULL,
    dim2_1 NOT NULL,
    dim3_0 NOT NULL,
    dim3_1 NOT NULL,
    dim4_0 NOT NULL,
    dim4_1 NOT NULL
);
`;

class Storage
{
    private const string filePath;
    private Database db;
    private Statement addValueStatement;

    this(in string filePath)
    {
        this.filePath = filePath;
        db = Database(filePath);
        db.run(sqlCreateSchema);

        addValueStatement = db.prepare("
            INSERT INTO "~tableName~"
            (
                id,
                dim1_0,
                dim1_1,
                dim2_0,
                dim2_1,
                dim3_0,
                dim3_1,
                dim4_0,
                dim4_1
            )
            VALUES
            (
                :id,
                :dim1_0,
                :dim1_1,
                :dim2_0,
                :dim2_1,
                :dim3_0,
                :dim3_1,
                :dim4_0,
                :dim4_1
            )
        ");
    }

    ~this()
    {
        db.close;
        remove(filePath);
    }

    private bool tableIsEmpty(string tableName)
    {
        return db.execute("SELECT * FROM "~tableName~" LIMIT 1").empty;
    }

    void addValue(Value v)
    {
        alias q = addValueStatement;

        q.bind(":id", v.id);
        q.bind(":dim1_0", v.bbox.dim1.p0);
        q.bind(":dim1_1", v.bbox.dim1.p1);
        q.bind(":dim2_0", v.bbox.dim2.p0);
        q.bind(":dim2_1", v.bbox.dim2.p1);
        q.bind(":dim3_0", v.bbox.dim3.p0);
        q.bind(":dim3_1", v.bbox.dim3.p1);
        q.bind(":dim4_0", v.bbox.dim4.p0);
        q.bind(":dim4_1", v.bbox.dim4.p1);

        q.execute;
        assert(db.changes() == 1);
        q.reset();
    }

    //Value getValue(
}

struct DimensionPair
{
    float p0;
    float p1;
}

struct BoundingBox
{
    DimensionPair dim1;
    DimensionPair dim2;
    DimensionPair dim3;
    DimensionPair dim4;
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

    auto s = new Storage(tempDir ~ "/__unittest.db"); // FIXME: что сделать с юниксовым слэшем чтобы тест и в виндах работал?

    assert(s.tableIsEmpty(tableName));

    Value t;
    t.id = 123;
    t.bbox.dim1.p0 = 1;
    t.bbox.dim1.p1 = 2;
    t.bbox.dim2.p0 = 1;
    t.bbox.dim2.p1 = 2;
    t.bbox.dim3.p0 = 1;
    t.bbox.dim3.p1 = 2;
    t.payload = [0xDE, 0xAD, 0xBE, 0xEF];

    s.addValue(t);
}
