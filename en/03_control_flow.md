# Control Flow

[← Previous: Common Programming Concepts](02_common_programming_concepts.md) · [Contents](toc.md)

A program whose statements run once, in written order, can only compute a fixed formula. Useful software must choose between alternatives and repeat work until a condition holds.

Basic Next takes a strict and explicit approach to control flow:

* Every construct opens with a keyword and closes with an explicit `END`.
* Every condition must evaluate to a `BOOLEAN`.
* Every loop exit or continuation explicitly names the kind of loop it affects.

These rules ensure that the control structure of a program is immediately visible without relying on indentation rules, and common logic defects are caught at compile time.

## Conditions Are Boolean

A condition in Basic Next must have the static type `BOOLEAN`. Integers, strings, pointers, and object references are never implicitly treated as true or false.

The compiler rejects truthy or falsy checks:

```basic
LET pending AS INTEGER = 0

IF pending THEN
    PRINT "work remains"
END IF
```

```
error[TYPE_MISMATCH]: Type mismatch: Expected BOOLEAN, but found INTEGER(INT32) in condition.
```

The comparison must be stated explicitly:

```basic
IF pending > 0 THEN
    PRINT "work remains"
END IF
```

Requiring an explicit `BOOLEAN` eliminates ambiguities common in languages where `0`, `""`, or `NULL` might be interpreted as false, ensuring the programmer's threshold is clearly documented in the code.

When a condition represents domain logic rather than a simple comparison, encapsulate it in a descriptive helper:

```basic
LET reading AS INTEGER = 105
LET upperLimit AS INTEGER = 100

LET isOutOfRange AS BOOLEAN = (reading < 0) OR (reading > upperLimit)
IF isOutOfRange THEN
    PRINT "measurement invalid"
END IF
```

## The Block `IF`

The standard form of `IF` evaluates a condition, executes the corresponding block, and closes with `END IF`. Additional branches are chained using `ELSE IF` (written as two separate words), and a fallback branch uses `ELSE`:

```basic
LET score AS INTEGER = 85

IF score >= 90 THEN
    PRINT "Grade: A"
ELSE IF score >= 80 THEN
    PRINT "Grade: B"
ELSE
    PRINT "Grade: C"
END IF
```

Branches are evaluated sequentially from top to bottom. The first condition that evaluates to `TRUE` runs, and all subsequent branches are skipped. Conditions must be ordered from most specific to least specific.

The `ELSE` branch is optional. When no action is needed if all conditions fail, omit the `ELSE` clause rather than leaving an empty block.

## The Single-Line `IF`

When a conditional branch consists of only a single simple statement, it can be written entirely on one line without `END IF`:

```basic
IF retries > 3 THEN PRINT "giving up" ELSE PRINT "retrying"
```

This form is restricted by design:

* Each branch admits only one simple statement (such as an assignment, `PRINT`, `RETURN`, `STOP`, `EXIT`, or `CONTINUE`).
* Compound statements, such as loops or nested `IF` statements, are forbidden.
* The entire construct must reside on a single physical line.

Attempting to add `END IF` to a single-line statement causes a syntax error, because the statement is already closed at the end of the line:

```basic
IF active THEN PRINT "running" END IF
```

```
error[E0100]: Syntax error: Expected newline or end of file after single-line IF statement
```

Use the single-line form for simple guards. If a branch requires more than one statement, use the block `IF ... END IF` form.

## Guard Clauses Instead of Nesting

Validating multiple preconditions using deeply nested `IF` statements creates complex code:

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

## Narrowing Alternative Types with `IS`

Basic Next allows variables to hold alternative types, such as `STRING OR EOF` or `INTEGER OR NULL`. A value cannot be used as a specific member type until the other alternatives are eliminated.

The `IS` operator checks the runtime variant of an alternative type. When a guard branch terminates the flow (with `RETURN` or `STOP`), the compiler narrows the variable to the remaining type in subsequent lines:

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

If the guard does not terminate execution, the type remains an alternative, and attempting to call `LEN(line)` will fail compilation.

## Pre-Condition Loops: `WHILE`

A `WHILE` loop checks its condition before every iteration, including the first. If the condition is initially `FALSE`, the body never executes:

```basic
LET remaining AS INTEGER = 5
LET sum AS INTEGER = 0

WHILE remaining > 0
    sum += remaining
    remaining--
END WHILE

PRINT sum    // 15
```

### Increment and Decrement Operators

Basic Next supports increment (`++`) and decrement (`--`) operators:

* As standalone statements, `x++` and `++x` increment `x` by 1.
* In expressions, prefix forms (`++x`, `--x`) update the variable and return the **new** value.
* In expressions, postfix forms (`x++`, `x--`) update the variable and return the **previous** value.

```basic
LET i AS INTEGER = 100
PRINT ++i        // 101 (i is incremented to 101, then printed)
PRINT i++        // 101 (current value printed, i becomes 102)
PRINT i          // 102
```

The operand must be an assignable target (such as a variable or array element). Chaining operators like `i++++` is a syntax error.

In any `WHILE` loop, ensure that each iteration modifies state toward the termination condition.

## Post-Condition Loops: `REPEAT ... UNTIL`

A `REPEAT` loop executes its body first, then evaluates the condition after `UNTIL`. The loop continues while the condition is `FALSE` and terminates when it evaluates to `TRUE`. The block closes with `END REPEAT`:

```basic
LET count AS INTEGER = 0

REPEAT
    count++
    PRINT "iteration:", count
UNTIL count >= 3
END REPEAT
```

Use `REPEAT ... UNTIL` when the operation must execute at least once before the condition can be checked, such as reading user input until a valid response is given:

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

Unlike `WHILE`, which checks a continuation condition, `UNTIL` specifies the termination condition.

## Counted Loops: `FOR`

A counted `FOR` loop declares its counter variable and integer type in the header, running from the start value through the end value inclusively:

```basic
FOR i AS INTEGER = 0 TO 8 STEP 2
    PRINT i    // 0 2 4 6 8
END FOR
```

* `STEP` defaults to `1` when omitted.
* `STEP 0` is rejected at compile time with `TYPE_MISMATCH`.
* Negative step values count downwards (`FOR i AS INTEGER = 5 TO 1 STEP -2` visits 5, 3, and 1).
* If the starting value is past the ending value in the direction of the step, the loop body does not execute.

When traversing indexed collections such as vectors:

```basic
LET names AS STRING[3] = ["ana", "bruno", "clara"]

FOR index AS INTEGER = 0 TO LEN(names) - 1
    PRINT index, names[index]
END FOR
```

Because indices are zero-based, the final element is at index `LEN(names) - 1`.

Avoid modifying the loop variable inside a `FOR` loop body. If the iteration count depends on dynamic runtime conditions, use a `WHILE` loop instead.

## Collection Iteration: `FOR EACH`

`FOR EACH` iterates over every element in a fixed-size collection in sequence:

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

## Loop Control: `EXIT` and `CONTINUE`

Basic Next requires explicit targets for loop jumps. Rather than bare `BREAK` or `CONTINUE`, statements must name the enclosing loop type:

* `EXIT FOR`, `EXIT WHILE`, and `EXIT REPEAT` terminate the loop immediately.
* `CONTINUE FOR`, `CONTINUE WHILE`, and `CONTINUE REPEAT` skip to the next iteration.

Using a loop control keyword that does not match the surrounding loop produces a compile-time error:

```
error[INVALID_LOOP_CONTROL]: Invalid loop control: EXIT FOR requires an enclosing FOR loop
```

### Breaking Out of Nested Loops

`EXIT` exits only the innermost enclosing loop of the specified type. Breaking out of nested loops can be managed with a control flag:

```basic
LET grid AS INTEGER[3][3] = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
LET found AS BOOLEAN = FALSE

FOR row AS INTEGER = 0 TO 2
    FOR col AS INTEGER = 0 TO 2
        IF grid[row][col] = 5 THEN
            found = TRUE
            EXIT FOR
        END IF
    END FOR
    IF found THEN
        EXIT FOR
    END IF
END FOR
```

Where possible, extract nested searches into a function and return directly upon finding the result:

```basic
FUNCTION FindValue(values AS INTEGER[3], target AS INTEGER) AS INTEGER
    FOR index AS INTEGER = 0 TO LEN(values) - 1
        IF values[index] = target THEN
            RETURN index
        END IF
    END FOR
    RETURN -1
END FUNCTION
```

Use `CONTINUE` at the beginning of a loop body to filter out records early, keeping the remainder of the iteration unindented.

## Return Analysis in Loops

The compiler checks all execution paths in non-`VOID` functions to ensure they terminate with `RETURN` or `STOP`. The compiler does not assume loops run at least once:

```basic
FUNCTION First(values AS INTEGER[3]) AS INTEGER
    FOR EACH value AS INTEGER IN values
        RETURN value
    END FOR
END FUNCTION
```

```
error[MISSING_RETURN]: Missing return: non-VOID FUNCTION can complete without RETURN expression
```

A fallback `RETURN` or error check must follow the loop to define what happens if the collection is empty or no item matches.

## Terminating Execution: `STOP`

The `STOP` statement immediately terminates the program and returns an integer exit code (from `0` to `255`) to the operating system:

```basic
IF NOT isConfigured THEN
    PRINT "configuration missing"
    STOP 2
END IF
```

For routine program exits, return a status code from the main `Start` function (`FUNCTION Start() AS INTEGER`). Reserve `STOP` for fatal, unrecoverable conditions deep within execution paths.

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

## Diagnostics Introduced in This Chapter

| Diagnostic | Cause |
| --- | --- |
| `TYPE_MISMATCH` | A condition expression is not `BOOLEAN`; `STEP` is `0`; assignment to a `FOR EACH` loop variable. |
| `INVALID_LOOP_CONTROL` | `EXIT` or `CONTINUE` references a loop type that does not enclose the statement. |
| `MISSING_RETURN` | A non-`VOID` function has an execution path that reaches the end without a `RETURN`. |
| `E0100` | Syntax error: compound statement in single-line `IF`, trailing `END IF` on a single-line statement, or invalid operator usage. |

## Summary

* Conditions must always be explicit `BOOLEAN` expressions.
* Block conditionals and loops close with explicit `END` keywords (`END IF`, `END WHILE`, `END REPEAT`, `END FOR`).
* Single-line `IF` statements are restricted to a single simple statement and must not include `END IF`.
* Guard clauses reduce nesting and enable type narrowing with `IS` on alternative types.
* Loop jump statements must explicitly name their loop target (`EXIT FOR`, `CONTINUE WHILE`, etc.).
* Non-`VOID` functions require a return path outside of loops to handle cases where the loop body does not execute.

---

[Next: Compound Data and Error Handling →](04_compound_data.md)
