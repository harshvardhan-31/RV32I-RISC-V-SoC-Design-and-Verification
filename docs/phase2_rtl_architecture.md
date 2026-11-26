# Phase 2 CPU Core RTL Architecture

> Document status: Complete Architecture Specification for Phase 2 RTL.
> Module Inventory: 12 Core SystemVerilog Modules in `rtl/core/`.

---

## 1. Five-Stage In-Order Datapath

The CPU core (`cpu_core.sv`) implements an integer 32-bit RISC-V RV32I five-stage pipelined datapath:

```
[IF: pc_unit] ---> [if_id_reg] ---> [ID: decoder/imm/control/regfile]
                                          |
                                          v
[WB: writeback] <--- [mem_wb_reg] <--- [MEM: load_store_unit] <--- [id_ex_reg]
                                          |                          |
                                          +---- [ex_mem_reg] <--- [EX: alu/branch]
```

### Stage 1: Instruction Fetch (IF)
- **Component:** `pc_unit.sv`.
- **Function:** Holds the current program counter, increments sequentially by 4 (`pc_plus4`), responds to branch/jump redirections from the Execute (EX) stage, and drives the dedicated instruction fetch port (`imem_req_o`, `imem_addr_o`).
- **Synchronous Interface:** Assumes 1-cycle latency from the instruction memory model.
- **Pipeline Register:** `if_id_reg.sv` latches `valid`, `pc`, `pc_plus4`, and `instr`. Supports synchronous reset, stall (freeze), and flush (bubble).

### Stage 2: Instruction Decode (ID)
- **Components:**
  - `instruction_decoder.sv`: Slices opcode `[6:0]`, `rd [11:7]`, `funct3 [14:12]`, `rs1 [19:15]`, `rs2 [24:20]`, `funct7 [31:25]`. Flags illegal encodings and tracks register usage.
  - `immediate_generator.sv`: Extracts and sign-extends I, S, B, U, and J format immediates.
  - `control_unit.sv`: Decodes major opcodes and function codes to generate ALU operation selections, operand source selects, memory read/write flags, register write enables, writeback destination selects, and branch/jump identifiers.
  - `register_file.sv`: 32 general-purpose 32-bit registers (`x0` through `x31`). Dual combinational read ports, single synchronous rising-edge write port. `x0` is hardwired to 0; writes to `x0` are rejected.
- **Pipeline Register:** `id_ex_reg.sv` registers operands, immediate, control signals, and destination register address. Supports reset, stall, and flush.

### Stage 3: Execute (EX)
- **Components:**
  - `alu.sv`: 32-bit arithmetic (ADD, SUB with overflow wraparound), bitwise logical (AND, OR, XOR), shifts (SLL, SRL, SRA with 5-bit shift amounts), signed and unsigned set-less-than comparisons (SLT, SLTU), and branch comparisons (BEQ, BNE, BLT, BGE, BLTU, BGEU).
  - Target Adder: Evaluates branch targets (`PC + imm`) and JALR targets (`(rs1 + imm) & ~1`).
  - Redirect Logic: Generates `redirect_valid` and `redirect_pc` to redirect `pc_unit` and synchronous `flush` to `if_id_reg` and `id_ex_reg`.
- **Pipeline Register:** `ex_mem_reg.sv` latches the ALU result (effective memory address or computed value), store data (`rs2`), destination register address, and memory/writeback controls.

### Stage 4: Memory Access (MEM)
- **Component:** `load_store_unit.sv`.
- **Function:** Connects the CPU core to the custom SoC data memory bus.
  - Generates byte enables (`dmem_be_o[3:0]`) and aligns write data for `SB`, `SH`, and `SW`.
  - Extracts and sign/zero-extends read data from memory for `LB`, `LBU`, `LH`, `LHU`, and `LW`.
  - Implements the single-outstanding-transaction handshake (`req`, `ready`, `error`).
  - Asserts `busy_o` when a transaction is outstanding, stalling upstream pipeline stages.
- **Pipeline Register:** `mem_wb_reg.sv` latches ALU result, load data, `pc_plus4`, `rd`, and writeback controls.

