# Ziglet: A Minimalist, High-Performance Virtual Machine in Zig

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/chrischtel/Ziglet?style=social)](https://github.com/chrischtel/Ziglet)

<img src="docs/logo.svg" alt="Ziglet Logo" width="300">

**Ziglet is a small, fast, and embeddable virtual machine written in Zig.  
Designed for performance and simplicity, Ziglet provides a versatile platform  
for running sandboxed code, game scripting, and more. It is both a playground  
for experimentation with VM internals and a foundation for building lightweight,  
secure applications.**

## Table of Contents

- [Overview](#what-is-ziglet)
- [How Ziglet and Lua Work Together](#how-ziglet-and-lua-work-together)
- [Current Features](#current-features)
- [Getting Started](#getting-started)
- [Examples](#examples)
  - [Basic Arithmetic](#basic-arithmetic)
  - [Memory Operations](#memory-operations)
  - [Control Flow](#control-flow)
- [Current Use Cases](#current-use-cases)
- [Current Development Status](#current-development-status)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgements](#acknowledgements)
- [FAQ](#frequently-asked-questions-faq)
- [Future Roadmap](#future-roadmap)
- [Project Status](#project-status)

---

<a id="what-is-ziglet"></a>
## What is Ziglet?

Unlike full-blown virtual machine hypervisors (such as VirtualBox or Hyper‑V)  
that emulate complete PC hardware to run entire operating systems, Ziglet is an  
*abstract machine*—a minimal, custom CPU with a fixed set of registers and a  
small, predefined instruction set. This means:

- **Fixed Architecture:**  
  Ziglet has 16 general-purpose registers, 64KB of managed memory, and a simple  
  stack-based operation model.
  
- **Minimal Instruction Set:**  
  It supports a limited set of operations (like LOAD, ADD, SUB, CMP, JMP, etc.).  
  Programs must be written or compiled specifically to use these instructions.
  
- **Sandboxed Environment:**  
  Code executed on Ziglet is isolated, ensuring that untrusted or error-prone  
  scripts cannot harm your main application. This makes Ziglet ideal for game  
  scripting, educational purposes, and secure code execution.

---

<a id="how-ziglet-and-lua-work-together"></a>
## How Ziglet and Lua Work Together

A popular use-case for a minimal VM like Ziglet is running game logic written in a  
higher-level language such as Lua. Here’s how the pipeline works:

1. **Script Authoring (Lua):**  
   Game designers write game logic in Lua. For example:
   ```lua
   -- enemy_ai.lua
   function onUpdate()
       local distance = 5 + 10
       if distance < 20 then
           attack()
       else
           flee()
       end
   end
   ```
2. **Compilation/Transpilation:**  
   A separate compiler (or transpiler) converts the Lua code into bytecode understood  
   by Ziglet. This process consists of parsing the Lua script, generating an AST,  
   performing semantic analysis (e.g., mapping variables to registers), and finally  
   outputting a series of low-level instructions. For instance, the arithmetic in the  
   Lua script:
   ```lua
   local distance = 5 + 10
   ```
   might be converted into bytecode like:
   ```zig
   const program = &[_]Instruction{
       .{ .opcode = .LOAD, .dest_reg = 2, .operand1 = 5,  .operand2 = 0 },
       .{ .opcode = .LOAD, .dest_reg = 3, .operand1 = 10, .operand2 = 0 },
       .{ .opcode = .ADD,  .dest_reg = 1, .operand1 = 2,  .operand2 = 3 },
       .{ .opcode = .HALT, .dest_reg = 0, .operand1 = 0,  .operand2 = 0 },
   };
   ```
   (A full implementation would also translate conditionals and function calls into  
   additional instructions.)

3. **Loading and Execution:**  
   The game engine loads this bytecode into Ziglet using the API (e.g., `loadProgram()`)  
   and then starts execution via the `execute()` function.  
   The VM runs the script in a safe, sandboxed environment, and host functions can be  
   registered to allow interaction with the game world (for example, triggering  
   animations or moving game entities).

---

<a id="current-features"></a>
## Current Features

- **Core Architecture:**
  - 16 general-purpose registers
  - 64KB managed memory space
  - Stack-based operations
  - Comprehensive instruction set

- **Instruction Set:**
  - Arithmetic operations (ADD, SUB, MUL, DIV, MOD)
  - Memory operations (LOAD, STORE, MEMCPY)
  - Control flow (JMP, JEQ, JNE, JGT, JLT, JGE)
  - Stack operations (PUSH, POP)
  - Comparison operations (CMP)

- **Debug & Optimization:**
  - Debug mode with instruction tracing
  - Hot path detection
  - Instruction caching
  - Execution statistics
  - Detailed runtime information

- **Memory Management:**
  - Bounds checking
  - Memory protection
  - Safe memory access
  - Resource cleanup

- **Error Handling:**
  - Detailed error contexts
  - Location tracking
  - Actionable suggestions
  - Comprehensive error types

---

<a id="getting-started"></a>
## Getting Started

1. **Fetch Ziglet using Zigs Package Manager**
   ```bash
   zig fetch --save git+github.com/chrischtel/Ziglet.git
   ```

2. **Add Ziglet to your project**
   ```zig
    const ziglet_dep = b.dependency("Ziglet", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("Ziglet", ziglet_dep.module("Ziglet"));
   ```

3. **Check out the examples under `examples/`**

---

<a id="examples"></a>
## Examples

<a id="basic-arithmetic"></a>
### Basic Arithmetic

```zig
const program = &[_]Instruction{
    .{ .opcode = .LOAD, .dest_reg = 1, .operand1 = 5, .operand2 = 0 },
    .{ .opcode = .LOAD, .dest_reg = 2, .operand1 = 10, .operand2 = 0 },
    .{ .opcode = .ADD, .dest_reg = 3, .operand1 = 1, .operand2 = 2 },
    .{ .opcode = .HALT, .dest_reg = 0, .operand1 = 0, .operand2 = 0 },
};
```

<a id="memory-operations"></a>
### Memory Operations

```zig
const program = &[_]Instruction{
    .{ .opcode = .LOAD, .dest_reg = 1, .operand1 = 42, .operand2 = 0 },
    .{ .opcode = .STORE, .dest_reg = 1, .operand1 = 100, .operand2 = 0 },
    .{ .opcode = .LOAD_MEM, .dest_reg = 2, .operand1 = 100, .operand2 = 0 },
    .{ .opcode = .HALT, .dest_reg = 0, .operand1 = 0, .operand2 = 0 },
};
```

<a id="control-flow"></a>
### Control Flow

```zig
const program = &[_]Instruction{
    .{ .opcode = .LOAD, .dest_reg = 1, .operand1 = 0, .operand2 = 0 },
    .{ .opcode = .CMP, .dest_reg = 1, .operand1 = 5, .operand2 = 0 },
    .{ .opcode = .JLT, .dest_reg = 0, .operand1 = 1, .operand2 = 0 },
    .{ .opcode = .HALT, .dest_reg = 0, .operand1 = 0, .operand2 = 0 },
};
```

---

<a id="current-use-cases"></a>
## Current Use Cases

- **Game Scripting:**  
  Run lightweight, sandboxed Lua (or Lua-like) scripts that control game logic and AI behaviors.
  
- **Educational Tool:**  
  Learn about computer architecture, VM internals, and the Zig programming language.
  
- **Code Sandboxing:**  
  Safely execute untrusted code in a strictly controlled virtual environment.
  
- **Embedded Systems:**  
  Perform lightweight computations on constrained devices with minimal resource overhead.

---

<a id="current-development-status"></a>
## Current Development Status

- [x] Core VM implementation
- [x] Basic instruction set
- [x] Memory management
- [x] Stack operations
- [x] Debug support and instruction tracing
- [x] Error handling and detailed runtime information
- [ ] JIT compilation (planned)
- [ ] Garbage collection (planned)
- [ ] Threading support (planned)
- [ ] Network operations (planned)
- [ ] File system access (planned)
- [ ] Standard library (planned)

---

<a id="contributing"></a>
## Contributing

We welcome contributions! Current focus areas:

- Additional instruction set features
- Performance optimizations
- Documentation improvements
- Example programs and tutorials
- Test coverage and robustness

---

<a id="license"></a>
## License

Ziglet is licensed under the [BSD 3-Clause](LICENSE).

---

<a id="acknowledgements"></a>
## Acknowledgements

- The Zig programming language and its vibrant community  
- All contributors and early adopters who have supported Ziglet's development

---

<a id="frequently-asked-questions-faq"></a>
## Frequently Asked Questions (FAQ)

**Q: What exactly is Ziglet?**  
A: Ziglet is a minimalist virtual machine that runs a fixed instruction set. It is not meant for full OS emulation—instead, it’s designed for executing sandboxed code, such as game scripts or experimental language runtimes, within a well-defined, secure environment.

**Q: How does Ziglet compare to other VMs, like Lua’s VM?**  
A: Lua’s VM is designed to execute a rich, high-level bytecode supporting dynamic language features. In contrast, Ziglet is intentionally minimal, with a very basic instruction set (e.g., arithmetic, memory management, control flow). To run Lua on Ziglet, you would compile Lua (or a subset of Lua) into Ziglet’s bytecode, providing a safe and lightweight backend to execute scripts.

**Q: How is game scripting supported?**  
A: Game developers can write game logic in Lua (or a similar language). A separate compiler/transpiler converts the high-level code into Ziglet’s bytecode. This bytecode is then loaded into the VM via our API. Running scripts in this isolated environment keeps the game engine secure while allowing dynamic updates.

**Q: Who builds the Lua compiler?**  
A: While Ziglet defines the bytecode format and provides the VM runtime, the Lua-to-bytecode compiler (or transpiler) is a separate component. We provide documentation and reference specifications so that tool developers can target Ziglet. This separation keeps the VM lean while still supporting powerful, high-level languages.

---

<a id="future-roadmap"></a>
## Future Roadmap

- **JIT Compilation:**  
  Boost performance by translating bytecode directly into native machine code on the fly.

- **Garbage Collection:**  
  Implement automatic memory management for supporting dynamic languages.

- **Threading Support:**  
  Enable concurrent execution of code, allowing complex multitasking.

- **Extended I/O:**  
  Add support for network operations, file system access, and a standard library.

- **Enhanced Instruction Set:**  
  Expand the VM to better support a larger subset of high-level languages, including Lua.

---

<a id="project-status"></a>
## Project Status

**Project Status:** Active development  
**Latest Update:** 16.02.2025  
**Stability:** Beta
