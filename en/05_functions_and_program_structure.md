# Functions and Program Structure

[← Previous: Compound Data and Error Handling](04_compound_data.md) · [Contents](toc.md)

Basic Next programs are composed of functions organized into files called modules. The language requires explicit signatures, strictly verifies return paths, and uses a disciplined import system to prevent namespace pollution.

## Function Declarations

A function is declared using the `FUNCTION` keyword, followed by its parameter list, the `AS` keyword, and its return type. The block is closed with `END FUNCTION`.

```basic
FUNCTION Add(a AS INTEGER, b AS INTEGER) AS INTEGER
    RETURN a + b
END FUNCTION
```

If a function does not return a value, its return type must be explicitly declared as `VOID`. In a `VOID` function, you can omit the `RETURN` statement entirely, or use a bare `RETURN` for an early exit.

```basic
FUNCTION LogMessage(msg AS STRING) AS VOID
    IF msg = "" THEN
        RETURN
    END IF
    PRINT msg
END FUNCTION
```

### Return Analysis

Basic Next employs strict return analysis at compile time. For any function with a return type other than `VOID`, the compiler verifies that *every* possible execution path ends with a valid `RETURN` statement (or a `STOP`).

If a path could theoretically reach `END FUNCTION` without returning a value, the analyzer rejects the program. The analyzer does not assume that loops run forever; a `RETURN` hidden exclusively inside a `WHILE` or `REPEAT` loop does not satisfy the return rule.

## Function Values

Basic Next supports treating functions as first-class values, allowing you to pass them as arguments or store them in variables. The type of a function value is written as `FUNCTION(parameter-types) AS return-type`.

```basic
FUNCTION Double(value AS INTEGER) AS INTEGER
    RETURN value * 2
END FUNCTION

FUNCTION Start() AS VOID
    LET transform AS FUNCTION(INTEGER) AS INTEGER = Double
    LET result AS INTEGER = transform(21)
    PRINT result
END FUNCTION
```

In version 0.3, only module-level functions and `STATIC` class methods can be used as function values. Instance methods cannot be stored this way, and there are no lambdas or closures.

## Modules: Programs in Several Files

### A program in three files

Every `.bn` file is a module. Start with a program split into three files in one directory:

```basic
// shapes.bn
EXPORT CONST Sides = 4

EXPORT FUNCTION Square(x AS INTEGER) AS INTEGER
    RETURN x * x
END FUNCTION

FUNCTION Helper() AS INTEGER
    // Not exported: only shapes.bn can call it.
    RETURN 1
END FUNCTION
```

```basic
// report.bn
IMPORT shapes AS Shapes

EXPORT FUNCTION Describe(x AS INTEGER) AS STRING
    RETURN "a square of side " + (x AS STRING) + " has area " + (Shapes.Square(x) AS STRING)
END FUNCTION
```

```basic
// main.bn
IMPORT report AS Report
IMPORT shapes AS Shapes

FUNCTION Start() AS VOID
    PRINT Report.Describe(3)
    PRINT Shapes.Sides
END FUNCTION
```

Run the entry file with either backend; both load the same files:

```sh
bni run main.bn
bnc main.bn -o main && ./main
```

```text
a square of side 3 has area 9
4
```

The entry file is the one that defines `Start`. The other files are libraries: they declare things for other modules to use and are never run on their own.

### What crosses the boundary: `EXPORT`

A declaration is private to its file unless it is marked `EXPORT`. A module can export:

- functions: `EXPORT FUNCTION`;
- types: `EXPORT CLASS`, `EXPORT STRUCT`, `EXPORT INTERFACE`;
- constants: `EXPORT CONST`. A module-level constant must be exported, and it comes after every `IMPORT`.

Using something a module does not export is an error even when the name exists in the file. Calling `Shapes.Helper()` from `main.bn` reports `NAME_NOT_FOUND` ("Name 'Helper' was not found in the exports of the imported module").

An exported class still controls its own members. `EXPORT` makes the class visible; `PUBLIC` makes a member usable from outside it. A class without a constructor has only an implicit `PRIVATE` one, so other modules cannot use `NEW` on it until it declares one:

```basic
// counter.bn
EXPORT CLASS Counter
    PUBLIC FUNCTION CONSTRUCTOR()
    END FUNCTION

    PUBLIC FUNCTION Twice(x AS INTEGER) AS INTEGER
        RETURN 2 * x
    END FUNCTION
END CLASS
```

