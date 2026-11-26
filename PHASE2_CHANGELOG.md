# Phase 2 Changelog and Implementation Record

---

## 1. Files Newly Added

### Synthesizable RTL Modules (`rtl/core/`)
- `rtl/core/pc_unit.sv` — Program Counter generation, increment, redirect handling, and stall priority.
- `rtl/core/if_id_reg.sv` — IF/ID pipeline register with synchronous reset, stall, and flush.
- `rtl/core/instruction_decoder.sv` — Slices opcode, rd, rs1, rs2, funct3, funct7, and flags illegal instructions.
- `rtl/core/immediate_generator.sv` — Sign/zero extension for I, S, B, U, and J immediate formats.
- `rtl/core/control_unit.sv` — Main control unit decoding ALU operations, operand selects, memory read/write, reg write, and branch/jump flags.
- `rtl/core/register_file.sv` — 32x32-bit integer register file with x0 hardwired to zero.
- `rtl/core/id_ex_reg.sv` — ID/EX pipeline register.
- `rtl/core/alu.sv` — 32-bit arithmetic, logical, shift, SLT/SLTU comparison, and branch condition evaluation.
- `rtl/core/ex_mem_reg.sv` — EX/MEM pipeline register.
- `rtl/core/load_store_unit.sv` — Memory bus master controller supporting LB..LW, SB..SW, byte enables, and bus handshakes.
- `rtl/core/mem_wb_reg.sv` — MEM/WB pipeline register.
- `rtl/core/cpu_core.sv` — 5-stage CPU core pipeline integration.

### Simulation Memory Models (`testbench/models/`)
- `testbench/models/instruction_memory_model.sv` — 1-cycle synchronous read latency memory model.
- `testbench/models/data_memory_bus_model.sv` — Byte-addressable bus slave model with configurable wait states and error generation.

### Unit Testbenches (`testbench/unit/`)
- `testbench/unit/tb_alu.sv` — Self-checking ALU testbench with edge cases (overflow, shamt, comparisons).
- `testbench/unit/tb_register_file.sv` — Self-checking testbench for register file dual-port reads, writes, reset, and x0 immunity.
- `testbench/unit/tb_instruction_decoder.sv` — Self-checking testbench for all RV32I formats and illegal encoding rejection.
- `testbench/unit/tb_immediate_generator.sv` — Self-checking testbench for immediate bit placement and sign extension.
- `testbench/unit/tb_control_unit.sv` — Self-checking control unit matrix and illegal instruction suppression testbench.
- `testbench/unit/tb_pipeline_registers.sv` — Self-checking testbench for IF/ID, ID/EX, EX/MEM, and MEM/WB registers.
- `testbench/unit/tb_load_store_unit.sv` — Self-checking LSU testbench for all load/store sizes, byte enables, and bus stalls.

### System Testbench (`testbench/system/`)
- `testbench/system/tb_cpu_core.sv` — Top-level system testbench with timeout watchdog, instruction loading, and architectural state assertion.

### Test Programs (`programs/`)
- `programs/asm/phase2_smoke.s` — Assembly smoke test covering arithmetic, logical, shift, comparisons, LUI, memory, and branch.
- `programs/hex/phase2_smoke.hex` — Verified machine code for smoke test.
- `programs/asm/phase2_branch.s` — Assembly branch redirect, JAL, and pipeline flush test.
- `programs/hex/phase2_branch.hex` — Verified machine code for branch test.

### Scripts & Automation (`scripts/`, repository root)
- `scripts/run_phase2_sim.sh` — Bash simulation runner using Icarus Verilog (`-g2012`).
- `scripts/lint_phase2.sh` — Verilator lint runner.
- `scripts/run_phase2_sim.ps1` — Windows PowerShell simulation runner.
- `Makefile` — Make orchestration for unit, system, and lint targets.

### Documentation & Reports (`docs/`, `reports/`)
- `docs/phase2_implementation_decisions.md` — Documented baseline decisions for Phase 2.
- `docs/phase2_rtl_architecture.md` — Datapath, pipeline registers, and interface specification.
- `docs/phase2_test_results.md` — Verification plan and test execution status.
- `reports/simulation/phase2/README.md` — Guidelines for committing simulation logs.
- `reports/simulation/phase2/REPORT_TEMPLATE.md` — Standard report template.
- `PHASE2_README.md` — Deliverable package summary.
- `PHASE2_CHANGELOG.md` — This file.

---

## 2. Existing Files Updated
- `docs/module_specification.md` — Updated module inventory: CPU modules 2..13 moved from "Proposed" to "Implemented (Phase 2)".
- `docs/development_roadmap.md` — Updated Phase 2 status with checklist of completed items.
- `README.md` — Updated project status to Phase 2 implemented, updated layout, and added simulation execution commands.
- `rtl/core/README.md` — Documented all 12 implemented CPU modules.
- `testbench/README.md` — Documented unit, system, and behavioral model directories.

---

## 3. Verification Execution Status

- **Tests Written:** 8 testbenches (7 unit + 1 system).
- **Tests Actually Executed in Current Environment:** None (`Not run`).
- **Reason:** Icarus Verilog (`iverilog` / `vvp`) is not installed on the current execution runner's host environment.
- **Integrity Guarantee:** In accordance with the project's verification policies, tests are marked "Not run" rather than falsely reporting passed results. Full instructions and scripts are provided for running under Linux, macOS, and Windows once Icarus Verilog is installed.

---

## 4. Known Limitations

1. **Hazard Handling:** No hardware forwarding unit or hazard detection unit is present in Phase 2. Assembly code must contain 3 NOPs between dependent instructions.
2. **Unaligned Memory Access:** Misaligned loads/stores do not trigger exceptions; lower address bits are used for byte-lane enables and word/halfword alignment.
3. **Privileged Operations & Traps:** ECALL and EBREAK are decoded as non-side-effecting system instructions; no CSRs or trap vectors are implemented in Phase 2.
4. **Instruction Fetch Latency:** Fetch architecture assumes a 1-cycle synchronous response from instruction memory.

---

## 5. Remaining Phase 3 and Phase 4 Tasks

### Phase 3: Hazard Detection and Forwarding
- Implement `rtl/core/forwarding_unit.sv` (EX/MEM and MEM/WB to EX stage forwarding).
- Implement `rtl/core/hazard_unit.sv` (Dynamic load-use stall detection and single-bubble insertion).
- Verify pipeline hazard resolution without software NOP insertion.

### Phase 4: Memory Subsystem and Peripheral Integration
- Implement synthesizable `rtl/memory/instruction_memory.sv` and `rtl/memory/data_memory.sv`.
- Implement `rtl/bus/bus_interconnect.sv` with address decoding and error response for unmapped regions.
- Implement `rtl/peripherals/uart_controller.sv`.
- Implement `rtl/peripherals/spi_master.sv`.
- Implement `rtl/peripherals/timer.sv`.
- Implement `rtl/peripherals/interrupt_controller.sv`.
- Implement `rtl/top/rv32i_soc_top.sv`.
