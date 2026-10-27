# Debugging and Profiling

[← Previous: Concurrency](15_concurrency.md) · [Contents](toc.md)

Debugging in Basic Next is built around an industry-standard foundation: the **Debug Adapter Protocol (DAP)**. Rather than requiring developers to learn a proprietary debugger tool or interface, Basic Next provides an in-process DAP server through the interpreter:

```shell
bni dap
```

In everyday development the interpreter (`bni`) serves as the primary development and debugging environment. Through `bni dap`, any modern editor or IDE—including Visual Studio Code, Neovim, Vim, and Helix—connects directly to the running program over standard I/O, providing interactive line-by-line debugging, breakpoint management, stack inspection, and variable watches.

---

## How `bni dap` Works

The Debug Adapter Protocol (originally designed by Microsoft and now an open standard) decouples editor user interfaces from runtime debuggers using JSON-RPC messages framed with `Content-Length` headers over `stdin` and `stdout`.

When an editor launches a debugging session:
* The editor spawns `bni dap` as a child process.
* The editor sends an `initialize` request and receives the adapter's capabilities.
* The developer's breakpoints are transmitted via `setBreakpoints` before execution starts.
* The editor sends a `launch` request pointing to the entry file (e.g. `program.bn`).
* The interpreter (`bn_interp`) pauses execution whenever an active breakpoint line is reached or during single-step operations (`next`, `stepIn`, `stepOut`).
* While paused, the editor queries the call stack (`stackTrace`), scope boundaries (`scopes`), and current runtime bindings (`variables`).

---

## Visual Studio Code Integration

Visual Studio Code provides first-class support for `bni dap` via the official extension or through a project-level launch configuration.

### Extension Setup

The official extension repository is [cquintella/basicnext-vscode](https://github.com/cquintella/basicnext-vscode). When installed, it registers Basic Next syntax highlighting, runs `bni check` diagnostics in the Problems pane, and wires the DAP provider automatically.

### Manual Launch Configuration (`launch.json`)

To configure debugging in any VS Code workspace without external extensions, create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug Basic Next Program",
      "type": "basicnext",
      "request": "launch",
      "program": "${file}",
      "stopOnEntry": false
    }
  ]
}
```

If using a generic DAP launcher (such as Mock Debug or an executable adapter configuration):

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug Basic Next (Custom Adapter)",
      "type": "node",
      "request": "launch",
      "adapterExecutable": {
        "command": "bni",
        "args": ["dap"]
      },
      "program": "${file}"
    }
  ]
}
```

### What You Can Do in VS Code

* **Breakpoints:** Click in the margin (gutter) next to any executable line of code, or press `F9`. A red dot indicates an active breakpoint.
* **Session Control:** Press `F5` to start debugging the active file. Execution proceeds until the first breakpoint is encountered.
* **Stepping Controls:**
  * **Step Over (`F10`):** Advances execution to the next line in the current function without descending into called functions.
  * **Step Into (`F11`):** Steps into the function invoked on the current line.
  * **Step Out (`Shift+F11`):** Resumes execution until the current function returns to its caller.
  * **Continue (`F5`):** Resumes free execution until the next breakpoint or program completion.
  * **Restart (`Ctrl+Shift+F5` / `Cmd+Shift+F5`):** Terminates and re-launches the program cleanly.
* **Variable Inspection:** The **Variables** panel displays all active local bindings in the current stack frame, their static types (`INTEGER`, `STRING`, `FLOAT`, alternative unions, etc.), and their current evaluated values.
* **Call Stack:** The **Call Stack** panel displays the active call hierarchy with function names and source line numbers. Clicking any ancestor frame displays that frame's local variables.

---

## Neovim Integration (`nvim-dap`)

