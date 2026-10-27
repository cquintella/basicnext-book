# Appendix A: Keywords

[← Previous: Appendices](appendices.md) · [Contents](toc.md)

This appendix is the reading manual for every reserved word. A command entry opens with the form you write, then says what that form does. Words that are not commands state only their role. The normative registry, including which spellings exist and which diagnostic a collision produces, is [`keywords.md`](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/keywords.md). Grammar is [`0.6.ebnf`](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/0.6.ebnf); behaviour is [`0.6.md`](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/0.6.md).

In a form, a word in uppercase is written as shown. A lowercase word is a placeholder you replace. Square brackets mark an optional part. An ellipsis repeats the preceding part. A form is the shape of the command, not a whole program.

When the grammar places two reserved words together, they are one construct and one entry here. `END FUNCTION` closes a function. It is not the entry for `END` followed by the entry for `FUNCTION`. The same rule covers `END IF`, `END FOR`, `END WHILE`, `END REPEAT`, `END CLASS`, `END STRUCT`, `END INTERFACE`, `ELSE IF`, `FOR EACH`, `EXIT FOR`, `EXIT WHILE`, `EXIT REPEAT`, `CONTINUE FOR`, `CONTINUE WHILE`, `CONTINUE REPEAT`, `POINTER TO`, `ASYNC FUNCTION`, `FUNCTION CONSTRUCTOR`, `FUNCTION DESTRUCTOR`, `EXPORT IMPORT`, and `AS WEAK`. Each half stays reserved, so neither word can be a name.

A keyword in a program is written in uppercase: `FOR`, `IF`, `WHILE`. The specification makes the same letters in any other ASCII case (`for`, `For`, `fOR`) a reserved identifier, which may not name a binding, a constant, a function, a class, a struct, an interface, or a member, and assigns that collision the diagnostic `RESERVED_IDENTIFIER`. The 0.6.10 toolchain does not yet enforce this: such names compile. Avoid them by convention.

Writing the uppercase keyword where a name belongs is a syntax error. `bni check` reports it before any later analysis:

<!-- bn-check: expect-error -->
```basic
FUNCTION Start() AS VOID
    LET FOR AS INTEGER = 1
    PRINT FOR
END FUNCTION
```

```text
error[E0100]: Syntax error: Expected binding name.
 --> keyword.bn:2:5
  |
  2 |     LET FOR AS INTEGER = 1
  |     ^ syntax error
  = cause: the source at this position does not continue the construct as its syntax requires
  = help: compare the line with the construct's syntax in the language reference; an earlier unclosed block or a misspelled keyword is a common origin
```

`INF` and `NAN` are floating-point literals, tested with `IS INF`, `IS -INF`, and `IS NAN`. They are not reserved words. `++` and `--` are operators, not reserved words. `TYPEOF` is a built-in function, taught in [chapter 2](02_values_types_and_variables.md). `DELETE` is an ordinary identifier. `OPEN`, `CLOSE`, `READ`, and `WRITE` are not keywords; files go through `HOST.FileSystem`. `CLS`, `BEEP`, and `PRINTAT` are not keywords; console operations are methods on `HOST.Console`.

The shortest program that uses a binding and a condition:

```basic
FUNCTION Start() AS VOID
    LET ready AS BOOLEAN = TRUE
    IF ready THEN
        PRINT "ready"
    END IF
END FUNCTION
```

`bni check` accepts it. `bni run` prints `ready`.

## Bindings

### LET

`LET name [, name] AS Type [= expression [, expression]]`

`LET [name [AS Type], …] = expression`

`LET` declares a binding: a local, a field, or a parameter's sibling in a declaration list. The type follows `AS` and stays fixed for the life of the binding. An initializer is optional; when it is absent the binding takes the default of its type. Several names of one type may share a statement, each with its own initializer. The bracket form binds several names from one vector or one `STRUCT`. A vector fills the names by position, from the first element. A `STRUCT` fills each name from the field of that same name. `AS` on a name inside the brackets is optional. Taught in [chapter 2](02_values_types_and_variables.md); destructuring in [chapter 6](06_vectors_strings_and_structs.md).

