# Appendix F: BNJson

[← Previous: Appendix E: External Module Conventions](appendix_e_external_modules.md) · [Contents](toc.md)

`BNJson` is an external, provider-backed module, and like every `BN*` facility it enters a program only through an explicit import:

```basic
IMPORT BNJson AS Json
```

## Parsing, building, and writing documents

The module offers two levels of access. `Json.Json.Parse` and `Json.Json.Stringify` cross the boundary between text and a document, and a typed document object model (DOM) lets a program build or inspect that document member by member. The same members are available under `bni` and in a `bnc` executable. What the module deliberately does not offer is automatic serialization: there is no `SERIALIZE` keyword and no `ToJson` method on domain classes, for reasons the next section makes concrete.

The limits are fixed and are part of the contract: a document may be nested at most **64** levels deep and may occupy at most **8 MiB**; trailing input after the document, duplicate keys, and non-finite numbers are all rejected. Depth is checked at the very DOM write that would exceed it, so a failure is reported where it is caused rather than later, at `Stringify`.

Nested documents are *moved*, not shared. `SetJson`, `AppendJson`, and `SetJsonAt` consume the child handle they are given, and `Clone` is the one way to obtain an independent duplicate. The scalar accessors (`GetString`, `SetInteger`, and their siblings) allocate no handles at all.

The normative contract is [`language/0.6/bnjson.md`](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/bnjson.md).

## Companion codecs

A domain type should not know that JSON exists. The convention is to place the encoding and decoding of a type `T` in a sibling module named `TJson`, so that `Bird` has a companion `BirdJson` (a sibling module, not a nested `Bird.Json` path). The domain module imports nothing from `BNJson`; the companion owns the codec; and the program that needs text calls `Stringify` itself, so the boundary between a document and its text stays visible in the code.

The complete example is in [`examples/appendix-f-serialization/`](../examples/appendix-f-serialization/): `Bird.bn`, `BirdJson.bn`, and this `main.bn`:

<!-- bn-check: see examples/appendix-f-serialization -->
```basic
IMPORT Bird AS Birds
IMPORT BirdJson AS BirdJson
IMPORT BNJson AS Json

FUNCTION Start() AS VOID
    LET eagle AS Birds.Bird = NEW Birds.Bird("eagle", 2)

    LET doc AS Json.Json OR Error = BirdJson.Encode(eagle)
    IF doc IS Error THEN
        PRINT "encode-failed"
        RETURN
    END IF

    LET text AS STRING OR Error = Json.Json.Stringify(doc)
    IF text IS Error THEN
        PRINT "stringify-failed"
        RELEASE doc
        RETURN
    END IF
    PRINT text

    LET again AS Birds.Bird OR Error = BirdJson.Decode(doc)
    IF again IS Error THEN
        PRINT "decode-failed"
        RELEASE doc
        RETURN
    END IF
    PRINT again.Name()
    PRINT again.Wings()

    RELEASE doc

    LET empty AS Json.Json = Json.Json.Object()
    LET invalid AS Birds.Bird OR Error = BirdJson.Decode(empty)
    PRINT "decode-error", invalid IS Error
    RELEASE empty
END FUNCTION
```

Run with `bni run main.bn`, it prints:

```text
{"name":"eagle","wings":2}
eagle
2
decode-error TRUE
```

Both companion functions report failure as an `Error` value, under `bni` and `bnc` alike. The last lines show the property that matters most: decoding an empty object yields an `Error`, and `Decode` never fabricates a placeholder `Bird` to stand in for a missing or wrongly typed field. A companion may add convenience functions that go straight from a value to text, but the book keeps the two steps, `Encode` and then `Stringify`, separate.

---

[Next: Appendix G: BNLog →](appendix_g_bnlog.md)
