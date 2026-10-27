# Values, Types and Variables

[← Previous: Getting Started](01_getting_started.md) · [Contents](toc.md)

Before a program can decide anything or repeat anything, it needs somewhere to keep values and a vocabulary for describing them. This chapter covers that layer: how to document intent in a comment, how to declare variables and constants, what the primitive types guarantee, how values are written as literals, and how to write them to the console. Every example is a complete program whose code sits inside `FUNCTION Start`, the entry point from [chapter 1](01_getting_started.md).

The organizing idea throughout is that Basic Next requires the type of every binding to be written down and never changes a value's type without being told to. That single decision determines most of what follows, including the diagnostics, so the chapter states the rule in each context and shows what the compiler reports when it is not met.

## Values, Types, and Bindings

Three notions underlie every program, in any language, and the rest of the chapter refers to them constantly.

A *value* is a datum the program computes with: the number `42`, the text `"Alice"`, the truth value `TRUE`. A value exists independently of any name; `42` is the same value wherever it appears.

A *type* is a set of values together with the operations that are meaningful on them (Cardelli and Wegner, 1985). The type `INTEGER` is a range of whole numbers with addition, comparison, and the other integer operations; the type `STRING` is the set of texts with concatenation, indexing, and length. The type of a value therefore determines what may be done with it: two integers may be added, but a text may not be divided. Basic Next checks types before the program runs, from the program text alone — it is *statically typed* — and requires the programmer to write the type of every declaration.

A *binding* associates a name with a value, so that the program can refer to the value by the name. When the value associated with a name can be replaced during execution, the binding is a *variable*; when it cannot, it is a *constant*. Basic Next makes the distinction with two keywords, `LET` and `CONST`. Because every binding in Basic Next has a declared type, the name carries the type with it: wherever `counter` appears, the reader and the compiler both know what kind of value it holds.

## Comments

Basic Next has two comment forms: `//` runs to the end of the line, and `/* ... */` spans as many lines as needed.

```basic
// Reads the next reading from the sensor buffer.

/*
   The calibration constant below comes from the vendor datasheet,
   revision C. It changes with the firmware, not with the hardware.
*/
```

The distinction worth holding onto is that code already states what a program does, so a comment that repeats it adds a line that can fall out of date without being noticed. What code cannot state is why a particular decision was made: which constraint forced a value, which alternative was rejected and for what reason, which input the function is known not to handle. That is what belongs in a comment.

In practice this means documenting the rationale rather than the mechanics, describing the contract of anything a module exports, updating a comment in the same edit that changes the code it describes, and marking unfinished work with a recognizable token such as `TODO`, `FIXME`, or `NOTE` so that it can be found by searching. A comment explaining a line that would be clear under a better name should be replaced by the better name.

## Variables

A variable can be pictured as a named place in which a value is kept. Three moments in the life of a variable are worth distinguishing, because the language treats each one explicitly: its *declaration*, which introduces the name and fixes its type; its *initialization*, which gives it a first value; and its *assignments*, each of which replaces the value with a new one of the same type. The name and the type stay the same throughout; only the value changes.

A variable is declared with `LET`, followed by its name, `AS`, its type, and optionally an initial value. The type is fixed for the variable's entire lifetime; a binding declared `INTEGER` never holds a `FLOAT`.

```basic
LET counter AS INTEGER = 10
LET name AS STRING = "Alice"
```

`AS INTEGER` and `AS STRING` are type annotations: they fix what the binding may hold, and assigning a value of another type is a compile-time error. When a change of type is genuinely intended, the program states it with an explicit conversion, `AS`, covered later in this chapter.

Several names of the same type may be declared in one statement, each with its own initializer:

```basic
LET first, second AS STRING = "auto", "bus"
```

Omitting the initializer is allowed for the scalar types, and the binding takes the documented default for its type: `0` or `0.0` for numeric types, `FALSE` for `BOOLEAN`, and the empty string for `STRING`. A few kinds of type introduced later have no default and always need an initializer; each is pointed out where it appears.

