module rtree.sqlite_storage;

import d2sqlite3;
import std.file: remove;

private enum tableName = "spatial";

private enum sqlCreateSchema =
`CREATE VIRTUAL TABLE IF NOT EXISTS `~tableName~` USING rtree
(
    id NOT NULL,
    dim1 NOT NULL,
    dim2 NOT NULL,
    dim3 NOT NULL,
    dim4 NOT NULL
);
`;

class Storage
{
    private const string filePath;
    private Database db;

    this(in string filePath)
    {
        this.filePath = filePath;
        db = Database(filePath);
        db.run(sqlCreateSchema);
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
}

unittest
{
    import std.file: tempDir;

    auto s = new Storage(tempDir ~ "/__unittest.db"); // FIXME: что делать с юниксовым слэшем тут?

    assert(s.tableIsEmpty(tableName));
}
