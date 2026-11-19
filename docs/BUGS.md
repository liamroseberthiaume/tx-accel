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


---

## BUG-003: Icarus Verilog Pipeline Compilation Compatibility

**Date:** November 14, 2026  
**Milestone:** M1, Systolic Array  
**Status:** Resolved for the tested 2x2 configuration

### Problem

When compiling the systolic array, Icarus Verilog reported:

`Unable to assign words of unresolved wire array.`

After modifying the code, compilation succeeded but repeatedly produced:

`sorry: constant selects in always_* processes are not currently supported (all bits will be included).`

### Root Cause

The initial implementation mixed continuous assignments
and clocked procedural assignments within unpacked
pipeline arrays, which Icarus Verilog could not elaborate.

Changing the stage-zero assignments to `always_comb`
resolved the elaboration errors, but exposed an Icarus
Verilog limitation involving constant bit selections.

### Debugging Process

1. Compiled the parameterized systolic array.
2. Identified 10 elaboration errors.
3. Replaced the stage-zero continuous assignments
   with procedural combinational assignments.
4. Confirmed the elaboration errors disappeared.
5. Investigated the remaining constant-select diagnostics.
6. Located the affected blocks at lines 66 and 125.
7. Replaced `always_comb` with `always @*`.

### Resolution

Used `always @*` for the combinational stage-zero
assignments in both A and B input pipelines.

This eliminated the Icarus Verilog diagnostics
without changing the intended pipeline delays.

### Verification

- Icarus Verilog compilation: PASSED
- Constant-select diagnostics: Eliminated
- 2x2 matrix multiplication: PASSED
- Expected output: [[19, 22], [43, 50]]
- Completion timing: PASSED
- Larger configurations: Require regression after this change

### Lessons Learned

- Simulator compatibility can influence RTL coding style.
- Successful compilation and correct functionality are
  separate verification requirements.
- Small RTL changes require regression testing.
- Compiler diagnostics should be investigated rather
  than automatically ignored.


---

## BUG-004: Yosys Parameterized Synthesis Assertion

**Date:** November 14, 2026
**Milestone:** M1, Systolic Array
**Status:** Workaround verified for N=1

### Problem

Yosys 0.33 encountered an internal assertion failure
when synthesizing the parameterized systolic array:

