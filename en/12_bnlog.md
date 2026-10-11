# Appendix F: BNLog

[← Previous: Appendix E: BNJson](11_bnjson.md) · [Contents](toc.md)

`BNLog` is an external structured-logging module, not a language primitive.
Import it explicitly, together with the capability of each transport you use
(`HOST.Console` for `AddConsole`, `HOST.FileSystem` for `AddFile`):

```basic
IMPORT HOST.Console AS Console
IMPORT BNLog AS Log
```

## Records and formats

A logger writes each record as one line. The line holds the time, the level,
the message and the fields you set, in one of three formats:

- `"JSON"`, the default: one JSON object per line, for collectors that read
  JSON Lines;
- `"SYSLOG"`: an RFC 5424 syslog line, with the level as the syslog
  priority, the machine's host name and the process number;
- `"APACHE"`: an Apache Combined Log line, built from the `http.*` fields of
  an access record.

`SetFormat` chooses the format by name. A name it does not know returns an
`Error` and keeps the format the logger had:

```basic
FUNCTION Start() AS INTEGER
    LET logger AS Log.Logger = NEW Log.Logger()
    LET fields AS Log.Fields = NEW Log.Fields()
    LET added AS VOID OR Error = logger.AddConsole(2)
    LET user AS VOID OR Error = fields.SetString("user", "ana")
    LET json AS VOID OR Error = logger.Log(2, "signed in", fields)
    LET syslog AS VOID OR Error = logger.SetFormat("SYSLOG")
    LET line AS VOID OR Error = logger.Log(2, "signed in", fields)
    LET wrong AS VOID OR Error = logger.SetFormat("XML")
    IF wrong IS Error THEN
        PRINT wrong
    END IF
    RETURN 0
END FUNCTION
```

The time, host name and process number change from run to run:

```text
{"fields":{"user":"ana"},"label":"","level":"INFO","message":"signed in","timestamp":"2026-10-09T21:53:20.121Z"}
<14>1 2026-10-09T21:53:20.122Z Andromeda1.local - 15681 - - signed in user=ana
Error 1 in BNLog.Logger.SetFormat: unknown log format "XML" (cause: the format is "JSON", "SYSLOG" or "APACHE")
```

In the syslog line, `<14>` is facility `user` with severity 6 (`INFO`), and
`-` stands for the label this logger does not have. A field whose name looks
like a secret (`password`, `token`, `api_key`, `cookie`, …) is never
written, in any format.

The full contract (levels, limits, transports, errors and every format's
layout) is in [`language/0.6/bnlog.md`](../../../basicnext/language/0.6/bnlog.md).

---

[Next: Appendix G: BNWeb →](13_bnweb.md)
