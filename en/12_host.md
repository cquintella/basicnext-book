# The HOST

[← Previous: The Standard Library](11_standard_library.md) · [Contents](toc.md)

A program reaches the operating system only through `HOST`, the one built-in interface of the language. Each part of the system — arguments, the clock, the console, random numbers, files, processes, the environment, the network — is a separate *capability*. This chapter covers the small capabilities; files ([chapter 13](13_files.md)) and the network ([chapter 14](14_networking.md)) have chapters of their own.

## Capabilities

A program reaches the operating system only through `HOST`. Each capability is imported explicitly (`IMPORT HOST.Clock AS Clock`), except `HOST.Args` and `HOST.NumProcs`, which need no import, and `HOST.Console`, whose import is optional. Nothing reaches the network, the file system, or other processes unless the program says so in its imports, and a restricted host can refuse an import before `Start` runs (`HOST_CAPABILITY_UNAVAILABLE`).

Most operations can fail, so they return `T OR Error`. The examples below test `IS Error` and use the value in the `ELSE` branch, where it has been narrowed to `T`.

| Capability | Import | Use it for |
| --- | --- | --- |
| `HOST.Args` | none | command-line arguments |
| `HOST.Clock` | `IMPORT HOST.Clock AS Clock` | wall-clock time and elapsed time |
| `HOST.NumProcs` | none | sizing a worker pool |
| `HOST.Console` | optional: `IMPORT HOST.Console AS CON` | clearing the screen, positioned text, window size |
| `HOST.Random` | `IMPORT HOST.Random AS R` | reproducible pseudorandom numbers |
| `HOST.FileSystem` | `IMPORT HOST.FileSystem AS FS` | reading and writing files ([chapter 13](13_files.md)) |
| `HOST.Exec` | `IMPORT HOST.Exec AS Exec` | running another program |
| `HOST.Env` | `IMPORT HOST.Env AS Env` | reading environment variables |
| `HOST.Net` | `IMPORT HOST.Net AS Net` | addresses, name resolution, TCP, UDP, ping ([chapter 14](14_networking.md)) |

The normative contracts are in the language specification: [`host.md`](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/host.md), [`console.md`](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/console.md), [`host-exec.md`](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/host-exec.md), and [`host-net.md`](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/host-net.md), and [`host-env.md`](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/host-env.md).

### `HOST.Args`

`HOST.Args` holds the command-line arguments. Only the executable module (the one with `Start`) may use it. `HOST.Args[0]` is the absolute path of the program; the arguments given after `--` follow it. `LEN(HOST.Args)` counts them all, including entry `0`.

```basic
FUNCTION Start() AS INTEGER
    IF LEN(HOST.Args) < 2 THEN
        PRINT "usage: greet NAME..."
        RETURN 2
    END IF
    FOR i AS INTEGER = 1 TO LEN(HOST.Args) - 1
        PRINT "Hello, " + HOST.Args[i] + "!"
    END FOR
    RETURN 0
END FUNCTION
```

```
$ bni run greet.bn
usage: greet NAME...
$ bni run greet.bn -- Ana Bia
Hello, Ana!
Hello, Bia!
```

Returning an `INTEGER` from `Start` sets the exit status, so the usage case exits with `2`.

### `HOST.Clock`

`Clock.Now()` returns a `TIMESTAMP`: milliseconds since 1970-01-01T00:00:00Z. `Clock.Timer()` returns nanoseconds from an unspecified origin as an `INT64` that never decreases. Use `Now` for calendar time and `Timer` for measuring a duration; a `Timer` value is not a date.

```basic
IMPORT HOST.Clock AS Clock

FUNCTION Start() AS VOID
    LET now AS TIMESTAMP = Clock.Now()
    PRINT "Now:", now

    LET started AS INT64 = Clock.Timer()
    LET total AS INTEGER = 0
    FOR i AS INTEGER = 1 TO 100000
        total = total + i % 7
    END FOR
    LET elapsed AS INT64 = Clock.Timer() - started
    PRINT "Loop result:", total
    PRINT "Elapsed (ns) > 0:", elapsed > 0
END FUNCTION
```

