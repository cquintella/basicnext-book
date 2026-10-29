# Files

[← Previous: The HOST](12_host.md) · [Contents](toc.md)

Files are reached through the `HOST.FileSystem` capability. Like every host operation, file access is synchronous and bounded: a call blocks until it completes or fails, and returns either the data or an `Error` ([chapter 7](07_alternatives_and_errors.md#errors)). Tabular files such as CSV have a module of their own, `BNData` ([Appendix I](appendix_i_bndata.md)).

```basic
IMPORT HOST.FileSystem AS FS
```

## Files, Paths, and Streams

A *file* is a named sequence of bytes kept by the operating system on persistent storage, so that it outlives the process that wrote it. A file is found by its *path*, the sequence of directory names leading to it, such as `data/readings.txt`; a path is *absolute* when it starts at the root of the file system and *relative* when it starts at the process's current directory.

A program does not work on a file directly. It first *opens* it, asking the operating system for access in a given *mode* — to read, to write, or to append — and receives a *handle* through which the following operations go. Reading and writing then proceed as a *stream*: each operation continues from where the previous one stopped. Finally the program *closes* the handle. Closing is more than a formality. Operating systems and runtimes collect small writes in memory, in a *buffer*, and pass them to storage in larger blocks; closing *flushes* what remains in the buffer, and a failure at that moment, such as a full disk, can only be reported then.

Every file is a sequence of bytes, but programs read them in two ways. A *text* file is interpreted as characters, encoded in some character encoding — in Basic Next always UTF-8, the encoding of Unicode that represents ASCII characters in one byte and every other character in two to four (Unicode Consortium, 2024) — and usually divided into lines. A *binary* file is taken as raw bytes, whose meaning is given by a format such as an image, an archive, or a database. The distinction is a matter of interpretation, not of storage, and a program must choose one interpretation for each open file.

## Text Files

`FS.Open(path, mode)` returns an `FS.File OR Error`. The mode is `FS.READ`, `FS.WRITE` (create or truncate), or `FS.APPEND` (write at the end, creating the file if needed). Close every file you open: `Close()` flushes the data and returns `VOID OR Error`, which is the only place a failed flush is reported. Text is UTF-8.

Writing, appending, reading line by line until `EOF`, checking, and deleting:

```basic
IMPORT HOST.FileSystem AS FS

FUNCTION WriteLines(path AS STRING) AS VOID OR Error
    LET file AS FS.File OR Error = FS.Open(path, FS.WRITE)
    IF file IS Error THEN
        RETURN file
    END IF
    LET first AS VOID OR Error = file.WriteLine("apples 3")
    IF first IS Error THEN
        RETURN first
    END IF
    LET second AS VOID OR Error = file.WriteLine("pears 5")
    IF second IS Error THEN
        RETURN second
    END IF
    RETURN file.Close()
END FUNCTION

FUNCTION AppendLine(path AS STRING, text AS STRING) AS VOID OR Error
    LET file AS FS.File OR Error = FS.Open(path, FS.APPEND)
    IF file IS Error THEN
        RETURN file
    END IF
    LET written AS VOID OR Error = file.WriteLine(text)
    IF written IS Error THEN
        RETURN written
    END IF
    RETURN file.Close()
END FUNCTION

FUNCTION PrintLines(path AS STRING) AS VOID OR Error
    LET file AS FS.File OR Error = FS.Open(path, FS.READ)
    IF file IS Error THEN
        RETURN file
    END IF
    LET number AS INTEGER = 0
    WHILE TRUE
        LET line AS STRING OR EOF OR Error = file.ReadLine()
        IF line IS Error THEN
            RETURN line
        END IF
        IF line IS EOF THEN
            EXIT WHILE
        END IF
        number = number + 1
        PRINT number, line
    END WHILE
    RETURN file.Close()
END FUNCTION

FUNCTION Start() AS INTEGER
    LET path AS STRING = "stock.txt"
    LET written AS VOID OR Error = WriteLines(path)
    IF written IS Error THEN
        PRINT "write failed:", written.Message
        RETURN 1
    END IF
    LET appended AS VOID OR Error = AppendLine(path, "plums 8")
    IF appended IS Error THEN
        PRINT "append failed:", appended.Message
        RETURN 1
    END IF
    LET listed AS VOID OR Error = PrintLines(path)
    IF listed IS Error THEN
        PRINT "read failed:", listed.Message
        RETURN 1
    END IF
    PRINT "exists before delete:", FS.Exists(path)
    LET removed AS VOID OR Error = FS.DeleteFile(path)
    IF removed IS Error THEN
        PRINT "delete failed:", removed.Message
        RETURN 1
    END IF
    PRINT "exists after delete:", FS.Exists(path)
    RETURN 0
END FUNCTION
```

```
1 apples 3
2 pears 5
3 plums 8
exists before delete: TRUE
exists after delete: FALSE
```

`ReadLine()` returns `STRING OR EOF OR Error`, so the loop stops on `EOF` and reports a genuine failure separately. `ReadAll()` returns the rest of the file as one `STRING`.

`FS.Exists(path)` returns `BOOLEAN OR Error` and `FS.DeleteFile(path)` returns `VOID OR Error`; neither needs an open file. Because `Exists` returns an alternative, its result cannot be used directly as a condition: test `IS Error` first, as the example above does.

## Binary Files

A file is used either for text (`ReadLine`, `ReadAll`, `Write`, `WriteLine`) or for bytes (`ReadBytes`, `WriteBytes`), never both; the first successful call decides, and mixing the two on one open file returns an `Error`. Bytes live in a `POINTER TO BYTE[]` region:

```basic
IMPORT HOST.FileSystem AS FS

FUNCTION Start() AS INTEGER
    LET path AS STRING = "header.bin"
    LET header AS POINTER TO BYTE[] = NEW BYTE[4]
    header[0] = 0x42
    header[1] = 0x4E
    header[2] = 0x00
    header[3] = 0x06

    LET output AS FS.File OR Error = FS.Open(path, FS.WRITE)
    IF output IS Error THEN
        PRINT "open failed:", output.Message
        RETURN 1
    END IF
    LET written AS VOID OR Error = output.WriteBytes(header, LEN(header))
    LET closed AS VOID OR Error = output.Close()
    IF written IS Error OR closed IS Error THEN
        PRINT "write failed"
        RETURN 1
    END IF

    LET input AS FS.File OR Error = FS.Open(path, FS.READ)
    IF input IS Error THEN
        PRINT "open failed:", input.Message
        RETURN 1
    END IF
    LET buffer AS POINTER TO BYTE[] = NEW BYTE[16]
    LET count AS INTEGER OR EOF OR Error = input.ReadBytes(buffer)
    input.Close()
    IF count IS INTEGER THEN
        PRINT "read", count, "bytes:", buffer[0], buffer[1], buffer[2], buffer[3]
    END IF
    RELEASE header
    RELEASE buffer
    FS.DeleteFile(path)
    RETURN 0
END FUNCTION
```

```
read 4 bytes: 66 78 0 6
```

A region created with `NEW BYTE[n]` is the byte buffer ([chapter 10](10_memory.md#regions-and-pointers)). `ReadBytes` fills it and returns how many bytes it read, `EOF` at the end of the file, or an `Error`.

## Directories, Private Files, Copying and Moving

A *directory* is a file-system entry that holds other entries, files or directories, under names; a path is the chain of directory names that leads to an entry. Every process has a *working directory*, the directory a relative path starts from. A *symbolic link* is an entry whose content is another path: the operating system usually follows it, so that opening the link opens whatever it points to. A link inside a directory a program trusts can therefore point anywhere, and a program that writes "into its own folder" can be made to write somewhere else (IEEE and The Open Group, 2024). Finally, every entry carries *permissions* that say who may read or change it; on Unix they are the read, write and execute bits for the owner, the owner's group, and everyone else.

`HOST.FileSystem` works on directories and whole files with eight methods:

| Method | Meaning |
| --- | --- |
| `GetCurrentDirectory()` | The absolute path of the working directory, `STRING OR Error`. |
| `SetCurrentDirectory(path)` | Makes the directory `path` the working directory. |
| `CreateDirectory(path)` | Creates one directory; its parent must exist. |
| `RemoveDirectory(path)` | Removes one empty directory. |
| `IsDirectory(path)` | `TRUE` for a directory, `FALSE` for a file or a link, `BOOLEAN OR Error`. |
| `OpenNew(path)` | Creates a new file and returns it open for writing, `FS.File OR Error`. |
| `Copy(source, destination)` | Copies the bytes of one file into a new file. |
| `Move(source, destination)` | Renames one entry on the same file system. |

Three rules hold for all of them. None of them follows a symbolic link at the end of a path, so nothing is ever written through one: a link is not a directory, and an existing link is an existing name. None of them changes an existing entry when it creates one: `CreateDirectory`, `OpenNew` and `Copy` return an `Error` with `Code` `FS.ALREADY_EXISTS` instead. And what they create is *private*: on Unix a new directory gets mode `0700` and a new file `0600`, readable only by its owner, whatever the process's default mask is. `Copy` copies only the bytes, never the permissions or the owner of the source, so a copy cannot carry a program that runs with someone else's privileges. `Move` keeps the entry itself, with its permissions, and does not copy between file systems: across two disks it returns `FS.IO_FAILED`. On Windows a new entry takes the permissions of the folder that holds it, so it is private only where that folder is, as in the user's profile.

`OpenNew` is the way to create a file that must stay private, such as a key or a downloaded secret; `FS.Open` with `FS.WRITE` creates a file readable according to the process's defaults and truncates an existing one. The program below creates a directory and a private file, copies and moves it, and shows the refusals:

```basic
IMPORT HOST.FileSystem AS FS

FUNCTION Report(label AS STRING, result AS VOID OR Error) AS VOID
    IF result IS Error THEN
        PRINT label, "failed:", result.Message
        PRINT "  ", result.Cause
    ELSE
        PRINT label, "done"
    END IF
END FUNCTION

FUNCTION Start() AS VOID
    Report("create reports", FS.CreateDirectory("reports"))
    LET draft AS FS.File OR Error = FS.OpenNew("reports/draft.txt")
    IF draft IS Error THEN
        PRINT "cannot create the draft:", draft.Message
        RETURN
    END IF
    draft.WriteLine("first line")
    Report("close draft", draft.Close())
    Report("copy", FS.Copy("reports/draft.txt", "reports/backup.txt"))
    Report("move", FS.Move("reports/draft.txt", "reports/final.txt"))
    Report("create final again", FS.Copy("reports/backup.txt", "reports/final.txt"))
    Report("remove reports", FS.RemoveDirectory("reports"))
    FS.DeleteFile("reports/final.txt")
    FS.DeleteFile("reports/backup.txt")
    Report("remove reports", FS.RemoveDirectory("reports"))
END FUNCTION
```

Run in an empty directory, it prints:

```
create reports done
close draft done
copy done
move done
create final again failed: cannot copy "reports/backup.txt" to "reports/final.txt"
   the path already exists, and an existing entry is never replaced or changed
remove reports failed: cannot remove the directory "reports"
   the directory has entries
remove reports done
```

The working directory belongs to the whole process. `SetCurrentDirectory` changes it for every task of the program, so a program that runs tasks ([chapter 15](15_concurrency.md)) should not change directory while they run. Every relative path is resolved against it before any other check:

```basic
IMPORT HOST.FileSystem AS FS

FUNCTION Start() AS VOID
    FS.CreateDirectory("work")
    LET isDirectory AS BOOLEAN OR Error = FS.IsDirectory("work")
    PRINT "work is a directory:", isDirectory
    LET entered AS VOID OR Error = FS.SetCurrentDirectory("work")
    PRINT "entered:", NOT (entered IS Error)
    LET note AS FS.File OR Error = FS.OpenNew("note.txt")
    IF note IS FS.File THEN
        note.Write("relative to work")
        note.Close()
    END IF
    FS.SetCurrentDirectory("..")
    LET exists AS BOOLEAN OR Error = FS.Exists("work/note.txt")
    PRINT "work/note.txt exists:", exists
    FS.DeleteFile("work/note.txt")
    FS.RemoveDirectory("work")
END FUNCTION
```

```
work is a directory: TRUE
entered: TRUE
work/note.txt exists: TRUE
```

A missing path is `FS.NOT_FOUND`; `RemoveDirectory` of a directory that still holds entries is `FS.DIRECTORY_NOT_EMPTY`; `SetCurrentDirectory` or `RemoveDirectory` of a file or a link is `FS.IS_NOT_DIRECTORY`. Listing the entries of a directory is not part of `HOST.FileSystem` yet.

## Restricting File Access: the Sandbox

A *sandbox* is an environment in which a program runs with less authority than the process that runs it would otherwise have. It applies the principle of least privilege ([chapter 12](12_host.md#programs-processes-and-the-operating-system)) to a single program: a tool that only needs to read its input directory and write its output directory should not be able to touch anything else, even if a defect or a malicious input leads it to try.

By default a program has the file permissions of the process that runs it: the operating system, user account, container, and service manager decide what it may touch, and Basic Next adds nothing. This is the *unrestricted* profile. It does not mean superuser access; it means Basic Next imposes no directory restrictions of its own.

The *sandboxed* profile limits `HOST.FileSystem` to declared directories. It is selected when the program is run or compiled:

```text
bni run app.bn --sandbox --read-root ./input --write-root ./output
bnc app.bn -o app --sandbox --read-root ./input --write-root ./output
```

A read root permits reading files below that directory, and entering it or checking whether an entry is a directory; a write root permits creating, truncating, appending, renaming, copying to, or deleting files below it, and creating or removing directories. A root itself can be read but is never a write target: it cannot be removed or renamed. The two are separate, so a program can consume its input without being able to alter it. Any other path is refused with an `Error` whose `Code` is `FS.POLICY_DENIED`:

```basic
IMPORT HOST.FileSystem AS FS

FUNCTION TryOpen(path AS STRING, mode AS INTEGER) AS VOID
    LET file AS FS.File OR Error = FS.Open(path, mode)
    IF file IS Error THEN
        PRINT path, "denied:", file.Code = FS.POLICY_DENIED
        RETURN
    END IF
    PRINT path, "opened"
    file.Close()
END FUNCTION

FUNCTION Start() AS VOID
    TryOpen("input/data.txt", FS.READ)
    TryOpen("output/result.txt", FS.WRITE)
    TryOpen("input/new.txt", FS.WRITE)
    TryOpen("../outside.txt", FS.READ)
END FUNCTION
```

Run with the two roots above, it prints:

```
input/data.txt opened
output/result.txt opened
input/new.txt denied: TRUE
../outside.txt denied: TRUE
```

Paths are compared by component, not by text: `/data2/file` is not below `/data`, and `..` cannot escape a root. A platform that cannot enforce the sandbox rejects `--sandbox` rather than producing an unrestricted program.

### Narrowing at Run Time

`bnc` records the sandbox in the compiled program as a ceiling: the most authority that program will ever have. Whoever runs it can narrow that authority further with environment variables, but never widen it:

```text
BN_FS_POLICY=deny ./app          # no file access through HOST.FileSystem
BN_FS_POLICY=read-only ./app     # reads allowed, writes denied
```

| Program | `BN_FS_POLICY` | Result |
| --- | --- | --- |
| unrestricted | not set | ordinary operating-system permissions |
| unrestricted | `deny` | no file access |
| unrestricted | `read-only` | reads allowed, writes denied |
| sandboxed | not set | only the declared roots |
| sandboxed | `deny` | no file access |

The same variables apply to `bni run`. A value the runtime does not recognise, such as `BN_FS_POLICY=bogus`, stops the program before `Start` with `CONFIG_INVALID` and exit status 2; a policy is never silently replaced by a default. Closing an already open file stays possible after a policy is narrowed, so a denied operation never prevents cleanup.

## Diagnostics Introduced in This Chapter

| Diagnostic | Raised when |
| --- | --- |
| `CONFIG_INVALID` | `BN_FS_POLICY` or another policy variable holds a value the runtime does not recognise. |

File operations report failures as `Error` values, not diagnostics; their codes (`FS.NOT_FOUND`, `FS.POLICY_DENIED`, and the others) are listed in [`host.md`](https://github.com/cquintella/BasicNext/blob/v0.6.12/language/0.6/host.md).

## Summary

Files are opened with `FS.Open`, which returns `FS.File OR Error`, and every file that is opened must be closed, because `Close` is where a failed write is finally reported. A file is used either for text, read and written in lines of UTF-8, or for bytes, moved through a `POINTER TO BYTE[]` region, but never for both; `ReadLine` returns `STRING OR EOF OR Error`, so the end of a file and a genuine failure are handled separately. Directories are created with `CreateDirectory` and removed with `RemoveDirectory`, a private file is created with `OpenNew`, and `Copy` and `Move` work on whole files; none of them follows a symbolic link, none of them changes an existing entry, and what they create is readable only by its owner on Unix. By default a program has the file permissions of the process that runs it. The `--sandbox` option, with `--read-root` and `--write-root`, confines `HOST.FileSystem` to declared directories, and the environment variable `BN_FS_POLICY` can narrow that authority further when the program runs, but never widen it.

The next chapter moves from the local file system to other machines.

## References

- IEEE and The Open Group (2024). *The Open Group Base Specifications Issue 8, IEEE Std 1003.1-2024* (POSIX.1). https://pubs.opengroup.org/onlinepubs/9799919799/
- Unicode Consortium (2024). *The Unicode Standard, Version 16.0*. https://www.unicode.org/versions/Unicode16.0.0/

---

[Next: Networking →](14_networking.md)
