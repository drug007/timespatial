module rtree.sqlite_storage;

import d2sqlite3;
import std.file: remove;

private enum tableName = "spatial";

private enum sqlCreateSchema =
`CREATE VIRTUAL TABLE IF NOT EXISTS `~tableName~` USING rtree
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

        //~ getValuesStatement = db.prepare("
            //~ SELECT
                //~ id,
                //~ dim1_min,
                //~ dim1_max,
                //~ dim2_min,
                //~ dim2_max,
                //~ dim3_min,
                //~ dim3_max,
                //~ dim4_min,
                //~ dim4_max
            //~ FROM "~tableName~"
            //~ WHERE
            //~ )
            //~ VALUES
            //~ (
                //~ :id,
                //~ :dim1_min,
                //~ :dim1_max,
                //~ :dim2_min,
                //~ :dim2_max,
                //~ :dim3_min,
                //~ :dim3_max,
                //~ :dim4_min,
                //~ :dim4_max
            //~ )
        //~ ");
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
        q.bind(":dim1_min", v.bbox.dim1.min);
        q.bind(":dim1_max", v.bbox.dim1.max);
        q.bind(":dim2_min", v.bbox.dim2.min);
        q.bind(":dim2_max", v.bbox.dim2.max);
        q.bind(":dim3_min", v.bbox.dim3.min);
        q.bind(":dim3_max", v.bbox.dim3.max);
        q.bind(":dim4_min", v.bbox.dim4.min);
        q.bind(":dim4_max", v.bbox.dim4.max);

        q.execute;
        assert(db.changes() == 1);
        q.reset();
    }

    //~ Value[] getValue(BoundingBox bbox)
    //~ {
        
    //~ }
}

struct DimensionPair
{
    float min;
    float max;
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
    t.bbox.dim1.min = 1;
    t.bbox.dim1.max = 2;
    t.bbox.dim2.min = 1;
    t.bbox.dim2.max = 2;
    t.bbox.dim3.min = 1;
    t.bbox.dim3.max = 2;
    t.payload = [0xDE, 0xAD, 0xBE, 0xEF];

    s.addValue(t);
}