### CONST

`CONST name [AS Type] = expression`

`[EXPORT] CONST name [AS Type] = literal`

`CONST` declares a constant. Inside a function the value is an expression. At module level the value is one literal, and a leading minus on a numeric literal is part of that literal. `EXPORT` makes a module constant visible to importers. A scalar literal may omit `AS`; the inferred integer is `INTEGER` (`INT32`) and the inferred float is `FLOAT` (`FLOAT64`). The value must fit the declared or inferred type. A constant that does not fit is `TYPE_MISMATCH`.

### AS

`name AS Type`

`expression AS BOOLEAN`

`expression AS numeric-type`

`expression AS STRING`

`AS` names a type. It appears on a binding (`LET n AS INTEGER`), a parameter, a function result (`AS VOID`), a conversion, and a counted or `FOR EACH` variable. The conversion form accepts `BOOLEAN`, a numeric type, or `STRING`. The weak form is the separate entry `AS WEAK`. Conversion is explicit: an expression does not change type because it is stored, passed, or returned. Mixing an integer with a floating-point operand is `TYPE_MISMATCH`; write `AS`.

## Types

`INTEGER` is the default signed integer and the same type as `INT32`. `FLOAT` is the default floating-point type and the same type as `FLOAT64`. A counted `FOR` without `AS` uses `INTEGER`. Two integer types of the same signedness combine to the wider one. `BYTE` with a signed type widens to at least `INT16`. Any other mix of a signed type and an unsigned type is `TYPE_MISMATCH`. `FLOAT32` with `FLOAT64` gives `FLOAT64`. Widths and defaults are taught in [chapter 2](02_values_types_and_variables.md).

### BOOLEAN

`BOOLEAN` has two values, `TRUE` and `FALSE`. Every condition is a `BOOLEAN`. A number is not a condition.

### BYTE

`BYTE` is the unsigned 8-bit integer.

### DATE

`DATE` is a calendar date. An uninitialized `DATE` is 1970-01-01. It is distinct from `TIME`, `TIMESTAMP`, and `TIMEZONE`. Reading the clock and converting these values is `HOST.Clock` and the temporal operations in [chapters 12](12_host.md) and [11](11_standard_library.md).

### FLOAT

`FLOAT` is `FLOAT64`. Arithmetic on floating-point values follows IEEE 754.

### FLOAT32

`FLOAT32` is the 32-bit IEEE 754 type. Combined with `FLOAT64` the result is `FLOAT64`.

### FLOAT64

`FLOAT64` is the 64-bit IEEE 754 type, the same type as `FLOAT`. `/` always divides as `FLOAT64`.

### INT8

`INT8` is the signed 8-bit integer. A counted loop whose next step would leave the variable's type ends instead of overflowing.

### INT16

`INT16` is the signed 16-bit integer. `BYTE` combined with a signed type widens to at least `INT16`.

### INT32

`INT32` is the signed 32-bit integer, the same type as `INTEGER`.

### INT64

`INT64` is the signed 64-bit integer. A literal bound that does not fit `INTEGER` needs an explicit `AS INT64` on the loop variable. `TIMESTAMP` is an `INT64` count of milliseconds.

### INTEGER

`INTEGER` is `INT32`. It is the type of a counted `FOR` variable that omits `AS`, of `LEN`, and of `SIZEOF`. A literal that does not fit is `TYPE_MISMATCH`.

### STRING

`STRING` is immutable text. `+` concatenates two strings. An index reads a character and is not an assignment target. `LEN` counts characters; `SIZEOF` counts UTF-8 bytes. `FOR EACH` over a `STRING` binds each character as a `STRING`.

### TIME

`TIME` is a time of day. An uninitialized `TIME` is 00:00:00.000. `SIZEOF` of a `TIME` is 4.

### TIMESTAMP

`TIMESTAMP` is an `INT64` count of milliseconds since 1970-01-01T00:00:00Z. It supports integer arithmetic. An uninitialized `TIMESTAMP` is 0. `SIZEOF` of a `TIMESTAMP` is 8.

