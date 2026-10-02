# Appendix L: BNSqlite

[← Previous: Appendix K: BNCrypto](18_bncrypto.md) · [Contents](toc.md)

`BNSqlite` is a standard library module in Basic Next providing an embedded SQLite3 relational database engine. The driver runs completely in-process using an embedded C SQLite3 implementation bundled with the runtime (`libsqlite3-sys` in `bn_rt`). It requires no external database server, network listener, or local daemon.

Because query results return structured tabular data as `BNData.DataFrame` instances, any module that imports `BNSqlite` must also import `BNData`:

```basic
IMPORT BNData AS Data
IMPORT BNSqlite AS Sqlite
```

Omitting `IMPORT BNData` is detected during semantic analysis and rejected with compile-time diagnostic `E0450`.

The normative language specification is [`language/0.6/bnsqlite.md`](../../../basicnext/language/0.6/bnsqlite.md).

---

## Connection Openers and Options

`BNSqlite` provides three functions to establish connections. Each returns an alternative union type: `Sqlite.Connection OR Error`.

### Sqlite.Open

`Sqlite.Open(path AS STRING) AS Sqlite.Connection OR Error`

Creates a new database file or opens an existing one in read-write mode. If the file does not exist, SQLite creates it automatically.

```basic
IMPORT BNData AS Data
IMPORT BNSqlite AS Sqlite

FUNCTION Start() AS INTEGER
    LET conn AS Sqlite.Connection OR Error = Sqlite.Open("analytics.db")
    IF conn IS Error THEN
        PRINT "Failed to open database:", conn.Code, conn.Message
        RETURN 1
    END IF

    // Connection is ready for reads and writes
    LET res AS VOID OR Error = conn.Close()
    RETURN 0
END FUNCTION
```

#### In-Memory Databases (`:memory:`)

Passing the literal string `":memory:"` opens a transient, private in-memory database:

```basic
LET memConn AS Sqlite.Connection OR Error = Sqlite.Open(":memory:")
```

* In-memory databases exist strictly within the process memory.
* Data persists across operations on the same connection.
* Distinct calls to `Sqlite.Open(":memory:")` create completely isolated, independent database instances.
* Closing the connection handle (`Close()`) immediately destroys the database and frees all allocated memory.

### Sqlite.OpenReadOnly

`Sqlite.OpenReadOnly(path AS STRING) AS Sqlite.Connection OR Error`

Opens an existing database file strictly in read-only mode.

* If the target file does not exist on disk, `OpenReadOnly` fails immediately with error code `Sqlite.FILE_NOT_FOUND` (1).
* Any attempt to perform mutations (`CREATE`, `INSERT`, `UPDATE`, `DELETE`) on this connection fails with error code `Sqlite.READ_ONLY` (7).

```basic
LET roConn AS Sqlite.Connection OR Error = Sqlite.OpenReadOnly("reference_data.db")
IF roConn IS Error THEN
    IF roConn.Code = Sqlite.FILE_NOT_FOUND THEN
        PRINT "Database file does not exist."
    END IF
    RETURN 1
END IF

// Queries succeed
LET df AS Data.DataFrame OR Error = roConn.Query("SELECT * FROM lookup;")

// Mutations fail with READ_ONLY (7)
LET writeAttempt AS VOID OR Error = roConn.Exec("DELETE FROM lookup;")
IF writeAttempt IS Error THEN
    PRINT "Write blocked:", writeAttempt.Code = Sqlite.READ_ONLY
END IF

LET res AS VOID OR Error = roConn.Close()
```

### Sqlite.OpenExisting

`Sqlite.OpenExisting(path AS STRING) AS Sqlite.Connection OR Error`

Opens an existing database file in read-write mode without creating a file if missing.

* If the specified database file does not exist, `OpenExisting` fails with error code `Sqlite.FILE_NOT_FOUND` (1).
* If the file exists, it is opened with read and write permissions.

```basic
LET db AS Sqlite.Connection OR Error = Sqlite.OpenExisting("production.db")
IF db IS Error THEN
    PRINT "Database missing, refusing to create new file:", db.Message
    RETURN 1
END IF

LET res AS VOID OR Error = db.Close()
```

---

## Connection Methods

Instances of `Sqlite.Connection` expose methods for statement execution, data retrieval, transaction demarcation, and lifecycle termination.

### Exec

`conn.Exec(sql AS STRING) AS VOID OR Error`

Executes a single Data Definition Language (DDL) or Data Manipulation Language (DML) statement that does not return row sets:

