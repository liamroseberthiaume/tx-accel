# tx-accel: INT8 Transformer Inference Accelerator

A SystemVerilog-based hardware accelerator for INT8 transformer inference, developed with a focus on digital design, hardware verification, and performance analysis.

## Project Overview

The goal of tx-accel is to design, implement, and verify a hardware accelerator capable of executing a quantized transformer block.

The accelerator will use a parameterized systolic array for matrix multiplication, along with dedicated hardware for quantization, activation functions, softmax, and layer normalization.

The project is being developed incrementally, with each hardware component tested against expected mathematical behaviour before integration.

**Current status:** Milestone 1 in progress. The processing element has passed its initial directed verification, lint, and synthesis checks.

## Architecture

The planned accelerator includes:

- Parameterized INT8 systolic array with INT32 accumulation
- On-chip operand and output buffers
- Matrix tiling and streaming controller
- APB host interface
- Integer post-processing and nonlinear units
- Command processor for transformer operations
- Performance counters for cycle and utilization analysis

The architecture uses an output-stationary dataflow, where each processing element maintains a local accumulator while input operands move through the array.

## Milestone 1: Processing Element

The first implemented component is a parameterized multiply-accumulate (MAC) processing element.

### Features

- Signed 8-bit multiplication
- Signed 32-bit accumulation
- Configurable operand and accumulator widths
- Clocked operand forwarding
- Valid, first, and last control-signal forwarding
- Accumulator hold during invalid cycles
- Asynchronous active-low reset

The accumulator follows:

`ACC_next = (first_in ? 0 : ACC_current) + (A × B)`

The accumulator updates only when `valid_in` is asserted.

### Verification Results

| Verification | Result |
|---|---|
| Directed SystemVerilog tests | 10/10 passed |
| Initial and final reset | Passed |
| Signed arithmetic and accumulation | Passed |
| Operand and flag forwarding | Passed |
| Verilator lint | No warnings |
| Yosys synthesis | 766 generic logic cells |
| Yosys structural check | 0 problems |

These results apply to the default 8-bit operand and 32-bit accumulator configuration. Randomized verification and full-array integration are still planned.

### Synthesis Statistics

The processing element was synthesized using Yosys 0.33.

- Generic logic cells: 766
- Wire bits: 819
- Memories: 0
- Structural problems: 0

These are generic logic statistics, not technology-mapped physical area measurements.

## Development Tools

- SystemVerilog
- Icarus Verilog
- Verilator
- Yosys
- Python 3
- Cocotb
- NumPy
- pytest
- Ubuntu 24.04 on WSL2
- Visual Studio Code

## Running the Current Tests

From the project root, compile and run the processing element testbench:

```bash
iverilog -g2012 -s tb_pe -o pe_sim rtl/pe.sv tests/tb/tb_pe.sv
vvp pe_sim
```

Run Verilator lint:

```bash
verilator --lint-only -Wall --top-module pe rtl/pe.sv
```

Run Yosys synthesis:

```bash
yosys -p "read_verilog -sv rtl/pe.sv; hierarchy -top pe; synth -top pe; stat"
```

## Development Roadmap

| Milestone | Description | Status |
|---|---|---|
| M1 | Processing element and systolic array | In progress |
| M2 | Streaming, buffers, tiling, APB, UVM | Planned |
| M3 | Quantization and nonlinear operations | Planned |
| M4 | Complete transformer block | Planned |
| M5 | Silicon-style area, timing, power analysis | Planned |
| M6 | FPGA or physical hardware implementation | Optional |

## Verification Philosophy

The project prioritizes correctness and reproducibility.

Development follows an incremental process:

1. Implement hardware functionality.
2. Develop self-checking testbenches.
3. Validate expected outputs.
4. Perform linting and synthesis.
5. Record and resolve bugs.
6. Preserve verified progress through Git.

Future verification will incorporate randomized input generation, independent Python reference models, coverage tracking, and automated regression testing.

## Debugging and Lessons Learned

Development issues are documented in [docs/BUGS.md](docs/BUGS.md).

Early debugging included an incomplete processing-element implementation that compiled successfully but produced unknown output values, and an accidental duplicate module declaration.

Both issues were resolved, and the PE subsequently passed its directed verification tests.

## Project Goal

The final deliverable is a verified INT8 transformer accelerator capable of executing a transformer block with results matching an independent bit-exact reference model.

Performance will be evaluated using simulation cycle counts and an open-source silicon implementation flow.

The completed project will document architectural decisions, verification methodology, hardware complexity, timing, and power consumption.