### TIMEZONE

`TIMEZONE` stores an IANA zone identifier. An uninitialized `TIMEZONE` is UTC. The value does not load a time-zone database. `SIZEOF` of a `TIMEZONE` is `TYPE_MISMATCH`.

### UINT16

`UINT16` is the unsigned 16-bit integer. Combined with another unsigned type, including `BYTE`, the result is the wider unsigned type. Combined with a signed type it is `TYPE_MISMATCH`.

### UINT32

`UINT32` is the unsigned 32-bit integer. The same signedness rule as `UINT16` applies. `EXPORT CONST U AS UINT32 = -1` is `TYPE_MISMATCH`.

### UINT64

`UINT64` is the unsigned 64-bit integer. The same signedness rule as `UINT16` applies.

### VOID

`VOID` is the result of a function that returns no value. `FUNCTION Start() AS VOID` is the parameterless entry point and exits with status 0. `FUNCTION Start() AS INTEGER` supplies a status in `0..255`. `POINTER TO VOID` is the opaque pointer. `NEW VOID` is not a form of `NEW`.

## Values inside an alternative

`NULL`, `NA`, and `EOF` exist only as a member of an alternative type. `x = NULL` and `x IS NULL` agree, and the same for `NA` and `EOF`. `PRINT` writes the words `NULL`, `NA`, and `EOF`. `AS BOOLEAN` of each is `FALSE`. Alternatives are taught in [chapter 7](07_alternatives_and_errors.md).

### NULL

`NULL` is the absence of an object or a value, written `T OR NULL`. A weak reference that no longer has a referent reads as `NULL`. Assign `NULL` to drop the reference held by a field or a `STATIC`.

### NA

`NA` is a missing datum, written `FLOAT OR NA` and the same shape for other types. `BNMath` and `BNData` use it.

### EOF

`EOF` is the end of an input, written `STRING OR EOF` for a line read by `INPUT`. `IF line IS EOF` distinguishes that end from a line of text.

### TRUE

`TRUE` is the `BOOLEAN` value that passes a condition. `REPEAT` stops when its `UNTIL` condition is `TRUE`.

### FALSE

`FALSE` is the other `BOOLEAN` value.

## Operators written as words

Precedence, loosest first, is `OR`, `XOR`, `AND`, `IS`, the comparisons, `SHL` and `SHR`, then `+` and `-`, then `*` `/` `DIV` `%`, then unary `NOT`. On `BOOLEAN`, `AND` and `OR` skip the right operand when the left operand already decides the result. `XOR` evaluates both sides. On integers the same four words are bitwise: `5 XOR 3` is `6`, and `NOT 0` is `-1`. Taught in [chapter 3](03_operators_and_conversions.md).

### AND

`AND` is Boolean conjunction or bitwise and.

### OR

`OR` is Boolean disjunction or bitwise or. The same word builds an alternative type: `INTEGER OR NULL`, `INTEGER OR Error`, `STRING OR EOF`.

### XOR

`XOR` is Boolean exclusive or, or bitwise exclusive or. Both operands are evaluated.

### NOT

`NOT` is Boolean negation, or the bitwise complement of an integer.

### DIV

`DIV` is the quotient of Euclidean integer division. The remainder operator is `%`, which is not a reserved word. The remainder is never negative, and `a = (a DIV b) * b + a % b`. `-7 DIV 2` is `-4` and `-7 % 2` is `1`. `7 DIV -2` is `-3` and `7 % -2` is `1`. A divisor of `0` stops the program with `DIVISION_BY_ZERO`. `/` is a different operator: it always divides as `FLOAT64`.

### SHL

`SHL` shifts an integer left. The count runs from `0` to the width minus one; any other count is `INVALID_SHIFT_COUNT`. A shift that loses a set bit or changes the sign is `NUMERIC_OVERFLOW`.

### SHR

`SHR` is a logical right shift. It fills with zeros in every integer type, including the signed ones. `-8` as `INT8` `SHR 1` is `124`. The count has the same limits as `SHL`.

