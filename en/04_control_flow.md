# Control Flow

[← Previous: Operators and Conversions](03_operators_and_conversions.md) · [Contents](toc.md)

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
error[TYPE_MISMATCH]: Type mismatch: Expected BOOLEAN, but found INT32 in condition.
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
error[E0101]: Syntax error: unexpected token after expression.
```

Use the single-line form for simple guards. If a branch requires more than one statement, use the block `IF ... END IF` form.

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
Use `REPEAT ... UNTIL` when the body must run at least once before the condition can be checked. Here the loop keeps rolling a (deterministic) die until it shows six:

```basic
FUNCTION Start() AS VOID
    LET attempt AS INTEGER = 0
    LET roll AS INTEGER = 0

    REPEAT
        attempt++
        roll = (attempt * 7) % 6 + 1
        PRINT "attempt", attempt, "rolled", roll
    UNTIL roll = 6
    END REPEAT
END FUNCTION
```

```
attempt 1 rolled 2
attempt 2 rolled 3
attempt 3 rolled 4
attempt 4 rolled 5
attempt 5 rolled 6
```

Unlike `WHILE`, which states a condition for continuing, `UNTIL` states the condition for stopping.

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

Avoid modifying the loop variable inside a `FOR` loop body. If the iteration count depends on dynamic runtime conditions, use a `WHILE` loop instead. Iterating over the elements of a vector, with `FOR EACH`, is covered with vectors in [chapter 6](06_vectors_strings_and_structs.md).

### Loop Scope

A loop is a block. The loop variable of a `FOR`, and every binding declared in a loop body, belong to that loop: they are not visible after `END FOR`, `END WHILE` or `END REPEAT`, so a later loop may reuse the same names. The `UNTIL` condition of a `REPEAT` is part of its block and can read the bindings of the body:

```basic
FUNCTION Start() AS VOID
    LET total AS INTEGER = 0
    FOR i AS INTEGER = 1 TO 3
        LET doubled AS INTEGER = i * 2
        total += doubled
    END FOR
    FOR i AS INTEGER = 10 TO 20 STEP 10
        LET doubled AS INTEGER = i * 2
        total += doubled
    END FOR
    PRINT total    // 72

    LET count AS INTEGER = 0
    REPEAT
        LET done AS BOOLEAN = count >= 2
        count += 1
    UNTIL done
    END REPEAT
    PRINT count    // 3
END FUNCTION
```

Reading a body binding after its loop is an error:

```
error[NAME_NOT_FOUND]: Undefined name: Name 'doubled' was not found in expression lookup.
```

A name still cannot shadow one that is visible where it is declared: a `FOR i` nested inside another `FOR i`, or a `FOR i` after a `LET i` in the same block, is `DUPLICATE_NAME`.

## Loop Control: `EXIT` and `CONTINUE`

Basic Next requires explicit targets for loop jumps. Rather than bare `BREAK` or `CONTINUE`, statements must name the enclosing loop type:

* `EXIT FOR`, `EXIT WHILE`, and `EXIT REPEAT` terminate the loop immediately.
* `CONTINUE FOR`, `CONTINUE WHILE`, and `CONTINUE REPEAT` skip to the next iteration.

Using a loop control keyword that does not match the surrounding loop produces a compile-time error:

```
error[INVALID_LOOP_CONTROL]: Invalid loop control: EXIT FOR requires an enclosing FOR loop
```

`CONTINUE` at the beginning of a loop body filters out cases early and keeps the rest of the iteration unindented:

```basic
FUNCTION Start() AS VOID
    LET evens AS INTEGER = 0
    FOR n AS INTEGER = 1 TO 10
        IF n % 2 <> 0 THEN
            CONTINUE FOR
        END IF
        evens += n
    END FOR
    PRINT evens    // 30