* DDL statements: `CREATE TABLE`, `CREATE INDEX`, `DROP TABLE`, `ALTER TABLE`, etc.
* DML statements: `INSERT`, `UPDATE`, `DELETE`.
* Single-Statement Rule: Only one SQL statement may be executed per call. Supplying multiple statements separated by semicolons (`;`) returns error code `Sqlite.MISUSE` (12).
* Misuse Restriction: Executing a `SELECT` statement via `Exec` returns `Sqlite.MISUSE` (12). Use `Query` instead.

```basic
LET okCreate AS VOID OR Error = conn.Exec("CREATE TABLE metrics (id INT PRIMARY KEY, key TEXT, val FLOAT);")
IF okCreate IS Error THEN
    PRINT "DDL failed:", okCreate.Message
    RETURN 1
END IF

LET okInsert AS VOID OR Error = conn.Exec("INSERT INTO metrics VALUES (1, 'cpu_load', 0.42);")
IF okInsert IS Error THEN
    PRINT "Insert failed:", okInsert.Message
    RETURN 1
END IF
```

### Query

`conn.Query(sql AS STRING) AS Data.DataFrame OR Error`

Executes a single `SELECT` query and returns the tabular result set directly as a `BNData.DataFrame`:

* Column Names: DataFrame column labels match the SQL query column names or aliases (`AS label`).
* Type Mapping:
  * SQL `INTEGER` maps to DataFrame `INTEGER` columns.
  * SQL `REAL` / `FLOAT` maps to DataFrame `FLOAT` columns.
  * SQL `TEXT` maps to DataFrame `STRING` columns.
  * SQL `BLOB` maps to DataFrame `STRING` columns formatted as lowercase hex strings.
  * SQL `NULL` values map to the DataFrame missing value sentinel `NA`.
* Misuse Restriction: Calling `Query` with non-query statements (`INSERT`, `UPDATE`, `CREATE`, etc.) returns `Sqlite.MISUSE` (12). Use `Exec` instead.

```basic
LET df AS Data.DataFrame OR Error = conn.Query("SELECT id, key, val FROM metrics ORDER BY id ASC;")
IF df IS Error THEN
    PRINT "Query failed:", df.Message
    RETURN 1
END IF

PRINT "Rows returned:", df.RowCount()
PRINT "Columns returned:", df.ColumnCount()

FOR i AS INTEGER = 0 TO df.RowCount() - 1
    LET rowId AS INTEGER OR NA OR Error = df.GetInteger(i, "id")
    LET rowKey AS STRING OR NA OR Error = df.GetString(i, "key")
    LET rowVal AS FLOAT OR NA OR Error = df.GetFloat(i, "val")
    PRINT "Row", i, ":", rowId, rowKey, rowVal
NEXT i
```

### Begin

`conn.Begin() AS VOID OR Error`

Explicitly starts a database transaction. Changes executed after `Begin()` remain uncommitted until `Commit()` is called. Calling `Begin()` while a transaction is already active returns `Sqlite.MISUSE` (12).

```basic
LET tx AS VOID OR Error = conn.Begin()
IF tx IS Error THEN
    PRINT "Could not start transaction:", tx.Message
    RETURN 1
END IF
```

### Commit

`conn.Commit() AS VOID OR Error`

Persists all operations performed within the active transaction to the database. Calling `Commit()` without an active transaction returns `Sqlite.MISUSE` (12).

```basic
LET res AS VOID OR Error = conn.Commit()
IF res IS Error THEN
    PRINT "Commit failed:", res.Message
    RETURN 1
END IF
```

### Rollback

`conn.Rollback() AS VOID OR Error`

Aborts the active transaction, discarding all mutations made since `Begin()`. Calling `Rollback()` without an active transaction returns `Sqlite.MISUSE` (12).

```basic
LET res AS VOID OR Error = conn.Begin()
res = conn.Exec("INSERT INTO metrics VALUES (99, 'bad_sample', -1.0);")

// Revert mutation
res = conn.Rollback()

// Verification shows table unchanged
LET checkDf AS Data.DataFrame OR Error = conn.Query("SELECT COUNT(*) AS c FROM metrics WHERE id = 99;")
```

### Changes

`conn.Changes() AS INTEGER`

Returns the total count of rows inserted, updated, or deleted by the most recently executed DML statement (`INSERT`, `UPDATE`, `DELETE`) on this connection. Returns `0` if no DML has run or on closed connections.