```basic
LET score AS INTEGER     // 0
LET active AS BOOLEAN    // FALSE
LET label AS STRING      // ""
```

Omitting the type is not allowed for an ordinary binding. There is no inference for `LET`:

```basic
LET message = "Hello"
```

```
error[E0101]: Syntax error: a binding declaration requires AS TYPE.
```

The reason for the rule is that a reader of a declaration should not have to evaluate the initializer, or trace a chain of function calls, to know what the binding holds. Writing the type also makes the declaration the place where a wrong assumption is caught, rather than the first arithmetic operation that depends on it.

The one exception is a destructuring `LET`, which splits a vector or a `STRUCT` into several bindings; it is introduced with those types in [chapter 6](06_vectors_strings_and_structs.md).

Names are worth spending thought on at this point, because Basic Next gives no way to recover meaning that a name fails to carry. Prefer a name that states what the value is in the problem being solved — `remainingAttempts`, `unitPrice`, `isEligible` — over one that describes its representation or its position in a loop. A name whose meaning requires a comment to explain is a name that has not been chosen yet.

### Identifier Naming and Reserved Words

Variable and constant names are identifiers. An identifier begins with an ASCII letter or an underscore (`_`), followed by any combination of ASCII letters, digits, or underscores. Identifiers are case-sensitive: `totalScore` and `TotalScore` are distinct bindings.

Only the exact uppercase spelling of a reserved word is a keyword, and a keyword cannot stand where a name belongs. Other spellings are where the specification and the toolchain part ways. The 0.6 specification reserves every case variation of a reserved word, so that `for`, `For`, `while`, `let`, or `string` would be rejected with `RESERVED_IDENTIFIER`; the 0.6.10 toolchain does not yet perform that check, and both of the following compile and run:

```basic
LET for AS INTEGER = 0       // Accepted by 0.6.10; reserved by the specification
LET string AS STRING = "ok"  // Accepted by 0.6.10; reserved by the specification
```

Treat the rule as binding regardless. A name that differs from a keyword only in case forces the reader to look twice at every use, and it will stop compiling as soon as the toolchain enforces what the specification already states.

## Constants

Many values in a program are not meant to change: a limit, a conversion factor, the name of the application. Declaring such a value as a constant states that fact in the program, and lets the compiler enforce it. A constant is a binding that is initialized once and never assigned again; a reader who sees its declaration knows its value everywhere it is used.

`CONST` declares a binding that cannot be reassigned. It always requires an initializer, and an attempt to assign to it is rejected:

```basic
CONST MAX_USERS AS INTEGER = 100
```

```
error[TYPE_MISMATCH]: Expected mutable binding, but found CONST 'MAX_USERS' in assignment target.
```

The type may be omitted when the initializer is a direct scalar literal, in which case it is inferred: a whole number gives `INTEGER` (that is, `INT32`), a decimal number gives `FLOAT` (`FLOAT64`), `TRUE` and `FALSE` give `BOOLEAN`, and quoted text gives `STRING`.

```basic
CONST LIMIT = 100          // INT32
CONST RATIO = 3.14159      // FLOAT64
CONST ACTIVE = TRUE        // BOOLEAN
CONST APP_NAME = "MyApp"   // STRING
```

A minus sign written directly before a single number is part of that literal, so negative constants are inferred the same way. The value is what counts: `-0xFF` is `-255`.

```basic
CONST SENTINEL = -1        // INT32
CONST OFFSET = -2.5        // FLOAT64
CONST MASK = -0xFF         // INT32, value -255
```

Inference applies to literals only. A specific width or signedness, an expression (including `-1 + 2`), a vector, or a special value such as `NULL` or `EOF` requires the type to be written:

```basic
CONST BUFFER_SIZE AS UINT32 = 4096
CONST AREA AS INTEGER = 4 * 5
```

A constant must fit its type. `CONST WIDE = 0x80000000` is rejected because the inferred `INT32` cannot hold it, and `CONST FLAGS AS UINT32 = -1` is rejected because an unsigned type has no negative values.

