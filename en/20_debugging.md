# Appendix M: Debugging Basic Next (`bni dap`)

[← Previous: Appendix L: BNSqlite](19_bnsqlite.md) · [Contents](toc.md)

Debugging in Basic Next is built around an industry-standard foundation: the **Debug Adapter Protocol (DAP)**. Rather than requiring developers to learn a proprietary debugger tool or interface, Basic Next provides an in-process DAP server through the interpreter:

```shell
bni dap
```

For 95% of daily software development, the interpreter (`bni`) serves as the primary development and debugging environment. Through `bni dap`, any modern editor or IDE—including Visual Studio Code, Neovim, Vim, and Helix—connects directly to the running program over standard I/O, providing interactive line-by-line debugging, breakpoint management, stack inspection, and variable watches.

---

## 1. How `bni dap` Works

The Debug Adapter Protocol (originally designed by Microsoft and now an open standard) decouples editor user interfaces from runtime debuggers using JSON-RPC messages framed with `Content-Length` headers over `stdin` and `stdout`.

When an editor launches a debugging session:
* The editor spawns `bni dap` as a child process.
* The editor sends an `initialize` request and receives the adapter's capabilities.
* The developer's breakpoints are transmitted via `setBreakpoints` before execution starts.
* The editor sends a `launch` request pointing to the entry file (e.g. `program.bn`).
* The interpreter (`bn_interp`) pauses execution whenever an active breakpoint line is reached or during single-step operations (`next`, `stepIn`, `stepOut`).
* While paused, the editor queries the call stack (`stackTrace`), scope boundaries (`scopes`), and current runtime bindings (`variables`).

---

## 2. Visual Studio Code Integration

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

## 3. Neovim Integration (`nvim-dap`)

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

## 4. Classic Vim Integration (`vimspector`)

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

## 5. Helix Integration

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

## 6. Debugging Compiled Native Binaries (`bnc`)

While `bni dap` covers 95% of everyday development and unit testing, compiled native binaries produced by `bnc` operate at machine level.

* **Current Status:** Binaries compiled with `bnc -o <output>` link directly against the native runtime library (`bn_rt`) and are executable system binaries (Mach-O, ELF, or Windows PE).
* **Native Tooling:** Because they are native executables, external performance and diagnostics tools—including **Instruments** (macOS), **perf** (Linux), **Valgrind**, and **AddressSanitizer**—can analyze execution traces and memory profiles directly.
* **Native Debuggers (LLDB / GDB):** Full source-level line-stepping for compiled binaries requires DWARF debug symbols (`-g`), allowing LLDB or GDB to map CPU instruction addresses back to `.bn` source line spans. DWARF generation is scheduled in the toolchain roadmap (`todo/bucket-typed-llvm-emitter.md`).

---

## 7. Best Practices for Debugging

* **Leverage Checked Conversions:** Basic Next arithmetic is checked against overflow by default. When an unexpected numeric trap occurs during execution, set a breakpoint prior to the calculation and inspect variable values using the Variables panel.
* **Inspect Alternative Types:** For functions returning `T OR Error`, step immediately after the call and observe the narrowed type in the debugger scope before and after `IF result IS Error`.
* **Zero-Warning Diagnostics First:** Always ensure `bni check <file.bn>` reports zero diagnostics before starting an interactive debug session. The debugger assumes syntactically and semantically valid source code.

---

[← Previous: Appendix L: BNSqlite](19_bnsqlite.md) · [Contents](toc.md)
