# Functions

[← Previous: Control Flow](04_control_flow.md) · [Contents](toc.md)

Every program so far has been one function, `Start`. This chapter writes others: functions that take parameters, return a value, stop early when a check fails, and are passed around as values. The language requires each signature to be written in full and verifies at compile time that every path of a function that returns a value does return one.

## Function Declarations

A function is declared with `FUNCTION`, its name, its parameter list, `AS`, and its return type. The block closes with `END FUNCTION`. Each parameter is written like a binding, with its name, `AS`, and its type:

```basic
FUNCTION Add(a AS INTEGER, b AS INTEGER) AS INTEGER
    RETURN a + b
END FUNCTION

FUNCTION LogMessage(message AS STRING) AS VOID
    IF message = "" THEN
        RETURN
    END IF
    PRINT message
END FUNCTION

FUNCTION Start() AS VOID
    LET sum AS INTEGER = Add(2, 3)
    LogMessage("sum is " + (sum AS STRING))    // sum is 5
    LogMessage("")                              // prints nothing
END FUNCTION
```

`RETURN` followed by an expression ends the function and hands the value to the caller. A function that returns nothing declares `VOID`; it may omit `RETURN` entirely, or use a bare `RETURN` to leave early, as `LogMessage` does.

A call must match the declaration: the same number of arguments, each of the declared type. There is no implicit conversion at a call, just as there is none in an assignment:

```
error[TYPE_MISMATCH]: Type mismatch: Expected INT32, but found STRING in function parameter.
error[TYPE_MISMATCH]: Type mismatch: Expected 1 argument(s), but found 2 argument(s) in function call.
```

Functions are declared at the top level of a file, side by side with `Start`, and may be declared in any order: `Start` can call a function written below it. A function may also call itself:

```basic
FUNCTION Factorial(n AS INT64) AS INT64
    IF n <= 1 THEN
        RETURN 1
    END IF
    RETURN n * Factorial(n - 1)
END FUNCTION

FUNCTION Start() AS VOID
    PRINT Factorial(20)    // 2432902008176640000
END FUNCTION
```

## Parameters Are Constant

A parameter is a constant binding: the function reads it but cannot assign a new value to it. When the function needs a value that changes, it declares a local:

```basic
FUNCTION Twice(n AS INTEGER) AS INTEGER
    LET doubled AS INTEGER = n * 2    // a local for the changing value
    RETURN doubled
END FUNCTION
```

Writing `n = n * 2` inside `Twice` is rejected:

```
error[TYPE_MISMATCH]: Type mismatch: Expected mutable binding, but found parameter 'n' (parameters are constant) in assignment target.
```

The rule means a reader never has to ask whether a parameter still holds what the caller passed. For objects, it has a further consequence for memory, described in [chapter 10](10_memory.md).

## Guard Clauses Instead of Nesting

Validating several preconditions with nested `IF` statements pushes the real work to the right and buries it:

```basic
LET total AS FLOAT = 100.0
LET isMember AS BOOLEAN = TRUE
LET coupon AS STRING = "SAVE10"
LET discount AS FLOAT = 0.0

IF total > 0.0 THEN
    IF isMember THEN
        IF coupon <> "" THEN
            discount = total * 0.15
        ELSE
            discount = total * 0.05
        END IF
    END IF
END IF
```

The preferred pattern is to handle invalid conditions or special cases early using guard clauses, keeping the primary logic unindented:

```basic
FUNCTION CalculateDiscount(total AS FLOAT, isMember AS BOOLEAN, coupon AS STRING) AS FLOAT
    IF total <= 0.0 THEN
        RETURN 0.0
    END IF
    IF NOT isMember THEN
        RETURN 0.0
    END IF
    IF coupon = "" THEN
        RETURN total * 0.05
    END IF

    RETURN total * 0.15
END FUNCTION
```

Early exits with `RETURN` keep error handling close to the checks and eliminate deeply nested `END IF` statements.

Called with different arguments:

<!-- bn-check: skip continues the CalculateDiscount function above -->
```basic
FUNCTION Start() AS VOID
    PRINT CalculateDiscount(100.0, TRUE, "SAVE10")    // 15.0
    PRINT CalculateDiscount(100.0, TRUE, "")          // 5.0
    PRINT CalculateDiscount(100.0, FALSE, "SAVE10")   // 0.0
END FUNCTION
```