Constants are the mechanism for removing unexplained literals from code. A `100` appearing in three conditions is three independent facts that happen to agree; `MAX_USERS` is one fact referenced three times, and changing it is one edit rather than a search. Declare the constant where the value's meaning belongs — inside the function when only that function is concerned, at module level with `EXPORT` when it is part of the module's contract ([chapter 8](08_modules.md)) — and name it for what it limits rather than for its value.

## Inspecting a Type

`TYPEOF(expression)` returns the canonical name of an expression's static type as a `STRING`. The aliases report their underlying representation, which makes it a useful way to confirm what an inferred constant actually is:

```basic
FUNCTION Start() AS VOID
    CONST count = 10
    CONST rate = 10.2
    LET flag AS BOOLEAN = TRUE
    LET message AS STRING = "Basic Next"

    PRINT TYPEOF(count)     // INT32
    PRINT TYPEOF(rate)      // FLOAT64
    PRINT TYPEOF(flag)      // BOOLEAN
    PRINT TYPEOF(message)   // STRING
END FUNCTION
```

`TYPEOF` reports the type known at compile time. It is a diagnostic aid for the programmer, not a mechanism for branching on types at runtime.

## Primitive Types

The *primitive* types are the ones the language provides directly and that are not built from other types: numbers, truth values, text, and time. The composite types of later chapters — vectors, structures, classes — are all assembled from them.

### Numeric Types

A computer represents a number in a fixed number of bits, and the choice of representation decides which numbers can be represented at all. An *integer* type of `n` bits holds whole numbers in a fixed range: from −2<sup>n−1</sup> to 2<sup>n−1</sup> − 1 when it is *signed*, and from 0 to 2<sup>n</sup> − 1 when it is *unsigned*. A *floating-point* type holds an approximation of a real number in the format of the IEEE 754 standard (IEEE, 2019): most decimal fractions, `0.1` among them, have no exact representation and are rounded to the nearest one that does (Goldberg, 1991). Integer arithmetic is therefore exact within its range, and floating-point arithmetic is approximate everywhere.

The two general-purpose numeric types are `INTEGER`, a signed 32-bit integer identical to `INT32`, and `FLOAT`, an IEEE 754 double-precision number identical to `FLOAT64`. Use them unless a specific width is required by the problem.

When it is — a binary file format, a hardware register, a protocol field — the fixed-width types state the layout exactly. The signed types are `INT8`, `INT16`, `INT32`, and `INT64`; the unsigned types are `BYTE` (unsigned 8-bit), `UINT16`, `UINT32`, and `UINT64`; the floating-point types are `FLOAT32` and `FLOAT64`. `TIMESTAMP` is an alias for `INT64` with a documented meaning, described below.

Integer arithmetic in Basic Next does not wrap. An operation whose result falls outside the range of its type raises `NUMERIC_OVERFLOW` at runtime, naming the value and the target type:

```basic
LET n AS INT8 = 127
n = n + 1
```

```
error[NUMERIC_OVERFLOW]: Numeric overflow: Numeric overflow while converting 128 to INT8.
```

This is a deliberate trade. Wraparound is faster and is what most languages inherit from the hardware, but a program that wraps continues running with a value that is arithmetically wrong, and the consequence surfaces somewhere else entirely. Halting at the operation that overflowed puts the failure where the cause is.

Floating-point values follow IEEE 754, including the special values `NAN`, `INF`, and `-INF`. `NAN` is not equal to itself, so testing for it uses `IS NAN` rather than `=`.

### `BOOLEAN`

`BOOLEAN` has exactly two values, `TRUE` and `FALSE`, and no other type is interchangeable with it. `PRINT` renders them as `TRUE` and `FALSE`. The consequences for conditions are the subject of [chapter 4](04_control_flow.md).

### `STRING`

A `STRING` is an immutable sequence of Unicode scalar values, written between double quotes. A literal cannot span a line break.

`LEN(s)` gives the number of scalar values, and `s[i]` gives the scalar at a zero-based index as a `STRING` of length one. An index outside `0` through `LEN(s) - 1` raises `INDEX_OUT_OF_BOUNDS`.

