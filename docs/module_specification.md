# Hardware Module Inventory

Status values: Proposed → Interface defined → Implemented → Unit verified → Integrated.

| # | Module | Stage / subsystem | Purpose | Inputs | Outputs | Interfaces with | Status |
|---|---|---|---|---|---|---|---|
| 1 | `rv32i_soc_top` | Top | SoC integration; explicit port wiring of CPU, memories, bus, peripherals | clk_i, rst_ni, uart_rx_i, spi_miso_i, ext_irq_i | uart_tx_o, spi_sclk_o, spi_mosi_o, spi_cs_no | cpu_core, instruction_memory, bus_interconnect, all peripherals | Proposed — not implemented |
| 2 | `cpu_core` | CPU | Wraps the five-stage pipeline with hazard detection and forwarding | clk_i, rst_ni, imem_* response, dmem_* response | imem_req_o/addr_o, dmem_req_o/addr_o/we_o/wdata_o/be_o | instruction_memory, bus_interconnect | Implemented (Phase 3 integrated) |
| 3 | `pc_unit` | IF | Holds PC; selects PC+4 or redirect target; obeys stall | clk_i, rst_ni, stall_i, redirect_i, redirect_pc_i[31:0] | pc_o[31:0], pc_plus4_o[31:0], imem_req_o, imem_addr_o | if_id_reg, alu, cpu_core | Implemented (Phase 2) |
| 4 | `if_id_reg` | IF/ID | Pipeline register: valid, PC, instruction | clk_i, rst_ni, pc_i, pc_plus4_i, instr_i, stall_i, flush_i | valid_o, pc_o, pc_plus4_o, instr_o | pc_unit, instruction_decoder | Implemented (Phase 2) |
| 5 | `instruction_decoder` | ID | Extracts opcode/rd/funct3/rs1/rs2/funct7; flags illegal encodings | instr_i[31:0] | opcode_o, rd_o, rs1_o, rs2_o, funct3_o, funct7_o, rs1_used_o, rs2_used_o, rd_used_o, illegal_instr_o | control_unit, immediate_generator, register_file | Implemented (Phase 2) |
| 6 | `immediate_generator` | ID | Sign-extends I/S/B/U/J immediates | instr_i[31:0], imm_type_i[2:0] | imm_o[31:0] | control_unit, id_ex_reg | Implemented (Phase 2) |
| 7 | `control_unit` | ID | Generates ALU op, operand selects, memory, branch and writeback controls | opcode_i, funct3_i, funct7_i, illegal_instr_i | imm_type_o, alu_op_o, alu_src_a_o, alu_src_b_o, mem_read_o, mem_write_o, reg_write_o, wb_sel_o, branch_o, jump_o, jalr_o, sys_ecall_o, sys_ebreak_o, sys_fence_o | instruction_decoder, id_ex_reg | Implemented (Phase 2) |
| 8 | `register_file` | ID/WB | 32x32 registers, 2 read / 1 write; x0 hardwired zero | clk_i, rst_ni, rs1_addr_i, rs2_addr_i, we_i, rd_addr_i, rd_data_i | rs1_data_o, rs2_data_o | instruction_decoder, mem_wb_reg | Implemented (Phase 2) |
| 9 | `id_ex_reg` | ID/EX | Pipeline register: operands, immediate, register indices, controls | clk_i, rst_ni, decoded fields, controls, stall_i, flush_i | registered fields, valid_o | control_unit, alu, cpu_core | Implemented (Phase 2) |
| 10 | `alu` | EX | ADD SUB AND OR XOR SLL SRL SRA SLT SLTU; branch compare (EQ NE LT GE LTU GEU) and target | op_a_i, op_b_i, alu_op_i, funct3_i | result_o[31:0], branch_taken_o | id_ex_reg, pc_unit, ex_mem_reg | Implemented (Phase 2) |
| 11 | `ex_mem_reg` | EX/MEM | Pipeline register: result/address, store data, rd, controls | clk_i, rst_ni, result_i, store_data_i, rd_i, controls, stall_i, flush_i | registered fields, valid_o | alu, load_store_unit | Implemented (Phase 2) |
| 12 | `load_store_unit` | MEM | Forms bus requests with byte enables; aligns and sign/zero-extends loads | clk_i, rst_ni, addr_i, wdata_i, funct3_i, mem_read_i, mem_write_i, bus rdata/ready/error | bus req/addr/we/wdata/be, load_data_o, busy_o, error_o | ex_mem_reg, bus_interconnect | Implemented (Phase 2) |
| 13 | `mem_wb_reg` | MEM/WB | Pipeline register: ALU/load/link value, rd, reg_write; writeback select | clk_i, rst_ni, alu_result_i, load_data_i, pc_plus4_i, rd_i, controls, stall_i, flush_i | wb_data_o, rd_addr_o, reg_write_o, valid_o | load_store_unit, register_file | Implemented (Phase 2) |
| 14 | `hazard_unit` | Control | Load-use detection, bus-wait hold, branch/jump flush | id_ex rd/mem_read, if_id rs1/rs2/rs1_used/rs2_used, redirect_valid_i, lsu_busy_i | stall_if_o, stall_id_o, bubble_id_ex_o, flush_if_id_o | id_ex_reg, if_id_reg, pc_unit, cpu_core | Implemented (Phase 3) |
| 15 | `forwarding_unit` | Control | Selects EX operands from EX/MEM or MEM/WB; newest wins; ignores x0 | ex_rs1/rs2, ex_mem rd/reg_write/mem_read, mem_wb rd/reg_write | fwd_sel_a_o[1:0], fwd_sel_b_o[1:0] | id_ex_reg, ex_mem_reg, mem_wb_reg, cpu_core | Implemented (Phase 3) |
| 16 | `instruction_memory` | Memory | Read-only instruction RAM/ROM; 1-cycle synchronous read | req_i, addr_i[31:0] | rdata_o[31:0], ready_o, error_o | Phase 4 deliverable | Proposed — not implemented |
| 17 | `data_memory` | Memory | Byte-addressable data RAM with byte enables | bus slave req/addr/we/wdata/be | rdata_o, ready_o, error_o | Phase 4 deliverable | Proposed — not implemented |
| 18 | `bus_interconnect` | Bus | Single-master custom bus, address decoder and response mux | master req/addr/we/wdata/be; slave rdata/ready/error | slave selects; master rdata/ready/error | Phase 4 deliverable | Proposed — not implemented |
| 19 | `uart_controller` | Peripheral | UART TX/RX with baud divider | bus slave port, rx_i | tx_o, irq_o, bus response | Phase 4 deliverable | Proposed — not implemented |
| 20 | `spi_master` | Peripheral | SPI master | bus slave port, miso_i | sclk_o, mosi_o, cs_no, irq_o | Phase 4 deliverable | Proposed — not implemented |
| 21 | `timer` | Peripheral | 32-bit counter with compare and interrupt | bus slave port | irq_o, bus response | Phase 4 deliverable | Proposed — not implemented |
| 22 | `interrupt_controller` | Peripheral | Pending/enable/clear aggregation | uart/spi/timer/ext irq, bus slave port | irq_o to cpu_core | Phase 4 deliverable | Proposed — not implemented |

RTL location: `rtl/core/<module>.sv`. Unit testbenches: `testbench/unit/tb_<module>.sv`.