ERROR: Assert `modules.count(module->name) == 0'
failed in kernel/rtlil.cc:664.

### Investigation

The original synthesis command used:

hierarchy -check -top systolic_array -chparam N 1

This caused the internal assertion failure during
parameterized module elaboration.

The underlying cause within Yosys has not been
confirmed.

### Resolution / Workaround

Changed parameter configuration to use the
dedicated `chparam` command:

chparam -set N 1 systolic_array

Followed by:

synth -top systolic_array
check -assert
stat

### Verification

- Yosys version: 0.33
- N=1 synthesis: PASSED
- N=2 synthesis: PASSED
- N=4 synthesis: PASSED
- N=8 synthesis: PASSED
- Structural problems: 0 for all configurations
- N=1 exit code: 0
- N=8 synthesis reached End of script
- Internal assertion avoided using `chparam`

### Remaining Warnings

The N=8 synthesis reported 51 unique warnings,
111 occurrences in total.

All N=8 warnings concerned converting unpacked
SystemVerilog arrays into individual signals or
registers.

No additional warning categories were identified.

These warnings are acceptable for the current
synthesis verification.

### Final Status

Workaround verified for N=1, N=2, N=4, and N=8.

The internal cause of the original Yosys assertion
has not been established. No RTL changes were needed.

### Lessons Learned

- Parameterized RTL may expose tool compatibility issues.
- An internal tool assertion is not proof of incorrect RTL.
- Alternative synthesis command sequences can resolve
  tool-specific issues.
- Always verify synthesis success using the exit code
  and structural checks.

### BUG-005: Incorrect Expected Result in 4×4 Backpressure Test

**Milestone:** M2, Step 2.7C  
**File:** `tests/tb/tb_tx_accel_top_4x4.sv`  
**Type:** Testbench verification error  
**Status:** Resolved

**Problem:**  
The integrated 4×4 matrix multiplication successfully verified all 16 output elements, but the subsequent result backpressure test failed with `FAIL: Result not held`.

**Root Cause:**  
The 4×4 testbench was created by copying the existing 2×2 testbench. The backpressure verification still referenced the old 2×2 expected result (`EXPECTED`) instead of the newly calculated 4×4 reference result (`expected_c`).

**Fix:**  
Changed the backpressure comparison from:

`result_c !== EXPECTED`

to:

`result_c !== expected_c`

**Verification:**  
Recompiled and reran the integrated 4×4 accelerator simulation. All 16 matrix elements passed, followed by successful result backpressure and result acceptance checks.

**Lesson Learned:**  
When adapting a testbench for a different hardware configuration, update all expected-result references, not just the primary result checker. A stale reference can cause a false test failure even when the underlying RTL is functioning correctly.

**RTL Changes Required:** None.


## BUG-006: Semicolon

**Status:** Fixed  
**Severity:** Low but frustrating 
**File:** `tests/tb/tb_tx_accel_output_buffering.sv`

### Description
The output-buffering testbench failed to compile because
of a missing semicolon after `$finish`.

The compiler reported a syntax error at line 232,
even though the actual mistake was on line 230.

### Root Cause
The code contained:

```systemverilog
$finish
```

Instead of:

```systemverilog
$finish;
```

### Resolution
Added the missing semicolon and reran the simulation.
All output-buffering tests passed.

### Lessons Learned
- Compiler errors may appear AFTER the actual mistake.
- Always check the preceding line for missing semicolons.
- One character can consume a completely unreasonable
  amount of debugging time.

**Hardware impact:** None  


## BUG-007: The Case of the Doppelgänger Testbench

**Status:** Fixed  
**Severity:** Low  
**Confusion Level:** Astronomical  
**Time Wasted:** Far more than necessary

### Description
During matrix tiling verification, the simulator kept
using outdated expected values despite the code being
corrected and saved multiple times.

VS Code showed the correct values, but the Ubuntu
terminal continued showing the old ones.

### Root Cause
Two copies of the testbench existed:

- `tests/tb/tb_tx_accel_tiling_4x4.sv`
- `tests/tb_tx_accel_tiling_4x4.sv`

VS Code was editing one file while Icarus Verilog
was compiling the other.

Pressing Ctrl+S worked perfectly.
It was just saving the wrong file.

### Resolution
1. Identified the different paths using `realpath`
   and VS Code's Copy Path feature.
2. Opened and corrected the actual compiled file.
3. Deleted the accidental duplicate.
4. Reran the simulation successfully.

### Lessons Learned
- Identical filenames do not mean identical files.
- Always verify the full path when saved changes
  don't appear in simulation.
- Use `realpath` and `grep` to investigate.
- Never underestimate the chaos caused by one
  missing directory in a file path.

**Hardware impact:** None  
**Developer sanity:** Temporarily compromised

**Final Verdict:**
The code was correct.
The save button was innocent.
The wrong file was the impostor.

## BUG-008: The END That Never Ended

**Status:** Fixed  
**Severity:** Low  
**Frustration Level:** High  
**File:** `tests/tb/tb_tx_accel_tiling_4x4.sv`

### Description
During matrix tiling verification, Icarus Verilog
reported a syntax error at line 332, near `endmodule`.

The actual problem was much earlier in the file.

### Root Cause
An `if` statement began with:

```systemverilog
if (result_c !== EXPECTED) begin
```

But the corresponding `end` was missing.

The compiler continued reading until it reached
the end of the module and finally gave up.

### Resolution
Added the missing `end` after the `$fatal` statement.

### Lessons Learned
- A syntax error may be reported far from its cause.
- Every `begin` must have a matching `end`.
- When an error appears at `endmodule`, inspect
  earlier blocks for missing `end` statements.

**Hardware impact:** None  
**Developer frustration:** Considerable

**Final Verdict:**
The compiler reached the end.
Unfortunately, the code never did.

## BUG-009: The Double-Dipping Tile Accumulator

**Status:** Fixed  
**Severity:** Medium  
**File:** `tests/tb/tb_tx_accel_tiling_4x4.sv`

### Description
While adding the first partial-tile accumulation logic,
the same code block was accidentally inserted twice.

Both sections attempted to add the same accelerator
result into the 4x4 result accumulator.

### Root Cause
Duplicate loops performed:

```systemverilog
tiled_c[r][c] = tiled_c[r][c]
    + $signed(result_c[
        (r*N+c)*ACC_WIDTH +: ACC_WIDTH
    ]);
```

If executed twice, this would double-count the
first partial tile and produce incorrect results.

### Resolution
Removed the duplicate accumulation block and
kept one copy after the result verification.

Compilation passed following the correction.
Functional simulation still needs to be rerun.

### Lessons Learned
- Always check for duplicate code when inserting
  new testbench logic.
- A successful compilation does not guarantee
  correct calculations.
- Accumulation logic must execute exactly once
  per intended partial result.

**Hardware impact:** None  
**Verification impact:** Potentially incorrect results

**Final Verdict:**
The accelerator calculated once.
The testbench wanted to collect twice.
Apparently, one correct answer wasn't enough.

