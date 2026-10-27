# Absence, Alternatives and Errors

[← Previous: Vectors, Strings and Structs](06_vectors_strings_and_structs.md) · [Contents](toc.md)

Some operations cannot promise a value. Reading a line may find the end of the input, a search may find nothing, a measurement may be missing, and a call may fail. Many languages represent these cases with a value that pretends to be ordinary — `null`, `-1`, an empty string — or with an exception that jumps out of the code. Basic Next writes them into the type instead. A binding that may hold "a string or the end of input" has the type `STRING OR EOF`, and the program cannot use it as a `STRING` until it has checked which one it holds.

This chapter introduces these *alternative types*, the three markers of absence, the `IS` test that tells the members apart, and `Error`, the value a failing operation returns.

## Alternative Types

An alternative type lists its possible members joined with `OR`:

```basic
FUNCTION Start() AS VOID
    LET answer AS STRING OR EOF = ""
    LET found AS INTEGER OR NULL = NULL
    PRINT answer, found
END FUNCTION
```

A binding of alternative type has no default value: it must always be initialized in the source, because the compiler will not choose on the programmer's behalf which member the binding starts as.

```
error[TYPE_MISMATCH]: Type mismatch: Expected initializer, but found missing initializer in INT32 OR NULL binding.
```

The order of the members does not matter: `INTEGER OR NULL` and `NULL OR INTEGER` are the same type.

## `NULL`, `NA`, and `EOF`

`NULL`, `NA`, and `EOF` are literals for the three kinds of absence: no value, a missing data point, and the end of an input stream. Each is valid only where the declared type includes it as an alternative:

```basic
FUNCTION Start() AS VOID
    LET found AS INTEGER OR NULL = NULL
    LET reading AS FLOAT OR NA = NA
    LET line AS STRING OR EOF = EOF
    LET ok AS BOOLEAN = TRUE

    PRINT found IS NULL, reading IS NA, line IS EOF, ok    // TRUE TRUE TRUE TRUE
    PRINT found, reading, line                              // NULL NA EOF
END FUNCTION
```

Each marker has its own meaning, and choosing the right one documents the program:

* `NULL` is the absence of a value: a search that found nothing, an object reference not yet set.
* `NA` is a missing observation in data: a sensor reading that was not taken, an empty cell in a table.
* `EOF` is the end of an input stream.

They are not numbers, and a `CONST` that holds one must state its type.

### Numeric Literals in Alternative Types

When a numeric literal is stored in a binding whose type is an alternative, it takes exactly one member: its default type (`INT32` or `FLOAT64`) when that is a member, otherwise the only member of its kind (integer or floating point). If neither rule picks one member, the store is a `TYPE_MISMATCH`, and the width must be written with `AS`:

```basic
FUNCTION Start() AS VOID
    LET a AS FLOAT32 OR FLOAT64 = 1.5
    LET c AS INT64 OR Error = 9
    LET d AS FLOAT32 OR INT32 = 1.5
    PRINT a IS FLOAT64, c IS INT64, d IS FLOAT32    // TRUE TRUE TRUE
END FUNCTION
```

`LET e AS INT8 OR INT16 = 1` is rejected; `LET e AS INT8 OR INT16 = 1 AS INT16` is not.

## Testing and Narrowing with `IS`

A value of alternative type cannot be used where one specific member is required. Arithmetic on an `INTEGER OR NULL` is rejected, because the value might be `NULL`:

```
error[TYPE_MISMATCH]: Type mismatch: Expected operands accepted by Plus, but found INT32 OR NULL and INT32 in binary operator Plus.
```

`value IS T` is a `BOOLEAN` test of which member the value currently holds. Inside an `IF` whose condition is an `IS` test, the compiler *narrows* the binding: in the branch where the test is `TRUE`, the value has type `T`, and in the `ELSE` branch it has the remaining members.