### Stage 5: Write Back (WB)
- **Mux & Writeback:** Selects the retirement value (ALU result, memory load data, or link address `pc_plus4`) and drives the write port of `register_file.sv` synchronously at the rising clock edge when `valid && reg_write` is active and `rd != 0`.

---

## 2. Signal and Interface Directory

| Module | Inputs | Outputs | Description |
|---|---|---|---|
| `pc_unit` | `clk_i, rst_ni, stall_i, redirect_i, redirect_pc_i[31:0]` | `pc_o[31:0], pc_plus4_o[31:0], imem_req_o, imem_addr_o[31:0]` | Program counter generator |
| `if_id_reg` | `clk_i, rst_ni, stall_i, flush_i, valid_i, pc_i, pc_plus4_i, instr_i` | `valid_o, pc_o, pc_plus4_o, instr_o` | IF-to-ID pipeline register |
| `instruction_decoder` | `instr_i[31:0]` | `opcode_o, rd_o, funct3_o, rs1_o, rs2_o, funct7_o, rs1_used_o, rs2_used_o, rd_used_o, illegal_instr_o` | Instruction field slicer and validator |
| `immediate_generator` | `instr_i[31:0], imm_type_i[2:0]` | `imm_o[31:0]` | Immediate extractor and sign-extender |
| `control_unit` | `opcode_i, funct3_i, funct7_i, illegal_instr_i` | `imm_type_o, alu_op_o, alu_src_a_o, alu_src_b_o, mem_read_o, mem_write_o, reg_write_o, wb_sel_o, branch_o, jump_o, jalr_o, sys_ecall_o, sys_ebreak_o, sys_fence_o` | Main control signal generator |
| `register_file` | `clk_i, rst_ni, rs1_addr_i, rs2_addr_i, we_i, rd_addr_i, rd_data_i` | `rs1_data_o, rs2_data_o` | 32x32 register file |
| `id_ex_reg` | `clk_i, rst_ni, stall_i, flush_i, valid_i, pc_i, pc_plus4_i, rs1_data_i, rs2_data_i, imm_i, rs1_addr_i, rs2_addr_i, rd_addr_i, funct3_i, alu_op_i, alu_src_a_i, alu_src_b_i, branch_i, jump_i, jalr_i, mem_read_i, mem_write_i, reg_write_i, wb_sel_i` | Registered equivalents | ID-to-EX pipeline register |
| `alu` | `op_a_i, op_b_i, alu_op_i, funct3_i` | `result_o[31:0], branch_taken_o` | Arithmetic Logic Unit & Branch Comparator |
| `ex_mem_reg` | `clk_i, rst_ni, stall_i, flush_i, valid_i, pc_plus4_i, alu_result_i, rs2_data_i, rd_addr_i, funct3_i, mem_read_i, mem_write_i, reg_write_i, wb_sel_i` | Registered equivalents | EX-to-MEM pipeline register |
| `load_store_unit` | `clk_i, rst_ni, valid_i, mem_read_i, mem_write_i, funct3_i, addr_i, wdata_i, dmem_ready_i, dmem_rdata_i, dmem_error_i` | `load_data_o, busy_o, error_o, dmem_req_o, dmem_addr_o, dmem_we_o, dmem_wdata_o, dmem_be_o` | Bus master load-store controller |
| `mem_wb_reg` | `clk_i, rst_ni, stall_i, flush_i, valid_i, alu_result_i, load_data_i, pc_plus4_i, rd_addr_i, reg_write_i, wb_sel_i` | `valid_o, rd_addr_o, reg_write_o, wb_data_o` | MEM-to-WB pipeline register |
| `cpu_core` | `clk_i, rst_ni, imem_*, dmem_*` | `imem_*, dmem_*` | Top-level 5-stage CPU wrapper |

---

## 3. Strict Phase Boundaries Maintained

In accordance with project scope guidelines:
1. **No Forwarding Unit:** Operands are read solely from `register_file.sv` in ID. Dependent instructions require software NOP padding.
2. **No Hardware Dynamic Hazard Detection Unit:** Pipeline hazards are not resolved in hardware in Phase 2; scheduled for Phase 3.
3. **No Peripheral Integration in Core:** Memory models reside exclusively in `testbench/models/`.
