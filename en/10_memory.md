# Memory

[← Previous: Classes and Interfaces](09_classes_and_interfaces.md) · [Contents](toc.md)

Basic Next uses automatic reference counting (ARC) for class objects, following Swift's model. The runtime tracks strong references, releases them when bindings leave scope, and runs a class destructor exactly once when the last strong reference disappears. The interpreter (`bni`) and the compiler (`bnc`) release every object at the same point, so a program prints the same lines on both.

## Strong references and destructors

Assignment to a class binding creates another strong reference. `RELEASE` drops one binding early; it does not force destruction while another strong reference still exists.

```basic
CLASS Box
    PUBLIC value AS INTEGER = 7

    PUBLIC FUNCTION CONSTRUCTOR()
    END FUNCTION

    FUNCTION DESTRUCTOR()
        PRINT "DEINIT"
    END FUNCTION
END CLASS

FUNCTION Start() AS VOID
    LET first AS Box = NEW Box()
    LET second AS Box = first
    RELEASE first
    PRINT second.value
END FUNCTION
```

The assignment to `second` retains the object. Releasing `first` therefore leaves `second` valid. When `second` leaves `Start`, the count reaches zero and `DEINIT` is printed once.

## When an object is released

A destructor that prints its name shows exactly when each object dies:

```basic
CLASS Tag
    PUBLIC name AS STRING = ""

    PUBLIC FUNCTION CONSTRUCTOR(label AS STRING)
        SELF.name = label
    END FUNCTION

    FUNCTION DESTRUCTOR()
        PRINT "free", SELF.name
    END FUNCTION
END CLASS

CLASS Holder
    PUBLIC slot AS Tag OR NULL = NULL

    PUBLIC FUNCTION CONSTRUCTOR()
    END FUNCTION
END CLASS

FUNCTION Show(item AS Tag) AS VOID
    PRINT "showing", item.name
END FUNCTION

FUNCTION Start() AS VOID
    LET h AS Holder = NEW Holder()
    h.slot = NEW Tag("first")
    h.slot = NEW Tag("second")    // free first
    h.slot = NULL                 // free second
    Show(NEW Tag("temporary"))    // showing temporary, then free temporary
    LET a AS Tag = NEW Tag("a")
    LET b AS Tag = NEW Tag("b")
    PRINT "end"
END FUNCTION                      // free b, then free a
```

The rules behind each line:

- **Reassignment** releases the previous value at once, whether the target is a local, a field, or a `STATIC`. Assigning `NULL` is how a field or a `STATIC` lets go of an object.
- **A temporary**, a value no binding holds, such as `NEW Tag("temporary")` passed straight to a function or the object returned by a call written as a statement, is released at the end of that statement.
- **At the end of a scope**, the locals are released in reverse declaration order: `b` before `a`. Swift leaves this order open; Basic Next fixes it so both toolchains print the same lines.
- **`STOP`** ends the program, but first every running function releases its locals as if it returned: the function that executes `STOP` first, then its caller, out to `Start`.

<!-- bn-check: skip continues the Tag class declared in the previous block -->
```basic
FUNCTION Check() AS VOID
    LET inner AS Tag = NEW Tag("inner")
    STOP 3                        // free inner, then free outer; exit code 3
END FUNCTION

FUNCTION Start() AS VOID
    LET outer AS Tag = NEW Tag("outer")
    Check()
    PRINT "not reached"
END FUNCTION
```

## Parameters keep the argument alive