## Return Analysis

For every function whose return type is not `VOID`, the compiler verifies that *every* path ends with a `RETURN` of a value (or a `STOP`). A path that could reach `END FUNCTION` without one is rejected:

```
error[MISSING_RETURN]: Missing return: non-VOID FUNCTION can complete without RETURN expression
```

The analysis does not assume that a loop body runs, even once. A `RETURN` inside a loop does not satisfy the rule on its own, because the loop might not find what it looks for:

```basic
FUNCTION FirstMultiple(n AS INTEGER, limit AS INTEGER) AS INTEGER
    FOR candidate AS INTEGER = 1 TO limit
        IF candidate % n = 0 THEN
            RETURN candidate
        END IF
    END FOR
END FUNCTION
```

This function is rejected with `MISSING_RETURN`. A `RETURN` after the loop states what happens when the search fails. That is also the clearer way to leave nested loops early — return as soon as the answer is found:

```basic
FUNCTION SmallestDivisor(n AS INTEGER) AS INTEGER
    FOR candidate AS INTEGER = 2 TO n - 1
        IF n % candidate = 0 THEN
            RETURN candidate
        END IF
    END FOR
    RETURN n
END FUNCTION

FUNCTION Start() AS VOID
    PRINT SmallestDivisor(91), SmallestDivisor(13)    // 7 13
END FUNCTION
```

A `VOID` function, conversely, may not return a value: `RETURN 1` in one is a `TYPE_MISMATCH`.

## The Exit Status of `Start`

`Start` may return `VOID`, in which case the program exits with status `0`, or `INTEGER`, in which case the value it returns, from `0` to `255`, is the exit status of the process:

```basic
FUNCTION Start() AS INTEGER
    CONST EXIT_USAGE = 64
    LET argumentsValid AS BOOLEAN = FALSE
    IF NOT argumentsValid THEN
        PRINT "usage: tool FILE"
        RETURN EXIT_USAGE
    END IF
    RETURN 0
END FUNCTION
```

The program prints the usage line and exits with status `64`. Returning a status from `Start` is the ordinary way to report failure to the shell; `STOP` ([chapter 4](04_control_flow.md)) is for ending the program from deep inside other functions.

## Function Values

A function can be stored in a variable or passed as an argument. The type of a function value is written `FUNCTION(parameter-types) AS return-type`:

```basic
FUNCTION Double(value AS INTEGER) AS INTEGER
    RETURN value * 2
END FUNCTION

FUNCTION Square(value AS INTEGER) AS INTEGER
    RETURN value * value
END FUNCTION

FUNCTION ApplyTwice(transform AS FUNCTION(INTEGER) AS INTEGER, value AS INTEGER) AS INTEGER
    RETURN transform(transform(value))
END FUNCTION

FUNCTION Start() AS VOID
    LET transform AS FUNCTION(INTEGER) AS INTEGER = Double
    PRINT transform(21)                 // 42
    PRINT ApplyTwice(Square, 3)         // 81
    PRINT ApplyTwice(Double, 3)         // 12
END FUNCTION
```

Only functions declared at the top level of a file (and the `STATIC` methods of classes, [chapter 9](09_classes_and_interfaces.md)) can be used as values. There are no lambdas or closures: a function value never captures local variables.

## Diagnostics Introduced in This Chapter

| Diagnostic | Raised when |
| --- | --- |
| `TYPE_MISMATCH` | An argument has the wrong type or the call has the wrong number of arguments; a parameter is assigned; a `VOID` function returns a value. |
| `MISSING_RETURN` | A non-`VOID` function has a path that reaches `END FUNCTION` without `RETURN`. |
| `NAME_NOT_FOUND` | A call names a function that is not declared. |

## Summary

* A function states every parameter type and its return type; `VOID` means it returns nothing.
* Parameters are constant; a changing value lives in a local.
* Guard clauses reject special cases at the top and keep the main path unindented.
* Every path of a non-`VOID` function must return, and the compiler does not assume a loop runs.
* `Start` may return an `INTEGER` exit status.
* Top-level functions are values of type `FUNCTION(...) AS ...`; there are no closures.

---

[Next: Vectors, Strings and Structs →](06_vectors_strings_and_structs.md)
