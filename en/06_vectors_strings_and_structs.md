# Vectors, Strings and Structs

[← Previous: Functions](05_functions.md) · [Contents](toc.md)

Every value in the preceding chapters has been a single number, boolean, or string. Real data rarely comes one value at a time: a week of temperature readings, the cells of a grid, the host name and port of a server. This chapter introduces the two ways Basic Next groups values. A *vector* holds a fixed number of values of one type, reached by position. A *structure*, declared with `STRUCT`, holds a fixed set of named fields, each with its own type.

Both are *value types*. Assigning a vector or a structure to another binding, or passing it to a function, copies it, so that two bindings never share the same elements. The property matters more than it may first appear: a function that receives a vector cannot change the caller's data behind its back, and a reader who sees an assignment knows that the two bindings are independent from then on. Classes, in [chapter 9](09_classes_and_interfaces.md), make the opposite choice, and the contrast between the two is one of the main ideas of Part III.

## Fixed-Size Vectors

A week of readings is a natural first example. Seven values of the same type, accessed by their position, are one vector:

```basic
FUNCTION Start() AS VOID
    LET temperatures AS FLOAT[7] = [21.5, 23.0, 19.8, 22.4, 24.1, 25.0, 20.2]
    LET warmest AS FLOAT = temperatures[0]
    FOR day AS INTEGER = 1 TO LEN(temperatures) - 1
        IF temperatures[day] > warmest THEN
            warmest = temperatures[day]
        END IF
    END FOR
    PRINT "warmest:", warmest    // warmest: 25.0
    temperatures[6] = 26.3
    PRINT temperatures[6]        // 26.3
END FUNCTION
```

