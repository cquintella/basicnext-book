# Appendix L: BNFfi — C Foreign Function Interface

[← Previous: Appendix K: BNCrypto](appendix_k_bncrypto.md) · [Contents](toc.md)

The `BNFfi` standard module provides a dynamic foreign function interface for calling C ABI functions from Basic Next programs without language extensions or special compiler keywords.

Both the interpreter (`bni run`) and the native compiler (`bnc`) execute `BNFfi` calls with exact observable parity.

## The Confinement and Safety Warning

Basic Next provides strict memory safety, bounds-checking, and automatic reference counting. A foreign C library operates outside these language guarantees.

* Calling C code escapes the sandbox. A C function can write to arbitrary memory, execute system calls, or crash the process.
* Basic Next cannot verify whether C parameter types match what the C function expects. If the signature passed to `C.Call` does not match the compiled C function, undefined behavior will occur.
* The wrapper pattern is strongly recommended: never expose raw `BNFfi` types directly across your application codebase. Wrap all foreign library interactions inside a dedicated, strongly-typed Basic Next class.

## Module Import and Types

To use the C foreign function interface, import the standard module:

```basicnext
IMPORT BNFfi AS C
```

`BNFfi` defines typed record classes corresponding to standard C ABI types:

* Fixed-width signed integers: `C.Int8`, `C.Int16`, `C.Int32`, `C.Int64`
* Fixed-width unsigned integers: `C.UInt8`, `C.UInt16`, `C.UInt32`, `C.UInt64`
* Platform-dependent C integers: `C.Int`, `C.UInt`, `C.Long`, `C.ULong`, `C.SizeT`
* Floating-point numbers: `C.Float` (32-bit `float`), `C.Double` (64-bit `double`)
* Booleans and text: `C.Bool`, `C.String`
* Return and handle types: `C.Void`, `C.Handle`, `C.HandleResult`
* Continuous arrays: `C.ByteArray`, `C.Int8Array`, `C.Int16Array`, `C.Int32Array`, `C.Int64Array`, `C.UInt16Array`, `C.UInt32Array`, `C.UInt64Array`, `C.FloatArray`, `C.DoubleArray`

## Calling a C Function

C function invocations follow three steps:

* Create an argument list container (`C.Args`) and append typed argument records via `.Add(...)`.
* Instantiate the expected result record container.
* Call `C.Call(library, symbol, args, result)`.

```basicnext
IMPORT BNFfi AS C

FUNCTION Start() AS INTEGER
    LET args AS C.Args = NEW C.Args()
    args.Add(NEW C.String("hello foreign function interface"))

    LET result AS C.SizeT = NEW C.SizeT(0)
    LET status AS VOID OR Error = C.Call("libSystem.B.dylib", "strlen", args, result)

    IF status IS Error THEN
        PRINT "Call failed: ", status.Message
        RETURN 1
    END IF

    PRINT "Length: ", result.Value()
    RETURN 0
END FUNCTION
```

## Reading Strings from Pointers

When a C function returns a heap pointer or a static C string (`const char *`), capture the pointer using `C.HandleResult`. You can then call `ReadString()` on the resulting `Handle`:

```basicnext
IMPORT BNFfi AS C

FUNCTION ReadGreeting() AS STRING OR Error
    LET empty_args AS C.Args = NEW C.Args()
    LET result AS C.HandleResult = NEW C.HandleResult()

    LET status AS VOID OR Error = C.Call("mylib", "get_greeting", empty_args, result)
    IF status IS Error THEN
        RETURN status
    END IF

    LET handle AS C.Handle OR NULL = result.Value()
    IF handle IS NULL THEN
        RETURN ""
    END IF

    RETURN handle.ReadString()
END FUNCTION
```

## Passing Arrays In-Place

Basic Next dynamic regions (`POINTER TO T[]`) can be passed to C functions for in-place modification or bulk reading:

```basicnext
IMPORT BNFfi AS C

FUNCTION ScaleBuffer() AS VOID
    LET buffer AS POINTER TO FLOAT[] = NEW FLOAT[4]
    buffer[0] = 1.0
    buffer[1] = 2.0
    buffer[2] = 3.0
    buffer[3] = 4.0

    LET args AS C.Args = NEW C.Args()
    args.Add(NEW C.DoubleArray(buffer))
    args.Add(NEW C.Int32(4))
    args.Add(NEW C.Double(2.5))

    LET res AS C.Void = NEW C.Void()
    LET status AS VOID OR Error = C.Call("mylib", "scale_floats", args, res)

    RELEASE buffer
END FUNCTION
```

## The Wrapper Pattern

Never scatter direct `C.Call` invocations across business logic. Always wrap foreign library calls in a domain class:

```basicnext
IMPORT BNFfi AS C

EXPORT CLASS Compression
    PRIVATE lib_name AS STRING

    PUBLIC FUNCTION CONSTRUCTOR()
        THIS.lib_name = "z"
    END FUNCTION

    PUBLIC FUNCTION Version() AS STRING OR Error
        LET args AS C.Args = NEW C.Args()
        LET res AS C.HandleResult = NEW C.HandleResult()
        LET status AS VOID OR Error = C.Call(THIS.lib_name, "zlibVersion", args, res)
        IF status IS Error THEN
            RETURN status
        END IF
        LET h AS C.Handle OR NULL = res.Value()
        IF h IS NULL THEN
            RETURN ""
        END IF
        RETURN h.ReadString()
    END FUNCTION
END CLASS
```

## Library Resolution and CLI Options

`BNFfi` discovers libraries using candidate path resolution:

* Explicit directories passed via `--ffi-path <dir>` (repeatable, earlier options take precedence).
* Environment variable `BN_LIBRARY_PATH` (colon-separated directories, or semicolon-separated on Windows).
* Standard operating system loader paths (`/usr/lib`, `/usr/local/lib`, standard Windows system search).

Compilation with `--sandbox` restricts access to unverified external foreign code.

---

[Next: Appendix M: BNDispatch →](appendix_m_bndispatch.md)
