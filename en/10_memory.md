# Memory

[← Previous: Classes and Interfaces](09_classes_and_interfaces.md) · [Contents](toc.md)

Every object created with `NEW` occupies memory, and a long-running program that never gave that memory back would eventually exhaust it. Languages answer the question of when to give it back in three broad ways. In C, the programmer frees each object explicitly, and a mistake either leaks memory or, worse, frees an object that is still in use. In Java, Python, or Go, a *tracing garbage collector* periodically searches for objects that can no longer be reached and reclaims them; the programmer is relieved of the bookkeeping, but cannot know when an object will be reclaimed, and the search itself takes time at moments the program does not choose.

Basic Next takes a third approach, *automatic reference counting* (ARC), following the model of Swift. Each object carries a count of the bindings that refer to it. Creating a reference increments the count, ending one decrements it, and the object is freed at the moment the count reaches zero — not later, at a collector's convenience, but at a point that can be read from the program text. The interpreter and the compiler apply exactly the same rules, so a program that prints from its destructors prints the same lines, in the same order, under `bni run` and as a native executable.

This chapter explains when objects are freed, the one situation ARC cannot resolve on its own and the weak references that resolve it, the `RELEASE` statement, and the regions of memory reached through pointers.

## Strong References

A binding that refers to an object — a local, a parameter, a field, a vector element — is a *strong reference*: as long as it exists, the object exists. Assigning an object to a second binding creates a second strong reference, not a second object. The destructor introduced in [chapter 9](09_classes_and_interfaces.md#constructors) runs when the last of them ends, and printing from it is the simplest way to observe the rule:

```basic
CLASS Box
    PUBLIC value AS INTEGER = 7

    PUBLIC FUNCTION CONSTRUCTOR()
    END FUNCTION

    FUNCTION DESTRUCTOR()
        PRINT "box freed"
    END FUNCTION
END CLASS

FUNCTION Start() AS VOID
    LET first AS Box = NEW Box()
    LET second AS Box = first
    RELEASE first
    PRINT "still here:", second.value
    PRINT "leaving Start"
END FUNCTION
```

```
still here: 7
leaving Start
box freed
```

`RELEASE first` ends the binding `first` early, but the object survives, because `second` still refers to it. It is freed only when `second` goes out of scope at the end of `Start`, and the destructor's line is accordingly the last one printed. `RELEASE` never destroys an object that another binding can still reach; it gives up one reference, and the count decides the rest.

## When an Object Is Freed

The rules that decide the exact moment are few, and the following program exercises all of them. Each line is annotated with what the destructor prints when that line runs:

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

**Reassignment releases the previous value at once.** When `h.slot` receives the second tag, the first loses its only reference and is freed before the next statement begins. This holds for locals, fields, and `STATIC` fields alike, and it is why assigning `NULL` is the way a field lets go of an object.

**A temporary is released at the end of its statement.** `NEW Tag("temporary")` is passed straight to `Show` and held by no binding of `Start`. The parameter keeps it alive for the duration of the call; when the statement that made the call is complete, nothing refers to the tag and it is freed. The same applies to an object returned by a function whose result the caller ignores.

**At the end of a scope, locals are released in reverse order of declaration.** `b` was declared after `a` and is released before it. Swift leaves this order unspecified; Basic Next fixes it, because a fixed order is what lets both toolchains print identical output, and because it matches the intuition that a later object may depend on an earlier one but not the reverse.

**`STOP` releases before it exits.** `STOP` ends the program ([chapter 4](04_control_flow.md#terminating-execution-stop)), but first every function that is running releases its locals, as if it had returned: the function that executed `STOP` first, then its caller, outward to `Start`. Destructors that close files or flush logs therefore run even on an early exit:

<!-- bn-check: skip continues the Tag class declared in the previous block -->
```basic
FUNCTION Check() AS VOID
    LET inner AS Tag = NEW Tag("inner")
    PRINT "checking", inner.name
    STOP 3                        // free inner, then free outer; exit code 3
END FUNCTION

FUNCTION Start() AS VOID
    LET outer AS Tag = NEW Tag("outer")
    PRINT "starting", outer.name
    Check()
    PRINT "not reached"
END FUNCTION
```

**A parameter never frees the caller's object.** A parameter is a constant binding ([chapter 5](05_functions.md#parameters-are-constant)), and the caller holds its argument for the whole call. Nothing a function does to its parameter — not even `RELEASE` — can free an object its caller is still using.

## Reference Cycles

Reference counting has one well-known limit. If two objects refer to each other, each keeps the other's count above zero, and neither is ever freed, even after the rest of the program has lost every way of reaching them. Such a pair is a *reference cycle*, and its memory is leaked.

The following program builds one. Two people refer to each other as partners; when `Pair` returns, its locals are released, but each person is still referenced by the other:

```basic
CLASS Person
    PUBLIC name AS STRING = ""
    PUBLIC partner AS Person OR NULL = NULL

    PUBLIC FUNCTION CONSTRUCTOR(name AS STRING)
        SELF.name = name
    END FUNCTION

    FUNCTION DESTRUCTOR()
        PRINT "free", SELF.name
    END FUNCTION
END CLASS

FUNCTION Pair() AS VOID
    LET ana AS Person = NEW Person("ana")
    LET bruno AS Person = NEW Person("bruno")
    ana.partner = bruno
    bruno.partner = ana
    PRINT "leaving Pair"
END FUNCTION

FUNCTION Start() AS VOID
    Pair()
    PRINT "after Pair"
END FUNCTION
```

```
leaving Pair
after Pair
```

Neither destructor runs. A tracing collector would detect that the two objects are unreachable; ARC, which only counts, cannot. Avoiding cycles is therefore the programmer's responsibility, and the language provides the means: weak references.

## Weak References

A *weak reference* refers to an object without counting toward its lifetime. It is declared with `WEAK`, and its type must include `NULL`, because the object it refers to may be freed while the weak reference still exists; when that happens, every weak reference to the object becomes `NULL`. Changing one line of the previous program breaks the cycle:

```basic
CLASS Person
    PUBLIC name AS STRING = ""
    PUBLIC partner AS WEAK Person OR NULL = NULL

    PUBLIC FUNCTION CONSTRUCTOR(name AS STRING)
        SELF.name = name
    END FUNCTION

    FUNCTION DESTRUCTOR()
        PRINT "free", SELF.name
    END FUNCTION
END CLASS

FUNCTION Pair() AS VOID
    LET ana AS Person = NEW Person("ana")
    LET bruno AS Person = NEW Person("bruno")
    ana.partner = bruno
    bruno.partner = ana
    PRINT "leaving Pair"
END FUNCTION

FUNCTION Start() AS VOID
    Pair()
    PRINT "after Pair"
END FUNCTION
```

```
leaving Pair
free bruno
free ana
after Pair
```

Now the only strong references are the locals of `Pair`, and both people are freed when it returns, in reverse order of declaration. The general design rule is to decide, for each pair of objects that point at each other, which one *owns* the other. The owner holds a strong reference; the reference back, from the owned object to its owner, is weak. A tree whose nodes point to their children strongly and to their parent weakly is the typical case.

Because a weak reference may become `NULL` at any moment, it is read like any other alternative type ([chapter 7](07_alternatives_and_errors.md)): test it with `IS` before use. It follows that a weak reference cannot keep an object alive on its own. An object created directly into a weak binding has no strong reference at all, and is freed at the end of the statement that created it:

```basic
CLASS Node
    PUBLIC FUNCTION CONSTRUCTOR()
    END FUNCTION
END CLASS

FUNCTION Start() AS VOID
    LET observer AS WEAK Node OR NULL = NULL
    observer = NEW Node()     // freed at once: nothing holds it strongly
    PRINT observer IS NULL    // TRUE
END FUNCTION
```

## `RELEASE`

`RELEASE name` ends a binding before the end of its scope. It applies to locals and parameters of any type — objects, alternatives such as `Tag OR NULL`, scalars, strings, structs, and vectors — and corresponds to Swift's `consume`. After it, the name may not be used again:

```basic
FUNCTION Start() AS VOID
    LET number AS INTEGER = 10
    LET name AS STRING = "temporary"
    LET values AS INTEGER[3] = [1, 2, 3]
    PRINT number, name, values[0]
    RELEASE number
    RELEASE name
    RELEASE values
END FUNCTION
```

For an object, releasing a binding gives up one strong reference, with the consequences described above. For a value type, it ends the binding and its storage. Its purpose in both cases is the same: to state, at the point where it becomes true, that a value is no longer needed, so that a large buffer or an object holding a resource does not survive to the end of a long function.

`RELEASE` acts on bindings only. An element (`values[0]`), a field (`h.slot`), or a static field is not a binding, and naming one is `INVALID_RELEASE_TARGET`; a field or a static field lets go of an object by being assigned `NULL`. Releasing a parameter ends only the function's own binding; the caller's object is untouched. Host resources such as open files are closed through their own methods (`file.Close()`, [chapter 13](13_files.md)) before their binding is released. The language has no `DELETE`: no statement can destroy an object that other bindings still reach.

Using a binding after releasing it, or releasing it twice, is an error, reported when the program runs on both backends:

```
error[USE_AFTER_RELEASE]: Released value cannot be used: binding was released
error[DOUBLE_RELEASE]: Value was released more than once: binding was already released
```

## Regions and Pointers

A vector has a length fixed by its type ([chapter 6](06_vectors_strings_and_structs.md)). When the length is known only while the program runs — the size of a file, a number read from input — the program allocates a *region*: `NEW T[n]` reserves `n` elements of type `T` and returns a `POINTER TO T[]`. Indexing and `LEN` work on a pointer as they do on a vector, and every index is checked against the region's length:

```basic
FUNCTION Start() AS VOID
    LET count AS INTEGER = 4
    LET squares AS POINTER TO INTEGER[] = NEW INTEGER[count]
    FOR i AS INTEGER = 0 TO LEN(squares) - 1
        squares[i] = i * i
    END FOR
    PRINT LEN(squares), squares[3]    // 4 9
END FUNCTION
```

Unlike a vector, a pointer is a reference: assigning it shares the region rather than copying it. A region is therefore reference-counted exactly as an object is. Each `POINTER TO T[]` binding is one strong reference, the region is freed when the last one ends, and `RELEASE` on a pointer gives up that binding's reference without taking the region away from any other:

```basic
FUNCTION Start() AS VOID
    LET a AS POINTER TO INTEGER[] = NEW INTEGER[3]
    a[0] = 7
    LET b AS POINTER TO INTEGER[] = a    // two strong references
    RELEASE a                            // a is done; the region lives on
    PRINT b[0]                           // 7
END FUNCTION                             // b leaves scope: region freed
```

A typed pointer can be converted to the opaque type `POINTER TO VOID`, which is how regions are passed to code that handles memory generically, such as the C interface of [Appendix L](appendix_l_bnffi.md). The conversion does not reinterpret the memory: the opaque pointer keeps the element type and the length, and converting it back checks both:

```basic
FUNCTION Start() AS VOID
    LET r AS POINTER TO FLOAT64[] = NEW FLOAT64[3]
    LET v AS POINTER TO VOID = r              // keeps element type and length 3
    LET restored AS POINTER TO FLOAT64[] = v  // converted back, checked
    PRINT LEN(restored)                       // 3
END FUNCTION
```

Restoring an opaque pointer to a different element type stops the program with `POINTER_TYPE_MISMATCH`, and restoring it to a fixed length that differs from the region's stops it with `POINTER_LENGTH_MISMATCH`. A pointer that refers to no region at all is reported as `NULL_POINTER_ACCESS` when it is read or written. In each case the failure is reported where it occurs, never left to corrupt memory silently, on both backends.

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

Basic Next reclaims memory by automatic reference counting. Every strong reference to an object or a region counts toward its lifetime, and the object is freed, and its destructor run, at the moment the last reference ends. That moment follows from a small set of rules: a reassigned value is released at once, a temporary at the end of its statement, the locals of a scope in reverse order of declaration, and the locals of every running function before `STOP` exits. Two objects that refer to each other strongly form a cycle that is never freed; the remedy is to make one direction of the reference `WEAK`, which does not count and becomes `NULL` when its object is freed. `RELEASE` ends a binding early without ever destroying what other bindings still reach, and regions allocated with `NEW T[n]` follow the same counting rules through their pointers. Every misuse — a released binding used again, a double release, a mismatched pointer — is reported, never silent.

Part III ends here. Part IV turns from the language itself to the programs written with it: the standard library, the host, files, networks, and concurrency.

---

[Next: The Standard Library →](11_standard_library.md)