### IS

`IS` tests a member of an alternative and narrows the value in that branch: `x IS INTEGER`, `x IS NULL`, `x IS NA`, `x IS EOF`, `x IS Error`. On a floating-point value, `IS NAN`, `IS INF`, and `IS -INF` are the tests; `NAN` compares equal to nothing, itself included. `IS POINTER TO T` tests a pointer. Narrowing is taught in [chapter 7](07_alternatives_and_errors.md).

## Decisions and loops

Conditions are `BOOLEAN`. The forms are taught in [chapter 4](04_control_flow.md).

### IF

```text
IF condition THEN
    statements
ELSE IF condition THEN
    statements
ELSE
    statements
END IF
```

`IF condition THEN statement [ELSE statement]`

`IF` chooses. The block form puts `THEN` at the end of the line, then the statements, optional `ELSE IF` chains, an optional `ELSE`, and `END IF`. The single-line form keeps one simple statement after `THEN`, and an optional simple statement after `ELSE`, and has no `END IF`. That statement may be `EXIT`, `CONTINUE`, `RETURN`, or `STOP`.

### THEN

`IF condition THEN`

`IF condition THEN statement`

`THEN` separates the condition from the body. A `THEN` followed by a statement on the same line is the single-line form and has no `END IF`.

### ELSE

```text
ELSE
    statements
```

`ELSE statement`

`ELSE` introduces the alternative body of an `IF`. In the block form it stands on its own line. In the single-line form one simple statement follows it on the same line.

### ELSE IF

```text
ELSE IF condition THEN
    statements
```

`ELSE IF` is one construct. It tests another condition inside a block `IF`, and the block still closes with `END IF`. It is not used in the single-line form.

### END

`END IF`

`END WHILE`

`END REPEAT`

`END FOR`

`END FUNCTION`

`END CLASS`

`END STRUCT`

`END INTERFACE`

`END` occurs only as the first word of a closer. The closer is the entry below, not this word alone.

### END IF

`END IF`

`END IF` closes a block `IF`. The single-line form `IF condition THEN statement` has no `END IF`.

### END WHILE

`END WHILE`

`END WHILE` closes a `WHILE`.

### END REPEAT

```text
UNTIL condition
END REPEAT
```

`END REPEAT` closes a `REPEAT`, after the `UNTIL` condition.

### END FOR

`END FOR`

`END FOR` closes a counted `FOR` and a `FOR EACH`.

### END FUNCTION

`END FUNCTION`

`END FUNCTION` closes a function body, including `FUNCTION CONSTRUCTOR` and `FUNCTION DESTRUCTOR`. An interface signature has no body and no `END FUNCTION`.

### END CLASS

`END CLASS`

`END CLASS` closes a `CLASS`.

### END STRUCT

`END STRUCT`

`END STRUCT` closes a `STRUCT`.

### END INTERFACE

`END INTERFACE`

`END INTERFACE` closes an `INTERFACE`.

### WHILE

```text
WHILE condition
    statements
END WHILE
```

`WHILE` tests the condition before the body and closes with `END WHILE`. A condition that is already `FALSE` skips the body.

### REPEAT

```text
REPEAT
    statements
UNTIL condition
END REPEAT
```

`REPEAT` runs the body, then tests. It closes with `UNTIL` and `END REPEAT`, and the body runs at least once.

### UNTIL

```text
UNTIL condition
END REPEAT
```

`UNTIL` is the condition after a `REPEAT` body. `TRUE` ends the loop.

### FOR

```text
FOR name [AS integer-type] = first TO last [STEP step]
    statements
END FOR
```

`FOR` is the counted loop. Without `AS`, `name` is `INTEGER`. `integer-type` is `BYTE`, `INT8`, `INT16`, `INT32`, `INT64`, `UINT16`, `UINT32`, `UINT64`, `INTEGER`, or `TIMESTAMP`. `first`, `last`, and the step are evaluated once, in that order, before the first iteration. The step defaults to `1`. A positive step continues while `name <= last`; a negative step continues while `name >= last`. The body may assign `name`. A floating-point bound is `TYPE_MISMATCH`.

