# Operators and Conversions

[← Previous: Values, Types and Variables](02_values_types_and_variables.md) · [Contents](toc.md)

The previous chapter declared values; this one combines them. Operators in Basic Next follow two rules that the rest of the chapter applies case by case: both operands of an operator have the same type, and a value changes type only when the program says so with `AS`.

## Operators and Expressions

Expressions are strictly typed. Operands of a binary operator must have the same type, and mixing types without an explicit conversion is rejected at compile time.

A literal written in the expression is the one exception, because it states a value rather than a type. A whole-number literal next to a floating-point operand takes that operand's type, as long as the floating-point type holds the value exactly:

```basic
FUNCTION Start() AS VOID
    LET price AS FLOAT = 2.5
    LET half AS FLOAT32 = 0.5
    PRINT price * 4, half + 1, price > 2    // 10.0 1.5 TRUE
END FUNCTION
```

A literal that the floating-point type cannot hold exactly is not rounded behind your back. `FLOAT` holds every whole number up to 2^53, but `9007199254740993` is 2^53 + 1, so `price * 9007199254740993` is rejected:

```
error[TYPE_MISMATCH]: Type mismatch: Expected operands accepted by Star, but found FLOAT64 and INT32 in binary operator Star.
```

Write `9007199254740993 AS FLOAT` when the nearest value is what you want; the conversion is then visible in the code.

### Arithmetic

The arithmetic operators are `+`, `-`, `*`, and `**` for exponentiation, which is right-associative. Arithmetic follows mathematical convention: `**` binds tighter than a unary minus, so `-2 ** 2` is `-(2 ** 2)`, as in −2² = −4. Write `(-2) ** 2` to square the negative number:

```basic
FUNCTION Start() AS VOID
    PRINT -2 ** 2, (-2) ** 2, 2 ** 3 ** 2    // -4 4 512
END FUNCTION
```

The last value is `2 ** (3 ** 2)`, because `**` groups from the right.

Division is three separate operations rather than one that changes meaning with its operands:

```basic
LET half AS FLOAT = 5 / 2            // 2.5
LET quotient AS INTEGER = 5 DIV 2    // 2
LET remainder AS INTEGER = 5 % 2     // 1
```

`/` always produces a `FLOAT`, even when both operands are integers. `DIV` and `%` are the quotient and the remainder of Euclidean division: the remainder is never negative, and `a = (a DIV b) * b + a % b` holds for every non-zero divisor. With positive operands this agrees with every other convention; with a negative operand it does not, and the difference is worth seeing once:

```basic
FUNCTION Start() AS VOID
    PRINT -5 DIV 2, -5 % 2      // -3 1
    PRINT 5 DIV -2, 5 % -2      // -2 1
    PRINT -5 DIV -2, -5 % -2    // 3 1
END FUNCTION
```

Truncating division, as in C, would give `-2` and `-1` on the first line; floor division, as in Python, would give `-3` and `-1` on the second. The Euclidean rule is the one that keeps `%` usable as an index into a table, whatever the sign of the dividend. A divisor of `0` stops the program with `DIVISION_BY_ZERO`. Writing three operators instead of one removes the most common source of quiet arithmetic error in other languages, where `5 / 2` yields `2` or `2.5` depending on the static types of the operands.