```
Now: 1790534062927
Loop result: 300000
Elapsed (ns) > 0: TRUE
```

### `HOST.NumProcs`

`HOST.NumProcs()` returns the number of logical processors available to the process, respecting container limits where the host reports them. It is the right input for choosing how many workers to start. It returns `INTEGER OR Error`, so a program keeps a fallback:

```basic
FUNCTION Start() AS VOID
    LET found AS INTEGER OR Error = HOST.NumProcs()
    LET workers AS INTEGER = 1
    IF found IS Error THEN
        PRINT "Processor count unavailable:", found.Message
    ELSE
        workers = found
    END IF
    PRINT "Workers:", workers
END FUNCTION
```

### `HOST.Console`

`PRINT` and `INPUT()` need no import. `HOST.Console` adds screen control:

| Method | Needs a terminal (TTY) |
| --- | --- |
| `Cls()` — clear the screen and move the cursor home | no |
| `Beep()` — ring the terminal bell | no |
| `PrintAt(column, row, text)` — write at a 1-based position, no newline | yes |
| `NumCols()`, `NumRows()` — current window size | yes |

```basic
IMPORT HOST.Console AS CON

FUNCTION Start() AS VOID
    CON.Cls()
    LET title AS STRING = "Basic Next"
    LET column AS INTEGER = (CON.NumCols() - LEN(title)) DIV 2 + 1
    CON.PrintAt(column, 1, title)
    CON.PrintAt(1, 3, "Window size:")
    PRINT
    PRINT CON.NumCols(), "x", CON.NumRows()
    CON.Beep()
END FUNCTION
```

In an 80×24 terminal this centres the title on row 1 (column `(80 - 10) DIV 2 + 1 = 36`) and prints `80 x 24`. When standard output is redirected to a file or a pipe, `Cls` and `Beep` still run, but the first call to `NumCols` stops the program:

```
error[HOST_CAPABILITY_UNAVAILABLE]: window size requires a TTY
```

`PrintAt` does not wrap or clip: a position outside the window, or text that would run past the right edge, is `INDEX_OUT_OF_BOUNDS`.
`PrintAt` coordinates are one-based terminal cells, in contrast to the zero-based indices used for strings and vectors; the two conventions are deliberate and not interchangeable. Setting foreground and background colours is not available in this version.

### `HOST.Random`

`R.Random()` returns a `FLOAT` in `[0, 1)`. `R.Seed(n)` makes the following sequence deterministic, and the same seed gives the same sequence under `bni` and `bnc`. Without `Seed`, each run starts from a different state.

```basic
IMPORT HOST.Random AS R

FUNCTION RollDie() AS INTEGER
    RETURN (R.Random() * 6.0) AS INTEGER + 1
END FUNCTION

FUNCTION Start() AS VOID
    R.Seed(42)
    PRINT RollDie(), RollDie(), RollDie()
    R.Seed(42)
    PRINT RollDie(), RollDie(), RollDie()
END FUNCTION
```

```
3 6 6
3 6 6
```

`HOST.Random` is not suitable for keys, tokens, or passwords; use the `BNCrypto` module for anything security-related.

### `HOST.Exec`

`Exec.Run(program, args)` starts another program, waits for it, and returns an `Exec.Result` with `ReturnCode`, `Stdout`, and `Stderr`. The program is found through `PATH` or given as a path; no shell is involved, so there is no quoting or globbing, and each argument is passed exactly as written. The child's standard input is closed.

There are two kinds of outcome, and they are handled differently. A program that ran and exited with a non-zero code is still a `Result`: the program decides what the code means. An `Error` means the program could not be run at all, or the host refused, timed out (60 s by default), or captured more than 16 MiB on a stream.

