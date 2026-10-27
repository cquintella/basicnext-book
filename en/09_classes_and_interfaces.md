# Classes and Interfaces

[← Previous: Modules](08_modules.md) · [Contents](toc.md)

The types of Part II describe data. A vector holds values of one type, a `STRUCT` holds named fields, and the functions that work on them live elsewhere in the program, connected to the data only by their parameters. That separation serves well while the data is simple. It serves less well once a value has rules that must always hold — an account balance that changes only through deposits and withdrawals, a counter that only goes up — because any function anywhere can reach into a struct and change a field.

A *class* addresses this by keeping the data and the operations that are allowed on it in one declaration. The fields of an object can be hidden from the rest of the program, and the functions declared inside the class, called *methods*, become the only way to change them. This chapter introduces classes, the visibility of their members, constructors, class-level (`STATIC`) members, inheritance, and interfaces. It leaves one question for [chapter 10](10_memory.md): when an object stops existing.

## Objects Are Shared, Not Copied

The first difference between a class and a struct is what assignment does. Assigning a struct copies its fields ([chapter 6](06_vectors_strings_and_structs.md#value-semantics)); assigning an object copies only a *reference* to it, so that both bindings designate the same object. A class is therefore called a *reference type*, in contrast to the *value types* of Part II.

The following program makes the difference visible. Two bindings refer to one account, and a deposit made through either is seen through both:

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

Each element of the program has a role that the rest of the chapter develops:

* `CLASS Account ... END CLASS` declares the type. Its body lists *fields*, declared like bindings but without `LET`, and *methods*, declared like functions.
* `NEW Account(100)` creates an object of the class and runs its *constructor*, the special method `FUNCTION CONSTRUCTOR`, with the argument `100`. An object is always created this way; there is no literal form for it.
* `alias.Deposit(50)` calls a method. The object before the dot is the one the method works on.
* Inside a method, `SELF` names that object. `SELF.balance` is the `balance` field of whichever account the method was called on.

Because a binding holds a reference, `CONST` applied to an object fixes the reference, not the object. A constant that holds an account cannot be made to designate a different account, but nothing prevents the account itself from receiving a deposit. Whether an object can change is decided by the class, through the visibility of its members, which is the subject of the next section.

## Visibility and `SELF`

Every member of a class — field or method — has a visibility that decides which code may use it. There are three levels:

* `PRIVATE`, the default, restricts the member to the methods of the class itself.
* `PUBLIC` makes the member available to any code that holds the object.
* `PROTECTED` makes the member available to the class and to the classes that extend it ([Inheritance](#inheritance) below), including subclasses declared in other modules, and to nothing else.

The default is the restrictive one deliberately. A field that no outside code can reach can only change through the methods of its class, and those methods are the one place where the class's rules need to be enforced. The `Account` above made `balance` public to keep the first example short; a more careful class keeps its state private and offers methods instead:

```basic
CLASS Counter
    PRIVATE count AS INTEGER = 0

    PUBLIC FUNCTION CONSTRUCTOR()
    END FUNCTION

    PUBLIC FUNCTION Increment() AS VOID
        SELF.count += 1
    END FUNCTION

    PUBLIC FUNCTION Value() AS INTEGER
        RETURN SELF.count
    END FUNCTION

    PUBLIC FUNCTION SameAs(other AS Counter) AS BOOLEAN
        RETURN SELF.count = other.count
    END FUNCTION
END CLASS

FUNCTION Start() AS VOID
    LET clicks AS Counter = NEW Counter()
    LET views AS Counter = NEW Counter()
    clicks.Increment()
    clicks.Increment()
    views.Increment()
    PRINT clicks.Value(), views.Value()    // 2 1
    PRINT clicks.SameAs(views)             // FALSE
END FUNCTION
```

Outside the class, `clicks.count` is rejected; the only way to change a counter is `Increment`, so a counter can never go down. Privacy belongs to the class, not to the individual object: `SameAs` reads `other.count`, the private field of a different counter, and that is allowed because the code reading it is a method of `Counter`.

Reaching a member from code that may not see it is a compile-time error that names the member and its level:

```
error[PRIVATE_ACCESS]: Private member access: member 'K.v' is PRIVATE
error[PROTECTED_ACCESS]: Protected member access: member 'A.v' is PROTECTED: accessible only from the body of the declaring class or of a class that EXTENDS it
```

Inside a method, a field or another method of the same object is always written with `SELF`: `SELF.count`, never `count` alone. An unqualified name inside a method refers only to parameters, locals, and module-level declarations, and a bare field name is reported as `NAME_NOT_FOUND`. The rule costs a few characters per access, and in return a reader can tell at a glance which names in a method are the object's state and which are temporary values of the call.

## Constructors

A constructor establishes the state of a new object before any other code can see it. It is declared as `FUNCTION CONSTRUCTOR` with a parameter list and no return type, and `NEW` calls it with the arguments written after the class name:

```basic
CLASS Customer
    PRIVATE id AS INTEGER

    PUBLIC FUNCTION CONSTRUCTOR(id AS INTEGER)
        SELF.id = id
    END FUNCTION
END CLASS
```

Here `SELF.id` is the field and `id` the parameter; the two names do not collide, because the field is always reached through `SELF`.

A class has at most one constructor; declaring a second one is a `DUPLICATE_NAME`. When a class needs several ways to be built — from Celsius or from Fahrenheit, from a file or from a string — each way is a `STATIC` factory method, described in the next section, that calls the single constructor.

A class that declares no constructor receives an implicit one, which takes no parameters and is `PRIVATE`. The consequence is intentional: no code outside the class can create its objects until the class says how they are to be created. A class meant to be instantiated by others therefore declares a `PUBLIC` constructor, even an empty one, as the `Counter` above does. Without it, `NEW` is rejected:

```
error[PRIVATE_ACCESS]: Private member access: CLASS 'K' has only an implicit PRIVATE constructor
```

A class may also declare a destructor, `FUNCTION DESTRUCTOR()`, with no parameters and no return type. It runs exactly once, when the object is freed. When that happens is determined by the memory model and is explained in [chapter 10](10_memory.md), where destructors are used to make it visible.

## Class Members: `STATIC`

Some state belongs to a class as a whole rather than to any one of its objects: the number of tickets issued so far, a cache shared by every instance, the next identifier to hand out. A field declared `STATIC` exists exactly once for the class, however many objects there are, and a `STATIC` method runs without any object at all. Both are reached through the class name:

```basic
CLASS Ticket
    PRIVATE STATIC issued AS INTEGER
    PRIVATE number AS INTEGER = 0

    PUBLIC FUNCTION CONSTRUCTOR()
        Ticket.issued += 1
        SELF.number = Ticket.issued
    END FUNCTION

    PUBLIC FUNCTION Number() AS INTEGER
        RETURN SELF.number
    END FUNCTION

    PUBLIC STATIC FUNCTION Issued() AS INTEGER
        RETURN Ticket.issued
    END FUNCTION
END CLASS

FUNCTION Start() AS VOID
    LET first AS Ticket = NEW Ticket()
    LET second AS Ticket = NEW Ticket()
    PRINT first.Number(), second.Number()    // 1 2
    PRINT Ticket.Issued()                    // 2
END FUNCTION
```

Each new ticket increments the shared counter and records its own number. Three rules follow from what a static member is:

* A static method has no object, so it cannot use `SELF` or read instance fields.
* Static members are always written through the class name, `Ticket.Issued()`, never through an object; `first.Issued()` is a `TYPE_MISMATCH`. The rule keeps the distinction between class state and object state visible at every use.
* A static field without an initializer takes the default of its type, as a `LET` does: `0`, `""`, `FALSE`. Types without a default — pointers, objects, alternative types — must be initialized. If computing the initial value of a static field leads back to the same field, the program stops with `STATIC_INITIALIZATION_CYCLE` rather than letting code observe a half-initialized class.

The most common use of static methods is the *factory*: a named way of creating objects that says what its argument means. The constructor below is `PRIVATE`, so the factories are the only way in:

```basic
CLASS Temperature
    PRIVATE celsius AS FLOAT = 0.0

    PRIVATE FUNCTION CONSTRUCTOR(celsius AS FLOAT)
        SELF.celsius = celsius
    END FUNCTION

    PUBLIC STATIC FUNCTION FromCelsius(value AS FLOAT) AS Temperature
        RETURN NEW Temperature(value)
    END FUNCTION

    PUBLIC STATIC FUNCTION FromFahrenheit(value AS FLOAT) AS Temperature
        RETURN NEW Temperature((value - 32.0) * 5.0 / 9.0)
    END FUNCTION

    PUBLIC FUNCTION Celsius() AS FLOAT
        RETURN SELF.celsius
    END FUNCTION
END CLASS

FUNCTION Start() AS VOID
    LET boiling AS Temperature = Temperature.FromFahrenheit(212.0)
    LET body AS Temperature = Temperature.FromCelsius(37.0)
    PRINT boiling.Celsius(), body.Celsius()    // 100.0 37.0
END FUNCTION
```

`NEW Temperature(212.0)` would leave the reader guessing at the scale; `Temperature.FromFahrenheit(212.0)` cannot be misread.

## Inheritance

A class may be declared as an extension of another with `EXTENDS`. The new class, the *subclass*, inherits every field and method of the *base class* and may add its own. Basic Next allows exactly one base class per class (*single inheritance*); a class that needs to promise several capabilities does so with interfaces, described in the next section.

The example below declares a general `Shape`, a `Rectangle` that extends it, and a `Square` that extends `Rectangle`:

```basic
CLASS Shape
    PROTECTED name AS STRING = ""

    PUBLIC FUNCTION CONSTRUCTOR(name AS STRING)
        SELF.name = name
    END FUNCTION

    PUBLIC FUNCTION Area() AS FLOAT
        RETURN 0.0
    END FUNCTION

    PUBLIC FUNCTION Describe() AS STRING
        RETURN SELF.name + " with area " + (SELF.Area() AS STRING)
    END FUNCTION
END CLASS

CLASS Rectangle EXTENDS Shape
    PRIVATE width AS FLOAT = 0.0
    PRIVATE height AS FLOAT = 0.0

    PUBLIC FUNCTION CONSTRUCTOR(width AS FLOAT, height AS FLOAT)
        SUPER("rectangle")
        SELF.width = width
        SELF.height = height
    END FUNCTION

    PUBLIC OVERRIDE FUNCTION Area() AS FLOAT
        RETURN SELF.width * SELF.height
    END FUNCTION
END CLASS

CLASS Square EXTENDS Rectangle
    PUBLIC FUNCTION CONSTRUCTOR(side AS FLOAT)
        SUPER(side, side)
        SELF.name = "square"
    END FUNCTION
END CLASS

FUNCTION Start() AS VOID
    LET plain AS Shape = NEW Shape("shape")
    LET wide AS Shape = NEW Rectangle(4.0, 2.5)
    LET even AS Shape = NEW Square(3.0)
    PRINT plain.Describe()    // shape with area 0.0
    PRINT wide.Describe()     // rectangle with area 10.0
    PRINT even.Describe()     // square with area 9.0
END FUNCTION
```

Four mechanisms are at work.

**Constructors chain through `SUPER`.** A subclass constructor first calls the constructor of its base class with `SUPER(...)`, so that the inherited part of the object is set up by the class that understands it. `Rectangle` passes its name to `Shape`; `Square` passes its side twice to `Rectangle`. When the base class declares a constructor, a subclass constructor that omits the call is rejected with `INVALID_SUPER`.

**`PROTECTED` opens a member to subclasses only.** `name` is invisible to `Start`, but `Square` may assign it, because `Square` extends `Shape`.

**A subclass object can be used wherever its base class is expected.** `wide` is declared as a `Shape` and holds a `Rectangle`. The assignment needs no conversion, because every rectangle is a shape; this direction of conversion is called an *upcast*.

**Methods are dispatched by the object, not by the binding.** `Rectangle` redefines `Area`, and the redefinition is marked `OVERRIDE`. When `Describe`, a method written once in `Shape`, calls `SELF.Area()`, the method that runs is the one of the object's actual class: `0.0` for the plain shape, `10.0` for the rectangle. `Square` declares no `Area` of its own and therefore inherits the one of `Rectangle`. This behaviour, *dynamic dispatch*, is what lets general code such as `Describe` work with kinds of shape that did not exist when it was written.

The `OVERRIDE` marker is required, and its absence is an error rather than a silent redefinition. The rule protects against two common mistakes: redefining an inherited method by accident, through a name that happened to be free, and believing a method overrides one that the base class does not actually have:

```
error[OVERRIDE_REQUIRED]: OVERRIDE marker required: 'B.S' overrides an inherited method: mark it OVERRIDE (PUBLIC OVERRIDE FUNCTION S)
error[OVERRIDE_WITHOUT_BASE]: OVERRIDE without a base method: 'A.S' is marked OVERRIDE but 'A' does not EXTEND a class
```

`STATIC` methods belong to a class rather than to an object and are therefore never dispatched dynamically. The opposite of an upcast — recovering a `Rectangle` from a binding declared as `Shape` — is specified by the language but not yet available in the 0.6.10 toolchain; a program that needs to tell kinds of object apart should give the base class a method that answers the question.

## Interfaces

Inheritance shares an implementation. Often what a program needs is weaker and more flexible: a guarantee that several unrelated classes all provide certain methods, so that one piece of code can work with any of them. An `INTERFACE` states such a guarantee. It is a named list of method signatures, with no fields, no constructor, and no bodies; its members are implicitly public.

A class promises to satisfy one or more interfaces with `IMPLEMENTS`, followed by a comma-separated list of names, which may come from other modules (`IMPLEMENTS Pets.Named`). The compiler then checks that the class has a `PUBLIC` instance method for every signature of every interface, with the same parameters and return type.

```basic
INTERFACE Printable
    FUNCTION Render() AS STRING
END INTERFACE

CLASS Report IMPLEMENTS Printable
    PRIVATE title AS STRING = ""

    PUBLIC FUNCTION CONSTRUCTOR(title AS STRING)
        SELF.title = title
    END FUNCTION

    PUBLIC FUNCTION Render() AS STRING
        RETURN "Report: " + SELF.title
    END FUNCTION
END CLASS

CLASS Invoice IMPLEMENTS Printable
    PRIVATE amount AS INTEGER = 0

    PUBLIC FUNCTION CONSTRUCTOR(amount AS INTEGER)
        SELF.amount = amount
    END FUNCTION

    PUBLIC FUNCTION Render() AS STRING
        RETURN "Invoice: " + (SELF.amount AS STRING)
    END FUNCTION
END CLASS

FUNCTION PrintAll(documents AS Printable[2]) AS VOID
    FOR EACH document AS Printable IN documents
        PRINT document.Render()
    END FOR
END FUNCTION

FUNCTION Start() AS VOID
    LET documents AS Printable[2] = [NEW Report("Q3"), NEW Invoice(250)]
    PrintAll(documents)
END FUNCTION
```

```
Report: Q3
Invoice: 250
```

`Report` and `Invoice` share no base class and no code, yet `PrintAll` handles both, because both promise `Render`. An interface name is a type: a binding, a parameter, or a vector element of type `Printable` may hold an object of any class that implements it. Through such a binding only the interface's members are visible; `document.title` would be rejected even when the object is a `Report`. As with base classes, the conversion back from an interface to a concrete class is not available.

The vector literal shows a further rule. Where a vector type is declared, each element is checked against the declared element type, so `NEW Report("Q3")` and `NEW Invoice(250)` are each upcast to `Printable`. A literal written without a declared type, such as the argument of `LEN`, takes the type of its first element instead, and every other element must be assignable to it.

A class that promises an interface and fails to provide one of its methods, or provides it with a different signature, is rejected where the class is declared:

```
error[TYPE_MISMATCH]: Type mismatch: Expected PUBLIC instance FUNCTION Render matching P, but found missing/private/static/incompatible implementation in interface implementation.
```

## Exporting a Class

A class is shared between modules like any other declaration, with `EXPORT CLASS` ([chapter 8](08_modules.md)). Exporting and visibility answer different questions, and a class needs both: `EXPORT` makes the class name usable in other modules, while `PUBLIC` decides which of its members those modules may use. In particular, the implicit constructor of a class that declares none is `PRIVATE`, so an exported class must declare a `PUBLIC` constructor before other modules can create its objects (both files are in [`examples/ch09-exported-class/`](../examples/ch09-exported-class/)):

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
    PRINT c.Twice(21)    // 42
END FUNCTION
```

The imported class is written through the module alias, `Lib.Counter`, in the type of the binding and after `NEW` alike. Without the `PUBLIC FUNCTION CONSTRUCTOR()`, the `NEW` in `main.bn` is rejected:

```
error[PRIVATE_ACCESS]: Private member access: CLASS 'Counter' has only an implicit PRIVATE constructor
```

## Diagnostics Introduced in This Chapter

| Diagnostic | Raised when |
| --- | --- |
| `PRIVATE_ACCESS` | A `PRIVATE` member, or the implicit `PRIVATE` constructor, is used from outside the class. |
| `PROTECTED_ACCESS` | A `PROTECTED` member is used from outside the class and its subclasses. |
| `INVALID_SUPER` | A subclass constructor does not call the constructor of its base class with `SUPER(...)`. |
| `OVERRIDE_REQUIRED` | A method overrides an inherited one without `OVERRIDE`. |
| `OVERRIDE_WITHOUT_BASE` | A method is marked `OVERRIDE` but no ancestor declares it. |
| `DUPLICATE_NAME` | A class declares a second constructor. |
| `STATIC_INITIALIZATION_CYCLE` | The initialization of a static field re-enters itself at run time. |
| `TYPE_MISMATCH` | A class does not satisfy an interface it names; a static member is reached through an object; a vector literal element is not assignable to the declared element type. |
| `NAME_NOT_FOUND` | A method names a field without `SELF`. |

## Summary

A class joins data with the operations allowed on it, and an object of a class is shared by reference rather than copied. Members are `PRIVATE` unless declared otherwise, so the methods of a class are the only code that can change its private state, and every access to that state is written through `SELF`. A class has one constructor, which `NEW` runs; alternative ways of building objects are `STATIC` factory methods, and `STATIC` fields hold state that belongs to the class as a whole. A class may extend one base class, chaining constructors with `SUPER` and marking each redefined method `OVERRIDE`; calls are dispatched according to the object's actual class. An interface names a set of methods that unrelated classes can promise to provide, and the interface name can then be used as a type.

All of this concerns what an object is and what it can do. The next chapter turns to its lifetime: when the memory of an object is reclaimed, and how a program controls it.

---

[Next: Memory →](10_memory.md)
