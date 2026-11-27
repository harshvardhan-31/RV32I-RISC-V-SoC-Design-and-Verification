# RV32I RISC-V SoC — Phase 3: Hazard Detection and Forwarding

This package contains the complete, GitHub-ready hardware implementation of **Phase 3: Hazard Detection and Forwarding** for the RV32I RISC-V SoC design, updated following the comprehensive engineering audit.

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
  - Validates pipeline register valid bits before enabling forwarding.
- **`cpu_core.sv`** (Updated top-level):
  - Instantiates `hazard_unit` and `forwarding_unit`.
  - Implements 3-way forwarding multiplexers for `fwd_rs1_val` and `fwd_rs2_val`.
  - Forwards `fwd_rs2_val` into `ex_mem_reg` for store data forwarding.
  - Uses forwarded `rs1` for JALR target computation.
  - Connects `id_funct12` between decoder and control unit for ECALL/EBREAK discrimination.
  - Replaces single `stall_pipeline` with fine-grained per-stage stall/flush control.
- **`instruction_decoder.sv` & `control_unit.sv`**:
  - Slices `funct12` (`instr[31:20]`) to accurately distinguish between ECALL (`12'h000`) and EBREAK (`12'h001`).
- **`pc_unit.sv`**:
  - Updated so `stall_i` holds PC during bus wait states, executing pending redirects immediately upon stall release.

### 1.2 Verification Testbenches
- **`testbench/unit/tb_hazard_unit.sv`**: Self-checking testbench covering 12 hazard detection test cases (`HAZARD-01..12`) with `$fatal`.
- **`testbench/unit/tb_forwarding_unit.sv`**: Self-checking testbench covering 20 forwarding test cases (`FORWARD-01..20`) including invalid entries, x0 immunity, reg-write qualification, and back-to-back priority.
- **`testbench/system/tb_hazard_integration.sv`**: System integration testbench verifying:
  - RAW dependency chains and store data forwarding with zero NOPs.
  - Cycle-level counter assertion confirming **exactly 1 stall cycle and 1 bubble insertion** for isolated load-use.
  - Multi-cycle data memory wait states (`WAIT_CYCLES = 2`).
  - Branch redirect occurring while an older memory transaction is outstanding.
- **`testbench/system/tb_cpu_forwarding.sv`**: System integration testbench verifying:
  - Consecutive ALU and 2-stage back forwarding.
  - Branch operand forwarding.
  - **Genuine immediate JALR dependency:** `ADDI x1, x0, 24` followed immediately by `JALR x4, x1, 0`.
  - Pipeline register x0 protection and back-to-back producer priority.

### 1.3 Assembly Test Programs without NOPs (`programs/asm/`)
- `raw_alu_dependencies.S`
- `load_use_dependencies.S`
- `branch_dependencies.S`
- `jump_dependencies.S`
- `store_data_dependencies.S`

### 1.4 Simulation and Linting Scripts (`scripts/`)
- `scripts/run_phase3_sim.sh`: Shell script to compile and run all Phase 3 unit and integration testbenches via Icarus Verilog.
- `scripts/lint_phase3.sh`: Shell script to run Verilator lint checks on all modules and the integrated CPU core.
- `Makefile` with targets: `test_phase3`, `test_hazard_unit`, `test_forwarding_unit`, `test_hazard_integration`, `test_cpu_forwarding`, `lint_phase3`.

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
