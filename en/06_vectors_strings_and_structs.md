# Vectors, Strings and Structs

[← Previous: Functions](05_functions.md) · [Contents](toc.md)

The values so far have been single numbers, booleans, and strings. This chapter groups them: a vector holds a fixed number of values of one type, and a `STRUCT` holds named fields of different types. Both are *value types* — assigning one or passing it to a function copies it — and both can be split back into separate bindings with a destructuring `LET`.

## Fixed-Size Vectors

A fixed-size vector stores multiple values of the same type sequentially. Vectors are defined by an element type followed by one or more dimensions inside brackets.

```basic
LET dimensions AS INTEGER[3] = [10, 20, 30]
LET grid AS INTEGER[2][3] = [[1, 2, 3], [4, 5, 6]]
```

For function signatures, fields, and parameters, each dimension must be a non-negative integer literal. Local `LET` bindings, however, can use declaration-time vector dimensions that are evaluated once at binding time:

```basic
LET n AS INTEGER = 4
LET values AS INTEGER[n] = [1, 2, 3, 4]
```

Indices are zero-based, running from `0` to one less than the dimension. Accessing an index outside this range raises an `INDEX_OUT_OF_BOUNDS` runtime error.

If you declare a vector without an initializer, each element is automatically assigned its type's default value:

```basic
LET values AS INTEGER[5]  // A vector of five 0s
values[2] = 42
```

### Vector Literals

Elements in square brackets, separated by commas, form a vector literal. Where a vector type is declared, each element is checked against the declared element type and the number of elements must match the declared length:

```basic
FUNCTION Start() AS VOID
    LET primes AS INTEGER[4] = [2, 3, 5, 7]
    LET wide AS INT64[2] = [1, 3000000000]
    LET weights AS FLOAT[3] = [0.5, 0.25, 0.25]

    PRINT primes[3], wide[1], weights[0]    // 7 3000000000 0.5
    PRINT LEN([1, 2, 3])                    // 3
END FUNCTION
```

Without a declared destination, as in the last line, the element type is that of the first element, and every other element must match it. `[1, 2.5]` is therefore rejected rather than promoted:

```
error[TYPE_MISMATCH]: Type mismatch: Expected INT32, but found FLOAT64 in vector literal element.
```

