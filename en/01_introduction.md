# Introduction

[← Previous: Preface](00_preface.md) · [Contents](toc.md)

**Author:** Carlos Quintella  
**License:** Mozilla Public License 2.0 (MPL-2.0)

![Basic Next Book Cover](../cover.jpg)

> **Note:** This tutorial covers the **0.6 line** of Basic Next. The normative specification lives in [`language/0.6/0.6.md`](../../../language/0.6/0.6.md), with the grammar in [`0.6.ebnf`](../../../language/0.6/0.6.ebnf) and the reserved word list in [`keywords.md`](../../../language/0.6/keywords.md).

Basic Next is an explicitly typed, object-oriented programming language designed for clarity, deterministic execution, and robust systems programming. It combines the readability of classic structured languages with modern type safety, automatic memory management via ARC (Automatic Reference Counting), and a dual-backend toolchain offering both an interpreted reference runtime and an optimizing native compiler.

This chapter introduces the core philosophy and features of Basic Next, shows how to install the toolchain and configure popular text editors, and guides you through writing, checking, interpreting, and compiling your first program.

## Core Language Features

Basic Next is built around a small, disciplined set of core design choices:

* **Explicit Typing:** Every variable, function parameter, class field, and return type must be written out. The compiler never relies on implicit type coercion or silent fallback conversions.
* **Readable Block Structure:** Code blocks open with a specific keyword and close with an explicit matching `END` statement (`END IF`, `END WHILE`, `END FUNCTION`, `END CLASS`). Code structure does not depend on braces `{}` or indentation rules.
* **Keywords in UPPERCASE:** All language keywords and built-in primitive types are written in uppercase (`LET`, `IF`, `FOR`, `INTEGER`, `STRING`). Identifiers (variables, functions, classes) are case-sensitive and typically use PascalCase or camelCase. To eliminate ambiguity, all case variations of reserved words (such as `for`, `For`, `while`, `let`) are reserved identifiers and cannot be used as user-defined names. This creates a clear visual distinction between language syntax and user-defined logic.
* **Unified Pipeline:** A single frontend parses source files, performs semantic analysis, and lowers code to a validated intermediate representation (BN IR).
* **Reference Interpreter and Native Compiler:** The same validated BN IR can be executed immediately by the reference interpreter (`bni`) or compiled ahead-of-time into native machine code (`bnc`).
* **Automatic Reference Counting (ARC):** Class instances and dynamic reference types are managed automatically through strong and weak references without a garbage collection pause.
* **Minimal Built-in Core:** The language runtime provides only `HOST` as a built-in interface for low-level operating system facilities. Extended features are modularized into standard libraries whose module names begin with `BN` (`BNMath`, `BNJson`, `BNData`, `BNSqlite`, `BNWeb`, `BNLog`, `BNCrypto`, `BNDispatch`).

## Syntax and Conventions

### The Case Convention (UPPERCASE Keywords)

Basic Next reserves uppercase words for language grammar and primitive types:

* Keywords: `FUNCTION`, `LET`, `CONST`, `IF`, `THEN`, `ELSE`, `WHILE`, `FOR`, `RETURN`, `IMPORT`, `EXPORT`.
* Primitive Types: `INTEGER`, `FLOAT`, `BOOLEAN`, `STRING`, `VOID`, `BYTE`, `INT16`, `INT32`, `INT64`, `FLOAT32`, `FLOAT64`.

Writing keywords in lowercase (such as `let` or `if`) results in a syntax error. Official editor plugins provide automatic capitalization as you type to make this effortless.

### Reserved Identifiers and Case Prohibition

Identifiers created by the programmer (variables, constants, functions, classes, structs, interfaces, fields) are case-sensitive:

```basic
LET counter AS INTEGER = 10
LET Counter AS INTEGER = 20
PRINT counter, Counter    // Prints: 10 20
```