A parameter is a constant binding ([chapter 5](05_functions.md#parameters-are-constant)): the function receives the caller's object and cannot assign a new value to the parameter. Because the caller keeps the argument alive for the whole call, nothing the function does releases the caller's object.

## Weak references

A weak reference does not keep an object alive. Declare it with `AS WEAK` and make the nullable state explicit:

```basic
CLASS Node
    PUBLIC next AS WEAK Node OR NULL = NULL

    PUBLIC FUNCTION CONSTRUCTOR()
    END FUNCTION
END CLASS

FUNCTION Start() AS VOID
    LET owner AS Node = NEW Node()
    LET observer AS WEAK Node OR NULL = owner
    RELEASE owner
    IF observer IS NULL THEN
        PRINT "expired"
    END IF
END FUNCTION
```

When the last strong reference is released, every weak reference to that object is cleared to `NULL`.

A weak reference never keeps an object alive on its own. An object created straight into a weak binding has no strong reference, so it is released at the end of that statement and the weak binding reads `NULL` right away:

```basic
LET observer AS WEAK Node OR NULL = NULL
observer = NEW Node()    // released at once: nothing holds it strongly
```

## `RELEASE`

`RELEASE` ends a local binding or a parameter early, of any type: objects, alternatives such as `Tag OR NULL` or `Tag OR Error`, primaries, structs, and vectors. It works like Swift's `consume`. It is a statement on a binding:

```basic
LET number AS INTEGER = 10
LET name AS STRING = "temporary"
LET values AS INTEGER[3] = [1, 2, 3]
RELEASE number
RELEASE name
RELEASE values
```

Element expressions, fields, and `STATIC` fields are not bindings, so `RELEASE values[0]`, `RELEASE h.slot`, and `RELEASE Holder.shared` are rejected (`INVALID_RELEASE_TARGET`); assign `NULL` to let a field or a `STATIC` go (`h.slot = NULL`). `RELEASE` of a parameter ends only the function's binding: the caller's object stays alive. Close HOST resources through their API (for example `file.Close()`) and then release the owning binding. `DELETE` is not a language keyword.

## Regions and pointers

A vector ([chapter 6](06_vectors_strings_and_structs.md)) has a length fixed by its type. When the length is known only at run time, `NEW T[n]` allocates a *region* of `n` elements of type `T` and returns a `POINTER TO T[]` to it. Indexing and `LEN` work on a pointer as on a vector, but a pointer is a reference: assigning it shares the region instead of copying it.

A region is reference-counted exactly like a class instance: every `POINTER TO T[]` binding to it is one strong reference, and the region is freed when the last one ends. `RELEASE` on a pointer binding means "drop **my** reference" — it never takes the region away from another binding:

```basic
FUNCTION Start() AS VOID
    LET a AS POINTER TO INTEGER[] = NEW INTEGER[3]
    a[0] = 7
    LET b AS POINTER TO INTEGER[] = a    // two strong references
    RELEASE a                            // a is done; the region lives on
    PRINT b[0]                           // 7
END FUNCTION                             // b leaves scope: region freed
```

Passing a pointer to a function works the same way: the callee may `RELEASE` its parameter, which ends only its own binding, without affecting the caller's.

A region fat pointer can be converted to an opaque pointer `POINTER TO VOID`. The opaque pointer retains the underlying element type code and count without reinterpreting memory:

```basic
LET r AS POINTER TO FLOAT64[] = NEW FLOAT64[3]
LET v AS POINTER TO VOID = r             // preserves length 3 and Float64 code
LET restored AS POINTER TO FLOAT64[] = v // restores typed fat pointer
PRINT LEN(restored)                      // 3
```

Restoring an opaque pointer to an incompatible element type stops execution with `POINTER_TYPE_MISMATCH`. Restoring to a fixed-length pointer with mismatched length stops with `POINTER_LENGTH_MISMATCH`. Opaque pointer conversions participate in normal reference counting and release rules.

Never touch a binding after releasing it. The validator and runtime diagnose `USE_AFTER_RELEASE` (`p[i]`, `LEN(p)`, passing `p`), `DOUBLE_RELEASE`, `NULL_POINTER_ACCESS`, and invalid bounds instead of silently continuing — on both `bni run` and `bnc` artifacts.

The normative ownership rules are in [`0.6.md`](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/0.6.md#memory-model-arc).

## Diagnostics Introduced in This Chapter

| Diagnostic | Raised when |
| --- | --- |
| `INVALID_RELEASE_TARGET` | `RELEASE` names something that is not a binding: an element, a field, or a `STATIC` field. |
| `USE_AFTER_RELEASE` | A binding is used after it was released. |
| `DOUBLE_RELEASE` | A binding is released twice. |
| `NULL_POINTER_ACCESS` | A pointer that holds no region is read or written. |
| `POINTER_TYPE_MISMATCH` | An opaque pointer is restored to an incompatible element type. |
| `POINTER_LENGTH_MISMATCH` | An opaque pointer is restored to a fixed-length pointer of another length. |

## Summary

* Objects and regions are reference-counted: each strong binding holds one reference, and the object is freed, and its destructor run, when the last one ends.
* Locals are released at the end of their scope in reverse declaration order; a temporary at the end of its statement; a reassigned value at once.
* A weak reference (`AS WEAK T OR NULL`) does not keep an object alive and reads `NULL` once it is freed; it is how a cycle is broken.
* `RELEASE` ends one binding early; it never frees an object another binding still holds.
* `NEW T[n]` allocates a region reached through a `POINTER TO T[]`; misuse of a released binding is diagnosed, never silent.

---

[Next: The Standard Library →](11_standard_library.md)