In Neovim, debugging is powered by [`mfussenegger/nvim-dap`](https://github.com/mfussenegger/nvim-dap), the standard DAP client for Lua-configured Neovim setups.

### Configuration (`init.lua`)

Add the adapter and language configuration to your Neovim configuration:

```lua
local dap = require('dap')

-- Define the Basic Next DAP adapter using bni
dap.adapters.basicnext = {
  type = 'executable',
  command = 'bni',
  args = { 'dap' },
}

-- Configure launch settings for Basic Next files
dap.configurations.basicnext = {
  {
    type = 'basicnext',
    request = 'launch',
    name = 'Launch file',
    program = '${file}',
  },
}
```

### Recommended Keymaps

```lua
local dap = require('dap')

vim.keymap.set('n', '<F5>', dap.continue, { desc = 'Debug: Continue / Start' })
vim.keymap.set('n', '<F10>', dap.step_over, { desc = 'Debug: Step Over' })
vim.keymap.set('n', '<F11>', dap.step_into, { desc = 'Debug: Step Into' })
vim.keymap.set('n', '<F12>', dap.step_out, { desc = 'Debug: Step Out' })
vim.keymap.set('n', '<leader>b', dap.toggle_breakpoint, { desc = 'Debug: Toggle Breakpoint' })
vim.keymap.set('n', '<leader>B', function()
  dap.set_breakpoint(vim.fn.input('Breakpoint condition: '))
end, { desc = 'Debug: Set Conditional Breakpoint' })
```

### Visual UI with `nvim-dap-ui`

For a multi-window layout with watches, scopes, stacks, and console windows matching graphical IDEs, combine `nvim-dap` with [`rcarriga/nvim-dap-ui`](https://github.com/rcarriga/nvim-dap-ui):

```lua
local dap, dapui = require('dap'), require('dapui')

dapui.setup()

dap.listeners.after.event_initialized['dapui_config'] = function()
  dapui.open()
end
dap.listeners.before.event_terminated['dapui_config'] = function()
  dapui.close()
end
dap.listeners.before.event_exited['dapui_config'] = function()
  dapui.close()
end
```

---

## Classic Vim Integration (`vimspector`)

In classic Vim 8+ or Neovim without Lua, the standard graphical debugging plugin is [`puremourning/vimspector`](https://github.com/puremourning/vimspector).

Create a `.vimspector.json` file in your workspace root:

```json
{
  "configurations": {
    "BasicNext - Launch": {
      "adapter": {
        "command": [
          "bni",
          "dap"
        ]
      },
      "configuration": {
        "request": "launch",
        "program": "${file}"
      }
    }
  }
}
```

In Vim, pressing `<F5>` initializes `bni dap`, opens split windows for variables, watches, and stack traces, and controls execution using standard Vimspector shortcuts.

---

## Helix Integration

The [Helix editor](https://helix-editor.com/) features built-in DAP support without requiring external plugins.

Add the following to your `~/.config/helix/languages.toml`:

```toml
[[language]]
name = "basicnext"
scope = "source.bn"
injection-regex = "basicnext|bn"
file-types = ["bn"]
comment-token = "//"
indent = { tab-width = 4, unit = "    " }

[language.debugger]
name = "bni-dap"
transport = "stdio"
command = "bni"
args = ["dap"]

[[language.debugger.templates]]
name = "Launch"
request = "launch"
completion = [ { name = "entry", completion = "filename" } ]
args = { program = "{0}" }
```

In Helix, you can use:
* `:debug-start` to initiate the session.
* `F9` / `:breakpoint-toggle` to manage breakpoints.
* `F5` / `:debug-continue` to advance.
* `F10` / `:debug-step-over` to step through statements.

---

## Debugging Compiled Native Binaries (`bnc`)

While `bni dap` covers 95% of everyday development and unit testing, compiled native binaries produced by `bnc` operate at machine level.

* **Current Status:** Binaries compiled with `bnc -o <output>` link directly against the native runtime library (`bn_rt`) and are executable system binaries (Mach-O, ELF, or Windows PE).
* **Native Tooling:** Because they are native executables, external performance and diagnostics tools—including **Instruments** (macOS), **perf** (Linux), **Valgrind**, and **AddressSanitizer**—can analyze execution traces and memory profiles directly.
* **Native Debuggers:** `bnc -g` adds source-level debug information: one entry per function, with the Basic Next name, and a line and column for every instruction. On Linux and macOS it is DWARF (on macOS, `clang` also writes a `.dSYM` bundle next to the executable); on Windows the linker writes a PDB. A debugger can then stop at a line of a `.bn` file:

  ```sh
  $ bnc -g --opt none app.bn -o app
  $ lldb ./app
  (lldb) breakpoint set -f app.bn -l 12
  (lldb) run
  ```

  Use `--opt none` while debugging: with optimization, the code of a line can be folded away or moved, and a breakpoint on it may never stop. Without `-g`, the executable carries no Basic Next debug information.

---

## Inspecting Reference Counts (ARC)

Both toolchains count references in the same ARC core of the runtime ([chapter 10](10_memory.md)), so every view below shows the same objects and counts for `bni` and for a `bnc` executable.

* **Variables panel (`bni dap`):** an object shows its class, its id, and its strong count, for example `Tag#0 (strong 2)`. Expanding it lists its fields and an `[arc]` entry with the id, the strong count, and the generation of its slot. A weak binding shows `→ Tag#0 (alive)` while its object lives and `→ dead (NULL)` after.
* **ARC scope (`bni dap`):** next to **Locals**, the **ARC** scope lists every live object, one line each (`#0  Tag (strong 2)`).
* **Debug console (`bni dap`):** `:arc` lists the live objects; `:arc <variable>` shows the record of the object a variable holds.
* **Trace (both toolchains):** with `BN_ARC_TRACE=1`, every retain, release, and destruction is written to standard error with its source line and column. For this program:

  ```basic
  FUNCTION Start() AS VOID
      LET a AS Tag = NEW Tag("a")
      LET b AS Tag = a
      a = NEW Tag("c")
      PRINT b.name, a.name
  END FUNCTION
  ```

  the trace is (lines 10 to 13 of the file, after the `Tag` class):

  ```text
  arc new Tag#0 strong=1 at 10:20
  arc retain Tag#0 strong=2 at 11:5
  arc new Tag#1 strong=1 at 12:9
  arc release Tag#0 strong=1 at 12:5
  arc release Tag#0 strong=0 at 11:5
  arc destroy Tag#0 strong=0 at 11:5
  arc release Tag#1 strong=0 at 10:5
  arc destroy Tag#1 strong=0 at 10:5
  ```

  `b` is released before `a` at the end of `Start`: locals go in reverse declaration order. Standard output is unchanged, so a trace never mixes with the program's own output.
* **Native debuggers (`bnc -g`):** the runtime exports two functions a debugger can call. `bn_rt_arc_dump()` prints the live objects to standard error, and `bn_rt_arc_info(id)` prints one:

  ```sh
  $ bnc -g --opt none app.bn -o app
  $ lldb ./app
  (lldb) breakpoint set -n bn_rt_arc_release
  (lldb) run
  (lldb) expr (void)bn_rt_arc_dump()
  arc: 1 live object(s)
    Tag#0 strong=1
  ```

  With `gdb`, the same call is `call (void)bn_rt_arc_dump()`.

---

## Execution Tracing and Profiling (`bni run`)

Beyond interactive debugging with DAP and native debugging with `bnc -g`, the interpreter provides built-in facilities for observational execution analysis without pausing program flow.

### Structured Event Tracing (`--trace-events`)

Basic Next includes an event-driven tracing mechanism that streams granular runtime events in NDJSON format (Newline Delimited JSON):

```shell
bni run --trace-events app.trace.ndjson app.bn
```

Each line in the generated trace file corresponds to a single execution event containing timestamp, source span, call depth, and contextual payload:
* **FunctionEntry / FunctionReturn:** Emitted when invoking or returning from functions, recording function names, argument values, and return values.
* **LineChange / Statement:** Emitted as the interpreter transitions across source locations and statements.
* **VariableWrite / VariableRead:** Emitted when local variables are bound, modified, or evaluated.
* **ErrorThrown / ErrorCaught:** Emitted when errors occur and when caught by error handling blocks.

The resulting NDJSON stream can be consumed by external visualization tools, log aggregators, or automated regression analyzers.

### Function Profiling (`--profile`)

To identify execution bottlenecks and analyze time distribution across functions, `bni run` provides a built-in profiler:

```shell
bni run --profile table app.bn
```

When execution completes, a profile table is printed to standard error displaying call counts, self time (time spent strictly inside the function excluding callees), and cumulative time:

```text
Function             Calls       Self (ms)      Total (ms)
----------------------------------------------------------
ComputeFibonacci     10946           12.45           12.45
ProcessDataset           1            1.20           13.65
Start                    1            0.05           13.70
```

For programmatic ingestion or CI pipeline assertions, emit the profile summary in JSON format:

```shell
bni run --profile json app.bn
```

---

## Best Practices for Debugging

* **Leverage Checked Conversions:** Basic Next arithmetic is checked against overflow by default. When an unexpected numeric trap occurs during execution, set a breakpoint prior to the calculation and inspect variable values using the Variables panel.
* **Inspect Alternative Types:** For functions returning `T OR Error`, step immediately after the call and observe the narrowed type in the debugger scope before and after `IF result IS Error`.
* **Zero-Warning Diagnostics First:** Always ensure `bni check <file.bn>` reports zero diagnostics before starting an interactive debug session. The debugger assumes syntactically and semantically valid source code.

## Summary

* `bni dap` serves the Debug Adapter Protocol, so VS Code, Neovim, Vim, and Helix debug a Basic Next program with breakpoints, stepping, and variable inspection.
* `bnc -g` adds debug information for native debuggers; use `--opt none` while debugging.
* `bni run --trace-events` records runtime events as NDJSON, and `--profile` summarizes time per function.

---

[Next: Appendices →](appendices.md)
