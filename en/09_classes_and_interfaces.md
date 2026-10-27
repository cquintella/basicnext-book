# Classes and Interfaces

[← Previous: Modules](08_modules.md) · [Contents](toc.md)

A `STRUCT` ([chapter 6](06_vectors_strings_and_structs.md)) groups fields into a value that is copied on every assignment. A `CLASS` groups fields and the functions that act on them, called methods, into an object that is shared: assigning it copies a reference, not the data. This chapter covers classes, the visibility of their members, constructors, inheritance, and interfaces. When an object is freed is the subject of [chapter 10](10_memory.md).

## Reference Types (`CLASS`)

A `CLASS` defines a reference type. Unlike a struct, assigning a class instance to a new variable does not copy the underlying data; it copies the reference. Both variables will point to the same object in memory.

Class instances are always allocated dynamically using the `NEW` keyword.

```basic
LET customer AS Customer = NEW Customer(10)
```

`Customer` is declared under [Constructors and Destructors](#constructors-and-destructors) below.

A complete program shows the difference from a struct. Two bindings refer to one account, so a deposit made through either is seen through both:

```basic
CLASS Account
    PUBLIC balance AS INTEGER = 0

    PUBLIC FUNCTION CONSTRUCTOR(opening AS INTEGER)
        SELF.balance = opening
    END FUNCTION

    PUBLIC FUNCTION Deposit(amount AS INTEGER) AS VOID
        SELF.balance += amount
    END FUNCTION
END CLASS

FUNCTION Start() AS VOID
    LET mine AS Account = NEW Account(100)
    LET alias AS Account = mine
    alias.Deposit(50)
    PRINT mine.balance, alias.balance    // 150 150
END FUNCTION
```

`NEW Account(100)` creates the object and runs its constructor. `Deposit` is a method, called with a dot on the object. Inside a method, `SELF` is the object the method was called on. The sections below explain each part.

For the same reason, `CONST` fixes a binding, not the object it refers to: a constant holding an object cannot be pointed at a different object, but the object's fields can still change.

## Visibility and `SELF`

By default, all fields and methods within a class are `PRIVATE`. Private members are scoped to the declaring class, meaning any method of that class can access the private members of any instance of that same class.

To make a member available to external code, you must explicitly mark it as `PUBLIC`.

A third level, `PROTECTED`, makes a member visible to the declaring class and to classes that `EXTENDS` it — including subclasses in other modules — and to nothing else; reaching it from outside is `PROTECTED_ACCESS`.

Inside a class method, you cannot access instance fields or methods using an unqualified name. You must always explicitly qualify instance access using the `SELF` keyword.

```basic
CLASS Counter
    PRIVATE count AS INTEGER = 0

    PUBLIC FUNCTION Increment() AS VOID
        SELF.count += 1
    END FUNCTION
END CLASS
```

## Constructors and Destructors

A class can define exactly one constructor to initialize its state. Constructors cannot be overloaded.

The constructor is declared as `FUNCTION CONSTRUCTOR` with an optional parameter list. It does not have a return type and is invoked automatically when `NEW` is called. If you do not declare a constructor, the compiler provides an implicit, parameterless `PRIVATE` constructor.

```basic
CLASS Customer
    PRIVATE id AS INTEGER

    PUBLIC FUNCTION CONSTRUCTOR(id AS INTEGER)
        SELF.id = id
    END FUNCTION
END CLASS
```

You may also define a destructor using `FUNCTION DESTRUCTOR()`. The destructor takes no parameters and has no return type. It runs exactly once, when the object is freed; [chapter 10](10_memory.md) explains when that happens.

## Static Members

Basic Next supports class-level state and behavior through the `STATIC` keyword. A static field exists exactly once per class. If the initializer is omitted, a defaultable type uses the same default as `LET` (`INTEGER` is `0`, `STRING` is `""`, `BOOLEAN` is `FALSE`). Types without a default (`POINTER`, class-typed fields, alternatives) still require `=`. A static method cannot use the `SELF` keyword or access instance fields.

Static members are always accessed through the class name, never through an instance.

```basic
CLASS Session
    PRIVATE STATIC nextId AS INTEGER = 0

    PUBLIC STATIC FUNCTION NextId() AS INTEGER
        Session.nextId += 1
        RETURN Session.nextId
    END FUNCTION
END CLASS

// Accessing the static method
LET id AS INTEGER = Session.NextId()
```

Re-entering the initialization of static fields raises a `STATIC_INITIALIZATION_CYCLE` error at runtime, ensuring partially initialized state is never observable.

Multiple ways to construct a class are expressed with `PUBLIC STATIC FUNCTION` factories that return `NEW` (for example `Temperature.FromFahrenheit(f)`, see [`examples/temperature-factories.bn`](https://github.com/cquintella/BasicNext/blob/v0.6.10/examples/temperature-factories.bn) in the Basic Next repository); a second `CONSTRUCTOR` signature is a static error.

## Inheritance

Basic Next supports single class inheritance using the `EXTENDS` keyword. A subclass inherits the methods and fields of its base class.

If the base class has a constructor, the subclass constructor must call it as the first statement using the `SUPER` keyword.

```basic
CLASS Animal
    PUBLIC FUNCTION Speak() AS VOID
        PRINT "..."
    END FUNCTION
END CLASS

CLASS Dog EXTENDS Animal
    PUBLIC FUNCTION CONSTRUCTOR()
        SUPER()
    END FUNCTION

    PUBLIC OVERRIDE FUNCTION Speak() AS VOID
        PRINT "Woof"
    END FUNCTION
END CLASS
```

A method in the subclass with the same signature as a base-class method overrides it, and is marked `OVERRIDE`. Virtual dispatch ensures the correct method is called at runtime, even when the object is accessed through a base class reference (upcast), across multi-level inheritance hierarchies.

```basic
CLASS Animal
    PUBLIC FUNCTION Speak() AS VOID
        PRINT "..."
    END FUNCTION
END CLASS

CLASS Mammal EXTENDS Animal
    PUBLIC OVERRIDE FUNCTION Speak() AS VOID
        PRINT "Mammal sound"
    END FUNCTION
END CLASS

CLASS Dog EXTENDS Mammal
    PUBLIC FUNCTION CONSTRUCTOR()
        SUPER()
    END FUNCTION

    PUBLIC OVERRIDE FUNCTION Speak() AS VOID
        PRINT "Woof"
    END FUNCTION
END CLASS

LET dog AS Dog = NEW Dog()
LET mammal AS Mammal = dog
LET animal AS Animal = mammal

dog.Speak()    // "Woof"
mammal.Speak() // "Woof"
animal.Speak() // "Woof"
```

A subclass may also inherit an override provided by an intermediate class without overriding it again:

```basic
CLASS GoldenRetriever EXTENDS Dog
    PUBLIC FUNCTION CONSTRUCTOR()
        SUPER()
    END FUNCTION
END CLASS

LET golden AS GoldenRetriever = NEW GoldenRetriever()
LET a AS Animal = golden
a.Speak() // Calls Dog.Speak: prints "Woof"
```

A method that overrides an inherited one must carry `OVERRIDE`, written `PUBLIC OVERRIDE FUNCTION Speak() AS STRING`: `bni check` reports `OVERRIDE_REQUIRED` when the marker is missing and `OVERRIDE_WITHOUT_BASE` when no ancestor declares an overridable method. `STATIC` methods are not virtual. Narrowing a base-typed reference back to a subclass (`pet AS Dog` → `Dog OR Error`) is specified but not yet available.

## Contracts (`INTERFACE` and `IMPLEMENTS`)

An `INTERFACE` is a named public contract consisting only of function signatures. It cannot contain fields, constructors, or implementation bodies. Interface members are implicitly public.

```basic
INTERFACE Printable
    FUNCTION Print() AS VOID
END INTERFACE
```

A class implements one or more interfaces explicitly using the `IMPLEMENTS` keyword followed by a comma-separated list of interface names (which can be imported from other modules, e.g., `IMPLEMENTS Pets.Named`). The class must provide a `PUBLIC` instance method for every required signature, matching the parameter count, types, and return type perfectly.

```basic
CLASS Report IMPLEMENTS Printable
    PUBLIC FUNCTION Print() AS VOID
        PRINT "Report data"
    END FUNCTION
END CLASS
```

An interface name acts as a type. A class reference can be assigned to a variable typed as an interface it implements. This implicit upcast preserves the object reference but restricts access to only the interface's members. Narrowing an interface value back to a concrete class is not available.

The same upcast applies to each element of a vector literal written where a vector type is declared. Here `Report` and `Invoice` both implement `Printable`, so the literal is a `Printable[2]`:

```basic
LET documents AS Printable[2] = [NEW Report(), NEW Invoice()]
FOR i AS INT32 = 0 TO 1
    documents[i].Print()
END FOR
```

Each element is checked against the declared element type, so an element of an unrelated class is a `TYPE_MISMATCH` that names it. A literal without a declared type, such as the argument of `LEN`, takes the type of its first element instead, and every other element must be assignable to it: `LEN([1, 2.5])` is a `TYPE_MISMATCH` naming `2.5`, while `LEN([1.0, 2.5])` is a `FLOAT` vector.

## Exporting a Class

An exported class still controls its own members. `EXPORT` makes the class visible; `PUBLIC` makes a member usable from outside it. A class without a constructor has only an implicit `PRIVATE` one, so no code outside the class, in its own module or another, can use `NEW` on it until it declares a `PUBLIC` one (see [`examples/ch09-exported-class/`](../examples/ch09-exported-class/)):

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

<!-- bn-check: see examples/ch09-exported-class -->
```basic
// main.bn
IMPORT counter AS Lib

FUNCTION Start() AS VOID
    LET c AS Lib.Counter = NEW Lib.Counter()
    PRINT c.Twice(21)
END FUNCTION
```

Without the `PUBLIC FUNCTION CONSTRUCTOR()`, `NEW Lib.Counter()` is `PRIVATE_ACCESS`:

```
error[PRIVATE_ACCESS]: Private member access: CLASS 'Counter' has only an implicit PRIVATE constructor
```

## Diagnostics Introduced in This Chapter

| Diagnostic | Raised when |
| --- | --- |
| `PRIVATE_ACCESS` | A `PRIVATE` member, or the implicit `PRIVATE` constructor, is used from outside the class. |
| `PROTECTED_ACCESS` | A `PROTECTED` member is used from outside the class and its subclasses. |
| `OVERRIDE_REQUIRED` | A method overrides an inherited one without `OVERRIDE`. |
| `OVERRIDE_WITHOUT_BASE` | A method is marked `OVERRIDE` but no ancestor declares it. |
| `STATIC_INITIALIZATION_CYCLE` | The initialization of a static field re-enters itself at run time. |
| `TYPE_MISMATCH` | A class does not satisfy an interface it names; a vector literal element is not assignable to the declared element type. |

## Summary

* A `CLASS` is a reference type: assignment shares the object; `NEW` creates one and runs its single constructor.
* Members are `PRIVATE` unless marked `PUBLIC` or `PROTECTED`, and instance members are always reached through `SELF`.
* `STATIC` members belong to the class and are reached through its name.
* A class extends at most one base class, calls `SUPER()` in its constructor, and marks overriding methods `OVERRIDE`.
* An `INTERFACE` lists method signatures; a class that `IMPLEMENTS` it can be used where the interface type is expected.
* `EXPORT CLASS` makes a class visible to other modules; its constructor must still be `PUBLIC` for them to create objects.

---

[Next: Memory →](10_memory.md)
