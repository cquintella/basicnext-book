# The Basic Next Programming Language

Official website: [http://basicnext.org](http://basicnext.org)

This edition teaches the 0.6 line of Basic Next and is checked against the 0.6.10 toolchain.

## [Preface](00_preface.md)
- The Problem the Language Addresses
- What the Decisions Are
- What Was Borrowed
- What the Language Does Not Have
- Why the Language Is Taught in This Book
- Where the Language Fits
- How This Book Is Organized
- References

## Part I — Getting Started

### 1. [Getting Started](01_getting_started.md)
- Installing the Toolchain
- A First Program
- Syntax Conventions
- Interpreter and Compiler
- Toolchain Commands
- Reading a Diagnostic
- Configuring Your Editor

## Part II — The Procedural Language

### 2. [Values, Types and Variables](02_values_types_and_variables.md)
- Values, Types, and Bindings
- Comments
- Variables
- Constants
- Inspecting a Type
- Primitive Types
- Literals
- Writing Output: `PRINT`
- Choosing Types Deliberately

### 3. [Operators and Conversions](03_operators_and_conversions.md)
- Expressions, Operators, and Precedence
- The Operators
- Compound Assignment, Increment and Decrement
- Explicit Conversion

### 4. [Control Flow](04_control_flow.md)
- Conditions Are Boolean
- The Block `IF`
- The Single-Line `IF`
- Pre-Condition Loops: `WHILE`
- Post-Condition Loops: `REPEAT ... UNTIL`
- Counted Loops: `FOR`
- Loop Control: `EXIT` and `CONTINUE`
- Terminating Execution: `STOP`
- Worked Example

### 5. [Functions](05_functions.md)
- Functions as Abstraction
- Function Declarations
- Parameters Are Constant
- Guard Clauses Instead of Nesting
- Return Analysis
- The Exit Status of `Start`
- Function Values

### 6. [Vectors, Strings and Structs](06_vectors_strings_and_structs.md)
- Fixed-Size Vectors
- Iterating over a Vector
- Measuring: `LEN` and `SIZEOF`
- Strings as Sequences
- Structures (`STRUCT`)
- Destructuring
- Worked Example

### 7. [Absence, Alternatives and Errors](07_alternatives_and_errors.md)
- Alternative Types
- `NULL`, `NA`, and `EOF`
- Testing and Narrowing with `IS`
- Reading Input
- Errors

### 8. [Modules](08_modules.md)
- Modules and Information Hiding
- Two Files
- A Program in Three Files
- What Crosses the Boundary: `EXPORT`
- Writing an `IMPORT`
- The Standard Library and the Host
- Where the Toolchain Looks: the Module Search Path
- Cycles

## Part III — Objects and Memory

### 9. [Classes and Interfaces](09_classes_and_interfaces.md)
- Objects: Data and Behaviour
- Objects Are Shared, Not Copied
- Visibility and `SELF`
- Constructors
- Class Members: `STATIC`
- Inheritance
- Interfaces
- Exporting a Class

### 10. [Memory](10_memory.md)
- Strong References
- When an Object Is Freed
- Reference Cycles
- Weak References
- `RELEASE`
- Regions and Pointers

## Part IV — Programs in the Real World

### 11. [The Standard Library](11_standard_library.md)
- `BNMath`
- `BNString`
- `BNPallet`
- Dates and Times
- Other Modules

### 12. [The HOST](12_host.md)
- Capabilities

### 13. [Files](13_files.md)
- Text Files
- Binary Files
- Restricting File Access: the Sandbox

### 14. [Networking](14_networking.md)
- Design Principles
- Addresses, Networks, and Name Resolution
- TCP: Reliable Streams
- UDP: Independent Datagrams
- ICMP Echo
- HTTP with `BNWeb`
- Interpreter and Compiler Support

### 15. [Concurrency](15_concurrency.md)
- Tasks, Queues, and Tickets
- Coordinating Tasks
- Bounds

### 16. [Debugging and Profiling](16_debugging_and_profiling.md)
- How `bni dap` Works
- Visual Studio Code Integration
- Neovim Integration (`nvim-dap`)
- Classic Vim Integration (`vimspector`)
- Helix Integration
- Debugging Compiled Native Binaries (`bnc`)
- Inspecting Reference Counts (ARC)
- Execution Tracing and Profiling (`bni run`)
- Best Practices for Debugging

## [Appendices](appendices.md)
- Appendix A: [Keywords](21_keywords.md)
- Appendix B: [Language Diagnostics](appendices.md#appendix-b-language-diagnostics)
- Appendix C: [Accepted Syntax (EBNF)](appendices.md#appendix-c-accepted-syntax-ebnf)
- Appendix D: [`bni` and `bnc`](appendices.md#appendix-d-bni-and-bnc)
- Appendix E: [External Module Conventions](appendix_e_external_modules.md)
- Appendix F: [`BNJson`](appendix_f_bnjson.md)
- Appendix G: [`BNLog`](appendix_g_bnlog.md)
- Appendix H: [`BNWeb`](appendix_h_bnweb.md)
- Appendix I: [`BNData`](appendix_i_bndata.md)
- Appendix J: [`BNSqlite`](appendix_j_bnsqlite.md)
- Appendix K: [`BNCrypto`](appendix_k_bncrypto.md)
- Appendix L: [`BNFfi` (C Foreign Function Interface)](appendix_l_bnffi.md)
- Appendix M: [`BNDispatch`](appendix_m_bndispatch.md)

---

[Start reading: Preface →](00_preface.md)
