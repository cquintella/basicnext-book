# Appendix E: External Module Conventions

[← Previous: Appendix A: Keywords](21_keywords.md) · [Contents](toc.md)

Every `BN*` facility is an external module backed by a host or provider interface, and all of them obey the same small set of rules. An external module is never implicitly available in the language core; it requires an explicit `IMPORT` with an alias; it must report a missing or failing provider as a bounded, deterministic error; it keeps its normative API and its test fixtures separate from the core grammar; and it may be implemented by a Rust provider without any change to Basic Next syntax.

`HOST` is the only built-in interface object in the specification. Everything else in the standard library, from `BNMath` and `BNString` to `BNCrypto`, `BNFfi`, and the constant-only `BNPallet`, follows these rules.

## Module search path

`IMPORT` resolves a module against one ordered list of directories, and the first directory that holds the file wins:

1. the directory of the entry file;
2. the `modules/` subdirectory of that directory, when present;
3. the standard library (`modules/bn` of the installation, or the one the `BN_HOME` environment variable names);
4. the directories in the `module-path` array of `config.toml`;
5. the directories given with `--module-path`, in command-line order.

The same list applies to `bni check`, `bni run`, `bni eval`, and `bnc`. [Chapter 8](08_modules.md#where-the-toolchain-looks-the-module-search-path) explains it with examples.

The standard library ships as `.bn` source. An installed toolchain finds it by walking upward from its own executable and accepting the first of these locations that exists:

- `<prefix>/share/bn/modules/bn`, the FHS location used by the install scripts, beside the diagnostics catalogue;
- `<prefix>/lib/bn/modules/bn`;
- a portable `modules/bn` beside the executable or in the working directory.

A system install therefore places the modules at, for example, `/usr/local/share/bn/modules/bn`, and needs no further configuration. A bare release binary downloaded on its own finds none of these, and then the standard library has to be named explicitly with `--module-path`, as the book's own check script does.

---

[Next: Appendix F: BNJson →](appendix_f_bnjson.md)