`+` also concatenates strings. It does not concatenate a string with a number; convert the number first with `AS STRING` (see [Explicit Conversion](#explicit-conversion) below).

### Comparison

`=` tests equality and `<>` inequality; `<`, `<=`, `>`, and `>=` compare ordered values. Both operands must have the same static type. Note that `=` is equality in an expression and assignment in a statement, and the two positions never overlap: an assignment is a statement, so a comparison cannot be written where an assignment is meant, and the class of defect represented by C's `if (x = 0)` does not arise.

### Logical and Bitwise

`AND`, `OR`, `NOT`, and `XOR` serve both roles, determined by the type of their operands. With `BOOLEAN` operands they are short-circuit logical operators, evaluating the right-hand side only when the result is not already determined. With integer operands they are bitwise:

```basic
FUNCTION Start() AS VOID
    LET a AS INTEGER = 12       // 0b1100
    LET b AS INTEGER = 10       // 0b1010

    PRINT a AND b               // 8
    PRINT a OR b                // 14
    PRINT a XOR b               // 6
    PRINT a SHL 2               // 48
    PRINT a SHR 2               // 3
END FUNCTION
```

`SHL` and `SHR` shift left and right and apply to integer types only. Because the operands cannot be mixed, there is no ambiguity about which reading applies at a given site.

When a compound condition is long enough that its grouping is not obvious at a glance, parenthesize it, or give it a name by extracting a function that returns `BOOLEAN` ([chapter 5](05_functions.md)). The second is usually better: it documents the rule and makes it testable in isolation.

## Compound Assignment, Increment and Decrement

An assignment can combine an operator with the store. `a += b` means `a = a + b`, and the same form exists for `-=`, `*=`, `/=`, `%=`, and `**=`. The target is evaluated once, and the result must fit the target's type, so `/=` on an `INTEGER` is rejected: `/` produces a `FLOAT`. On a `STRING`, `+=` appends.

```basic
FUNCTION Start() AS VOID
    LET total AS INTEGER = 10
    total += 5
    total -= 3
    total *= 2
    total %= 7
    PRINT total             // 3

    LET ratio AS FLOAT = 9.0
    ratio /= 2.0
    ratio **= 2.0
    PRINT ratio             // 20.25

    LET word AS STRING = "Basic"
    word += " Next"
    PRINT word              // Basic Next
END FUNCTION
```

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

The operand must be an assignable target (a variable, a field, or a vector element). Chaining operators like `i++++` is a syntax error.

## Explicit Conversion

Basic Next performs no implicit conversion, including between numeric types that would lose nothing. Assigning an `INTEGER` to a `FLOAT` binding is an error:

```
error[TYPE_MISMATCH]: Expected FLOAT64, but found INT32 in binding initializer.
```

The `AS` operator states the conversion:

```basic
FUNCTION Start() AS VOID
    LET count AS INTEGER = 3
    LET ratio AS FLOAT = count AS FLOAT
    LET truncated AS INTEGER = 3.9 AS INTEGER     // 3
    LET flag AS BOOLEAN = 0 AS BOOLEAN            // FALSE

    PRINT ratio, truncated, flag
END FUNCTION
```

One case needs no `AS`: a whole-number literal written directly as the initializer of a `LET`, `CONST`, or `EXPORT CONST` declared as `FLOAT`, `FLOAT32`, or `FLOAT64`. The literal already states the value, so it is stored as that floating-point number:

```basic
LET scale AS FLOAT = 2             // 2.0
LET mask AS FLOAT = 0xFF           // 255.0
CONST LOW AS FLOAT32 = -16         // -16.0
```

This applies to literals only. `LET ratio AS FLOAT = count` still needs `count AS FLOAT`, and so does any expression. The integer must be exactly representable in the declared type, so `LET x AS FLOAT32 = 16777217` is rejected: `FLOAT32` cannot hold that value without rounding. Assignments, arguments, and return values are unchanged and still require `AS`.

Converting from floating-point to integer truncates the fractional part towards zero; it does not round. A value outside the target type's range raises `NUMERIC_OVERFLOW`, as an integer narrowing does; `NAN`, `INF` and `-INF` raise `INVALID_NUMERIC_CONVERSION`, since they have no integer value at all. Converting to `BOOLEAN` treats numeric zero, the empty string, and the absence markers `NULL`, `NA` and `EOF` ([chapter 7](07_alternatives_and_errors.md)) as `FALSE` and anything else as `TRUE` — a conversion that must be asked for, which is what distinguishes it from the implicit truthiness the language does not have.

`AS STRING` turns a number or a `BOOLEAN` into the text `PRINT` would write for it. It is how a number joins a string:

```basic
FUNCTION Start() AS VOID
    LET count AS INTEGER = 3
    LET ratio AS FLOAT = 1 / 4
    LET done AS BOOLEAN = count > 2

    PRINT "items: " + (count AS STRING)       // items: 3
    PRINT "ratio: " + (ratio AS STRING)       // ratio: 0.25
    PRINT "done: " + (done AS STRING)         // done: TRUE
END FUNCTION
```

The conversion cannot fail. A float gets the shortest text that reads back as the same value, always with a decimal point (`2.0`), or `NAN`, `INF`, `-INF`. There is no width, precision, or locale: `AS STRING` converts, it does not format. It accepts only numbers and `BOOLEAN`; a `STRING`, `NULL`, or an alternative such as `INTEGER OR Error` is a `TYPE_MISMATCH`, so narrow the value first ([chapter 7](07_alternatives_and_errors.md)).

A conversion in the middle of an expression is a signal worth reading. It usually means a value is being carried in a type that does not match its meaning, and the better fix is often to change the declaration rather than to add the cast.

## Diagnostics Introduced in This Chapter

| Diagnostic | Raised when |
| --- | --- |
| `TYPE_MISMATCH` | The operands of an operator have different types, or a literal next to a floating-point operand cannot be held exactly; a compound assignment produces a type the target cannot hold. |
| `DIVISION_BY_ZERO` | The divisor of `/`, `DIV`, or `%` is zero. |
| `NUMERIC_OVERFLOW` | An integer operation or an `AS` conversion leaves the range of the target type. |
| `INVALID_NUMERIC_CONVERSION` | `NAN`, `INF` or `-INF` converted with `AS` to an integer type. |

## Summary

Operands share a type; a literal adapts to its neighbour only when it fits exactly. Division is three operators — `/`, `DIV`, `%` — and integers never wrap. `AND`, `OR`, `NOT`, and `XOR` are logical on `BOOLEAN` and bitwise on integers. Compound assignment and `++`/`--` update a variable in place. `AS` is the only way a value changes type, and `AS STRING` is how a number joins text.

The next chapter uses these expressions as conditions, to choose between alternatives and to repeat work.

---

[Next: Control Flow →](04_control_flow.md)
