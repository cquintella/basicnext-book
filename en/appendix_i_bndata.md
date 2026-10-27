# Appendix I: BNData

[← Previous: Appendix H: BNWeb](appendix_h_bnweb.md) · [Contents](toc.md)

`BNData` is the standard data-provider module for tabular datasets and CSV operations in Basic Next. It is not built into the core language; use an explicit import:

```basic
IMPORT BNData AS Data
IMPORT HOST.FileSystem AS FS
```

While `HOST.FileSystem` handles raw text and binary byte streams, `BNData` provides structured columnar data manipulation centered around the `Data.DataFrame` class.

## CSV Reading and Writing

`BNData` consumes `HOST.FileSystem` open file handles for CSV parsing and serialization:

```basic
LET file AS FS.File OR Error = FS.Open("sales.csv", FS.READ)
IF file IS Error THEN
    RETURN
END IF

// Read CSV with headers and semicolon separator
LET table AS Data.DataFrame OR Error = Data.ReadCSV(file, TRUE, ";")
file.Close()
RELEASE file

IF table IS Error THEN
    PRINT "CSV Error: " + table.Message
    RETURN
END IF
```

Writing a DataFrame back to disk:

```basic
LET outFile AS FS.File OR Error = FS.Open("output.csv", FS.WRITE)
IF outFile IS Error THEN
    RETURN
END IF

LET status AS VOID OR Error = Data.WriteCSV(outFile, table, TRUE, ",")
outFile.Close()
RELEASE outFile
```

## The `Data.DataFrame` Class

`Data.DataFrame` represents an in-memory tabular structure where columns share equal row counts.

### Creating and Populating Columns

DataFrames can be constructed programmatically using fixed-size vectors:

```basic
LET df AS Data.DataFrame = NEW Data.DataFrame()

LET names AS STRING[3] = ["Alice", "Bob", "Charlie"]
LET ages AS INTEGER[3] = [25, 30, 35]

df.AddStringColumn("Name", names)
df.AddIntegerColumn("Age", ages)

PRINT "Rows:", df.RowCount()
PRINT "Cols:", df.ColumnCount()

RELEASE df
```

### Statistics and Conversions

Values read via `ReadCSV` are stored as `STRING`. Numeric statistics require explicit conversion:

```basic
LET conv AS VOID OR Error = table.ConvertToFloat("Price")
IF NOT (conv IS Error) THEN
    LET avgPrice AS FLOAT OR Error = table.Mean("Price")
    PRINT "Average Price:", avgPrice
END IF
```

An empty cell becomes `NA`, a missing datum. The column statistics leave `NA` cells out, and a column of `NA` cells only counts as empty: its `Mean` is `NAN` and its `Min` is an `Error`. `NA` is not the number `NAN`: a `NAN` cell still makes the statistic `NAN`, as in `BNMath`.

```basic
IMPORT BNData AS Data

FUNCTION Start() AS VOID
    LET text AS STRING[3] = ["1", "", "3"]
    LET table AS Data.DataFrame = NEW Data.DataFrame()
    table.AddStringColumn("x", text)
    table.ConvertToFloat("x")
    PRINT table.Mean("x"), table.Min("x")    // 2.0 1.0
    RELEASE table
END FUNCTION
```

Three methods work on the missing cells directly. `CountNA` counts them in one column, `DropNA` returns a new frame without the rows that have any, and `FillNA` replaces them in a numeric column, keeping its type (an `INTEGER` column needs a whole number):

```basic
IMPORT BNData AS Data

FUNCTION Start() AS VOID
    LET text AS STRING[4] = ["10", "", "30", ""]
    LET table AS Data.DataFrame = NEW Data.DataFrame()
    table.AddStringColumn("x", text)
    table.ConvertToFloat("x")
    PRINT table.CountNA("x")           // 2
    LET complete AS Data.DataFrame OR Error = table.DropNA()
    IF complete IS Data.DataFrame THEN
        PRINT complete.RowCount()      // 2
        RELEASE complete
    END IF
    table.FillNA("x", 0.0)
    PRINT table.CountNA("x"), table.Mean("x")    // 0 10.0
    RELEASE table
END FUNCTION
```

Every `Data.DataFrame` instance must be released with `RELEASE df` when no longer needed.

---

[Next: Appendix J: BNSqlite →](appendix_j_bnsqlite.md)
