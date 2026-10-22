# Appendix F: BNLog

[← Previous: Appendix E: BNJson](11_bnjson.md) · [Contents](toc.md)

`BNLog` is an external structured-logging module, not a language primitive.
It follows the architecture of the Winston logger for Node.js: levels,
records, formats and destinations are separate ideas. Import it explicitly,
together with the capability of the destination you write to
(`HOST.Console` for the console, `HOST.FileSystem` for a file):

```basic
IMPORT HOST.Console AS Console
IMPORT BNLog AS Log
```

## Making a logger

A logger is made once, with a label, a format and a destination:

```basic
LET app AS Log.Logger OR Error = Log.Logger.New("shop", "JSON", "CONSOLE")
```

* The label (`"shop"`) is written in every record.
* The format is `"JSON"`, `"SYSLOG"` or `"APACHE"`.
* The destination is `"CONSOLE"`, `"NULL"` (discard everything), or the path
  of a file the logger appends to.

`New` returns `Log.Logger OR Error`: an unknown format, an empty label, a
destination whose capability you did not import, or a file the program may
not write is an `Error`, and the program decides what to do. A logger has
one destination; a program that logs to the console and to a file makes two
loggers.

## Writing records

A record carries a message and a `Log.Event`, a STRUCT the module declares:

```basic
STRUCT Event
    service AS STRING
    request_id AS STRING
    route AS STRING
    user AS STRING
    detail AS STRING
    code AS INTEGER
END STRUCT
```

There is one method per level, from the most severe to the least: `Error`,
`Warn`, `Info`, `Http`, `Verbose`, `Debug` and `Silly`. Each takes the
message and the event and returns `VOID OR Error`. A field you leave at `""`
or `0` is unset: it takes the logger's default (`SetDefaults`), or is left
out of the record.

```basic
IMPORT HOST.Console AS Console
IMPORT BNLog AS Log

FUNCTION Start() AS INTEGER
    LET app AS Log.Logger OR Error = Log.Logger.New("shop", "JSON", "CONSOLE")
    IF app IS Error THEN
        PRINT app
        RETURN 1
    END IF
    LET defaults AS Log.Event
    defaults.service = "orders"
    LET kept AS VOID OR Error = app.SetDefaults(defaults)
    LET event AS Log.Event
    event.user = "ana"
    event.code = 42
    LET wrote AS VOID OR Error = app.Info("order placed", event)
    LET hidden AS VOID OR Error = app.Debug("cart details", event)
    LET closed AS VOID OR Error = app.Close(1000)
    RETURN 0
END FUNCTION
```

Only the `Info` record is written; the time changes from run to run:

```text
{"fields":{"code":"42","service":"orders","user":"ana"},"label":"shop","level":"INFO","message":"order placed","timestamp":"2026-10-11T20:30:20.784Z"}
```

The `Debug` record is not written because a logger writes only records at
least as severe as its minimum level, `Log.Level.INFO` unless you call
`SetLevel` (for example `app.SetLevel(Log.Level.DEBUG)`). `Flush` writes what
the destination buffers, and `Close` flushes and ends the logger; after
`Close`, every call but `Close` returns an `Error` with code
`Log.CLOSED`.

## Access logs

An `"APACHE"` logger writes the Apache Combined Log Format that web servers
and log analyzers read. Its records come from a `Log.Apache` STRUCT through
`Access`, which has no message:

```basic
IMPORT HOST.Console AS Console
IMPORT BNLog AS Log

FUNCTION Start() AS INTEGER
    LET web AS Log.Logger OR Error = Log.Logger.New("web", "APACHE", "CONSOLE")
    IF web IS Error THEN
        RETURN 1
    END IF
    LET request AS Log.Apache
    request.remote = "203.0.113.7"
    request.method = "GET"
    request.path = "/orders?page=2"
    request.protocol = "HTTP/1.1"
    request.status = 200
    request.bytes = 512
    LET line AS VOID OR Error = web.Access(request)
    LET event AS Log.Event
    LET wrong AS VOID OR Error = web.Info("not an access record", event)
    IF wrong IS Error THEN
        PRINT wrong
    END IF
    RETURN 0
END FUNCTION
```

```text
203.0.113.7 - - [11/Oct/2026:20:30:20 +0000] "GET /orders HTTP/1.1" 200 512 "-" "-"
Error 1 in BNLog.Logger.Info: cannot write a level record to an APACHE logger (cause: an APACHE logger writes access records only (Logger.Access))
```

The query of the path (`?page=2`) is never written. An APACHE logger writes
access records only, so a level method on it returns an `Error`. A JSON or
SYSLOG logger accepts both kinds: an access record is written at level
`HTTP`, with its fields named `http.method`, `http.path`, and so on.
`SetAccessDefaults` sets the defaults of access records, as `SetDefaults`
does for events.

## Formats

* `"JSON"`: one JSON object per line, for collectors that read JSON Lines.
* `"SYSLOG"`: an RFC 5424 syslog line, with the level as the syslog
  priority, the machine's host name, the label and the process number,
  followed by the message and `key=value` for each field.
* `"APACHE"`: the Apache Combined Log Format, from access records.

A field whose name looks like a secret (`password`, `token`, `api_key`,
`cookie`, …) is never written, in any format.

## Errors

Every failure is an `Error` value whose `Code` is a constant of the module
(`Log.INVALID_ARGUMENT`, `Log.CLOSED`, `Log.IO_FAILED`, …) and whose
`Operation` names the member. A destination needs its capability import:

```basic
IMPORT BNLog AS Log

FUNCTION Start() AS INTEGER
    LET app AS Log.Logger OR Error = Log.Logger.New("shop", "SYSLOG", "CONSOLE")
    IF app IS Error THEN
        PRINT app
    END IF
    RETURN 0
END FUNCTION
```

```text
Error 6 in BNLog.Logger.New: HOST.Console capability is required (cause: the destination needs IMPORT HOST.Console)
```

The full contract (levels, records, limits, destinations, errors and every
format's layout) is in
[`language/0.6/bnlog.md`](../../../basicnext/language/0.6/bnlog.md).

---

[Next: Appendix G: BNWeb →](13_bnweb.md)
