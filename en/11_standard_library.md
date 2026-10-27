# The Standard Library

[← Previous: Memory](10_memory.md) · [Contents](toc.md)

The language core is deliberately small. Mathematics, string utilities, data formats, logging, HTTP, databases, and cryptography live in standard-library modules whose names begin with `BN`. Each is an ordinary module, imported with an alias as in [chapter 8](08_modules.md), and nothing from it is available until it is imported. This chapter covers the modules most programs use — `BNMath`, `BNString`, and `BNPallet` — and the temporal operations; the full contract of every module is in the appendices.

## Languages and Their Libraries

A *library* is a collection of declarations written once and reused by many programs. Every practical language is used together with one, and the boundary between what a language defines and what its library provides is a design decision. A large core makes common facilities available without ceremony, but every program then carries them, and changing one means changing the language. A small core with a library keeps the language stable and lets each facility evolve, be replaced, or be left out on its own. Basic Next takes the second path: the core defines the types, statements, and `HOST`, and everything else is a module that a program imports only when it needs it. The library that ships with the toolchain is the *standard library*.

## `BNMath`

The mathematics standard library is the `BNMath` module. Every use requires an import; the alias is used for member calls.

```basic
IMPORT BNMath AS Math
LET root AS FLOAT = Math.SQRT(9.0)
LET rounded AS FLOAT = Math.ROUND(3.14159, 2)
LET lower AS FLOAT = Math.FLOOR(3.9)
```

`BNMath` provides strict IEEE 754 implementations for common mathematical functions. Operations return `FLOAT` unless restricted to integers.

The available surface includes:
- Mathematical and exponential functions: `ABS`, `MIN`, `MAX`, `SIGN`, `FLOOR`, `CEIL`, `TRUNC`, `ROUND`, `SQRT`, `HYPOT`, `FMA`, `EXP`, `LOG`, `LOG10`, `LOG2`, `POW`.
- Trigonometry: `SIN`, `COS`, `TAN`, `ASIN`, `ACOS`, `ATAN`, `ATAN2`.
- Text parsing: `VAL(text AS STRING) AS FLOAT`.
- Descriptive statistics: `MEAN`, `MEDIAN`, `MODE`, `STDEV`, `VARIANCE`, `RANGE`, `QUARTILE1`, `QUARTILE3`, the population forms `PVariance` and `PStdev` (divisor `n` instead of `n − 1`), `Quantile(values, p)` (R type 7), the shape measures `Skewness`, `Kurtosis` (excess), `PSkewness` and `PKurtosis`, and `Covariance(x, y)` and `Correlation(x, y)` of two vectors of the same length.
- Range constants: `MAX_INTEGER`, `MIN_INTEGER`, `MAX_FLOAT`, `MIN_FLOAT` (and width-specific variants).
- Constants: the attributes `Pi` and `Euler`, the `FLOAT` values closest to π and e.
- Integer divisors: `Gcd` (greatest common divisor) and `Lcm` (least common multiple), on `INT64`.
- Angles: the methods `DegreeToRad` and `RadToDegree`.

Trigonometry works in radians. `Math.Pi` is the `FLOAT` closest to π, and `DegreeToRad` and `RadToDegree` convert with one multiplication by the fixed ratio π / 180 or 180 / π, so a program gives the same result with `bni` and with `bnc` on every platform:

```basic
IMPORT BNMath AS Math

FUNCTION Start() AS VOID
    PRINT Math.Pi, Math.Euler                                // 3.141592653589793 2.718281828459045
    PRINT Math.DegreeToRad(180.0), Math.DegreeToRad(90.0)    // 3.141592653589793 1.5707963267948966
    PRINT Math.RadToDegree(Math.Pi / 4.0)                    // 45.0
END FUNCTION
```

`Gcd` and `Lcm` work on whole numbers. They take any integer type whose values fit `INT64` and return an `INT64`, exactly; a result too large for `INT64` stops the program with `NUMERIC_OVERFLOW`:

```basic
IMPORT BNMath AS Math

FUNCTION Start() AS VOID
    PRINT Math.Gcd(12, 18), Math.Lcm(4, 6)     // 6 12
    PRINT Math.Gcd(-12, 18), Math.Lcm(0, 5)    // 6 0
END FUNCTION
```

Simplifying the fraction 12/18 divides both parts by `Gcd(12, 18)`, giving 2/3; two schedules that repeat every 4 and every 6 days meet every `Lcm(4, 6)` = 12 days.

The descriptive statistics take a vector or a region of any integer or floating type; integers are converted to `FLOAT` element by element. A `NAN` anywhere in the data makes the result `NAN`.

`MEAN` adds the values in their order with a compensated sum, which keeps the small terms a plain sum would lose against large ones. Infinities decide before any sum: one `INF` makes the mean `INF`, and `INF` together with `-INF` has no mean, so the result is `NAN`:

