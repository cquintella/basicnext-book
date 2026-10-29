# Appendices

[← Previous: Debugging and Profiling](16_debugging_and_profiling.md) · [Contents](toc.md)

The appendices are reference material, lettered A to N. Appendices B, C, and D are short and live on this page; every other appendix has a page of its own. Links to the normative files of the Basic Next repository are pinned to the `v0.6.10` tag, except the contracts that arrived with 0.6.11.

| Appendix | Subject | Page |
| --- | --- | --- |
| A | Keywords | [21_keywords.md](21_keywords.md) |
| B | Language diagnostics | this page |
| C | Accepted syntax (EBNF) | this page |
| D | `bni` and `bnc` | this page |
| E | External module conventions | [appendix_e_external_modules.md](appendix_e_external_modules.md) |
| F | `BNJson` | [appendix_f_bnjson.md](appendix_f_bnjson.md) |
| G | `BNLog` | [appendix_g_bnlog.md](appendix_g_bnlog.md) |
| H | `BNWeb` | [appendix_h_bnweb.md](appendix_h_bnweb.md) |
| I | `BNData` | [appendix_i_bndata.md](appendix_i_bndata.md) |
| J | `BNSqlite` | [appendix_j_bnsqlite.md](appendix_j_bnsqlite.md) |
| K | `BNCrypto` | [appendix_k_bncrypto.md](appendix_k_bncrypto.md) |
| L | `BNFfi` | [appendix_l_bnffi.md](appendix_l_bnffi.md) |
| M | `BNDispatch` | [appendix_m_bndispatch.md](appendix_m_bndispatch.md) |
| N | `BNCompress` | [appendix_n_bncompress.md](appendix_n_bncompress.md) |

Appendix A keeps the file name `21_keywords.md` because the Vim and VS Code extensions download it from that address.

## Appendix A: Keywords

The reading manual is [Appendix A](21_keywords.md). A pair the grammar writes together, such as `END FUNCTION` or `END FOR`, is one entry. The normative registry is [`keywords.md`](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/keywords.md).

## Appendix B: Language Diagnostics