### FOR EACH

```text
FOR EACH name [AS Type] IN source
    statements
END FOR
```

`FOR EACH` is one construct. `source` is a vector or a `STRING`, evaluated once. `name` is a constant binding holding a copy of the element. Without `AS`, `name` has the element type, which is `STRING` when the source is a `STRING`.

### EACH

`FOR EACH name [AS Type] IN source`

`EACH` occurs only in `FOR EACH`.

### IN

`FOR EACH name [AS Type] IN source`

`IN` names the vector or `STRING` that `FOR EACH` walks.

### TO

`FOR name [AS integer-type] = first TO last [STEP step]`

`POINTER TO Type`

`TO` names the last value of a counted `FOR`. The same word appears in a pointer type, `POINTER TO Type`.

### STEP

`FOR name [AS integer-type] = first TO last STEP step`

`STEP` is the increment of a counted `FOR`. The default is `1`. A literal `STEP 0` is `TYPE_MISMATCH`. A step that is `0` at run time stops the program with `INVALID_FOR_STEP`.

### EXIT

`EXIT FOR`

`EXIT WHILE`

`EXIT REPEAT`

`EXIT` occurs only in those three statements. `EXIT` alone is not a statement.

### EXIT FOR

`EXIT FOR`

`EXIT FOR` leaves the innermost counted `FOR` or `FOR EACH`. Outside such a loop the statement is `INVALID_LOOP_CONTROL`.

### EXIT WHILE

`EXIT WHILE`

`EXIT WHILE` leaves the innermost `WHILE`. Outside such a loop the statement is `INVALID_LOOP_CONTROL`.

### EXIT REPEAT

`EXIT REPEAT`

`EXIT REPEAT` leaves the innermost `REPEAT`. Outside such a loop the statement is `INVALID_LOOP_CONTROL`.

### CONTINUE

`CONTINUE FOR`

`CONTINUE WHILE`

`CONTINUE REPEAT`

`CONTINUE` occurs only in those three statements. `CONTINUE` alone is not a statement.

### CONTINUE FOR

`CONTINUE FOR`

`CONTINUE FOR` starts the next iteration of the innermost counted `FOR` or `FOR EACH`. A counted `FOR` adds its step first. Outside such a loop the statement is `INVALID_LOOP_CONTROL`.

### CONTINUE WHILE

`CONTINUE WHILE`

`CONTINUE WHILE` starts the next iteration of the innermost `WHILE`. Outside such a loop the statement is `INVALID_LOOP_CONTROL`.

### CONTINUE REPEAT

`CONTINUE REPEAT`

`CONTINUE REPEAT` starts the next iteration of the innermost `REPEAT`. Outside such a loop the statement is `INVALID_LOOP_CONTROL`.

### STOP

`STOP code`

`STOP code` ends the program with status `code`, after releasing the locals of every running function, innermost first. `code` is an integer expression in `0..255`. A literal outside that range is `INVALID_EXIT_CODE` at compile time. A value outside it at run time stops the program with `INVALID_EXIT_CODE` and status `1`.

### RETURN

`RETURN`

`RETURN value`

`RETURN` leaves the current function. A function declared `AS VOID` returns with `RETURN` and no value. Any other result type returns a value of that type. On every path that can finish, a non-`VOID` function returns a value.

## Functions and modules

A module is one file. There are no top-level statements. The entry point is a parameterless function named `Start`. Functions are taught in [chapter 5](05_functions.md), modules in [chapter 8](08_modules.md).

### FUNCTION

```text
[EXPORT] [ASYNC] FUNCTION Name([name AS Type, …]) AS Type
    statements
END FUNCTION
```

`FUNCTION(Type, …) AS Type`

`FUNCTION` declares a function. The body closes with `END FUNCTION`. The second form is the type of a function value: the names of the parameters are absent, and only their types are written. An interface lists signatures only, so an interface member has no body and no `END FUNCTION`. `FUNCTION CONSTRUCTOR` and `FUNCTION DESTRUCTOR` are separate entries.