```basic
FUNCTION IndexOf(values AS INTEGER[5], target AS INTEGER) AS INTEGER OR NULL
    FOR index AS INTEGER = 0 TO LEN(values) - 1
        IF values[index] = target THEN
            RETURN index
        END IF
    END FOR
    RETURN NULL
END FUNCTION

FUNCTION Start() AS VOID
    LET primes AS INTEGER[5] = [2, 3, 5, 7, 11]
    LET position AS INTEGER OR NULL = IndexOf(primes, 7)
    IF position IS NULL THEN
        PRINT "not found"
    ELSE
        PRINT "found at", position + 1    // found at 4
    END IF
    PRINT IndexOf(primes, 4)              // NULL
END FUNCTION
```

In the `ELSE` branch, `position` cannot be `NULL`, so it is an `INTEGER` and `position + 1` is accepted. `IndexOf` states in its signature that it may find nothing, which is more honest than returning `-1` and hoping every caller remembers to check.

### Narrowing After a Guard

A guard clause ([chapter 5](05_functions.md)) narrows the rest of the block. When every branch of an `IF` without `ELSE` ends with `RETURN` or `STOP`, the code after it can only be reached by the other members:

```basic
FUNCTION ProcessInput(line AS STRING OR EOF) AS VOID
    IF line IS EOF THEN
        PRINT "end of input reached"
        RETURN
    END IF

    // In the lines below, line is narrowed to STRING:
    PRINT "received characters:", LEN(line)
END FUNCTION
```

If the guard does not end the function, the type remains an alternative, and `LEN(line)` is rejected.

### What Does Not Narrow

Only an `IS` test narrows, as an `if let` or `guard let` unwraps an optional in Swift. Neither the initial value of a `LET` nor an assignment narrows: after `LET score AS INTEGER OR NULL = 5`, the variable is still an `INTEGER OR NULL`, and arithmetic on it is rejected with the `TYPE_MISMATCH` shown above.

Inside the narrowed branch, an assignment reads the narrowed value and then ends the narrowing from that point. The same holds when the assignment happens in a nested block, such as a loop body, whether or not that block runs:

```basic
FUNCTION Start() AS VOID
    LET score AS INTEGER OR NULL = 5
    IF score IS INTEGER THEN
        score = score + 1    // reads the narrowed INTEGER, stores into INTEGER OR NULL
        PRINT score          // 6
    END IF
END FUNCTION
```

