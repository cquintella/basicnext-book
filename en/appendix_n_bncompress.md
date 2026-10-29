# Appendix N: BNCompress

[← Previous: Appendix M: BNDispatch](appendix_m_bndispatch.md) · [Contents](toc.md)

Compression replaces repeated patterns in data with shorter references to an earlier occurrence, so that text, logs and documents take less space on disk and on the wire. DEFLATE (RFC 1951) is the algorithm behind most of it: Gzip (RFC 1952) wraps a DEFLATE stream with a header and a checksum, and a ZIP archive stores many named entries, each compressed with DEFLATE or kept as is (STORED). EPUB books, Office documents and Java archives are ZIP archives with a fixed layout.

`BNCompress` is an external module. It is not part of the Basic Next core and every consumer must import it explicitly:

```basic
IMPORT BNCompress AS Compress
```

The normative contract is [`language/0.6/bncompress.md`](https://github.com/cquintella/BasicNext/blob/v0.6.11/language/0.6/bncompress.md). The algorithms are one Rust library that both `bni` and `bnc` call, so an interpreted and a compiled program produce the same bytes.

## Compressing in memory

`DeflateText` compresses the UTF-8 bytes of a `STRING`, and `InflateText` turns them back into text. Text that repeats itself shrinks the most:

```basic
IMPORT BNCompress AS Compress

FUNCTION Start() AS VOID
    LET text AS STRING = ""
    FOR i = 1 TO 100
        text += "the same line again; "
    END FOR
    LET packed AS Compress.Bytes OR Error = Compress.DeflateText(text)
    IF packed IS Error THEN
        PRINT packed.Message
        RETURN
    END IF
    PRINT LEN(text), packed.Length()
    LET unpacked AS STRING OR Error = Compress.InflateText(packed)
    IF unpacked IS STRING THEN
        PRINT unpacked = text
    END IF
END FUNCTION
```

```
2100 44
TRUE
```

The compressed form is a `Compress.Bytes`, an opaque buffer: it has a `Length()`, a `ToHex()` and a `ToText()`, but it never converts to `STRING` by itself, because compressed data is not text. `FromText` and `FromHex` build a buffer from text or from hexadecimal, and `Deflate`, `Inflate`, `Gzip` and `Gunzip` work on buffers. `GzipText` and `GunzipText` are the Gzip counterparts of the text functions.

## When the data is not what it claims to be

Every function that reads compressed data returns `T OR Error`. Data that is not a valid stream is reported, never decoded into something plausible:

```basic
IMPORT BNCompress AS Compress

FUNCTION Start() AS VOID
    LET data AS Compress.Bytes = Compress.FromText("not a deflate stream")
    LET result AS Compress.Bytes OR Error = Compress.Inflate(data)
    IF result IS Error THEN
        PRINT result.Code = Compress.CORRUPT_DATA, result.Operation
    END IF
    LET zipped AS Compress.Bytes OR Error = Compress.GzipText("abc")
    IF zipped IS Compress.Bytes THEN
        LET hex AS STRING = zipped.ToHex()
        PRINT hex[0] + hex[1] + hex[2] + hex[3]
    END IF
END FUNCTION
```

```
TRUE Inflate
1f8b
```

The `Error` carries a `Code` from the module's constants (`Compress.CORRUPT_DATA` here) and the `Operation` that failed. The second line shows the two bytes every Gzip stream starts with.

Decompression is also bounded. A small archive can be built to expand into gigabytes, a *decompression bomb*; `BNCompress` stops at 256 MiB of output in one call, or in one `ExtractAll`, and returns an `Error` with `Code` `Compress.LIMIT_EXCEEDED` before allocating or writing the rest.

## Writing and reading a ZIP archive

`Compress.ZipArchive.Create` opens a new archive for writing and `Compress.ZipArchive.Open` an existing one for reading. Entries are added by name; the name may contain `/` to place the entry in a folder of the archive:

```basic
IMPORT BNCompress AS Compress

FUNCTION Write(path AS STRING) AS VOID OR Error
    LET created AS Compress.ZipArchive OR Error = Compress.ZipArchive.Create(path)
    IF created IS Error THEN
        RETURN created
    END IF
    LET archive AS Compress.ZipArchive = created
    LET first AS VOID OR Error = archive.AddStoredText("mimetype", "application/epub+zip")
    IF first IS Error THEN
        RETURN first
    END IF
    LET second AS VOID OR Error = archive.AddText("notes/readme.txt", "Compressed with DEFLATE.")
    IF second IS Error THEN
        RETURN second
    END IF
    RETURN archive.Close()
END FUNCTION

FUNCTION Start() AS VOID
    LET written AS VOID OR Error = Write("notes.zip")
    IF written IS Error THEN
        PRINT written.Message
        RETURN
    END IF
    LET opened AS Compress.ZipArchive OR Error = Compress.ZipArchive.Open("notes.zip")
    IF opened IS Error THEN
        PRINT opened.Message
        RETURN
    END IF
    FOR index = 0 TO opened.EntryCount() - 1
        LET name AS STRING OR Error = opened.EntryName(index)
        IF name IS STRING THEN
            PRINT index, name
        END IF
    END FOR
    LET readme AS STRING OR Error = opened.ExtractText("notes/readme.txt")
    IF readme IS STRING THEN
        PRINT readme
    END IF
    LET missing AS STRING OR Error = opened.ExtractText("absent.txt")
    IF missing IS Error THEN
        PRINT missing.Code = Compress.NOT_FOUND
    END IF
    opened.Close()
END FUNCTION
```

```
0 mimetype
1 notes/readme.txt
Compressed with DEFLATE.
TRUE
```

`AddText`, `AddBytes` and `AddFile` compress the entry with DEFLATE. `AddStoredText` and `AddStoredBytes` keep it uncompressed, which some formats require: an EPUB must begin with an uncompressed `mimetype` entry, so that a reader can identify the file from its first bytes. `ExtractText`, `ExtractBytes`, `ExtractFile` and `ExtractAll` read entries back, and a name the archive does not hold is `Compress.NOT_FOUND`.

`Close()` writes the archive's central directory, the index at the end of the file. An archive is also closed when its last reference ends, but only `Close()` can report that finishing it failed — a full disk, for example — so a program that writes an archive calls it and checks the result, as `Write` does above.

## Archives and the file system

An archive names files, and those names come from whoever made the archive. `ExtractAll` refuses an entry whose name would leave the destination folder (`../../etc/passwd`), the attack known as *Zip Slip*, with `Compress.ZIP_SLIP`.

Every file `BNCompress` reads or writes passes through the same execution policy as `HOST.FileSystem` ([Chapter 13](13_files.md)): under `--sandbox`, `--read-root`, `--write-root` or `BN_FS_POLICY=deny`, a path the policy does not allow is an `Error` with `Code` `Compress.POLICY_DENIED`, and nothing is read or written. A compressed archive is not a way around the sandbox.

A symbolic link is a file that points to another path, and a link left inside a writable folder could send a write somewhere else. Under a root, `BNCompress` opens files the way `FS.Open` does: a path that reaches a link — the file itself, a link to a file that does not exist yet, or a linked folder on the way — is `Compress.POLICY_DENIED`, and nothing is written through it. An archive also records a Unix mode for each entry, and `BNCompress` never applies it: an extracted file gets the same permissions as a file the program creates with `FS.Open`, so an archive cannot install a program that runs with its owner's privileges.

---

[Contents](toc.md)
