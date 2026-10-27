# Concurrency

[← Previous: Networking](14_networking.md) · [Contents](toc.md)

Basic Next has no threads in the language and gives the reserved word `PARALLEL` no meaning. Work runs concurrently through the `BNDispatch` module: a program creates a *queue* with a bounded number of workers, submits named functions to it with `ASYNC`, and waits for each result with `AWAIT`. Every wait has a timeout, every queue has a size limit, and every failure arrives as an `Error`.

```basic
IMPORT BNDispatch AS Dispatch
```

## Concurrency and Parallelism

Two terms are often used interchangeably and are worth separating. *Concurrency* is a property of a program's structure: it consists of several activities, or *tasks*, whose executions overlap in time, so that one may start before another has finished. *Parallelism* is a property of its execution: several of those activities run at the same instant, on different processors. A concurrent program may run on a single processor, with the tasks taking turns, and it then gains responsiveness — one task can wait for the network while another computes — but not speed. On several processors the same program can also run in parallel and finish sooner.

Concurrency brings a class of defects that sequential programs do not have. When two tasks access the same data and at least one of them changes it, the result can depend on the exact order in which their steps interleave; such a defect is a *race condition*, and because the interleaving differs from run to run, it may appear rarely and be hard to reproduce. The classical remedy is *mutual exclusion*: a *lock* (or *mutex*) ensures that only one task at a time executes the section of code that touches the shared data, its *critical section* (Dijkstra, 1965). Locks bring a hazard of their own, the *deadlock*, in which each of two tasks holds a lock and waits forever for the other's.

The safest way to avoid these defects is not to share mutable data at all, and to let tasks communicate only through well-defined channels (Hoare, 1978). Basic Next is designed on that principle. Each task works on its own copy of the program's state, tasks exchange values only as arguments and results, and the synchronization objects they do share are provided by the library with explicit timeouts, so that a task waiting for a lock that is never released ends with an error instead of hanging the program.

## Tasks, Queues, and Tickets

A task is a function declared `ASYNC FUNCTION`, whose result type is `T OR Error`. `ASYNC queue Fn(args)` submits it to a queue and returns a `Dispatch.Ticket OR Error`; `AWAIT ticket(timeoutMs)` waits for the task and yields its `T OR Error`:

```basic
IMPORT BNDispatch AS Dispatch

ASYNC FUNCTION SumTo(limit AS INTEGER) AS INTEGER OR Error
    LET total AS INTEGER = 0
    FOR n AS INTEGER = 1 TO limit
        total += n
    END FOR
    RETURN total
END FUNCTION

FUNCTION Start() AS INTEGER
    CONST TIMEOUT_MS = 5000
    LET queue AS Dispatch.Queue OR Error = Dispatch.Queue.Concurrent(2)
    IF queue IS Error THEN
        PRINT "queue:", queue.Message
        RETURN 1
    END IF

    LET small AS Dispatch.Ticket OR Error = ASYNC queue SumTo(100)
    LET large AS Dispatch.Ticket OR Error = ASYNC queue SumTo(10000)
    IF small IS Error OR large IS Error THEN
        PRINT "submission failed"
        RETURN 1
    END IF

    LET first AS INTEGER OR Error = AWAIT small(TIMEOUT_MS)
    LET second AS INTEGER OR Error = AWAIT large(TIMEOUT_MS)
    IF first IS Error OR second IS Error THEN
        PRINT "a task failed"
        RETURN 1
    END IF
    PRINT first, second          // 5050 50005000

    small.Close()
    large.Close()
    LET closed AS VOID OR Error = queue.Close(TIMEOUT_MS)
    IF closed IS Error THEN
        RETURN 1
    END IF
    RETURN 0
END FUNCTION
```

`Queue.Concurrent(2)` starts two workers; `Queue.Serial()` starts one, and `Queue.Auto()` one per available processor (see `HOST.NumProcs` in [chapter 12](12_host.md)). Both tasks may run at the same time; `AWAIT` returns each result when it is ready. `queue.Close` cancels pending work and waits for running work to finish; running work is never killed.