`IS` also tests floating-point values: `x IS NAN`, `x IS INF`, and `x IS -INF` ([chapter 2](02_values_types_and_variables.md#numeric-types)).

## Reading Input

Standard input can end at any time, so reading a line returns `STRING OR EOF` rather than a `STRING`. The expression form `INPUT()` reads one line:

```basic
FUNCTION Start() AS VOID
    LET line AS STRING OR EOF = INPUT()
    IF line IS EOF THEN
        PRINT "End of input stream."
        RETURN
    END IF
    PRINT "got:", line
END FUNCTION
```

Run with `echo hello | bni run program.bn`, it prints `got: hello`; with no input at all, it prints `End of input stream.`

The statement form writes a prompt and stores the result in an existing binding, which must already be declared and initialized, because its type is an alternative:

```basic
FUNCTION Start() AS VOID
    LET x AS STRING OR EOF = ""

    INPUT "Enter value for X: ", x
    IF x IS EOF THEN
        RETURN
    END IF
    PRINT "x =", x
END FUNCTION
```

A `REPEAT` loop fits input that must be asked again until it is valid. The function below returns `"n"` when input ends, so its caller always receives a `STRING`:

```basic
FUNCTION PromptChoice() AS STRING
    LET answer AS STRING OR EOF = ""
    LET valid AS BOOLEAN = FALSE

    REPEAT
        INPUT "Continue? (y/n): ", answer
        IF answer IS EOF THEN
            RETURN "n"
        END IF
        valid = (answer = "y") OR (answer = "n")
        IF NOT valid THEN
            PRINT "Please answer y or n."
        END IF
    UNTIL valid
    END REPEAT

    RETURN answer
END FUNCTION
```

## Errors

Basic Next has no exceptions. An operation that can fail returns its result or an `Error`, and says so in its type: `INTEGER OR Error`, `STRING OR Error`. The caller cannot reach the result without first handling the error, so an unhandled failure is a compile-time error rather than a crash at run time.

`ASC(text)` from [chapter 2](02_values_types_and_variables.md#string) is such an operation: it fails on an empty string, which has no first character. A function that calls it can handle the error or pass it on to its own caller by returning it:

```basic
FUNCTION DigitValue(text AS STRING) AS INTEGER OR Error
    LET code AS INTEGER OR Error = ASC(text)
    IF code IS Error THEN
        RETURN code
    END IF
    RETURN code - 48
END FUNCTION

FUNCTION Start() AS VOID
    LET seven AS INTEGER OR Error = DigitValue("7")
    LET nothing AS INTEGER OR Error = DigitValue("")
    IF seven IS INTEGER THEN
        PRINT seven * 2                         // 14
    END IF
    IF nothing IS Error THEN
        PRINT nothing.Code, nothing.Message     // 1 ASC requires a non-empty STRING
    END IF
END FUNCTION
```

After the guard, `code` is an `INTEGER`, so `code - 48` is accepted. In the error branch, `RETURN code` hands the same `Error` to the caller; the return type `INTEGER OR Error` says that it may.

An `Error` carries four read-only fields:

| Field | Type | Contents |
| --- | --- | --- |
| `Code` | `INTEGER` | A constant published by the module or capability that owns the operation, such as `FS.NOT_FOUND`. |
| `Operation` | `STRING` | The name of the operation that failed. |
| `Message` | `STRING` | What failed. |
| `Cause` | `STRING` | Why it failed: the rule, the policy, or the operating-system error. |

A program receives an `Error` but never constructs one: there is no `NEW Error`, and a class cannot extend it. For the same reason an `Error` has no default value, and a binding of type `Error` needs an initializer that is an `Error` the program received. Compare an error's `Code` with the constants of its module rather than with a number; the constants are listed with each capability in Part IV and in the appendices.

### Producing Control Characters

`CHAR(code)` returns `STRING OR Error`, which matters in practice: there is no `\n` or `\t` escape in a string literal, so a newline or a tab is produced with `CHAR` and narrowed before use:

```basic
FUNCTION Start() AS VOID
    LET nl AS STRING OR Error = CHAR(10)
    LET tab AS STRING OR Error = CHAR(9)
    IF nl IS Error THEN
        RETURN
    END IF
    IF tab IS Error THEN
        RETURN
    END IF
    PRINT "first" + nl + "second"
    PRINT "a" + tab + "b"
END FUNCTION
```

```
first
second
a	b
```

When the goal is simply to end a line, use a second `PRINT`, which already writes the newline. Keep the control characters in named bindings created once, as above, rather than calling `CHAR` in the middle of an expression.

## Diagnostics Introduced in This Chapter

| Diagnostic | Raised when |
| --- | --- |
| `TYPE_MISMATCH` | A binding of alternative type has no initializer; a value of alternative type is used where one member is required; a numeric literal matches no single member of an alternative. |

## Summary

* An alternative type such as `STRING OR EOF` writes "this value may be one of several things" into the type.
* `NULL`, `NA`, and `EOF` are three distinct markers of absence.
* `IS` tests the member a value holds and narrows the binding inside the branch, or after a guard that returns.
* Only an `IS` test narrows; neither an initializer nor an assignment does.
* `INPUT` returns `STRING OR EOF` because input can end.
* A failing operation returns `T OR Error`; the program handles the `Error` or returns it to its caller.

---

[Next: Modules →](08_modules.md)