### EXPORT

`EXPORT FUNCTION …`

`EXPORT CLASS …`

`EXPORT STRUCT …`

`EXPORT INTERFACE …`

`EXPORT CONST name [AS Type] = literal`

`EXPORT IMPORT path AS Alias`

`EXPORT` makes a declaration visible to importers. It is written immediately before the declaration. A declaration without `EXPORT` is private to its module; a use from outside is `NAME_NOT_FOUND`.

### EXPORT IMPORT

`EXPORT IMPORT path AS Alias`

`EXPORT IMPORT` is one construct. It imports `path` and re-exports it under `Alias`. A further importer reaches it as `This.Alias.Name`. Only a module import may be re-exported, not a `HOST` capability.

### IMPORT

`IMPORT path AS Alias`

`IMPORT HOST.Capability AS Alias`

`IMPORT path AS Alias` makes the exported declarations of `path` visible as `Alias.Name`. `path` is one or more names separated by `.`. Imports form no cycle, re-exports included; a module that reaches itself is `IMPORT_CYCLE`. A `HOST` capability other than `HOST.Args` is imported the same way: `IMPORT HOST.FileSystem AS Files`. `Exec`, `Env`, `Close`, and the other capability members are identifiers, not keywords.

### HOST

`HOST.Args`

`IMPORT HOST.Capability AS Alias`

`HOST` is the built-in capability object. `HOST.Args` needs no `IMPORT`. Every other capability is named with `IMPORT HOST.… AS Alias`. `HOST` itself is not re-exported by `EXPORT IMPORT`. The capabilities are taught in [chapter 12](12_host.md).

## Classes, structs, and interfaces

`CLASS` is a reference type under ARC. `STRUCT` is a value copied on assignment. `INTERFACE` is a contract. The three are taught in [chapter 9](09_classes_and_interfaces.md). Memory is taught in [chapter 10](10_memory.md).

### CLASS

`CLASS Name` opens a reference type and `END CLASS` closes it. `EXTENDS` names the base class. `IMPLEMENTS` lists the interfaces the class implements. `NEW Name(arguments)` allocates an instance and runs `FUNCTION CONSTRUCTOR`.

### STRUCT

`STRUCT Name` opens a value aggregate and `END STRUCT` closes it. Assignment copies the value. `RELEASE` of a struct ends that aggregate binding. `SIZEOF` of a struct is the sum of its fields, with no padding.

### INTERFACE

`INTERFACE Name` opens a public contract and `END INTERFACE` closes it. The body is function signatures only: no fields, no constructors, no bodies. Members are public. An interface name is a type. A class reference may be stored in a variable of an interface the class implements; the use is then limited to those members.

### IMPLEMENTS

`IMPLEMENTS` follows the class name and lists one or more interfaces, separated by commas. The names may be qualified (`IMPLEMENTS Pets.Named`). The class provides a `PUBLIC` instance method for every signature, with the same parameter types and result type.

### EXTENDS

`EXTENDS` names the base class. A subclass body can use the base's `PUBLIC` and `PROTECTED` members. `SUPER` names that base from inside the subclass.

### FUNCTION CONSTRUCTOR

`FUNCTION CONSTRUCTOR` is one construct. It takes an optional parameter list, has no result type, and closes with `END FUNCTION`. A class has at most one. `NEW` allocates the most-derived object, runs `SUPER` (the base field initializers and the base constructor, and so on), then the derived field initializers, then the rest of the derived constructor. A class that does not `EXTENDS` another runs its field initializers, then the constructor body.

### CONSTRUCTOR

`CONSTRUCTOR` occurs only in `FUNCTION CONSTRUCTOR`.

### FUNCTION DESTRUCTOR

`FUNCTION DESTRUCTOR` is one construct. It takes no parameters and has no result type, and closes with `END FUNCTION`. It runs at most once, when the strong count reaches zero. The chain runs from the most derived class toward the base, with no `SUPER` call; a class without a destructor is a no-op step. After the chain, the object's strong fields are released in reverse declaration order, derived before base. `RELEASE SELF` inside a destructor ends that parameter binding.