```basic
IMPORT HOST.Exec AS Exec

FUNCTION Report(program AS STRING, argument AS STRING) AS VOID
    LET args AS STRING[1] = [argument]
    LET result AS Exec.Result OR Error = Exec.Run(program, args)
    IF result IS Error THEN
        PRINT program, "could not run:", result.Message
        RETURN
    END IF
    PRINT program, argument, "returned", result.ReturnCode
    PRINT "  stdout:", result.Stdout
    PRINT "  stderr:", result.Stderr
END FUNCTION

FUNCTION Start() AS VOID
    Report("uname", "-s")
    Report("ls", "/no/such/dir")
    Report("no-such-program", "x")
END FUNCTION
```

On macOS:

```
uname -s returned 0
  stdout: Darwin

  stderr:
ls /no/such/dir returned 1
  stdout:
  stderr: ls: /no/such/dir: No such file or directory

no-such-program could not run: No such file or directory (os error 2)
```

The captured text includes the child's own final newline. `Run` takes the argument list as a vector; a function of your own cannot take a variable-length vector, so build a fixed-size one where you call `Run`. Restricted execution policies deny `HOST.Exec` entirely.

### `HOST.Env`

`Env.Get(name)` and `Env.Has(name)` read environment variables of the running process. The surface is strictly read-only: no modifying or removing variables and no enumeration is provided.

```basic
IMPORT HOST.Env AS Env

FUNCTION Start() AS VOID
    LET present AS BOOLEAN OR Error = Env.Has("USER")
    IF present IS Error THEN
        PRINT "environment unavailable:", present.Message
        RETURN
    END IF
    IF present THEN
        LET username AS STRING OR Error = Env.Get("USER")
        IF username IS STRING THEN
            PRINT "Current user:", username
        END IF
    END IF
END FUNCTION
```

Both calls return an alternative, because reading the environment is a host capability that can fail. `Has` yields `BOOLEAN OR Error`, and a condition accepts only `BOOLEAN`, so `IF Env.Has("USER") THEN` is rejected with `TYPE_MISMATCH`. Testing `IS Error` first and returning narrows `present` to `BOOLEAN` for the rest of the function, which is what lets the following `IF` typecheck.

`Get` returns an `Error` with `Code = Env.NOT_SET` if the variable does not exist. If the variable name is empty, contains `=`, or contains NUL bytes, `Env.INVALID_NAME` is returned. If the environment variable contains invalid UTF-8 bytes, `Env.INVALID_UTF8` is returned. If restricted by policy (`BN_ENV_POLICY=deny`), `Env.POLICY_DENIED` is returned.

### Interpreter and Compiler Support

Every example in this chapter runs under `bni run`. `bnc` compiles the `Args`, `Clock`, `NumProcs`, `Console`, `Exec`, and `Env` examples, and `R.Random()` natively when `R.Seed` is called in the same function. When `bnc` refuses an operation, it says so with `TARGET_UNSUPPORTED_HOST`; run the program with `bni` instead.

## Diagnostics Introduced in This Chapter

| Diagnostic | Raised when |
| --- | --- |
| `HOST_CAPABILITY_UNAVAILABLE` | The host refuses a capability, or an operation needs a terminal and standard output is not one. |
| `INDEX_OUT_OF_BOUNDS` | `PrintAt` writes outside the window. |
| `TARGET_UNSUPPORTED_HOST` | `bnc` cannot compile a host operation for the target. |

## Summary

* `HOST` is the only path to the operating system, and each capability is named in an import (except `Args`, `NumProcs`, and the optional `Console`).
* Host operations that can fail return `T OR Error`; test `IS Error` before using the value.
* `HOST.Args` gives the command line, `HOST.Clock` the time, `HOST.Random` reproducible pseudorandom numbers, `HOST.Exec` other programs, and `HOST.Env` the environment.

---

[Next: Files →](13_files.md)
