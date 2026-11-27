# RV32I RISC-V SoC — Phase 3: Hazard Detection and Forwarding

This package contains the complete, GitHub-ready hardware implementation of **Phase 3: Hazard Detection and Forwarding** for the RV32I RISC-V SoC design.

---

## 1. What's Included in Phase 3

### 1.1 Synthesizable RTL Modules (`rtl/core/`)
- **`hazard_unit.sv`**: Dynamic hazard detection unit handling:
  - Load-use RAW hazards: holds PC and IF/ID, inserts exactly one bubble into ID/EX.
  - Control hazards: generates flush signals on taken branches and jumps resolved in EX (2-cycle penalty).
  - Memory wait states: prioritizes `lsu_busy` bus stalls, freezing the entire pipeline synchronously.
  - x0 protection: ignores load-use dependencies targeting `x0`.
  - False dependency prevention: checks decoder usage flags (`rs1_used`, `rs2_used`) to prevent false stalls on instructions like `LUI` or `AUIPC`.
- **`forwarding_unit.sv`**: Priority-based data forwarding unit:
  - Priority 1: EX/MEM → EX forwarding (`2'b10`).
  - Priority 2: MEM/WB → EX forwarding (`2'b01`).
  - Blocks EX/MEM forwarding when the instruction is a load (`mem_read = 1`), deferring resolution to load-use stall + MEM/WB forward.
  - Never forwards when destination is `x0` or `reg_write = 0`.
- **`cpu_core.sv`** (Updated top-level):
  - Instantiates `hazard_unit` and `forwarding_unit`.
  - Implements 3-way forwarding multiplexers for `fwd_rs1_val` and `fwd_rs2_val`.
  - Forwards `fwd_rs2_val` into `ex_mem_reg` for store data forwarding.
  - Uses forwarded `rs1` for JALR target computation.
  - Replaces single `stall_pipeline` with fine-grained per-stage stall/flush control.

### 1.2 Verification Testbenches
- **`testbench/unit/tb_hazard_unit.sv`**: Self-checking testbench covering 12 hazard detection test cases (HAZARD-01 through HAZARD-12) with `$fatal` checks.
- **`testbench/unit/tb_forwarding_unit.sv`**: Self-checking testbench covering 12 forwarding test cases (FORWARD-01 through FORWARD-12) with `$fatal` checks.
- **`testbench/system/tb_hazard_integration.sv`**: System integration testbench verifying execution of RAW chains, load-use stalls, and store data forwarding without software NOPs.
- **`testbench/system/tb_cpu_forwarding.sv`**: System integration testbench verifying back-to-back ALU, 2-stage back ALU, branch operand forwarding, and JALR base forwarding without software NOPs.

### 1.3 Assembly Test Programs without NOPs (`programs/asm/`)
- `raw_alu_dependencies.S`
- `load_use_dependencies.S`
- `branch_dependencies.S`
- `jump_dependencies.S`
- `store_data_dependencies.S`

### 1.4 Simulation and Linting Scripts (`scripts/`)
- `scripts/run_phase3_sim.sh`: Shell script to compile and run all Phase 3 unit and integration testbenches via Icarus Verilog.
- `scripts/lint_phase3.sh`: Shell script to run Verilator lint checks on all modules and the integrated CPU core.
- Updated `Makefile` with targets: `test_phase3`, `test_hazard_unit`, `test_forwarding_unit`, `test_hazard_integration`, `test_cpu_forwarding`, `lint_phase3`.

### 1.5 Engineering Documentation (`docs/`)
- `docs/phase3_implementation_decisions.md`: Baseline decisions on forwarding select encoding, load-use bubbles, store forwarding, and priority.
- `docs/phase3_hazard_architecture.md`: Hazard detection logic equations, timing diagrams, and priority encoding.
- `docs/phase3_forwarding_architecture.md`: Forwarding datapath diagrams, priority rules, and forwarding mux implementation.
- `docs/phase3_pipeline_control.md`: Stage-by-stage stall and flush truth tables and scenario breakdowns.
- `docs/phase3_test_plan.md`: Comprehensive list of all 24 unit tests and 10 system test sequences.
- `docs/phase3_test_results.md`: Complete test results table (marked "Not run" pending local simulator execution).

---

## 2. Quick Start Guide

### Prerequisites
- **Icarus Verilog** (`iverilog`, `vvp`) >= 11.0
- **Verilator** >= 4.200 (optional, for linting)
- **Bash shell** / GNU Make

### Running Tests
```bash
# Run all Phase 3 simulations
make test_phase3

# Or directly with bash
bash scripts/run_phase3_sim.sh

# Run unit tests only
bash scripts/run_phase3_sim.sh --unit-only

# Run system integration tests only
bash scripts/run_phase3_sim.sh --sys-only

# Run Verilator linting
make lint_phase3
```
