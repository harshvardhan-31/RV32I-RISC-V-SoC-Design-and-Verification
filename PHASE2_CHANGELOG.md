# Phase 2 Changelog and Implementation Record

---

## 1. Files Newly Added in Phase 2 Baseline

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

---

## 2. Engineering Audit & Corrections Applied

During the Phase 2/Phase 3 engineering audit, the following fixes were implemented:
1. **ECALL / EBREAK Distinction:**
   - Modified `instruction_decoder.sv` to output `funct12_o` (`instr_i[31:20]`).
   - Sliced `funct12_i` into `control_unit.sv` to distinguish ECALL (`12'h000`) and EBREAK (`12'h001`), resolving an issue where `funct7_i[0]` (bit 25) was previously checked instead of bit 20.
   - Added self-checking tests for ECALL, EBREAK, and illegal SYSTEM instructions in `tb_instruction_decoder.sv` and `tb_control_unit.sv`.
2. **PC Unit Stall Priority Over Redirection:**
   - Modified `pc_unit.sv` so that `stall_i` takes precedence over `redirect_i`.
   - Prevents wrong-path instruction fetch or dropped targets during memory wait states (`lsu_busy`). Redirection executes synchronously once the memory stall clears.
3. **Data Memory Model Wait Cycles Configuration:**
   - Updated `data_memory_bus_model.sv` with dynamic `wait_cycles_cfg` variable to allow runtime wait-state configuration without re-instantiation.
