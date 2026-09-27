# The Standard Library and Host

[← Previous: Memory Management](07_memory_management.md) · [Contents](toc.md)

Basic Next decouples the core language from the operating system. `HOST` is
the only built-in interface object. All `BN*` facilities are external modules
and must be imported explicitly; their detailed contracts live in separate
appendices.

## The `BNMath` namespace

The mathematics standard library is the `BNMath` module. Every use requires
an import; the alias is used for member calls.

```basic
IMPORT BNMath AS Math
LET root AS FLOAT = Math.SQRT(9.0)
LET rounded AS FLOAT = Math.ROUND(3.14159, 2)
LET lower AS FLOAT = Math.FLOOR(3.9)
```

`BNMath` provides strict IEEE 754 implementations for common mathematical functions. Operations return `FLOAT` unless restricted to integers.

The available surface includes:
- Mathematical and exponential functions: `ABS`, `MIN`, `MAX`, `SIGN`, `FLOOR`, `CEIL`, `TRUNC`, `ROUND`, `SQRT`, `HYPOT`, `FMA`, `EXP`, `LOG`, `LOG10`, `LOG2`, `POW`.
- Trigonometry: `SIN`, `COS`, `TAN`, `ASIN`, `ACOS`, `ATAN`, `ATAN2`.
- Text parsing: `VAL(text AS STRING) AS FLOAT`.
- Descriptive statistics: `MEAN`, `MEDIAN`, `MODE`, `STDEV`, `VARIANCE`, `RANGE`, `QUARTILE1`, `QUARTILE3`.
- Range constants: `MAX_INTEGER`, `MIN_INTEGER`, `MAX_FLOAT`, `MIN_FLOAT` (and width-specific variants).

## The `BNString` module

`BNString` is an external module that wraps the primary `STRING` value in the
ARC-managed `S.String` object. Import it explicitly when you need fluent string
operations:

```basic
IMPORT BNString AS S

LET text AS S.String = NEW S.String("  Olá,BN  ")
LET clean AS S.String = text.Trim()
PRINT clean.LowCaps().ToString()
PRINT clean.Contains("BN")

LET words AS S.Tokenizer OR NULL = clean.Tokenizer(",")
IF words IS NOT NULL THEN
    PRINT words.Next()
END IF
```

`Len`/`Length` report Unicode scalar values, `LowCaps` and `HiCaps` perform
Unicode-aware case conversion, and `Tokenizer` walks separator-delimited tokens.
`S.String` instances follow the same ARC rules as other class objects: strong
bindings retain them, scope exit releases them, and weak bindings become `NULL`
when the last strong reference is gone. See the full API in
[`docs/library/bnstring.md`](../../library/bnstring.md) and the runnable
[`bnstring_tour.bn`](../../../examples/bnstring_tour.bn).

## HOST capabilities

A program reaches the operating system only through `HOST`. Each capability
is imported explicitly (`IMPORT HOST.Clock AS Clock`), except `HOST.Args` and
`HOST.NumProcs`, which need no import. Nothing reaches the network, the file
system, or other processes unless the program says so in its imports, and a
restricted host can refuse an import before `Start` runs
(`HOST_CAPABILITY_UNAVAILABLE`).

Most operations can fail, so they return `T OR Error`. The examples below
test `IS Error` and use the value in the `ELSE` branch, where it has been
narrowed to `T`.

| Capability | Import | Use it for |
| --- | --- | --- |
| `HOST.Args` | none | command-line arguments |
| `HOST.Clock` | `IMPORT HOST.Clock AS Clock` | wall-clock time and elapsed time |
| `HOST.NumProcs` | none | sizing a worker pool |
| `HOST.Console` | `IMPORT HOST.Console AS CON` | clearing the screen, positioned text, window size |
| `HOST.Random` | `IMPORT HOST.Random AS R` | reproducible pseudorandom numbers |
| `HOST.FileSystem` | `IMPORT HOST.FileSystem AS FS` | reading and writing files |
| `HOST.Exec` | `IMPORT HOST.Exec AS Exec` | running another program |
| `HOST.Net` | `IMPORT HOST.Net AS Net` | addresses, name resolution, TCP, UDP, ping |