### DESTRUCTOR

`DESTRUCTOR` occurs only in `FUNCTION DESTRUCTOR`.

### SELF

`SELF` is the receiver parameter of a method. `RELEASE SELF` ends only that binding. The caller's object stays alive when other strong references remain.

### SUPER

`SUPER` names the base and is not a value: it cannot be assigned, passed, indexed, or returned. `SUPER(arguments)` is legal only as the first statement of a constructor in a class that `EXTENDS` another, and it calls the single constructor of the direct base. When that base constructor has no parameters, a subclass constructor that omits `SUPER()` receives the call implicitly. `SUPER.Name(arguments)` calls the `PUBLIC` instance method `Name` of the nearest ancestor that declares it. A class that does not `EXTENDS` another does not use `SUPER`.

### OVERRIDE

`OVERRIDE` sits immediately before `FUNCTION` on an instance method that replaces an inherited one: `PUBLIC OVERRIDE FUNCTION Speak() AS STRING`. It is required for that replacement. A missing marker is `OVERRIDE_REQUIRED`. A marker with no overridable ancestor method is `OVERRIDE_WITHOUT_BASE`. `STATIC` methods are not virtual and take no `OVERRIDE`. A `PRIVATE` base method is not overridden.

### STATIC

`STATIC` is one shared member of a class, or static local state of a function. A `STATIC` method is not virtual.

### PUBLIC

`PUBLIC` is visible to any code that can name the member: the same class, a subclass, and unrelated code.

### PRIVATE

`PRIVATE` is visible only in the same class body.

### PROTECTED

`PROTECTED` is visible in the same class body and in the body of a class that `EXTENDS` it, including across modules when the base class is exported. It is not visible through a base-typed reference from outside that hierarchy. That use is `PROTECTED_ACCESS`. `PROTECTED` may appear on a `STATIC` member, with the same rule.

## Memory

### NEW

`NEW Name(arguments)` allocates a class instance and runs its constructor. `NEW` also allocates a pointer region. Lifetime is ARC. Ordinary code drops a reference by leaving scope, by assigning over it, or by assigning `NULL` to a field.

### RELEASE

`RELEASE` ends a local binding or a parameter early. The operand names that binding: a primary, a fixed vector, a struct, a class object, an alternative, or a pointer region. A field, a `STATIC`, or an element of a fixed aggregate is `INVALID_RELEASE_TARGET`. `RELEASE` of a class or a region drops one strong from that binding and runs the destructor, or frees the region, only when the strong count reaches zero. Other aliases stay alive. `RELEASE` of a vector ends the aggregate; it does not remove an element. After `RELEASE`, a use of the binding is a use-after-release error. Leaving scope does the same end-of-binding work, so ordinary programs omit `RELEASE`. `RELEASE` does not close a `HOST` resource; the capability's `Close` does that.

### AS WEAK

`AS WEAK` is one construct: `AS WEAK ClassName`, usually `AS WEAK ClassName OR NULL`. The reference does not keep the referent alive. When the strong count reaches zero, a later read is `NULL`.

### WEAK

`WEAK` occurs only in `AS WEAK`.

### POINTER TO

`POINTER TO` is one construct. The forms are `POINTER TO T`, `POINTER TO T[n]`, `POINTER TO T[]`, and `POINTER TO VOID`. `LEN` of a region pointer is its element count. `LEN` of a pointer that is not a region is a static error. `SIZEOF` of a pointer is `TYPE_MISMATCH`. `IS POINTER TO T` tests the pointer.

### POINTER

`POINTER` occurs only in `POINTER TO`.

## Console, length, and size

### PRINT

`PRINT` writes to the console, then ends the line. Several values may be written in one statement.

### INPUT

`INPUT target` reads one line into `target`. `INPUT prompt, target` writes `prompt` first, without a line ending, then reads. `target` is a `STRING` or a `STRING OR EOF`. A number is read as text and converted with `BNMath.VAL`.