```basic
LET res AS VOID OR Error = conn.Exec("UPDATE metrics SET val = 0.5 WHERE val < 0.5;")
PRINT "Updated rows:", conn.Changes()
```

### LastInsertRowId

`conn.LastInsertRowId() AS INTEGER`

Returns the rowid of the most recent successful `INSERT` into a rowid-backed table on this connection.

```basic
LET res AS VOID OR Error = conn.Exec("INSERT INTO metrics (key, val) VALUES ('temp', 21.5);")
PRINT "Inserted row ID:", conn.LastInsertRowId()
```

### Close

`conn.Close() AS VOID OR Error`

Explicitly closes the database connection and releases underlying OS file descriptors and SQLite memory allocations.

* After a connection is closed, calling any method (`Exec`, `Query`, `Begin`, `Commit`, `Rollback`, `Close`) returns error code `Sqlite.CLOSED` (13).
* Calling `Close()` twice on the same connection returns `Sqlite.CLOSED` (13).
* If not explicitly closed, connections are safely closed automatically upon variable destruction or garbage collection.

```basic
LET closeStatus AS VOID OR Error = conn.Close()
IF closeStatus IS Error THEN
    PRINT "Failed to close:", closeStatus.Message
END IF
```

---

## Common Errors, Causes, and Resolutions

All runtime errors returned by `BNSqlite` carry four structured fields:
* `.Code`: An `INTEGER` matching one of the 16 exported `Sqlite.*` constants.
* `.Operation`: The qualified name of the failing operation (e.g., `"BNSqlite.Connection.Exec"`).
* `.Message`: A human-readable diagnostic description of the failure.
* `.Cause`: The underlying root cause returned by SQLite or the operating system.

### Compile-Time Semantic Error: E0450

* Symptom: Compiler flags `error[E0450]: companion module missing: module 'BNSqlite' requires 'IMPORT BNData'`.
* Cause: `BNSqlite` returns tabular query outputs as `BNData.DataFrame` instances. Importing `BNSqlite` without importing `BNData` leaves the DataFrame type undefined in scope.
* Resolution: Add `IMPORT BNData AS Data` (or any valid alias) before or alongside `IMPORT BNSqlite`.

```basic
// Correct:
IMPORT BNData AS Data
IMPORT BNSqlite AS Sqlite
```

### Code 1: FILE_NOT_FOUND

* Symptom: `conn.Code = Sqlite.FILE_NOT_FOUND` (1).
* Cause: `Sqlite.OpenReadOnly` or `Sqlite.OpenExisting` was called on a file path that does not exist on disk.
* Resolution: Verify the file path before opening, ensure preceding deployment steps created the file, or use `Sqlite.Open(path)` if automatic database creation is intended.

### Code 2: ACCESS_DENIED

* Symptom: `conn.Code = Sqlite.ACCESS_DENIED` (2).
* Cause: Operating system filesystem permissions deny read or write access to the database file or its parent directory.
* Resolution: Check filesystem ownership and permissions on the database file and its containing folder (e.g. `chmod 644 app.db` or ensuring write access to the parent folder for WAL journal files).

### Code 3: POLICY_DENIED

* Symptom: `conn.Code = Sqlite.POLICY_DENIED` (3).
* Cause: The path violates the active Basic Next HOST execution policy or sandboxing rules:
  * Attempting to access paths outside permitted read/write filesystem roots.
  * Attempting directory traversal using parent path segments (`..`).
  * Supplying path strings containing null bytes (`\0`).
* Resolution: Keep database paths inside the permitted project directory roots and use normalized paths without `..` traversal components.

### Code 4: CORRUPT

* Symptom: `conn.Code = Sqlite.CORRUPT` (4).
* Cause: The SQLite file header or database pages are malformed, partially overwritten, or truncated.
* Resolution: Restore the database from backup, or run SQLite recovery utilities (`sqlite3 app.db ".recover"`).

### Code 5: BUSY

* Symptom: `conn.Code = Sqlite.BUSY` (5).
* Cause: Another process or thread holds an exclusive lock on the database file, and the lock was not released before the 5000ms busy timeout expired.
* Resolution: Ensure concurrent transactions are brief, avoid holding open transactions across long-running operations, or enable SQLite WAL mode (`PRAGMA journal_mode=WAL;`).

### Code 6: LOCKED

* Symptom: `conn.Code = Sqlite.LOCKED` (6).
* Cause: A table or schema conflict occurred within the same database connection (for example, attempting to drop a table while a query is reading from it).
* Resolution: Ensure queries are completed and their result DataFrames evaluated before executing schema modifications on the same connection.