An integer element is not converted to floating point inside a vector literal either: `[1, 2]` does not fill a `FLOAT[2]`; write `[1.0, 2.0]`. The exception for whole numbers described in [chapter 3](03_operators_and_conversions.md#explicit-conversion) covers a single scalar initializer only.

### Value Semantics

Vectors have value semantics for assignment and parameter passing. Assigning a vector to a new variable copies all of its elements; the new vector does not alias the old one, and modifying one does not affect the other:

```basic
FUNCTION FindValue(values AS INTEGER[5], target AS INTEGER) AS INTEGER
    FOR index AS INTEGER = 0 TO LEN(values) - 1
        IF values[index] = target THEN
            RETURN index
        END IF
    END FOR
    RETURN -1
END FUNCTION

FUNCTION Start() AS VOID
    LET primes AS INTEGER[5] = [2, 3, 5, 7, 11]
    LET copy AS INTEGER[5] = primes
    copy[0] = 99
    PRINT primes[0], copy[0]                          // 2 99
    PRINT FindValue(primes, 7), FindValue(primes, 4)  // 3 -1
END FUNCTION
```

A parameter of vector type states its length, `INTEGER[5]`, and the argument must have that length. Inside the function the vector is a copy, and, as with every parameter, it is constant.

## Iterating over a Vector

A counted `FOR` ([chapter 4](04_control_flow.md)) walks a vector by index. Because indices are zero-based, the last element is at `LEN(names) - 1`:

```basic
FUNCTION Start() AS VOID
    LET names AS STRING[3] = ["ana", "bruno", "clara"]

    FOR index AS INTEGER = 0 TO LEN(names) - 1
        PRINT index, names[index]
    END FOR
END FUNCTION
```

### `FOR EACH`

`FOR EACH` visits every element in order, without an index:

```basic
LET names AS STRING[3] = ["ana", "bruno", "clara"]

FOR EACH name AS STRING IN names
    PRINT name
END FOR
```

The loop variable is read-only. Modifying it is rejected by the compiler:

```
error[TYPE_MISMATCH]: Type mismatch: Expected mutable binding, but found CONST 'name' in assignment target.
```

Prefer `FOR EACH` whenever the loop does not require the element's index. It avoids index bounds errors and simplifies traversal.

`FOR EACH` also walks the characters of a `STRING`, one `STRING` of length one at a time.

## Measuring: `LEN` and `SIZEOF`

Two built-in functions measure a value. Both return an `INTEGER`, and neither needs an import.

`LEN(value)` is the logical count of items: the number of characters of a `STRING`, the total number of elements of a vector across all its dimensions, and `1` for a single number.

`SIZEOF(value)` is the portable byte size of the value's representation, with no padding: `BOOLEAN` is 1 byte, `DATE` and `TIME` are 4, a `STRING` is the length of its UTF-8 encoding, and a vector or a `STRUCT` is the sum of the sizes of its elements.

```basic
FUNCTION Start() AS VOID
    LET grid AS INTEGER[2][3] = [[1, 2, 3], [4, 5, 6]]
    PRINT grid[1][2], LEN(grid), SIZEOF(grid)    // 6 6 24
END FUNCTION
```

`SIZEOF` is a compile-time error for values whose size is not fixed by their type: pointers ([chapter 10](10_memory.md)), interfaces ([chapter 9](09_classes_and_interfaces.md)), alternative types ([chapter 7](07_alternatives_and_errors.md)), and structs containing strings.

## Strings as Sequences

[Chapter 2](02_values_types_and_variables.md#string) introduced `s[i]` and `LEN(s)`. A string behaves like a read-only vector of characters: it can be indexed and walked with `FOR` or `FOR EACH`, but never changed in place. Assigning to an index is rejected:

```
error[TYPE_MISMATCH]: Type mismatch: Expected mutable indexed value, but found STRING index in indexed assignment.
```

To build a different string, concatenate with `+` or `+=` ([chapter 3](03_operators_and_conversions.md)). The `BNString` module ([chapter 11](11_standard_library.md)) adds searching, trimming, case conversion, and splitting.

## Value Types (`STRUCT`)

A `STRUCT` declares a small, composite value type with named fields. Structs cannot contain methods, static fields, constructors, or visibility modifiers (all fields are implicitly public).

```basic
STRUCT Point
    X AS FLOAT = 0.0
    Y AS FLOAT = 0.0
END STRUCT

LET origin AS Point
LET moved AS Point = origin
moved.X = 10.0
```

Like vectors, structs have value semantics. Assignment or parameter passing creates a complete copy of the field values. Changing `moved.X` in the example above does not affect `origin.X`, and a function that "changes" a struct returns a new one:

```basic
STRUCT Point
    X AS FLOAT = 0.0
    Y AS FLOAT = 0.0
END STRUCT

FUNCTION Moved(p AS Point, dx AS FLOAT) AS Point
    LET result AS Point = p
    result.X += dx
    RETURN result
END FUNCTION

FUNCTION Start() AS VOID
    LET origin AS Point
    LET moved AS Point = Moved(origin, 10.0)
    PRINT origin.X, moved.X    // 0.0 10.0
    LET corner AS Point = [3.0, 4.0]
    PRINT corner.X, corner.Y   // 3.0 4.0
END FUNCTION
```

The last binding is filled by a bracket literal, as a vector would be: one element per field, in declaration order. The rules of that form are given with destructuring below.

## Destructuring a vector or a `STRUCT`

One `LET` can declare several bindings from a single vector or a single `STRUCT`. The source is evaluated once, and the new names are not in scope inside it.

```basic
LET point AS INTEGER[2] = [3, 4]
LET [x AS INTEGER, y] = point
PRINT x, y
LET grid AS INTEGER[2][3] = [[1, 2, 3], [4, 5, 6]]
LET [top, bottom] = grid
PRINT top[0], bottom[2]
```

`x` is declared `INTEGER`. `y` omits `AS` and takes the type of `point[1]`, which is also `INTEGER`. For a vector of more than one dimension, each binding receives a row: `top` and `bottom` are `INTEGER[3]`. A name written with `AS` must be a type the value can be assigned to.

The number of bindings must equal the length of the first dimension. A fixed vector of another length is rejected when the program is checked:

```basic
LET [a] = point
```

```
error[TYPE_MISMATCH]: Type mismatch: Expected vector of length 2, but found 1 bindings in destructuring LET.
```

When the length is known only at run time, a different count stops the program with `INDEX_OUT_OF_BOUNDS`.

A `STRUCT` is split by field name, in any order, and a subset of the fields is enough. The binding's name is the field's name. There is no renaming.

```basic
STRUCT Site
    port AS INTEGER = 80
    name AS STRING
END STRUCT

LET site AS Site = [10, "web"]
LET [name, port] = site
PRINT name, port
```

`[10, "web"]` fills `Site` by declaration order: the first element is `port`, the second is `name`. The same bracket literal is accepted wherever a `STRUCT` type is declared — a `LET` initializer, a field initializer, an argument, a `RETURN`, or an assignment. It needs one element for every field. A shorter literal is a `TYPE_MISMATCH`; a field's default does not fill the gap. Reordering the fields changes what the literal means. Destructuring, which uses the names, does not.

A bracket literal never makes an object. Objects ([chapter 9](09_classes_and_interfaces.md)) are made by `NEW` and their constructor, and they are read field by field. An object, a `STRING`, or a scalar used as the source of a destructuring `LET` is a `TYPE_MISMATCH`.

Destructuring exists only in `LET`. The same brackets on the left of an ordinary assignment are a syntax error:

```basic
[x, y] = point
```

```
error[E0101]: Syntax error: an assignment target must be an identifier, member, or index.
```

A repeated name, or a name already declared in the function, is `DUPLICATE_NAME`.

## Worked Example

The following program processes a vector of sensor readings, stops at a sentinel value (`-1`), rejects out-of-range readings, classifies valid measurements, and calculates the average:

```basic
FUNCTION IsOutOfRange(reading AS INTEGER, upperLimit AS INTEGER) AS BOOLEAN
    RETURN reading < 0 OR reading > upperLimit
END FUNCTION

FUNCTION Band(reading AS INTEGER) AS STRING
    IF reading >= 90 THEN
        RETURN "high"
    ELSE IF reading >= 60 THEN
        RETURN "normal"
    END IF
    RETURN "low"
END FUNCTION

FUNCTION Start() AS VOID
    CONST END_OF_BATCH AS INTEGER = -1
    CONST UPPER_LIMIT AS INTEGER = 100

    LET readings AS INTEGER[8] = [72, 118, 65, 90, -1, 55, 80, 40]
    LET accepted AS INTEGER = 0
    LET total AS INTEGER = 0

    FOR EACH reading AS INTEGER IN readings
        IF reading = END_OF_BATCH THEN
            EXIT FOR
        END IF
        IF IsOutOfRange(reading, UPPER_LIMIT) THEN
            PRINT "rejected:", reading
            CONTINUE FOR
        END IF
        PRINT reading, Band(reading)
        total += reading
        accepted++
    END FOR

    IF accepted = 0 THEN
        PRINT "no usable readings"
        RETURN
    END IF

    PRINT "accepted:", accepted
    PRINT "mean:", total / accepted
END FUNCTION
```

Executing this program with `bni run readings.bn` outputs:

```
72 normal
rejected: 118
65 normal
90 high
accepted: 3
mean: 75.66666666666667
```

Division with `/` performs floating-point division and returns a `FLOAT`. Checking `IF accepted = 0 THEN` prevents potential division by zero when the sentinel appears at the start of the collection.

The program combines the chapters so far: `FOR EACH` walks the vector, `EXIT FOR` stops at the sentinel, `CONTINUE FOR` skips a rejected reading, and the helper functions keep the loop body short.

## Diagnostics Introduced in This Chapter

| Diagnostic | Raised when |
| --- | --- |
| `TYPE_MISMATCH` | A vector literal element or length does not match the declared type; a `STRUCT` literal has fewer elements than fields; a `FOR EACH` variable or a string index is assigned; a destructuring `LET` has the wrong number of bindings. |
| `INDEX_OUT_OF_BOUNDS` | A vector or string index is outside `0` through the length minus one. |
| `DUPLICATE_NAME` | A destructuring `LET` repeats a name or reuses one already declared. |
| `E0101` | Destructuring brackets are written on the left of an ordinary assignment. |

## Summary

* A vector holds a fixed number of values of one type; indices start at `0`.
* Vectors and structs are value types: assignment and parameter passing copy them.
* `FOR EACH` visits every element; `LEN` counts elements and `SIZEOF` measures bytes.
* A string is a read-only sequence of characters.
* A `STRUCT` groups named fields; a bracket literal fills it in declaration order.
* A destructuring `LET` splits a vector by position or a `STRUCT` by field name.

---

[Next: Absence, Alternatives and Errors →](07_alternatives_and_errors.md)