```basic
// main.bn
IMPORT counter AS Lib

FUNCTION Start() AS VOID
    LET c AS Lib.Counter = NEW Lib.Counter()
    PRINT c.Twice(21)
END FUNCTION
```

Without the `PUBLIC FUNCTION CONSTRUCTOR()`, `NEW Lib.Counter()` is `PRIVATE_ACCESS`. Chapter 6 covers `PUBLIC` and `PRIVATE`.

### Writing an `IMPORT`

`IMPORT` permits that an item marked as EXPORT in another file be used in the current `.bn` file.
YOu can use the keyword `AS`to handled naming conflicts. If the imported item already has the name used in the importing file.

```basic
IMPORT path AS Alias
```

- **Placement.** Imports come first in the file, before any declaration.
- **The alias is required.** Everything the module exports is reached through it: `Shapes.Square`, `Lib.Counter`. An import never adds names to your file, so two modules can both export a `Square` without colliding.
- **The path names a file.** Leave out the `.bn`. Each dot goes down one directory, so `IMPORT geo.shapes AS Shapes` loads `geo/shapes.bn`.
- **Letter case must match exactly**, in directory and file names alike. `IMPORT Shapes AS S` does not load `shapes.bn`. The rule holds on every platform, including macOS and Windows, whose file systems ignore case, so a program that loads on one machine loads on all of them.
- **Keywords are uppercase.** `IMPORT x As Y` is a syntax error.

Two other kinds of path use the same syntax:

- **Standard library.** `BN*` modules (`IMPORT BNString AS Str`, `IMPORT BNWeb AS Web`) are files of the installed standard library (Chapter 8).
- **HOST capabilities.** `IMPORT HOST.FileSystem AS FS` names a host capability, not a file. `HOST.Console`, `HOST.Args` and `HOST.NumProcs` need no import.

A path with two or more segments can also name **one exported type** of a module: `IMPORT BNString.String AS Str` binds `Str` to the `String` class only, and `NEW Str("x")` and `LET s AS Str` work as with the whole module. The last segment is tried as an export first and as a nested file second. A name that is neither is `IMPORT_EXPORT_NOT_FOUND`. Exported functions and constants still need the whole-module import.

### Where the toolchain looks: the module search path

Every `IMPORT` in the program is looked up in the same ordered list of directories, whichever file it is written in. The first directory that holds the file wins:

1. the directory of the entry file;
2. the `modules/` subdirectory of that directory, when present;
3. the standard library (`modules/bn` of the installation, or the one the `BN_HOME` environment variable names);
4. the directories in the `module-path` array of `config.toml`;
5. the directories given with `--module-path`, in command-line order.

Because the list starts at the entry file, an import inside `geo/area.bn` that wants its neighbour `geo/util.bn` writes `IMPORT geo.util AS Util`, not `IMPORT util AS Util`.

Libraries kept outside the program's directory are added to the list, either per command:

```sh
bni run --module-path ../shared --module-path vendor/bn main.bn
bnc --module-path ../shared main.bn -o main
```

or once for the project, in `config.toml`. A relative path there is taken from the directory of the `config.toml` file:

```toml
module-path = ["../shared", "vendor/bn"]
```

The toolchain uses `config.toml` from the current directory, or the one beside the executable, or the file named with `--config <file>`. Since the list is searched in order, a file in the entry directory shadows a file with the same name further down. Keep library names distinct.

### Cycles and diagnostics

A module may not import itself, directly or through other modules. A cycle is `IMPORT_CYCLE`. A module is loaded once, however many files import it.

| Diagnostic | Meaning |
| --- | --- |
| `MODULE_NOT_FOUND` | No directory of the search path holds the file, letter for letter. The message names the path looked for. |
| `NAME_NOT_FOUND` | The module exists but does not export that name. |
| `IMPORT_EXPORT_NOT_FOUND` | A dotted path whose last segment is neither an exported type nor a nested module. |
| `IMPORT_CYCLE` | The imports form a cycle. |
| `PRIVATE_ACCESS` | The type is exported, but the member or constructor used is not `PUBLIC`. |

---

[Next: Object-Oriented Features →](06_object_oriented_features.md)