To eliminate ambiguity and prevent naming collisions, all spellings of any reserved word under ASCII case-insensitive comparison (such as `for`, `For`, `fOR`, `while`, `let`, `string`) are **reserved identifiers**. They cannot be user-defined names. The specified diagnostic is `RESERVED_IDENTIFIER`. [Appendix A](21_keywords.md) shows what `bni check` reports when the uppercase keyword itself stands where a name belongs.

### Explicit Blocks

In Basic Next, every compound structure must be explicitly closed with its corresponding `END` keyword:

* `FUNCTION ... END FUNCTION`
* `IF ... END IF`
* `WHILE ... END WHILE`
* `FOR ... END FOR`
* `REPEAT ... UNTIL ... END REPEAT`
* `CLASS ... END CLASS`
* `STRUCT ... END STRUCT`

This eliminates ambiguities like the "dangling else" problem and makes code reviews easy to follow even across large diffs.

## Memory Management: ARC

Basic Next uses **Automatic Reference Counting (ARC)** for managing objects on the heap:

* When an object is instantiated with `NEW`, its reference count is initialized.
* Assigning an object to a strong binding increments the reference count; when a binding goes out of scope, the count is decremented.
* When the strong reference count drops to zero, the object's `DESTRUCTOR` is executed and its memory is reclaimed immediately without stopping application threads.
* Cyclic references can be broken using weak references (`AS WEAK ClassName OR NULL`), which do not increment the strong reference count.
* Primitive scalars (`INTEGER`, `FLOAT`, `BOOLEAN`) and fixed-size vectors are value types allocated on the stack or inline inside containing structures.

There is no manual `free` or `DELETE` keyword, nor is there a tracing garbage collector running in the background.

## Standard Library and Modules

Basic Next adheres to a strict principle of explicit reach: no external facility enters a module's scope unless explicitly imported.

### The `HOST` Interface

`HOST` is the only built-in runtime object provided by the language core. It provides access to process arguments (`HOST.Args`), console operations (`HOST.Console`), and system capabilities when permitted by execution policy (`HOST.FileSystem`, `HOST.Net`, `HOST.Exec`, `HOST.Clock`, `HOST.Random`).

### Standard `BN*` Modules

General-purpose libraries live in the standard module path under `modules/bn/` and use names starting with the `BN` prefix:

* `BNMath`: Mathematical constants, trigonometric functions, logarithms, and conversions.
* `BNJson`: JSON parsing, DOM manipulation, and serialization.
* `BNData`: Tabular data frames, CSV parsing, and vector manipulation.
* `BNSqlite`: Embedded SQLite database querying and transactional operations.
* `BNWeb`: HTTP client and server abstractions, URI helpers, and routing.
* `BNLog`: Structured application and access logging, with severity levels, formats (JSON, syslog, Apache) and destinations.
* `BNCrypto`: Cryptographic hashing (SHA-256, SHA-512) and utility functions.
* `BNDispatch`: Concurrency workers and task queues.
* `BNString`: Extended Unicode string manipulations.

To use a standard module, import it using an explicit alias:

```basic
IMPORT BNMath AS Math

FUNCTION Start() AS VOID
    PRINT Math.SQRT(16.0)
END FUNCTION
```

## Compilation vs. Interpretation

Basic Next provides two complementary tools built on the same compiler frontend:

```
[ Source .bn ] 
      │
      ▼
[ Frontend: Lexer + Parser + Semantic Analysis ]
      │
      ▼
[ Validated BN IR ]
      ├──► bni (Reference Interpreter / LSP / DAP)
      └──► bnc (LLVM Compiler ──► Native Binary)
```

### Interpretation (`bni`)
* `bni run` executes code directly using the typed-IR interpreter.
* Serves as the normative, executable reference of the language specification.
* Requires no external compiler toolchains (such as Clang or LLVM).
* Powers developer tooling, including `bni check`, `bni lsp` (Language Server Protocol), and `bni dap` (Debug Adapter Protocol).