```basic
FUNCTION Start() AS VOID
    LET word AS STRING = "café"
    PRINT LEN(word)                  // 4
    PRINT word[0]                    // c
    PRINT word[LEN(word) - 1]        // é
    PRINT SIZEOF(word)               // 5
END FUNCTION
```

The last two lines illustrate a distinction that matters whenever text leaves the program. `LEN` counts characters in the sense a reader means; `SIZEOF` gives the size in bytes of the UTF-8 encoding, which is larger whenever the text contains a character outside ASCII. Use `LEN` for indexing and for anything presented to a person, and `SIZEOF` for buffers and storage.

Strings are immutable: `s[i]` is not an assignment target, there is no slice syntax, and there is no `CHAR` type. Two global functions convert between a character and its code point: `ASC(text)` returns the scalar value of the first character as `INTEGER OR Error`, and `CHAR(code)` returns a one-character `STRING OR Error`. The `OR Error` in those types means the call can fail and hand back an error instead of a value; [chapter 7](07_alternatives_and_errors.md) shows how a program handles that. Both return `Error` rather than stopping — for an empty string and for a code that is not a valid scalar value, respectively — and neither requires an import.

### Temporal Types

Four types describe time. `TIMESTAMP` is an `INT64` count of milliseconds since the Unix epoch in UTC. `DATE`, `TIME`, and `TIMEZONE` are distinct value types for a calendar date, a clock time, and a zone identifier. Their defaults are what an uninitialized binding takes:

```basic
FUNCTION Start() AS VOID
    LET stamp AS TIMESTAMP     // 0
    LET day AS DATE            // 1970-01-01
    LET clock AS TIME          // 00:00:00.000
    LET zone AS TIMEZONE       // UTC

    PRINT stamp, day, clock, zone
END FUNCTION
```

These types have no literal form. [Chapter 11](11_standard_library.md) shows how to build a value from its text form and convert between the types, and [chapter 12](12_host.md) how to read the current time through `HOST.Clock`.

## Literals

A literal is a value written directly in the source: `42`, `0.5`, `"Alice"`, `TRUE`. Basic Next has a deliberately small set of literal forms, and each one is spelled exactly one way. This section lists all of them, states what type each one takes, and shows the diagnostics for the spellings that other languages accept and Basic Next does not.

The rule that governs every numeric literal is that it states a value, not a type. A literal has a default type, `INTEGER` for a whole number and `FLOAT` for a number with a decimal point, but when it is written where a type is already declared it takes that type, provided the value fits. How `CONST` uses the default type to infer a constant's type is covered in [Constants](#constants); this section is about the literals themselves.

### Integer Literals

An integer literal is written in decimal, in hexadecimal with the prefix `0x`, or in binary with the prefix `0b`. Hexadecimal digits may be upper- or lowercase; the prefixes are lowercase only.

```basic
FUNCTION Start() AS VOID
    LET decimal AS INTEGER = 255
    LET hex AS INTEGER = 0xFF
    LET binary AS INTEGER = 0b11111111
    LET padded AS INTEGER = 007
    LET big AS INT64 = 3000000000
    LET small AS BYTE = 200

    PRINT decimal, hex, binary, padded    // 255 255 255 7
    PRINT big, small                      // 3000000000 200
    PRINT TYPEOF(255), TYPEOF(0xFF)       // INT32 INT32
END FUNCTION
```

Leading zeros in a decimal literal are allowed and mean nothing: `007` is seven, not an octal number. There is no octal form, no digit separator, and no type suffix. `0o17`, `1_000`, `0XFF`, and `0b102` are all rejected by the lexer, which reports the whole malformed token:

```
error[E0001]: Lexical error: Found 'malformed numeric literal '1_000'', but expected a valid Basic Next token.
```

