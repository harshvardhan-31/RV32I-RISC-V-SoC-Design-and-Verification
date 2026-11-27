# rtl/core/

Synthesizable SystemVerilog implementation of the RV32I 5-stage CPU Core.

## Modules Implemented (Phase 2):
1. `pc_unit.sv` — Program Counter generator and branch/jump redirect multiplexer.
2. `if_id_reg.sv` — IF/ID pipeline register with stall and flush capabilities.
3. `instruction_decoder.sv` — RV32I field extractor and illegal instruction validator.
4. `immediate_generator.sv` — Sign/zero extension for I, S, B, U, and J immediate formats.
5. `control_unit.sv` — Control signal and ALU operation decoder.
6. `register_file.sv` — 32x32-bit register file (dual read, single synchronous write, x0 hardwired 0).
7. `id_ex_reg.sv` — ID/EX pipeline register.
8. `alu.sv` — 32-bit arithmetic, logical, shift, SLT/SLTU, and branch comparator.
9. `ex_mem_reg.sv` — EX/MEM pipeline register.
10. `load_store_unit.sv` — Memory bus master controller (LB/LH/LW/LBU/LHU, SB/SH/SW, byte enables).
11. `mem_wb_reg.sv` — MEM/WB pipeline register.
12. `cpu_core.sv` — Top-level 5-stage pipeline integration.