A task runs on its own copy of the program's state and shares nothing with the code that submitted it. Its arguments are limited to scalars, `STRING`, the temporal types, and the `BNDispatch` classes themselves; its result to `VOID`, `INTEGER`, `FLOAT`, `STRING`, or `BOOLEAN`. A parameter of another type, such as an object or a vector, is a `TYPE_MISMATCH`. A task must be a named function: there are no closures to submit.

## Coordinating Tasks

Because tasks share no state, they coordinate through objects of `BNDispatch` passed as arguments: a `Mutex`, a `Semaphore`, a `Group`, a `Barrier`, a `Queue`, or a `Ticket` passed to a task names the same object in the worker. Here two tasks take turns on one mutex:

```basic
IMPORT BNDispatch AS Dispatch

ASYNC FUNCTION Report(name AS STRING, lock AS Dispatch.Mutex) AS VOID OR Error
    CONST LOCK_TIMEOUT_MS = 1000
    LET locked AS VOID OR Error = lock.Lock(LOCK_TIMEOUT_MS)
    IF locked IS Error THEN
        RETURN locked
    END IF
    PRINT "task", name, "holds the lock"
    RETURN lock.Unlock()
END FUNCTION

FUNCTION Start() AS VOID
    CONST TIMEOUT_MS = 5000
    LET lock AS Dispatch.Mutex OR Error = Dispatch.Mutex.New()
    LET queue AS Dispatch.Queue OR Error = Dispatch.Queue.Concurrent(2)
    IF lock IS Error OR queue IS Error THEN
        PRINT "setup failed"
        RETURN
    END IF
    LET a AS Dispatch.Ticket OR Error = ASYNC queue Report("a", lock)
    LET b AS Dispatch.Ticket OR Error = ASYNC queue Report("b", lock)
    IF a IS Error OR b IS Error THEN
        PRINT "submission failed"
        RETURN
    END IF
    LET joined AS VOID OR Error = queue.Join(TIMEOUT_MS)
    IF joined IS Error THEN
        PRINT "join failed:", joined.Message
    END IF
    PRINT "both done"
END FUNCTION
```

The two `task ... holds the lock` lines appear in either order, because the tasks run concurrently; `both done` is always last, because `Join` waits for every ticket. A mutex is not re-entrant, and a task that ends while holding one releases it.

## Bounds

To prevent resource exhaustion and unbounded waits:

* a concurrent queue has 1 through 64 workers;
* a queue holds at most 1024 pending tickets (more is `Dispatch.SATURATED`);
* every timeout is 1 through 60,000 milliseconds; an `AWAIT` timeout written as a literal outside that range is the compile-time error `AWAIT_TIMEOUT`;
* a wait that runs past its timeout returns an `Error` with `Code` `Dispatch.TIMEOUT`.

The classes, their members, and the error codes are listed in [Appendix M](appendix_m_bndispatch.md).

## Diagnostics Introduced in This Chapter

| Diagnostic | Raised when |
| --- | --- |
| `AWAIT_TIMEOUT` | An `AWAIT` timeout literal is outside 1 through 60,000 milliseconds. |
| `TYPE_MISMATCH` | A task parameter or result has a type a task cannot carry. |

## Summary

Concurrency in Basic Next is provided by a module, `BNDispatch`, rather than by the language: there are no threads and no mutable state shared between tasks. A task is a named `ASYNC FUNCTION`. `ASYNC queue Fn(args)` submits it to a queue with a fixed number of workers and returns a ticket, and `AWAIT ticket(ms)` waits for its result as `T OR Error`. Tasks run on their own copy of the program's state and coordinate only through the `BNDispatch` objects — mutexes, semaphores, groups, barriers — passed to them as arguments. Every bound, from the number of workers to the length of a queue, is explicit, and every wait has a timeout, so a stalled task produces an error instead of a stalled program.

The last chapter of the book turns from writing programs to finding out why one does not behave as expected.

## References

- Dijkstra, E. W. (1965). *Cooperating Sequential Processes* (EWD 123). Technological University, Eindhoven. https://www.cs.utexas.edu/~EWD/transcriptions/EWD01xx/EWD123.html
- Hoare, C. A. R. (1978). Communicating Sequential Processes. *Communications of the ACM*, 21(8), 666–677. https://doi.org/10.1145/359576.359585

---

[Next: Debugging and Profiling →](16_debugging_and_profiling.md)