```basic
IMPORT BNMath AS Math

FUNCTION Start() AS VOID
    LET readings AS FLOAT[4] = [10000000000000000.0, 1.0, -10000000000000000.0, 1.0]
    LET hot AS FLOAT[3] = [20.5, INF, 21.0]
    LET broken AS FLOAT[2] = [INF, -INF]
    PRINT Math.MEAN(readings), Math.MEAN(hot), Math.MEAN(broken)    // 0.5 INF NAN
END FUNCTION
```

A plain left-to-right sum of `readings` gives a mean of `0.25`: the first `1.0` vanishes next to `1e16`, and only the last one survives. If the running sum of finite values grows past the largest `FLOAT`, the mean is `INF` (or `-INF`), so the order of the values can matter at that extreme.

### Numeric Limits

The bounds of the numeric types are constants in the standard `BNMath` module, which must be imported:

```basic
IMPORT BNMath AS Math

FUNCTION Start() AS VOID
    PRINT Math.MIN_INT32, Math.MAX_INT32    // -2147483648 2147483647
    PRINT Math.MIN_INT64, Math.MAX_INT64
    PRINT Math.MIN_FLOAT, Math.MAX_FLOAT
END FUNCTION
```

Reading a bound from `BNMath` rather than writing the number keeps the meaning visible and survives a change of type in the declaration it guards.

## `BNString`

`BNString` is an external module that wraps the primary `STRING` value in the ARC-managed `S.String` object. Import it explicitly when you need fluent string operations:

```basic
IMPORT BNString AS S

LET text AS S.String = NEW S.String("  Olá,BN  ")
LET clean AS S.String = text.Trim()
PRINT clean.LowCaps().ToString()
PRINT clean.Contains("BN")

LET words AS S.Tokenizer OR NULL = clean.Tokenizer(",")
IF words IS S.Tokenizer THEN
    PRINT words.Next()
END IF
```

