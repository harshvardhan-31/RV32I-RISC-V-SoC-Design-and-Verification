# Phase 3 Changelog — Hazard Detection and Forwarding

All notable changes and deliverables implemented for Phase 3 of the RV32I RISC-V SoC design.

---

## 1. Summary of Changes
Phase 3 transitions the five-stage RV32I CPU core from a baseline design requiring software-inserted NOPs to an autonomous pipelined processor with dynamic hazard detection and hardware data forwarding.

---

## 2. New Files Added

### 2.1 Synthesizable RTL (`rtl/core/`)
- `rtl/core/hazard_unit.sv`:
  - Implements load-use RAW hazard detection logic.
  - Implements control-hazard flush generation for taken branches and jumps.
  - Implements bus wait-state freeze when `lsu_busy` is high.
  - Evaluates register usage flags to eliminate false dependencies.
- `rtl/core/forwarding_unit.sv`:
  - Implements EX/MEM (Priority 1) and MEM/WB (Priority 2) operand forwarding.
  - Enforces `x0` protection (no forwarding for destination `x0`).
  - Blocks EX/MEM load forwarding (`mem_read = 1`) to allow load-use stall resolution.

### 2.2 Testbenches (`testbench/`)
- `testbench/unit/tb_hazard_unit.sv`: Unit testbench covering 12 hazard cases (HAZARD-01..12) with `$fatal`.
- `testbench/unit/tb_forwarding_unit.sv`: Unit testbench covering 12 forwarding cases (FORWARD-01..12) with `$fatal`.
- `testbench/system/tb_hazard_integration.sv`: System testbench for RAW ALU chains, load-use bubble insertion, and store data forwarding.
- `testbench/system/tb_cpu_forwarding.sv`: System testbench for ALU forwarding, branch operand forwarding, and JALR base forwarding.

### 2.3 Assembly Programs (`programs/asm/`)
- `programs/asm/raw_alu_dependencies.S`
- `programs/asm/load_use_dependencies.S`
- `programs/asm/branch_dependencies.S`
- `programs/asm/jump_dependencies.S`
- `programs/asm/store_data_dependencies.S`

### 2.4 Simulation and Lint Scripts (`scripts/`)
- `scripts/run_phase3_sim.sh`
- `scripts/lint_phase3.sh`

### 2.5 Documentation (`docs/` & Root)
- `docs/phase3_implementation_decisions.md`
- `docs/phase3_hazard_architecture.md`
- `docs/phase3_forwarding_architecture.md`
- `docs/phase3_pipeline_control.md`
- `docs/phase3_test_plan.md`
- `docs/phase3_test_results.md`
- `PHASE3_README.md`
- `PHASE3_CHANGELOG.md`

---

## 3. Modified Files

- **`rtl/core/cpu_core.sv`**:
  - Integrated `hazard_unit` and `forwarding_unit`.
  - Added 3-way forwarding multiplexers for `rs1` and `rs2`.
  - Wired forwarded `rs2` (`fwd_rs2_val`) to `ex_mem_reg` for store data forwarding.
  - Wired forwarded `rs1` (`fwd_rs1_val`) to `jalr_target` calculation.
  - Replaced single `stall_pipeline` with fine-grained per-stage stall/flush control logic.
- **`Makefile`**:
  - Added Phase 3 test targets: `test_phase3`, `test_hazard_unit`, `test_forwarding_unit`, `test_hazard_integration`, `test_cpu_forwarding`, `lint_phase3`.
- **`README.md`**:
  - Updated project status to Phase 3 completed.
  - Updated architecture description, Mermaid diagrams, and module inventory.
- **`docs/module_specification.md`**:
  - Updated `hazard_unit` and `forwarding_unit` status to "Implemented (Phase 3)".
  - Updated `cpu_core` status to "Implemented (Phase 3 integrated)".
- **`docs/development_roadmap.md`**:
  - Marked Phase 3 acceptance criteria completed.
- **`docs/pipeline_architecture.md`**:
  - Updated status from proposal to implemented in Phase 3.
  - Added detailed descriptions of forwarding, load-use, and stall/flush priorities.
- **`docs/verification_plan.md`**:
  - Added test specification tables for `hazard_unit`, `forwarding_unit`, and Phase 3 system integration.

---

## 4. Tests Not Executed & Known Limitations

- **Simulation execution status:** All testbenches and simulations are marked **Not run** in test result documentation because Icarus Verilog and Verilator were not installed in the CI container environment where the package was prepared.
- **Assembly hex files:** Programs in `programs/asm/` are reference source files. Hand-encoded hex test vectors are embedded directly into SystemVerilog system testbenches using parameter macros. Generating standalone `.hex` files requires `riscv32-unknown-elf-gcc`.
- **Reference ISS:** No instruction set simulator (ISS) co-simulation was performed; register verification is checked against golden architectural values.
- **Privileged architecture:** Traps, exceptions, CSRs, and privileged modes are not implemented (planned for future phases).