The type `FLOAT[7]` reads as "seven `FLOAT`s": the element type, followed by the number of elements in brackets. The length is part of the type, so a `FLOAT[7]` and a `FLOAT[8]` are different types, and a vector never grows or shrinks. A program that needs a length known only at run time allocates a region instead, as described in [chapter 10](10_memory.md#regions-and-pointers).

Elements are numbered from `0`, so the seven readings are `temperatures[0]` through `temperatures[6]`, and the last index is always `LEN(temperatures) - 1`. An element is read and assigned with the same bracket notation. Every index is checked when the program runs, and an index outside the vector stops the program with `INDEX_OUT_OF_BOUNDS` rather than reading whatever memory happens to lie beyond it:

```
error[INDEX_OUT_OF_BOUNDS]: Index out of bounds: Index 3 is outside vector (bound: 3).
```

A vector may have more than one dimension. `INTEGER[2][3]` is two rows of three integers, written as a literal of two row literals; `grid[i][j]` is an element and `grid[i]`, with fewer indices than dimensions, is a whole row. Where the length of a local vector depends on a value computed earlier, the dimension may be an expression, evaluated once when the declaration runs. Without an initializer, every element takes the default of its type:

```basic
FUNCTION Start() AS VOID
    LET grid AS INTEGER[2][3] = [[1, 2, 3], [4, 5, 6]]
    PRINT grid[0][2], grid[1][0]    // 3 4

    LET size AS INTEGER = 4
    LET squares AS INTEGER[size]
    FOR i AS INTEGER = 0 TO size - 1
        squares[i] = i * i
    END FOR
    PRINT squares[3]                // 9
END FUNCTION
```

Expressions as dimensions are allowed only in a local `LET`. The type of a field, a parameter, or a return value states its dimensions with literals, because those types are part of a declaration that other code relies on; a negative dimension computed at run time stops the program with `INVALID_VECTOR_DIMENSION`.

### Vector Literals

A list of elements in square brackets, separated by commas, is a vector literal. Where a vector type is declared, as in every `LET` above, each element is checked against the declared element type, and the number of elements must equal the declared length:

```basic
FUNCTION Start() AS VOID
    LET primes AS INTEGER[4] = [2, 3, 5, 7]
    LET wide AS INT64[2] = [1, 3000000000]
    LET weights AS FLOAT[3] = [0.5, 0.25, 0.25]

    PRINT primes[3], wide[1], weights[0]    // 7 3000000000 0.5
    PRINT LEN([1, 2, 3])                    // 3
END FUNCTION
```

A literal written where no type is declared, such as the argument of `LEN` in the last line, takes the type of its first element, and every other element must have the same type. The language does not search for a common type that would accommodate all of them, so `[1, 2.5]` is rejected rather than silently promoted to floating point:

```
error[TYPE_MISMATCH]: Type mismatch: Expected INT32, but found FLOAT64 in vector literal element.
```

For the same reason an integer element is never converted to floating point inside a vector literal: `[1, 2]` does not fill a `FLOAT[2]`, and the literal must be written `[1.0, 2.0]`. The exception for whole numbers described in [chapter 3](03_operators_and_conversions.md#explicit-conversion) applies to a single scalar initializer only, where the value and the target are both in plain view.

### Value Semantics

Assigning a vector to another binding copies all of its elements. Afterwards the two vectors are independent, and a change to one is not visible through the other. The same holds for passing a vector to a function:

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

A parameter of vector type is a constant, like every parameter ([chapter 5](05_functions.md#parameters-are-constant)). The language specification extends the rule to its elements: assigning `values[0]` inside `FindValue` is to be rejected with `TYPE_MISMATCH`. The 0.6.10 toolchain does not yet enforce that part of the rule, and the two backends then disagree about whether the caller sees the change; treat the elements of a vector parameter as read-only. A function that produces a modified vector returns a new one.

`FindValue` accepts only vectors of exactly five integers; an `INTEGER[2]` argument is a `TYPE_MISMATCH`. A function meant for vectors of any length declares an *open* parameter, leaving the first dimension empty. The function then learns the length with `LEN`:

```basic
FUNCTION Sum(values AS INTEGER[]) AS INTEGER
    LET total AS INTEGER = 0
    FOR index AS INTEGER = 0 TO LEN(values) - 1
        total += values[index]
    END FOR
    RETURN total
END FUNCTION

FUNCTION Start() AS VOID
    LET few AS INTEGER[3] = [1, 2, 3]
    LET more AS INTEGER[5] = [10, 20, 30, 40, 50]
    PRINT Sum(few), Sum(more)    // 6 150
END FUNCTION
```

An open parameter is not copied — the function reads the caller's vector directly — which is safe precisely because the parameter is constant. Only parameters may be open; a local, a field, or a return type always states its length.

## Iterating over a Vector

The examples so far walk a vector by index, with a counted `FOR` ([chapter 4](04_control_flow.md#counted-loops-for)) from `0` to `LEN(v) - 1`. That form is needed when the loop uses the position itself, as `FindValue` does to report where it found the target. When only the elements matter, `FOR EACH` visits them in order without an index:

```basic
FUNCTION Start() AS VOID
    LET names AS STRING[3] = ["ana", "bruno", "clara"]

    FOR EACH name AS STRING IN names
        PRINT name
    END FOR
END FUNCTION
```

The loop declares its variable with a type, like a counted `FOR`, and the variable is a constant copy of the current element. Assigning to it would change nothing in the vector, so the compiler rejects the attempt instead of letting it pass unnoticed:

```
error[TYPE_MISMATCH]: Type mismatch: Expected mutable binding, but found CONST 'name' in assignment target.
```

For a vector of several dimensions, `FOR EACH` visits every element in row-major order: an `INTEGER[2][3]` yields its six integers, the first row before the second. It also walks the characters of a `STRING`, each as a `STRING` of length one. In the 0.6.10 toolchain it does not accept an open parameter, which is walked by index as `Sum` shows.

`FOR EACH` is the better choice whenever the index is not needed. It states the intent — "for every reading" — directly, and it cannot go out of bounds, because there is no index to get wrong.

## Measuring: `LEN` and `SIZEOF`

Two built-in functions measure a value. Both return an `INTEGER` and need no import, and they answer different questions.

`LEN(value)` counts items: the characters of a `STRING`, the elements of a vector — all of them, across every dimension, so that `LEN` of an `INTEGER[2][3]` is `6` — and `1` for a single number. It is the function to use for loops and indices.

`SIZEOF(value)` measures the size in bytes of the value's representation, without padding: a `BOOLEAN` is 1 byte, a `DATE` or a `TIME` is 4, a `STRING` is the length of its UTF-8 encoding, and a vector or a structure is the sum of the sizes of its elements. It is the function to use when data leaves the program, for a buffer, a file format, or a protocol.

```basic
FUNCTION Start() AS VOID
    LET grid AS INTEGER[2][3] = [[1, 2, 3], [4, 5, 6]]
    PRINT grid[1][2], LEN(grid), SIZEOF(grid)    // 6 6 24
END FUNCTION
```

Six `INTEGER`s of four bytes each occupy 24 bytes. `SIZEOF` is a compile-time error for values whose size is not fixed by their type: pointers ([chapter 10](10_memory.md)), interfaces ([chapter 9](09_classes_and_interfaces.md)), alternative types ([chapter 7](07_alternatives_and_errors.md)), and structures that contain strings.

## Strings as Sequences

[Chapter 2](02_values_types_and_variables.md#string) introduced `s[i]` and `LEN(s)` for strings. With vectors in hand, a string can be described more precisely: it behaves like a read-only vector of characters. It can be indexed and walked with `FOR` or `FOR EACH`, but never changed in place, and assigning to an index is rejected:

```
error[TYPE_MISMATCH]: Type mismatch: Expected mutable indexed value, but found STRING index in indexed assignment.
```

A program that needs a different string builds one, by concatenation with `+` or `+=` ([chapter 3](03_operators_and_conversions.md)). The `BNString` module ([chapter 11](11_standard_library.md)) adds searching, trimming, case conversion, and splitting.

## Structures (`STRUCT`)

A vector suits values that are alike and are reached by position. Many values are neither: a point has an `X` and a `Y`, a network site has a port and a name, and calling them element `0` and element `1` would hide their meaning. A `STRUCT` declares a type made of named fields, each with its own type and, optionally, a default value:

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

A field is reached with a dot, `origin.X`. A binding declared without an initializer, like `origin`, takes the default of every field. Like a vector, a structure is a value type: `LET result AS Point = p` makes a copy, so `Moved` changes its own copy and returns it, and `origin` is untouched. A function that "changes" a structure is therefore written, as here, as a function that returns a new one.

A structure is deliberately simple. It holds data and nothing else: no methods, no constructor, no static fields, and no visibility — every field is public. When a type needs to protect its data or attach behaviour to it, it is a class ([chapter 9](09_classes_and_interfaces.md)).

### Structure Literals

The last binding of the example, `corner`, is filled by a bracket literal, as a vector would be: one element per field, in the order the fields are declared. The same literal is accepted wherever a structure type is declared — a `LET` initializer, a field initializer, an argument, a `RETURN`, or an assignment. It must supply every field, even one that has a default, because a literal with a gap would be ambiguous about which field was left out:

```
error[TYPE_MISMATCH]: Type mismatch: Expected STRUCT with 2 fields, but found literal with 1 elements in STRUCT literal.
```

Because the literal is positional, reordering the fields of a structure changes the meaning of every literal of that type. That is a reason to prefer field-by-field assignment for structures with many fields, and to keep positional literals for small, stable ones such as a point.

## Destructuring

The bracket form also works in the other direction. A *destructuring* `LET` declares several bindings at once from one vector or one structure:

```basic
STRUCT Site
    port AS INTEGER = 80
    name AS STRING
END STRUCT

FUNCTION Start() AS VOID
    LET point AS INTEGER[2] = [3, 4]
    LET [x AS INTEGER, y] = point
    PRINT x, y                    // 3 4

    LET grid AS INTEGER[2][3] = [[1, 2, 3], [4, 5, 6]]
    LET [top, bottom] = grid
    PRINT top[0], bottom[2]       // 1 6

    LET site AS Site = [8080, "web"]
    LET [name, port] = site
    PRINT name, port              // web 8080
END FUNCTION
```

The two sources are split by different rules, each suited to its kind of value.

**A vector is split by position.** `x` receives `point[0]` and `y` receives `point[1]`. The number of bindings must equal the length of the first dimension, and for a vector of several dimensions each binding receives a whole row, so `top` and `bottom` are each an `INTEGER[3]`. A count that differs from a fixed length is rejected when the program is checked; when the length is known only at run time, a different count stops the program with `INDEX_OUT_OF_BOUNDS`:

```
error[TYPE_MISMATCH]: Type mismatch: Expected vector of length 2, but found 1 bindings in destructuring LET.
```

**A structure is split by name.** Each binding takes the field of the same name, so the order of the bindings is free and a subset of the fields is enough; `LET [name, port] = site` works even though the fields are declared the other way round. A binding cannot be renamed, because the name is how the field is found.

This is the one place where `LET` may omit a type. A name written without `AS`, like `y`, takes the type of the value it receives; a name written with `AS`, like `x`, must state a type that value can be assigned to. The omission is allowed here because the type is already written in the declaration of the source, one line above.

The source is evaluated once, and it must be a vector or a structure: an object, a string, or a scalar used as the source is a `TYPE_MISMATCH`, and a bracket literal never creates an object, which is always made by `NEW` ([chapter 9](09_classes_and_interfaces.md)). Destructuring exists only in a declaration. The same brackets on the left of an ordinary assignment are a syntax error, and a repeated name, or a name already declared in the function, is `DUPLICATE_NAME`:

```
error[E0101]: Syntax error: an assignment target must be an identifier, member, or index.
```

## Worked Example

The following program brings Part II together so far. It processes a batch of sensor readings stored in a vector. A reading of `-1` is a *sentinel* that marks the end of the valid data, so everything after it is ignored; readings outside the instrument's range are rejected and reported; each remaining reading is classified, and the program finally reports the mean:

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

Running it with `bni run readings.bn` prints:

```
72 normal
rejected: 118
65 normal
90 high
accepted: 3
mean: 75.66666666666667
```

Each construct has a specific role. `FOR EACH` walks the readings because the loop never needs their positions. `EXIT FOR` ends the loop at the sentinel, and `CONTINUE FOR` skips a rejected reading while keeping the rest of the loop body unindented. The two helper functions give names to the rules — what counts as out of range, which band a reading falls in — so that the loop reads as a description of the procedure rather than as a list of comparisons. The constants `END_OF_BATCH` and `UPPER_LIMIT` do the same for the two numbers the procedure depends on.

The final guard matters. If the sentinel were the first reading, `accepted` would be `0` and the mean undefined; the program says so instead of dividing by zero. When it does divide, `/` produces a `FLOAT` even though both operands are integers ([chapter 3](03_operators_and_conversions.md#arithmetic)), which is why the mean keeps its fractional part.

## Diagnostics Introduced in This Chapter

| Diagnostic | Raised when |
| --- | --- |
| `TYPE_MISMATCH` | A vector literal element or length does not match the declared type; a vector argument has the wrong length; a structure literal has fewer elements than fields; a `FOR EACH` variable or a string index is assigned; a destructuring `LET` has the wrong number of bindings. |
| `INDEX_OUT_OF_BOUNDS` | A vector or string index is outside `0` through the length minus one. |
| `INVALID_VECTOR_DIMENSION` | A dimension computed at run time is negative. |
| `DUPLICATE_NAME` | A destructuring `LET` repeats a name or reuses one already declared. |
| `E0101` | Destructuring brackets are written on the left of an ordinary assignment. |

## Summary

A vector holds a fixed number of values of one type, numbered from `0`; its length is part of its type, and every index is checked. A structure holds named fields of different types and nothing else. Both are value types: assignment and parameter passing copy them, so two bindings never share elements, and a function that changes one returns a new value. A parameter may leave a vector's length open and read it with `LEN`. `FOR EACH` visits the elements of a vector or the characters of a string when the position is not needed. `LEN` counts items and `SIZEOF` measures bytes. Bracket literals build vectors and structures, the latter by position, and a destructuring `LET` takes them apart again — a vector by position, a structure by field name.

The next chapter addresses a question that every chapter so far has avoided: what a program does when a value it expects is not there.

---

[Next: Absence, Alternatives and Errors →](07_alternatives_and_errors.md)