`Len`/`Length` report Unicode scalar values, `LowCaps` and `HiCaps` perform Unicode-aware case conversion, and `Tokenizer` walks separator-delimited tokens. `S.String` instances follow the same ARC rules as other class objects: strong bindings retain them, scope exit releases them, and weak bindings become `NULL` when the last strong reference is gone. See the full API in [`language/0.6/bnstring.md`](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/bnstring.md) and the runnable [`bnstring_tour.bn`](https://github.com/cquintella/BasicNext/blob/v0.6.10/examples/bnstring_tour.bn).

Note the test on `words`. `Tokenizer` returns `S.Tokenizer OR NULL`, and `IS` names the member being tested; there is no `IS NOT` form, so the code asks for the member it wants to use.

## `BNPallet`

`BNPallet` is the smallest module in the standard library and a useful illustration of what a module can be: it contains no functions at all, only the CSS Color 4 named sRGB colours, exported as `UINT32` constants encoded as `0xRRGGBB`. The aliases that CSS defines, such as `AQUA` and `CYAN` or `GRAY` and `GREY`, are kept as separate names with the same value.

```basic
IMPORT BNPallet AS Color

FUNCTION Start() AS VOID
    LET sky AS UINT32 = Color.SKYBLUE
    LET red AS UINT32 = (sky SHR 16) AND 0xFF
    LET green AS UINT32 = (sky SHR 8) AND 0xFF
    LET blue AS UINT32 = sky AND 0xFF
    PRINT red, green, blue              // 135 206 235
    PRINT Color.AQUA = Color.CYAN       // TRUE
END FUNCTION
```

The value is an opaque number, not a colour object; extracting the channels is ordinary bitwise arithmetic. Because the members are constants, a colour can be used anywhere a `UINT32` literal can, and a misspelled name is a compile-time error rather than a wrong colour at run time.

## Dates and Times

Programs deal with time in two different senses, and confusing them is a common source of defects. An *instant* is a point on a single global time line, independent of where it is observed: the moment a message was sent. *Civil time* is how people in a particular place name instants: a date and a time of day on a calendar, such as 27 October 2026 at 15:30. The relation between the two depends on a *time zone*, a region that follows one set of rules for its offset from Coordinated Universal Time (UTC), including changes for daylight saving time. The same instant is 18:30 in UTC and 15:30 in São Paulo, and a local time such as 02:30 may not exist at all on the night a zone moves its clocks forward. Instants are therefore stored and compared as counts from a fixed origin — conventionally the *Unix epoch*, 1 January 1970 at 00:00 UTC — and converted to civil time only to be read by people, always with an explicit time zone. The rules of every zone are maintained in the IANA Time Zone Database (IANA, 2026), whose identifiers, such as `America/Sao_Paulo`, Basic Next uses.

[Chapter 2](02_values_types_and_variables.md#temporal-types) introduced the four temporal types and their defaults. They keep the distinction between instant and civil time in the types themselves:

* `TIMESTAMP` is an alias for `INT64` that counts milliseconds since the Unix epoch in UTC. It supports ordinary integer arithmetic.
* `DATE` is a Gregorian calendar date, such as `2026-10-27`.
* `TIME` is a time of day, such as `15:30:00.000`.
* `TIMEZONE` is an IANA zone identifier, such as `America/Sao_Paulo` or `UTC`.

None of them has a literal form. A value is built from its standard text form, which is checked when the program runs, and the conversions between an instant and a local calendar value always name the zone:

```basic
FUNCTION Start() AS VOID
    LET day AS DATE = Date.Parse("2026-10-27")
    LET clock AS TIME = Time.Parse("15:30:00.000")
    LET zone AS TIMEZONE = TimeZone.Parse("America/Sao_Paulo")
    LET stamp AS TIMESTAMP = Timestamp.FromLocal(day, clock, zone)

    PRINT day, clock                        // 2026-10-27 15:30:00.000
    PRINT stamp                             // 1793125800000
    PRINT Timestamp.Format(stamp)           // 2026-10-27T18:30:00.000Z
    PRINT Timestamp.AtZone(stamp, zone)     // 2026-10-27T15:30:00.000-03:00
    PRINT TimeZone.Offset(zone, stamp)      // -10800
END FUNCTION
```

`Date.Parse`, `Time.Parse`, `TimeZone.Parse`, and `Timestamp.Parse` stop the program with `INVALID_DATE`, `INVALID_TIME`, `INVALID_TIMEZONE`, or `PARSE_ERROR` when the text is invalid. `Timestamp.Format` writes RFC 3339 in UTC; `Timestamp.AtZone` writes the local time of a zone with its offset; `Timestamp.FromLocal` goes the other way. `TimeZone.Offset` and `TimeZone.IsDST` answer the zone's rules at an instant, daylight saving time included. These functions need no import. The UTC calendar helpers (`TODATE`, `TOTIME`, `TOHOUR`, `TOWEEKDAY`) are in `BNMath`. The current time comes from `HOST.Clock` ([chapter 12](12_host.md)). The full contract is [`temporal.md`](https://github.com/cquintella/BasicNext/blob/v0.6.10/language/0.6/temporal.md).

## Other Modules

The remaining modules are covered by their own appendices:

* `BNJson` — bounded JSON parsing, building, and serialization ([Appendix F](appendix_f_bnjson.md)).
* `BNLog` — structured application and access logging ([Appendix G](appendix_g_bnlog.md)).
* `BNWeb` — HTTP client and server, routes, cookies, sessions, static files ([Appendix H](appendix_h_bnweb.md); introduced in [chapter 14](14_networking.md)).
* `BNData` — CSV and tabular data frames ([Appendix I](appendix_i_bndata.md)).
* `BNSqlite` — embedded SQLite databases ([Appendix J](appendix_j_bnsqlite.md)).
* `BNCrypto` — digests, authenticated encryption, signatures ([Appendix K](appendix_k_bncrypto.md)).
* `BNFfi` — calling C libraries ([Appendix L](appendix_l_bnffi.md)).
* `BNDispatch` — queues, tasks, and synchronization ([Appendix M](appendix_m_bndispatch.md); introduced in [chapter 15](15_concurrency.md)).

All of them follow the conventions of [Appendix E](appendix_e_external_modules.md).

## Diagnostics Introduced in This Chapter

| Diagnostic | Raised when |
| --- | --- |
| `NUMERIC_OVERFLOW` | `Gcd` or `Lcm` produce a result that does not fit `INT64`. |
| `INVALID_DATE`, `INVALID_TIME`, `INVALID_TIMEZONE`, `PARSE_ERROR` | Temporal text does not match its standard form. |

## Summary

The standard library consists of `BN*` modules, each imported with an alias and none available otherwise. `BNMath` provides IEEE 754 mathematics, descriptive statistics, the limits of the numeric types, and constants such as `Pi`, with results that are identical under the interpreter and the compiler. `BNString` wraps text in an object with operations for searching, trimming, case conversion, and tokenizing. `BNPallet` shows that a module may consist of constants alone. Dates and times have no literal form: they are built from their standard text forms, and every conversion between an instant and a local calendar value names its time zone explicitly. The remaining modules, from JSON to SQLite and cryptography, are documented in the appendices.

The next chapter turns from libraries written in Basic Next to the capabilities that only the host can provide.

## References

- IANA (2026). *Time Zone Database*. Internet Assigned Numbers Authority. Continuously updated; accessed October 2026. https://www.iana.org/time-zones

---

[Next: The HOST →](12_host.md)