### Ahead-of-Time Compilation (`bnc`)
* `bnc` compiles the validated BN IR through LLVM into an optimized native executable.
* Generates standalone machine code artifacts with zero interpreter runtime overhead.
* Guarantees semantic parity: if a feature cannot be faithfully represented on the target platform, `bnc` rejects it with a support error rather than emitting code that behaves differently from `bni`.

## Installing the Toolchain

Basic Next source files use the `.bn` extension and must be UTF-8 encoded.

Prebuilt releases for Linux, macOS, and Windows are available from the official [GitHub Releases](https://github.com/cquintella/BasicNext/releases).

### Building from Source

To build and install the toolchain from source using Rust:

```sh
git clone https://github.com/cquintella/BasicNext.git
cd BasicNext
cargo build --release -p bni -p bnc -p bn_rt
```

Copy or symlink the resulting binaries (`target/release/bni` and `target/release/bnc`) to a directory on your system `PATH` (such as `~/.local/bin` or `/usr/local/bin`).

### Verifying the Installation

Verify that the tools are available in your terminal:

```sh
$ bni --version
bni 0.6.4
$ bnc --version
bnc 0.6.4
```

## Toolchain Commands Overview

| Command | Description |
| --- | --- |
| `bni check <file.bn>` | Runs lexer, parser, and semantic type analysis without executing code. |
| `bni run <file.bn> [-- args]` | Validates IR and executes the `Start` entry point in the interpreter. |
| `bnc <file.bn> [-o output]` | Compiles the validated IR into a native binary. |
| `bni eval '<source>'` | Directly evaluates a Basic Next expression or short snippet. |
| `bni lex <file.bn>` | Dumps tokens produced by the lexer (useful for debugging syntax errors). |
| `bni lsp` | Starts the Language Server Protocol daemon on standard I/O. |
| `bni dap` | Starts the Debug Adapter Protocol daemon on standard I/O. |

Exit codes follow a standard convention: `0` indicates success, `1` indicates a compilation or language diagnostic error, and `2` indicates invalid command-line flags or missing external tooling.

## Configuring Your Editor

Official plugins provide syntax highlighting, smart indentation, automatic uppercase conversion of keywords, and real-time compiler diagnostics.

### Vim and Neovim (`basicnext-vim`)

The official `basicnext-vim` plugin provides syntax highlighting, indentation, keyword auto-capitalization, and integration with `bni`:

#### Quick Installation (Vim)
```sh
mkdir -p ~/.vim/pack/plugins/start
git clone https://github.com/cquintella/basicnext-vim.git ~/.vim/pack/plugins/start/basicnext-vim
```

#### Quick Installation (Neovim)
```sh
mkdir -p ~/.local/share/nvim/site/pack/plugins/start
git clone https://github.com/cquintella/basicnext-vim.git ~/.local/share/nvim/site/pack/plugins/start/basicnext-vim
```

#### Plugin Features
* Automatically detects `*.bn` files as `filetype=basicnext`.
* Automatically capitalizes keywords when you type a space or delimiter (can be toggled with `let g:basicnext_auto_caps = 0`).
* Runs `:make` to check the current file with `bni check` and populates the Quickfix list.
* Connects to `bni lsp` using `vim-lsp` or `coc.nvim`.

### Visual Studio Code (`basicnext-vscode`)

The official VS Code extension provides TextMate syntax highlighting, problem matchers for compiler errors on save, snippet expansions, and full debugging via `bni dap`.

#### Installation
From a clone of the extension repository:

```sh
git clone https://github.com/cquintella/basicnext-vscode.git
cd basicnext-vscode
npx --yes @vscode/vsce package --allow-missing-repository
code --install-extension basicnext-0.6.4.vsix
```

#### Key VS Code Settings
* `basicnext.executable`: Path to the `bni` binary (auto-detected if on `PATH`).
* `basicnext.compilerExecutable`: Path to the `bnc` compiler binary.
* `basicnext.checkOnSave`: Runs `bni check` on save to display diagnostics in the Problems view (enabled by default).
* `basicnext.autoUppercaseKeywords`: Automatically uppercases keywords as you type (enabled by default).

Pressing `Cmd+F5` (or `Ctrl+F5`) executes the active `.bn` file directly in the integrated terminal using `bni run`.

## A First Program

Create a file named `hello.bn`:

```basic
// A minimal Basic Next program
FUNCTION Start() AS VOID
    PRINT "Hello, World!"
END FUNCTION
```

### Checking the Code

Run the checker to verify syntax and types:

```sh
$ bni check hello.bn
hello.bn: lexical, syntax, and semantic checks passed
```

### Running with the Interpreter

Execute the program with `bni`:

```sh
$ bni run hello.bn
Hello, World!
```

### Compiling to a Native Executable

Compile the program to a native binary with `bnc`:

```sh
$ bnc hello.bn -o hello
$ ./hello
Hello, World!
```

By default the binary runs on any processor of the same architecture. `--cpu native` tunes it for the machine that compiles it:

```sh
$ bnc --cpu native hello.bn -o hello
```

Such a binary may not start on another processor, so keep the default for anything you distribute. The output does not change: `--cpu native` never alters a result, and floating-point arithmetic stays exactly as `bni` computes it.

### Understanding the Structure
* `FUNCTION Start() AS VOID`: Every executable program requires a parameterless entry point named `Start`. It must return either `VOID` (exiting with status code 0) or `INTEGER` (providing a custom exit code between 0 and 255).
* `PRINT`: A built-in statement that writes values to standard output followed by a newline.
* `END FUNCTION`: Closes the function definition explicitly.
* `//`: Indicates a single-line comment. Multi-line comments use `/* ... */`.

## Modules and Organization

Every `.bn` file represents a distinct module. Top-level statements outside of declarations are forbidden: code must reside inside functions, methods, classes, or structs.

### Exporting and Importing

Symbols are private to their module by default. Add the `EXPORT` keyword to make a function, constant, or class accessible to other modules:

In `modules/MathUtils.bn`:

```basic
EXPORT FUNCTION Square(n AS INTEGER) AS INTEGER
    RETURN n * n
END FUNCTION
```

In `main.bn`:

```basic
IMPORT MathUtils AS Math

FUNCTION Start() AS VOID
    PRINT Math.Square(5)
END FUNCTION
```

The `AS <alias>` clause is mandatory. Basic Next does not inject imported names into the local namespace, preventing naming collisions.

## Understanding Compiler Diagnostics

Compiler diagnostics are designed to be actionable and precise. Consider an invalid assignment between incompatible types:

```basic
FUNCTION Start() AS VOID
    LET a AS INTEGER = 10
    LET b AS FLOAT = a
    PRINT b
END FUNCTION
```

Running `bni check program.bn` reports:

```
error[TYPE_MISMATCH]: Type mismatch: Expected FLOAT64, but found INT32 in binding initializer.
 --> program.bn:3:22
  |
  3 |     LET b AS FLOAT = a
  |                      ^ incompatible value
```

Every diagnostic contains:
* **Severity:** `error` or `warning`.
* **Diagnostic Code:** A stable identifier (such as `TYPE_MISMATCH` or `UNUSED_BINDING`).
* **Message:** A clear description of expected versus received types.
* **Location:** The exact line and column indicator (`^`).

To resolve this error, specify the type conversion explicitly using the `AS` operator:

```basic
LET b AS FLOAT = a AS FLOAT
```

## Summary

* Basic Next enforces explicit types, capitalized keywords, and explicit `END` delimiters for high readability and maintainability.
* Memory management is handled deterministically by Automatic Reference Counting (ARC).
* System interactions go through `HOST`, while expanded features are available via standard `BN*` modules.
* Programs are validated once through BN IR and can be run via the reference interpreter (`bni`) or compiled to native binaries (`bnc`).
* Editor integrations for Vim, Neovim, and VS Code support automatic uppercase formatting, quick syntax checking, and debugging.

---

[Next: Common Programming Concepts →](02_common_programming_concepts.md)