### LEN

`LEN` returns an `INTEGER` count: characters of a `STRING`, elements of a vector, entries of `HOST.Args` (including entry `0`), or the element count of a region pointer. `LEN` of a pointer that is not a region is a static error.

### SIZEOF

`SIZEOF(x)` returns the portable size of `x` in bytes, as `INTEGER`, the same on every target. The size is `1` for `BOOLEAN`, `BYTE`, and `INT8`; `2`, `4`, or `8` for the 16-, 32-, and 64-bit numbers; `8` for `TIMESTAMP`; `4` for `DATE` and `TIME`; the UTF-8 byte count for a `STRING`; the sum of the fields for a `STRUCT`; the sum of the elements for a vector. It is not the memory layout of the allocator. `SIZEOF` of a pointer, an object, an interface, a `TIMEZONE`, a function value, or an alternative is `TYPE_MISMATCH`.

## Task words

### ASYNC FUNCTION

`ASYNC FUNCTION` is one construct. `ASYNC FUNCTION Name(...) AS T OR Error` declares a task function. The result types are `VOID`, `INTEGER`, `FLOAT`, `STRING`, and `BOOLEAN`, each as `T OR Error`. The body closes with `END FUNCTION`. See [chapter 15](15_concurrency.md) and [Appendix M](appendix_m_bndispatch.md).

### ASYNC

`ASYNC` also submits a task: `ASYNC queue Name(arguments)` yields `Dispatch.Ticket OR Error` from an explicitly typed `Dispatch.Queue`. The queue, the function, and the arguments are evaluated once, left to right. The declaration form is `ASYNC FUNCTION`. `BNDispatch` is imported; it is not built in.

### AWAIT

`AWAIT ticket(timeoutMs)` waits and yields `T OR Error` when the ticket comes from a function declared `AS T OR Error`. The timeout is an integer from 1 through 60,000 milliseconds. A later `AWAIT` of the same ticket replays the stored success until `Close`.

## Reserved words with no statement

### PARALLEL

`PARALLEL` is reserved and has no statement. It cannot be used as a name.

### SYSTEM

`SYSTEM` is reserved and has no statement. The command line is `HOST.Args`, which needs no `IMPORT`. `LEN(HOST.Args)` is the number of entries, including entry `0`.

## Diagnostics

These are the codes named above, in the form `bni check` and `bni run` use.

A keyword written where a name belongs is a syntax error, `E0100`, as in the `LET FOR` program at the top of this appendix. Any other letter case of a reserved word used as a name is specified as `RESERVED_IDENTIFIER`, but 0.6.10 accepts it.

A condition that is not `BOOLEAN`, a mix of signed and unsigned integers other than `BYTE` with a signed type, an integer mixed with a float, a constant or a `STEP 0` literal that does not fit, and a `SIZEOF` of a pointer, object, interface, `TIMEZONE`, function value, or alternative are `TYPE_MISMATCH`.

`EXIT` or `CONTINUE` outside the named loop is `INVALID_LOOP_CONTROL`. `STOP` with a code outside `0..255` is `INVALID_EXIT_CODE`. A shift count outside `0 .. width-1` is `INVALID_SHIFT_COUNT`. A counted loop whose step is `0` at run time is `INVALID_FOR_STEP`. Integer `DIV` or `%` by zero is `DIVISION_BY_ZERO`. An integer result that leaves its type is `NUMERIC_OVERFLOW`, including an `SHL` that drops a set bit or changes the sign.

`RELEASE` of something that is not a local or a parameter is `INVALID_RELEASE_TARGET`. A `PROTECTED` member used outside its class and its subclasses is `PROTECTED_ACCESS`. An inherited instance method without `OVERRIDE` is `OVERRIDE_REQUIRED`. `OVERRIDE` with nothing to override is `OVERRIDE_WITHOUT_BASE`. An import cycle is `IMPORT_CYCLE`. A name that is not exported, read from another module, is `NAME_NOT_FOUND`.

---

[Next: Appendix E: External Module Conventions →](appendix_e_external_modules.md)