END FUNCTION
```

### Breaking Out of Nested Loops

`EXIT` leaves only the innermost enclosing loop of the named kind. To leave two nested loops, the outer loop tests a flag set by the inner one:

```basic
FUNCTION Start() AS VOID
    CONST TARGET = 6
    LET found AS BOOLEAN = FALSE

    FOR row AS INTEGER = 1 TO 3
        FOR col AS INTEGER = 1 TO 3
            IF row * col = TARGET THEN
                PRINT "found at", row, col    // found at 2 3
                found = TRUE
                EXIT FOR
            END IF
        END FOR
        IF found THEN
            EXIT FOR
        END IF
    END FOR
END FUNCTION
```

A search like this is often clearer as a function that returns as soon as it finds the answer; [chapter 5](05_functions.md) shows that form.

## Terminating Execution: `STOP`

The `STOP` statement immediately terminates the program and returns an integer exit code (from `0` to `255`) to the operating system:

```basic
FUNCTION Start() AS VOID
    LET isConfigured AS BOOLEAN = FALSE
    IF NOT isConfigured THEN
        PRINT "configuration missing"
        STOP 2
    END IF
    PRINT "running"
END FUNCTION
```

The program prints `configuration missing` and exits with status `2`; `running` is never printed. For an ordinary exit status, `Start` can return one instead ([chapter 5](05_functions.md)); reserve `STOP` for conditions the program cannot recover from.

## Worked Example

The following program applies the Collatz rule (halve an even number, triple an odd one and add one) to each start value from 1 to 10, counts the steps until the value reaches 1, gives up on a value that takes more than a fixed limit, and reports the start value with the longest run:

```basic
FUNCTION Start() AS VOID
    CONST STEP_LIMIT = 100
    LET longestStart AS INTEGER = 0
    LET longestSteps AS INTEGER = 0

    FOR start AS INTEGER = 1 TO 10
        LET value AS INTEGER = start
        LET steps AS INTEGER = 0
        WHILE value <> 1
            IF value % 2 = 0 THEN
                value = value DIV 2
            ELSE
                value = 3 * value + 1
            END IF
            steps++
            IF steps > STEP_LIMIT THEN
                PRINT "gave up on", start
                EXIT WHILE
            END IF
        END WHILE
        IF steps > longestSteps THEN
            longestStart = start
            longestSteps = steps
        END IF
    END FOR

    PRINT "longest:", longestStart, "with", longestSteps, "steps"
END FUNCTION
```

Running it with `bni run collatz.bn` prints:

```
longest: 9 with 19 steps
```

`value` and `steps` are declared inside the `FOR` body, so each start value begins with fresh bindings. `DIV` keeps the halving in integers; `/` would produce a `FLOAT`. The constant `STEP_LIMIT` names the safety bound instead of leaving a bare `100` in the condition.

## Diagnostics Introduced in This Chapter

| Diagnostic | Cause |
| --- | --- |
| `TYPE_MISMATCH` | A condition expression is not `BOOLEAN`; `STEP` is `0`. |
| `NAME_NOT_FOUND` | A binding declared in a loop body is read after the loop. |
| `DUPLICATE_NAME` | A loop variable shadows a name visible where it is declared. |
| `INVALID_LOOP_CONTROL` | `EXIT` or `CONTINUE` names a loop kind that does not enclose the statement. |
| `E0101` | Syntax error: compound statement in single-line `IF`, or trailing `END IF` on a single-line statement. |

## Summary

Control flow in Basic Next is explicit in three ways. Every condition is a `BOOLEAN` expression, so the threshold a program tests is always written down. Every block, conditional or loop, closes with an `END` that names it. And every jump out of a loop names the kind of loop it leaves. Within those rules the familiar forms are available: the block and single-line `IF`, the `WHILE` loop that tests before each iteration, the `REPEAT ... UNTIL` loop that tests after it, and the counted `FOR` that declares its own variable. A loop is a scope, so its bindings disappear at its `END`, and `STOP` ends the whole program with an exit code.

The examples in this chapter all lived inside `Start`. The next chapter shows how to divide a program into functions, each with its own parameters and result.

---

[Next: Functions →](05_functions.md)