### Code 7: READ_ONLY

* Symptom: `conn.Code = Sqlite.READ_ONLY` (7).
* Cause: Attempting to execute a modifying statement (`INSERT`, `UPDATE`, `DELETE`, `CREATE TABLE`) on a connection opened with `Sqlite.OpenReadOnly`.
* Resolution: If mutations are required, open the connection with `Sqlite.Open` or `Sqlite.OpenExisting`.

### Code 8: SYNTAX_ERROR

* Symptom: `conn.Code = Sqlite.SYNTAX_ERROR` (8).
* Cause: The SQL statement contains a typo, unrecognized keyword, unmatched quotation mark, or invalid SQL grammar.
* Resolution: Check the `.Message` and `.Cause` fields for exact error details from the SQLite parser. Verify SQL syntax against standard SQLite3 grammar.

### Code 9: SCHEMA_ERROR

* Symptom: `conn.Code = Sqlite.SCHEMA_ERROR` (9).
* Cause: The query or statement references a table, view, or column name that does not exist in the database schema.
* Resolution: Verify table and column spelling. Ensure migration and `CREATE TABLE` scripts ran successfully prior to querying.

### Code 10: CONSTRAINT_VIOLATION

* Symptom: `conn.Code = Sqlite.CONSTRAINT_VIOLATION` (10).
* Cause: The executed statement violated an integrity constraint:
  * `UNIQUE` or `PRIMARY KEY` violation (duplicate key).
  * `NOT NULL` violation (inserting `NULL` into a non-nullable column).
  * `CHECK` constraint failure.
  * `FOREIGN KEY` constraint failure.
* Resolution: Validate records before insertion, handle duplicate key conflicts using `INSERT OR REPLACE` or `ON CONFLICT DO UPDATE`, or handle `Sqlite.CONSTRAINT_VIOLATION` conditionally in your Basic Next error recovery logic.

### Code 11: TYPE_MISMATCH

* Symptom: `conn.Code = Sqlite.TYPE_MISMATCH` (11).
* Cause: SQLite datatype mismatch occurred during execution or schema enforcement.
* Resolution: Ensure types supplied in SQL literals match the expected column affinities in the schema.

### Code 12: MISUSE

* Symptom: `conn.Code = Sqlite.MISUSE` (12).
* Cause: Common misuse patterns include:
  * Calling `conn.Exec` with a `SELECT` statement.
  * Calling `conn.Query` with an `INSERT`, `UPDATE`, or DDL statement.
  * Passing multiple SQL statements separated by semicolons (`;`) in a single call.
  * Calling `conn.Commit` or `conn.Rollback` when no transaction was opened with `conn.Begin`.
  * Calling `conn.Begin` while a transaction is already active.
* Resolution:
  * Use `Query` for statements that yield rows, and `Exec` for statements that do not.
  * Execute statements one at a time.
  * Ensure `Begin`, `Commit`, and `Rollback` pairs match exactly.

### Code 13: CLOSED

* Symptom: `conn.Code = Sqlite.CLOSED` (13).
* Cause: Attempting to call `Exec`, `Query`, `Begin`, `Commit`, `Rollback`, or `Close` on a connection handle that has already been closed.
* Resolution: Do not access connection variables after calling `conn.Close()`. Check connection status or remove redundant `Close()` calls.

### Code 14: LIMIT_EXCEEDED

* Symptom: `conn.Code = Sqlite.LIMIT_EXCEEDED` (14).
* Cause: An SQL statement exceeded engine limits (e.g. statement length, number of joined tables, or maximum column count).
* Resolution: Simplify overly complex SQL statements or split queries into manageable chunks.

### Code 15: IO_FAILED

* Symptom: `conn.Code = Sqlite.IO_FAILED` (15).
* Cause: The underlying operating system encountered an unrecoverable disk error (e.g. disk full, read-only physical filesystem, or lost network storage mount).
* Resolution: Ensure sufficient storage space on the target volume and verify storage hardware health.

### Code 16: INTERNAL_ERROR

* Symptom: `conn.Code = Sqlite.INTERNAL_ERROR` (16).
* Cause: An unexpected internal error or assertion failed within the SQLite3 core engine.
* Resolution: Inspect `.Message` and `.Cause`. Report edge cases with reproducible scripts to the Basic Next project issue tracker.

---

[Next: Appendix M: Debugging Basic Next →](20_debugging.md)

