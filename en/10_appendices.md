# Appendices

[← Previous: Architecture](17_architecture.md) · [Contents](toc.md)

Because Basic Next specifies behavior transparently, the exact language specifications and technical lists are maintained in their respective normative files within the repository.

## Appendix A: Keywords

The reading manual is [Appendix A](21_keywords.md). A pair the grammar writes together, such as `END FUNCTION` or `END FOR`, is one entry.

Keywords in a program are written in uppercase (`FOR`, `IF`, `WHILE`). Any other ASCII spelling of those letters (`for`, `For`, `fOR`) is a reserved identifier and cannot name a binding, a type, or a member. The normative registry is [`keywords.md`](../../../language/0.6/keywords.md).

## Appendix B: Language Diagnostics

Basic Next is designed with a zero-warning policy. Diagnostics either reject the source entirely or report a clear runtime failure.

Diagnostic behavior follows the accepted language contract and command
reference:

* [0.6 language specification](../../../language/0.6/0.6.md)
* [`bni(1)`](../../man/bni.1) and [`bnc(1)`](../../man/bnc.1)

## Appendix C: Accepted Syntax (EBNF)

The structural grammar of Basic Next is strictly defined using Extended Backus-Naur Form (EBNF). The EBNF focuses exclusively on parsing valid syntax, while semantic rules (such as return analysis) are enforced by the compiler.

The normative grammar for the 0.6 line is:

* [`0.6.ebnf`](../../../language/0.6/0.6.ebnf) — grammar
* [`0.6.md`](../../../language/0.6/0.6.md) — semantics
* [`keywords.md`](../../../language/0.6/keywords.md) — reserved words

## Appendix D: `bni` and `bnc`

`bni` interprets and checks a program. `bnc` compiles it to a native binary.
Their manuals are [`bni(1)`](../../man/bni.1) and [`bnc(1)`](../../man/bnc.1).
Installation and troubleshooting are in
[`docs/project/usage.md`](../../project/usage.md). The normative language text
is [`0.6.md`](../../../language/0.6/0.6.md).

External provider-backed modules are documented in separate appendices:

- [`BNJson`](11_bnjson.md)
- [`BNLog`](12_bnlog.md)
- [`BNWeb`](13_bnweb.md)
- [`BNData`](14_bndata.md)
- [External module conventions](15_external_modules.md)
- [`BNDispatch`](16_bndispatch.md)
- [`BNCrypto`](18_bncrypto.md)
- [`BNSqlite`](19_bnsqlite.md)
- [Debugging (`bni dap`)](20_debugging.md)

---

[Next: Appendix E: BNJson →](11_bnjson.md)