A diagnostic either rejects the source before it runs, or stops a running program with a clear runtime failure. Each code below is introduced in the chapter listed, with the rule it enforces and an example of the message. The normative definitions are in the [0.6 language specification](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/0.6.md) and the manuals [`bni(1)`](https://github.com/cquintella/BasicNext/blob/v0.6.10/man/bni.1) and [`bnc(1)`](https://github.com/cquintella/BasicNext/blob/v0.6.10/man/bnc.1).

### Reported before the program runs

| Code | Meaning | Introduced in |
| --- | --- | --- |
| `E0001` | Lexical error: a malformed literal, an unsupported escape, a control character or line break in a string. | [Chapter 2](02_values_types_and_variables.md) |
| `E0100` | Syntax error: an expected construct is missing, such as a statement outside a function. | [Chapter 1](01_getting_started.md) |
| `E0101` | Syntax error: a construct is complete but breaks a rule of the grammar. | [Chapter 1](01_getting_started.md) |
| `TYPE_MISMATCH` | A value of one type is used where another is required. | [Chapter 1](01_getting_started.md) |
| `NAME_NOT_FOUND` | A name is not declared, or a module does not export it. | [Chapter 2](02_values_types_and_variables.md) |
| `DUPLICATE_NAME` | A name is declared twice in the same scope, or shadows a visible one. | [Chapter 4](04_control_flow.md) |
| `INVALID_LOOP_CONTROL` | `EXIT` or `CONTINUE` names a loop that does not enclose it. | [Chapter 4](04_control_flow.md) |
| `MISSING_RETURN` | A non-`VOID` function can reach its end without `RETURN`. | [Chapter 5](05_functions.md) |
| `MODULE_NOT_FOUND` | No directory of the module search path holds the imported file. | [Chapter 8](08_modules.md) |
| `IMPORT_EXPORT_NOT_FOUND` | A dotted import names neither an exported type nor a nested module. | [Chapter 8](08_modules.md) |
| `IMPORT_CYCLE` | The imports form a cycle. | [Chapter 8](08_modules.md) |
| `PRIVATE_ACCESS` | A `PRIVATE` member or the implicit constructor is used from outside its class. | [Chapter 9](09_classes_and_interfaces.md) |
| `PROTECTED_ACCESS` | A `PROTECTED` member is used outside its class and subclasses. | [Chapter 9](09_classes_and_interfaces.md) |
| `INVALID_SUPER` | A subclass constructor does not call its base constructor with `SUPER(...)`. | [Chapter 9](09_classes_and_interfaces.md) |
| `OVERRIDE_REQUIRED` | A method overrides an inherited one without `OVERRIDE`. | [Chapter 9](09_classes_and_interfaces.md) |
| `OVERRIDE_WITHOUT_BASE` | A method is marked `OVERRIDE`, but no ancestor declares it. | [Chapter 9](09_classes_and_interfaces.md) |
| `INVALID_RELEASE_TARGET` | `RELEASE` names an element, a field, or a static field. | [Chapter 10](10_memory.md) |
| `AWAIT_TIMEOUT` | An `AWAIT` timeout literal is outside 1 through 60,000 milliseconds. | [Chapter 15](15_concurrency.md) |
| `TARGET_UNSUPPORTED_HOST` | `bnc` cannot compile a host operation for the target. | [Chapter 12](12_host.md) |

### Reported while the program runs

| Code | Meaning | Introduced in |
| --- | --- | --- |
| `NUMERIC_OVERFLOW` | An integer operation or conversion leaves the range of its type. | [Chapter 2](02_values_types_and_variables.md) |
| `INDEX_OUT_OF_BOUNDS` | An index is outside a string, a vector, or a region. | [Chapter 2](02_values_types_and_variables.md) |
| `INVALID_VECTOR_DIMENSION` | A vector dimension computed at run time is negative. | [Chapter 6](06_vectors_strings_and_structs.md) |
| `DIVISION_BY_ZERO` | The divisor of `/`, `DIV`, or `%` is zero. | [Chapter 3](03_operators_and_conversions.md) |
| `INVALID_NUMERIC_CONVERSION` | `NAN` or an infinity is converted to an integer type. | [Chapter 3](03_operators_and_conversions.md) |
| `STATIC_INITIALIZATION_CYCLE` | A static field's initialization re-enters itself. | [Chapter 9](09_classes_and_interfaces.md) |
| `USE_AFTER_RELEASE` | A binding is used after `RELEASE`. | [Chapter 10](10_memory.md) |
| `DOUBLE_RELEASE` | A binding is released twice. | [Chapter 10](10_memory.md) |
| `NULL_POINTER_ACCESS` | A pointer that holds no region is read or written. | [Chapter 10](10_memory.md) |
| `POINTER_TYPE_MISMATCH` | An opaque pointer is restored to an incompatible element type. | [Chapter 10](10_memory.md) |
| `POINTER_LENGTH_MISMATCH` | An opaque pointer is restored to a fixed length that differs. | [Chapter 10](10_memory.md) |
| `INVALID_DATE`, `INVALID_TIME`, `INVALID_TIMEZONE`, `PARSE_ERROR` | Temporal text does not match its standard form. | [Chapter 11](11_standard_library.md) |
| `HOST_CAPABILITY_UNAVAILABLE` | The host refuses a capability, or an operation needs a terminal it does not have. | [Chapter 12](12_host.md) |
| `CONFIG_INVALID` | A policy environment variable holds a value the runtime does not recognise. | [Chapter 13](13_files.md) |

Failures of library and host operations — a missing file, a refused connection, a timeout — are not diagnostics: they are `Error` values the program handles ([chapter 7](07_alternatives_and_errors.md#errors)).

## Appendix C: Accepted Syntax (EBNF)

The grammar of Basic Next is defined in Extended Backus-Naur Form. The EBNF defines which programs parse; semantic rules, such as return analysis, are enforced by the compiler and stated in the specification.

* [`0.6.ebnf`](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/0.6.ebnf) — grammar
* [`0.6.md`](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/0.6.md) — semantics
* [`keywords.md`](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/keywords.md) — reserved words

## Appendix D: `bni` and `bnc`

`bni` checks and interprets a program; `bnc` compiles it to a native binary; `bnr` is the interactive read-eval-print loop. Their manuals are [`bni(1)`](https://github.com/cquintella/BasicNext/blob/v0.6.10/man/bni.1) and [`bnc(1)`](https://github.com/cquintella/BasicNext/blob/v0.6.10/man/bnc.1). [Chapter 1](01_getting_started.md) introduces the commands; installation, documentation, and releases are at [http://basicnext.org](http://basicnext.org) and in the project [`README.md`](https://github.com/cquintella/BasicNext/blob/v0.6.10/README.md).

---

[Next: Appendix A: Keywords →](21_keywords.md)
