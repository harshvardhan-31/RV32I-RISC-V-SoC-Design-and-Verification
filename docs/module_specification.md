# Hardware Module Inventory

All 22 modules are **planned**. None has RTL yet. A module may move to "Implemented" only when its RTL file is committed, and to "Verified" only when a real simulation log is stored under `reports/`.

Status values: Proposed → Interface defined → Implemented → Unit verified → Integrated.

| # | Module | Stage / subsystem | Purpose | Inputs | Outputs | Interfaces with | Status |
|---|---|---|---|---|---|---|---|
| 1 | `rv32i_soc_top` | Top | SoC integration; explicit port wiring of CPU, memories, bus, peripherals | clk_i, rst_ni, uart_rx_i, spi_miso_i, ext_irq_i | uart_tx_o, spi_sclk_o, spi_mosi_o, spi_cs_no | cpu_core, instruction_memory, bus_interconnect, all peripherals | Proposed — not implemented |
| 2 | `cpu_core` | CPU | Wraps the five-stage pipeline and its control units | clk_i, rst_ni, imem_* response, dmem_* response, irq_i (contract TBD) | imem_req_o/addr_o, dmem_req_o/addr_o/we_o/wdata_o/be_o | instruction_memory, bus_interconnect, interrupt_controller | Proposed — not implemented |
| 3 | `pc_unit` | IF | Holds PC; selects PC+4 or redirect target; obeys stall | clk_i, rst_ni, stall_i, redirect_i, redirect_pc_i[31:0] | pc_o[31:0], imem_req_o | hazard_unit, alu (branch target), if_id_reg | Proposed — not implemented |
| 4 | `if_id_reg` | IF/ID | Pipeline register: valid, PC, instruction | pc_i, instr_i, stall_i, flush_i | valid_o, pc_o, instr_o | pc_unit, instruction_decoder, hazard_unit | Proposed — not implemented |
| 5 | `instruction_decoder` | ID | Extracts opcode/rd/funct3/rs1/rs2/funct7; flags illegal encodings (handling TBD) | instr_i[31:0] | opcode_o, rd_o, rs1_o, rs2_o, funct3_o, funct7_o, illegal_o | control_unit, immediate_generator, register_file | Proposed — not implemented |
| 6 | `immediate_generator` | ID | Sign-extends I/S/B/U/J immediates | instr_i[31:0], imm_type_i | imm_o[31:0] | control_unit, id_ex_reg | Proposed — not implemented |
| 7 | `control_unit` | ID | Generates ALU op, operand selects, memory, branch and writeback controls | opcode_i, funct3_i, funct7_i | alu_op_o, alu_src_o, mem_read_o, mem_write_o, reg_write_o, wb_sel_o, branch_o, jump_o, imm_type_o | instruction_decoder, id_ex_reg | Proposed — not implemented |
| 8 | `register_file` | ID/WB | 32x32 registers, 2 read / 1 write; x0 hardwired zero; same-cycle read/write behaviour TBD | rs1_addr_i, rs2_addr_i, we_i, rd_addr_i, rd_data_i | rs1_data_o, rs2_data_o | instruction_decoder, mem_wb_reg | Proposed — not implemented |
| 9 | `id_ex_reg` | ID/EX | Pipeline register: operands, immediate, register indices, controls | decoded fields, controls, stall_i, flush_i | registered fields, valid_o | control_unit, alu, forwarding_unit, hazard_unit | Proposed — not implemented |
| 10 | `alu` | EX | ADD SUB AND OR XOR SLL SRL SRA SLT SLTU; branch compare (EQ NE LT GE LTU GEU) and target | op_a_i, op_b_i, alu_op_i, funct3_i | result_o[31:0], branch_taken_o | id_ex_reg, forwarding_unit, pc_unit | Proposed — not implemented |
| 11 | `ex_mem_reg` | EX/MEM | Pipeline register: result/address, store data, rd, controls | result_i, store_data_i, rd_i, controls, hold_i, flush_i | registered fields, valid_o | alu, load_store_unit, forwarding_unit | Proposed — not implemented |
| 12 | `load_store_unit` | MEM | Forms bus requests with byte enables; aligns and sign/zero-extends loads; misalignment TBD | addr_i, wdata_i, funct3_i, mem_read_i, mem_write_i, bus rdata/ready/error | bus req/addr/we/wdata/be, load_data_o, busy_o | ex_mem_reg, bus_interconnect, hazard_unit | Proposed — not implemented |
| 13 | `mem_wb_reg` | MEM/WB | Pipeline register: ALU/load/link value, rd, reg_write; writeback select | alu_result_i, load_data_i, pc_plus4_i, rd_i, controls | wb_data_o, rd_o, reg_write_o, valid_o | load_store_unit, register_file, forwarding_unit | Proposed — not implemented |
| 14 | `hazard_unit` | Control | Load-use detection, bus-wait hold, branch/jump flush; stall/flush priority TBD | id_ex rd/mem_read, if_id rs1/rs2 + used flags, branch_taken_i, lsu_busy_i | stall_if_o, stall_id_o, flush_if_id_o, flush_id_ex_o | pc_unit, all pipeline registers | Proposed — not implemented |
| 15 | `forwarding_unit` | Control | Selects EX operands from EX/MEM or MEM/WB; newest wins; ignores x0 | id_ex rs1/rs2, ex_mem rd/reg_write, mem_wb rd/reg_write | fwd_a_sel_o, fwd_b_sel_o | id_ex_reg, ex_mem_reg, mem_wb_reg, alu | Proposed — not implemented |
| 16 | `instruction_memory` | Memory | Read-only instruction RAM/ROM; proposed 1-cycle synchronous read; size TBD | req_i, addr_i[31:0] | rdata_o[31:0], ready_o, error_o | pc_unit (via cpu_core) | Proposed — not implemented |
| 17 | `data_memory` | Memory | Byte-addressable data RAM with byte enables; size TBD | bus slave req/addr/we/wdata/be | rdata_o, ready_o, error_o | bus_interconnect | Proposed — not implemented |
| 18 | `bus_interconnect` | Bus | Single-master custom bus, address decoder and response mux; unmapped -> error | master req/addr/we/wdata/be; slave rdata/ready/error | slave selects; master rdata/ready/error | load_store_unit, data_memory, all peripherals | Proposed — not implemented |
| 19 | `uart_controller` | Peripheral | UART TX/RX with baud divider; FIFO depth TBD | bus slave port, rx_i | tx_o, irq_o, bus response | bus_interconnect, interrupt_controller | Proposed — not implemented |
| 20 | `spi_master` | Peripheral | SPI master; CPOL/CPHA support and CS count TBD | bus slave port, miso_i | sclk_o, mosi_o, cs_no, irq_o | bus_interconnect, interrupt_controller | Proposed — not implemented |
| 21 | `timer` | Peripheral | 32-bit counter with compare and interrupt | bus slave port | irq_o, bus response | bus_interconnect, interrupt_controller | Proposed — not implemented |
| 22 | `interrupt_controller` | Peripheral | Pending/enable/clear aggregation; CPU trap contract TBD | uart/spi/timer/ext irq, bus slave port | irq_o to cpu_core (TBD) | peripherals, cpu_core | Proposed — not implemented |

Planned RTL location: `rtl/<subsystem>/<module>.sv`. Planned testbench: `testbench/unit/tb_<module>.sv`.