A literal has no sign of its own. In an expression, `-5` is the unary minus applied to `5`. In a declaration's initializer, a minus sign written directly before one number is part of the literal, which is what lets the most negative value of each type be written: `LET n AS INTEGER = -2147483648` and `LET m AS INT64 = -9223372036854775808` are both accepted, although `2147483648` on its own does not fit an `INT32`.

The value must fit the type it is stored in. This is checked at compile time, and the diagnostic names the declared type:

```basic
LET b AS BYTE = 256        // TYPE_MISMATCH: BYTE holds 0 through 255
LET u AS UINT32 = -1       // TYPE_MISMATCH: no negative unsigned values
LET n AS INT8 = -129       // TYPE_MISMATCH: INT8 holds -128 through 127
```

```
error[TYPE_MISMATCH]: Type mismatch: Expected BYTE, but found INT32 in binding initializer.
```

The message reports `INT32` because that is the literal's default type; what it means is that the value does not fit `BYTE`. When a whole number is too large for `INTEGER`, declare the binding with a wider type — `INT64`, `UINT32`, `UINT64` — and the literal takes that type. Hexadecimal is no exception: `0xFFFFFFFF` fits a `UINT32` and is accepted there, but it is not a negative `INT32` bit pattern, as it would be in C.

### Floating-Point Literals

A floating-point literal is one or more digits, a decimal point, and one or more digits. Both sides of the point are required, and there is no exponent:

```basic
FUNCTION Start() AS VOID
    LET ratio AS FLOAT = 0.25
    LET single AS FLOAT32 = 1.5
    LET whole AS FLOAT = 2

    PRINT ratio, single, whole            // 0.25 1.5 2.0
    PRINT TYPEOF(0.25)                    // FLOAT64
    PRINT 1.0 / 0.0, -INF, NAN            // INF -INF NAN
    PRINT NAN IS NAN, INF > 1.0           // TRUE TRUE
END FUNCTION
```

`.5`, `1.`, and `1e10` are lexical errors. A very large or very small number is written out in full, or computed from a constant in the `BNMath` module ([chapter 11](11_standard_library.md)):

```
error[E0001]: Lexical error: Found 'malformed numeric literal '1e10'', but expected a valid Basic Next token.
error[E0001]: Lexical error: Found 'a number cannot start with '.'', but expected valid BN character sequence.
```

