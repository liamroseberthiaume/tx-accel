# tx-accel: Bug Log

This document tracks hardware design and verification issues encountered during development, including symptoms, root causes, debugging methods, fixes, and lessons learned.

## BUG-001: Processing Element Reset Failure

**Date:** November 14, 2026  
**Milestone:** M1, Processing Element Verification  
**Status:** Resolved

### Problem

During initial simulation of the processing element (`pe.sv`), the testbench failed its reset verification.

The simulation produced:

```text
FATAL: tests/tb/tb_pe.sv: Initial reset FAILED
```

### Symptoms

All six PE outputs remained unknown (`x`) after reset:

```text
rst_n = 0
acc_out = x
a_out = x
b_out = x
valid_out = x
first_out = x
last_out = x
```

### Root Cause

The `rtl/pe.sv` file contained the module interface but was missing the processing logic.

Specifically, it did not contain:

- The `always_ff` clocked logic block.
- Register reset assignments.
- The signed multiplication logic.
- Accumulator update logic.
- Operand and control-signal forwarding.

The module compiled successfully because a syntactically valid module can have undriven outputs.

### Debugging Process

1. Added diagnostic `$display` statements to the testbench.
2. Confirmed all outputs remained unknown after reset.
3. Inspected `rtl/pe.sv`.
4. Used `grep` to search for `always_ff` and `acc_out <=`.
5. Confirmed the processing logic was missing.

### Resolution

Replaced `rtl/pe.sv` with the complete PE implementation, including signed multiplication, accumulator updates, forwarding registers, and asynchronous reset logic.

Verified the implementation using Icarus Verilog.

**Result:** All 10 directed PE tests passed, including initial and final reset verification.

### Lessons Learned

- Successful compilation does not guarantee correct hardware behaviour.
- Undriven signals may remain unknown during simulation.
- Self-checking testbenches detect incomplete implementations.
- Always verify that source-file changes were saved before compiling.

---

## BUG-002: Duplicate Module Declaration

**Date:** November 14, 2026  
**Milestone:** M1, Processing Element Verification  
**Status:** Resolved

### Problem

During debugging, compilation failed because the module `pe` was declared more than once.

```text
'pe' has already been declared in this scope
```

### Root Cause

Processing-element source code had accidentally been placed in `tests/tb/tb_pe.sv`, creating a duplicate `pe` module declaration.

### Resolution

Restored the correct separation of files:

- `rtl/pe.sv` contains `module pe`, the synthesizable hardware.
- `tests/tb/tb_pe.sv` contains `module tb_pe`, the verification testbench.

Verified module declarations using `grep`, then recompiled the design.

### Lessons Learned

- Keep synthesizable RTL separate from verification code.
- Check module declarations when encountering duplicate-module errors.
- Use distinct module names for hardware and testbenches.

---

## Verification After Fixes

The corrected processing element achieved:

| Verification | Result |
|---|---|
| Directed simulation | 10/10 tests passed |
| Initial and final reset | Passed |
| Signed arithmetic | Passed |
| Operand and flag forwarding | Passed |
| Verilator lint | No warnings |
| Yosys synthesis | 766 generic logic cells |
| Yosys structural check | 0 problems |

## Future Prevention

For subsequent modules:

1. Verify file locations and module declarations before compiling.
2. Compile and run tests together using `&&` to avoid executing stale simulation binaries after compilation failures.
3. Run lint checks before accepting an implementation.
4. Record unexpected failures and their fixes in this document.
5. Commit verified, working versions to GitHub before major design changes.