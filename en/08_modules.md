# Modules

[← Previous: Absence, Alternatives and Errors](07_alternatives_and_errors.md) · [Contents](toc.md)

Every program so far fits in one file. Real programs do not, and they rely on code someone else wrote: the standard library and the capabilities of the host. Both needs are served by one mechanism. Every `.bn` file is a *module*; a module marks with `EXPORT` what other files may use, and a file brings another module in with `IMPORT`.

## Two Files

The smallest multi-file program is an entry file and one library beside it (both files are in [`examples/ch08-two-files/`](../examples/ch08-two-files/)). In `MathUtils.bn`:

```basic
EXPORT FUNCTION Square(n AS INTEGER) AS INTEGER
    RETURN n * n
END FUNCTION
```

In `main.bn`, in the same directory:

<!-- bn-check: see examples/ch08-two-files -->
```basic
IMPORT MathUtils AS Math

FUNCTION Start() AS VOID
    PRINT Math.Square(5)    // 25
END FUNCTION
```

`IMPORT MathUtils AS Math` loads `MathUtils.bn` and makes its exports reachable through the alias `Math`. The entry file is the one that defines `Start`; the other files are libraries, which declare things for other modules to use and are never run on their own.

## A Program in Three Files

A larger program splits its work by subject. Here three files sit in one directory (they are reproduced in [`examples/ch08-three-files/`](../examples/ch08-three-files/)):

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

<!-- bn-check: see examples/ch08-three-files -->
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

## What Crosses the Boundary: `EXPORT`

A declaration is private to its file unless it is marked `EXPORT`. A module can export:

* functions: `EXPORT FUNCTION`;
* types: `EXPORT STRUCT`, and `EXPORT CLASS` and `EXPORT INTERFACE` ([chapter 9](09_classes_and_interfaces.md));
* constants: `EXPORT CONST`.

Using something a module does not export is an error even when the name exists in the file. Calling `Shapes.Helper()` from `main.bn` reports:

```
error[NAME_NOT_FOUND]: Undefined name: Name 'Helper' was not found in the exports of the imported module.
```

### Module Constants

A constant shared by several files is declared at module level with `EXPORT CONST`, after the module's imports. It follows the rules of [chapter 2](02_values_types_and_variables.md#constants), and its initializer must be a single literal, possibly negative; an expression is a compile-time error even with `AS`. The importing file reads it through the alias (both files are in [`examples/ch08-module-constants/`](../examples/ch08-module-constants/)):

```basic
// Limits.bn
EXPORT CONST PI = 3.141592653589793
EXPORT CONST MIN_LEVEL = -3
```

<!-- bn-check: see examples/ch08-module-constants -->
```basic
IMPORT Limits AS L

FUNCTION Start() AS VOID
    PRINT L.PI, L.MIN_LEVEL    // 3.141592653589793 -3
END FUNCTION
```

A module-level constant must be exported; a module has no private top-level constants.

## Writing an `IMPORT`

`IMPORT` makes the exports of another module usable in the current file, under an alias:

```basic
IMPORT path AS Alias
```

* **Placement.** Imports come first in the file, before any declaration.
* **The alias is required.** Everything the module exports is reached through it: `Shapes.Square`, `Math.SQRT`. An import never adds names to your file, so two modules can both export a `Square` without colliding.
* **The path names a file.** Leave out the `.bn`. Each dot goes down one directory, so `IMPORT geo.shapes AS Shapes` loads `geo/shapes.bn`.
* **Letter case must match exactly**, in directory and file names alike. `IMPORT Shapes AS S` does not load `shapes.bn`. The rule holds on every platform, including macOS and Windows, whose file systems ignore case, so a program that loads on one machine loads on all of them.
* **Keywords are uppercase.** `IMPORT x As Y` is a syntax error.

A path with two or more segments can also name **one exported type** of a module: `IMPORT BNString.String AS Str` binds `Str` to the `String` class only. The last segment is tried as an export first and as a nested file second; a name that is neither is `IMPORT_EXPORT_NOT_FOUND`. Exported functions and constants still need the whole-module import.

## The Standard Library and the Host

Two other kinds of path use the same syntax, and they are how a program reaches beyond the language core.

**Standard-library modules** have names that begin with `BN`: `BNMath`, `BNString`, `BNJson`, `BNWeb`, and others. They are ordinary `.bn` modules shipped with the toolchain, and nothing from them is available until it is imported:

```basic
IMPORT BNMath AS Math

FUNCTION Start() AS VOID
    PRINT Math.SQRT(16.0)    // 4.0
END FUNCTION
```

**Host capabilities** are reached through `HOST`, the one built-in interface of the language to the operating system. `IMPORT HOST.FileSystem AS FS` names a capability, not a file. Three capabilities need no import — `HOST.Console`, `HOST.Args`, and `HOST.NumProcs` — and the rest do.

Part IV of the book covers both: the standard library in [chapter 11](11_standard_library.md), the host capabilities in [chapter 12](12_host.md), and files, networking, and concurrency in the chapters after it. The appendices give the full contract of each `BN*` module.

## Where the Toolchain Looks: the Module Search Path

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

## Cycles

A module may not import itself, directly or through other modules; a cycle is `IMPORT_CYCLE`. A module is loaded once, however many files import it.

## Diagnostics Introduced in This Chapter

| Diagnostic | Raised when |
| --- | --- |
| `MODULE_NOT_FOUND` | No directory of the search path holds the file, letter for letter. The message names the path looked for. |
| `NAME_NOT_FOUND` | The module exists but does not export that name. |
| `IMPORT_EXPORT_NOT_FOUND` | A dotted path whose last segment is neither an exported type nor a nested module. |
| `IMPORT_CYCLE` | The imports form a cycle. |

## Summary

* Every `.bn` file is a module; the entry module defines `Start`.
* `EXPORT` makes a function, type, or constant visible to other modules; everything else stays private to its file.
* `IMPORT path AS Alias` loads a module by its file path, letter for letter, and reaches its exports only through the alias.
* `BN*` modules are the standard library; `HOST` capabilities reach the operating system. Both are imported the same way.
* Every import is resolved against one ordered search path, the same for `bni` and `bnc`.

---

[Next: Classes and Interfaces →](09_classes_and_interfaces.md)