A floating-point literal is `FLOAT` by default and becomes `FLOAT32` when stored in a `FLOAT32` binding, rounded to the nearest single-precision value. A whole-number literal stored in a floating-point binding is converted only if the floating-point type holds it exactly, as described in [chapter 3](03_operators_and_conversions.md#explicit-conversion). A floating-point literal is never accepted where an integer type is declared:

```
error[TYPE_MISMATCH]: Type mismatch: Expected INT32, but found FLOAT64 in binding initializer.
```

Floating-point literals are binary approximations of the decimal text, so `0.1 + 0.2` prints `0.30000000000000004`. That is IEEE 754 arithmetic, not a fault of the literal; compare floating-point results with a tolerance rather than with `=`.

### `NAN` and `INF`

`NAN` and `INF` are literals of type `FLOAT`, written in uppercase, and are never identifiers. There is no `-INF` token: `-INF` is the unary minus applied to `INF`, which is why it may be written anywhere an expression is allowed. As noted under [Numeric Types](#numeric-types), `NAN = NAN` is `FALSE`; test with `IS NAN`.

### `TRUE` and `FALSE`

The two `BOOLEAN` values are the literals `TRUE` and `FALSE`. No number or string stands in for them, and the lowercase `true` is not a literal but an undefined name (`NAME_NOT_FOUND`).

### String Literals

A string literal is text between double quotes. Single quotes do not delimit a string, and a literal must close on the line it opens: there is no multi-line string.

Inside a literal there are exactly two escape sequences: `\"` for a double quote and `\\` for a backslash.

```basic
FUNCTION Start() AS VOID
    LET quoted AS STRING = "She said \"hi\""
    LET path AS STRING = "C:\\temp"
    LET empty AS STRING = ""

    PRINT quoted              // She said "hi"
    PRINT path                // C:\temp
    PRINT LEN(empty)          // 0
    PRINT "naïve café ✓", LEN("✓")
END FUNCTION
```

```
She said "hi"
C:\temp
0
naïve café ✓ 1
```

Any other backslash sequence is an error, and so is a control character typed directly into the literal, such as a tab:

```
error[E0001]: Lexical error: Found 'unsupported string escape; use \" or \\', but expected valid BN character sequence.
error[E0001]: Lexical error: Found 'string literals cannot contain control characters', but expected a valid Basic Next token.
error[E0001]: Lexical error: Found 'string literals cannot contain a line break', but expected a valid Basic Next token.
```

The last message is also what an unterminated string produces, since the literal runs into the end of the line.

Source files are UTF-8, and a literal may contain any Unicode character that is not a control character. `"✓"` is one character long; `LEN` and `SIZEOF` measure it as described under [`STRING`](#string).

## Writing Output: `PRINT`

`PRINT` writes its arguments to standard output followed by a newline. Arguments separated by commas are printed with a single space between them; joining with `+` concatenates without adding anything. `PRINT` with no arguments writes an empty line.

```basic
FUNCTION Start() AS VOID
    LET name AS STRING = "Alice"

    PRINT "Processing user:", name       // Processing user: Alice
    PRINT "Processing user: " + name     // Processing user: Alice
    PRINT
    PRINT "done"
END FUNCTION
```

The two forms above produce the same output here only because the literal ends with a space. Prefer the comma form for messages assembled from several values, and reserve `+` for text that is genuinely one string.

## Choosing Types Deliberately

Three habits follow from the rules in this chapter and are worth adopting from the first program.

Declare the type that matches the meaning of the value, not the one that makes the current line compile. A count of retries is an `INTEGER`; a byte read from a file is a `BYTE`; a ratio is a `FLOAT`. When a declaration forces a cast at every use, the declaration is usually the thing to change.

Use `INTEGER` and `FLOAT` by default and reach for a fixed width when the layout is part of the problem. A narrower type does not make a program faster in any way a beginner will measure, and it introduces an overflow boundary that must be respected.

Replace a literal with a named constant as soon as it appears in a condition or is used more than once. The name is where the reasoning lives, and it is the only part of the program that can explain why the number is what it is.

## Diagnostics Introduced in This Chapter

| Diagnostic | Raised when |
| --- | --- |
| `E0101` | A `LET` declaration omits `AS TYPE`. |
| `E0001` | A lexical error: a malformed numeric literal, an unsupported string escape, a control character or line break inside a string; a `CONST` without a type initialized by something other than a scalar literal. |
| `TYPE_MISMATCH` | A value of another type is stored without a conversion; a literal does not fit the declared type; a `CONST` is used as an assignment target. |
| `NAME_NOT_FOUND` | A name is not declared, such as the lowercase `true`. |
| `NUMERIC_OVERFLOW` | An integer operation leaves the range of its type. |
| `INDEX_OUT_OF_BOUNDS` | A string index is outside `0` through `LEN(s) - 1`. |

## Summary

Every binding states its type, and the type does not change. Constants fix a name to a value and are the place where a number's meaning is recorded. Integers do not wrap, and a literal must fit the type it is stored in. `PRINT` writes values separated by spaces and ends the line.

Each of these makes a program longer to write and shorter to reason about. The next chapter combines values with operators and converts between types, always explicitly.

## References

- Cardelli, L., and Wegner, P. (1985). On Understanding Types, Data Abstraction, and Polymorphism. *ACM Computing Surveys*, 17(4), 471–523. https://doi.org/10.1145/6041.6042
- Goldberg, D. (1991). What Every Computer Scientist Should Know About Floating-Point Arithmetic. *ACM Computing Surveys*, 23(1), 5–48. https://doi.org/10.1145/103162.103163
- IEEE (2019). *IEEE Standard for Floating-Point Arithmetic* (IEEE Std 754-2019). https://doi.org/10.1109/IEEESTD.2019.8766229

---

[Next: Operators and Conversions →](03_operators_and_conversions.md)