The normative contracts are in the language specification:
[`host.md`](https://github.com/cquintella/BasicNext/blob/main/language/0.6/host.md),
[`console.md`](https://github.com/cquintella/BasicNext/blob/main/language/0.6/console.md),
[`host-exec.md`](https://github.com/cquintella/BasicNext/blob/main/language/0.6/host-exec.md), and
[`host-net.md`](https://github.com/cquintella/BasicNext/blob/main/language/0.6/host-net.md).

### `HOST.Args`

`HOST.Args` holds the command-line arguments. Only the executable module (the
one with `Start`) may use it. `HOST.Args[0]` is the absolute path of the
program; the arguments given after `--` follow it. `LEN(HOST.Args)` counts
them all, including entry `0`.

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

Returning an `INTEGER` from `Start` sets the exit status, so the usage case
exits with `2`.

### `HOST.Clock`

`Clock.Now()` returns a `TIMESTAMP`: milliseconds since 1970-01-01T00:00:00Z.
`Clock.Timer()` returns nanoseconds from an unspecified origin as an `INT64`
that never decreases. Use `Now` for calendar time and `Timer` for measuring a
duration; a `Timer` value is not a date.

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

`HOST.NumProcs()` returns the number of logical processors available to the
process, respecting container limits where the host reports them. It is the
right input for choosing how many workers to start. It returns
`INTEGER OR Error`, so a program keeps a fallback:

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

In an 80×24 terminal this centres the title on row 1 (column
`(80 - 10) DIV 2 + 1 = 36`) and prints `80 x 24`. When standard output is
redirected to a file or a pipe, `Cls` and `Beep` still run, but the first
call to `NumCols` stops the program:

```
error[HOST_CAPABILITY_UNAVAILABLE]: window size requires a TTY
```

`PrintAt` does not wrap or clip: a position outside the window, or text that
would run past the right edge, is `INDEX_OUT_OF_BOUNDS`.

### `HOST.Random`

`R.Random()` returns a `FLOAT` in `[0, 1)`. `R.Seed(n)` makes the following
sequence deterministic, and the same seed gives the same sequence under `bni`
and `bnc`. Without `Seed`, each run starts from a different state.

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

`HOST.Random` is not suitable for keys, tokens, or passwords; use the
`BNCrypto` module for anything security-related.

### `HOST.FileSystem`

`FS.Open(path, mode)` returns an `FS.File OR Error`. The mode is `FS.READ`,
`FS.WRITE` (create or truncate), or `FS.APPEND` (write at the end, creating
the file if needed). Close every file you open: `Close()` flushes the data and
returns `VOID OR Error`, which is the only place a failed flush is reported.
Text is UTF-8.

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

`ReadLine()` returns `STRING OR EOF OR Error`, so the loop stops on `EOF` and
reports a genuine failure separately. `ReadAll()` returns the rest of the file
as one `STRING`.

A file is used either for text (`ReadLine`, `ReadAll`, `Write`, `WriteLine`)
or for bytes (`ReadBytes`, `WriteBytes`), never both; the first successful
call decides. Bytes live in a `POINTER TO BYTE[]` region:

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

### `HOST.Exec`

`Exec.Run(program, args)` starts another program, waits for it, and returns
an `Exec.Result` with `ReturnCode`, `Stdout`, and `Stderr`. The program is
found through `PATH` or given as a path; no shell is involved, so there is no
quoting or globbing, and each argument is passed exactly as written. The
child's standard input is closed.

There are two kinds of outcome, and they are handled differently. A program
that ran and exited with a non-zero code is still a `Result`: the program
decides what the code means. An `Error` means the program could not be run
at all, or the host refused, timed out (60 s by default), or captured more
than 16 MiB on a stream.

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

The captured text includes the child's own final newline. `Run` takes the
argument list as a vector; a function of your own cannot take a
variable-length vector, so build a fixed-size one where you call `Run`.
Restricted execution policies deny `HOST.Exec` entirely.

### `HOST.Net`

Networking is typed: an `Address` is parsed and validated before it can be
used, an `Endpoint` pairs an address with a port, and every operation that
waits takes a timeout in milliseconds. No example below needs the Internet.

**Addresses, networks, and name resolution.** `Net.Address.Parse` accepts IPv4
and IPv6 text and rejects host names; `Net.Resolve` is the only operation that
turns a name into addresses.

```basic
IMPORT HOST.Net AS Net

FUNCTION Describe(text AS STRING) AS VOID
    LET address AS Net.Address OR Error = Net.Address.Parse(text)
    IF address IS Error THEN
        PRINT text, "is not an address:", address.Message
    ELSE
        PRINT address.ToString(), "loopback:", address.IsLoopback(), "private:", address.IsPrivate()
    END IF
END FUNCTION

FUNCTION Start() AS INTEGER
    Describe("127.0.0.1")
    Describe("192.168.10.7")
    Describe("::1")
    Describe("example.com")

    LET lan AS Net.CIDR OR Error = Net.CIDR.Parse("192.168.10.0/24")
    LET host AS Net.Address OR Error = Net.Address.Parse("192.168.10.7")
    IF lan IS Error OR host IS Error THEN
        PRINT "parse failed"
        RETURN 1
    END IF
    PRINT "prefix:", lan.PrefixLength(), "contains 192.168.10.7:", lan.Contains(host)

    LET found AS Net.Addresses OR Error = Net.Resolve("localhost", 2000)
    IF found IS Error THEN
        PRINT "resolve failed:", found.Message
        RETURN 1
    END IF
    FOR i AS INTEGER = 0 TO found.Count() - 1
        LET item AS Net.Address OR Error = found.Get(i)
        IF item IS Error THEN
            PRINT "entry", i, "failed:", item.Message
        ELSE
            PRINT "localhost ->", item.ToString()
        END IF
    END FOR
    RETURN 0
END FUNCTION
```

```
127.0.0.1 loopback: TRUE private: FALSE
192.168.10.7 loopback: FALSE private: TRUE
::1 loopback: TRUE private: FALSE
example.com is not an address: invalid IP address
prefix: 24 contains 192.168.10.7: TRUE
localhost -> ::1
localhost -> 127.0.0.1
```

`Resolve` returns an `Addresses` collection in the system's order, read with
`Count()` and `Get(i)`.

**TCP.** `Net.TCPListen` opens listeners on a set of endpoints, `Accept` waits
for a connection, and `Net.TCPConnect` connects. `Read` and `Write` move bytes
through a `POINTER TO BYTE[]` buffer; `Read` returns `EOF` when the peer has
closed. This program is both server and client on the loopback interface:

```basic
IMPORT HOST.Net AS Net

FUNCTION Start() AS INTEGER
    LET loopback AS Net.Address OR Error = Net.Address.Parse("127.0.0.1")
    IF loopback IS Error THEN
        RETURN 1
    END IF
    // Port 0 asks the system for any free port.
    LET wanted AS Net.Endpoint OR Error = Net.Endpoint.Create(loopback, 0)
    IF wanted IS Error THEN
        RETURN 1
    END IF
    LET endpoints AS Net.Endpoint[1] = [wanted]
    LET listener AS Net.TCPListener OR Error = Net.TCPListen(endpoints, 8)
    IF listener IS Error THEN
        PRINT "listen failed:", listener.Message
        RETURN 1
    END IF
    LET bound AS Net.Endpoint OR Error = listener.LocalEndpoint()
    IF bound IS Error THEN
        RETURN 1
    END IF
    PRINT "listening on port", bound.Port()

    LET client AS Net.TCPStream OR Error = Net.TCPConnect(bound, 2000)
    LET server AS Net.TCPStream OR Error = listener.Accept(2000)
    IF client IS Error OR server IS Error THEN
        PRINT "connection failed"
        RETURN 1
    END IF

    LET message AS POINTER TO BYTE[] = NEW BYTE[2]
    message[0] = 72    // 'H'
    message[1] = 105   // 'i'
    LET sent AS INTEGER OR Error = client.Write(message, 2)
    IF sent IS Error THEN
        PRINT "write failed:", sent.Message
        RETURN 1
    END IF

    LET received AS POINTER TO BYTE[] = NEW BYTE[2]
    LET count AS INTEGER OR EOF OR Error = server.Read(received, 2)
    IF count IS INTEGER THEN
        PRINT "server read", count, "bytes:", received[0], received[1]
    END IF

    client.Close()
    server.Close()
    listener.Close()
    RELEASE message
    RELEASE received
    RETURN 0
END FUNCTION
```

```
listening on port 64483
server read 2 bytes: 72 105
```

Port `0` asks the system for a free port; `LocalEndpoint()` reports which one
was chosen.

**UDP.** `Net.UDPBind` opens a socket, `SendTo` sends one datagram, and
`Receive(size, timeout)` returns a `UDPPacket` that knows its source, its
size, and whether it was truncated to fit:

```basic
IMPORT HOST.Net AS Net

FUNCTION Start() AS INTEGER
    LET loopback AS Net.Address OR Error = Net.Address.Parse("127.0.0.1")
    IF loopback IS Error THEN
        RETURN 1
    END IF
    LET any AS Net.Endpoint OR Error = Net.Endpoint.Create(loopback, 0)
    IF any IS Error THEN
        RETURN 1
    END IF
    LET receiver AS Net.UDPSocket OR Error = Net.UDPBind(any)
    LET sender AS Net.UDPSocket OR Error = Net.UDPBind(any)
    IF receiver IS Error OR sender IS Error THEN
        PRINT "bind failed"
        RETURN 1
    END IF
    LET target AS Net.Endpoint OR Error = receiver.LocalEndpoint()
    IF target IS Error THEN
        RETURN 1
    END IF

    LET datagram AS POINTER TO BYTE[] = NEW BYTE[3]
    datagram[0] = 1
    datagram[1] = 2
    datagram[2] = 3
    LET sent AS INTEGER OR Error = sender.SendTo(target, datagram, 3)
    IF sent IS Error THEN
        PRINT "send failed:", sent.Message
        RETURN 1
    END IF

    // Receive at most 16 bytes, waiting up to 2000 ms.
    LET packet AS Net.UDPPacket OR Error = receiver.Receive(16, 2000)
    IF packet IS Error THEN
        PRINT "receive failed:", packet.Message
        RETURN 1
    END IF
    LET copy AS POINTER TO BYTE[] = NEW BYTE[16]
    LET copied AS INTEGER OR Error = packet.CopyTo(copy, 16)
    IF copied IS INTEGER THEN
        PRINT "received", packet.Size(), "bytes, truncated:", packet.WasTruncated()
        PRINT "payload:", copy[0], copy[1], copy[2]
    END IF

    sender.Close()
    receiver.Close()
    RELEASE datagram
    RELEASE copy
    RETURN 0
END FUNCTION
```

```
received 3 bytes, truncated: FALSE
payload: 1 2 3
```

**Ping.** `Net.Ping` sends one ICMP Echo to a parsed address. Timeout,
unreachable host, and missing ICMP permission are distinct errors, and a host
without ICMP permission still allows every other `HOST.Net` operation.

```basic
IMPORT HOST.Net AS Net

FUNCTION Start() AS INTEGER
    LET target AS Net.Address OR Error = Net.Address.Parse("127.0.0.1")
    IF target IS Error THEN
        RETURN 1
    END IF
    LET reply AS Net.PingReply OR Error = Net.Ping(target, 1000)
    IF reply IS Error THEN
        // Timeout, unreachable, and missing ICMP permission are distinct errors.
        PRINT "ping failed:", reply.Code, reply.Message
        RETURN 1
    END IF
    PRINT "reply from", reply.Address().ToString(), "in", reply.RoundTripMicroseconds(), "us"
    RETURN 0
END FUNCTION
```

```
reply from 127.0.0.1 in <round-trip time> us
```

### Interpreter and compiler support

Every example in this section runs under `bni run`. `bnc` compiles the
`Args`, `Clock`, `Console`, `Exec`, TCP, and `Ping` examples, and
`R.Random()` natively when `R.Seed` is called in the same function. In 0.6 it
rejects the rest with `TARGET_UNSUPPORTED_OP` or `TARGET_UNSUPPORTED_HOST`:
the `FS.File` methods (`FS.Open` itself compiles), `FS.Exists`,
`FS.DeleteFile`, `HOST.NumProcs`, and several `HOST.Net` operations such as
the `Address` predicates, `CIDR`, `TCPStream.SetTimeouts`, and
`UDPSocket.LocalEndpoint`. When `bnc` refuses an operation, run the program
with `bni` instead.

## External module references

Basic Next provides several provider-backed modules that must be explicitly imported:

- `BNData`: Contract documented in [Appendix H](14_bndata.md).
- `BNWeb`: Added in version 0.3, it provides an HTTP client/server, routes, filters, and URL boundaries. Contract in [Appendix G](13_bnweb.md).
- `BNLog`: Added in version 0.3, it provides structured application and access logging. Contract in [Appendix F](12_bnlog.md).
- `BNJson`: Added in version 0.3, it provides bounded JSON parsing and serialization. Contract in [Appendix E](11_bnjson.md).

## Temporal Data

Basic Next distinguishes strictly between instant-in-time timestamps and human calendar values.

- `TIMESTAMP`: An alias for `INT64` representing an exact moment (milliseconds since the UTC Unix epoch). It supports standard integer arithmetic.
- `DATE`: An immutable Gregorian date (e.g., `2026-08-25`). Logically a 32-bit day count.
- `TIME`: An immutable time of day (e.g., `22:07:20.000`). Logically a 32-bit millisecond count.
- `TIMEZONE`: An IANA identifier (e.g., `America/Sao_Paulo` or `UTC`). The value stores that identifier; the interpreter does not load a TZDB
  database or apply zone rules.

Calendar, formatting, and time-zone operations use explicit calls in the temporal library rather than implicit string conversions.

## Built-ins: `LEN` and `SIZEOF`

Basic Next provides two built-in forms for measuring size. Both evaluate their operand and return an `INTEGER`.

### `LEN(value)`

Returns the logical count of items:
- For a numeric value, the length is `1`.
- For a `STRING`, it is the number of Unicode scalar values (characters).
- For a fixed-size vector, it is the total number of elements across all dimensions.

### `SIZEOF(value)`

Returns the portable byte size of the value's representation, with no padding.
- `BOOLEAN` is 1 byte.
- `DATE` and `TIME` are 4 bytes.
- `STRING` returns the exact UTF-8 byte length of its text.
- Vectors and structs return the sum of their elements' sizes.

`SIZEOF` is a static error for pointers, interfaces, alternative types, and structs containing dynamically sized strings.

---

[Next: I/O and Concurrency →](09_io_and_concurrency.md)
