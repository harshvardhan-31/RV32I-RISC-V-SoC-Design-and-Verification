# Verification Plan

> No simulation has been executed. All results columns are **Not run**. A test is marked Passed only after its log is committed under `reports/simulation/` with commit hash, tool version, command and seed.

## Strategy
- Self-checking SystemVerilog testbenches per module (`testbench/unit/`).
- System testbenches load RV32I programs from `programs/` into instruction memory.
- Golden reference: hand-computed tables for units; a reference ISS (Spike, TBD) for programs.
- Assertions (SVA) for x0, valid/flush and bus handshake stability.
- Coverage: opcode coverage, hazard-type coverage, address-region coverage (tool support TBD).

## ALU — `alu`

| ID | Scenario | Expected result | Status |
|---|---|---|---|
| ALU-01 | ADD/SUB with overflow wrap (0x7FFFFFFF+1, 0-1) | Result equals reference model for every vector; 10,000+ random vectors with logged seed | Not run |
| ALU-02 | SUB result 0xFFFFFFFF for 0-1 | Result equals reference model for every vector; 10,000+ random vectors with logged seed | Not run |
| ALU-03 | AND/OR/XOR random vectors vs reference | Result equals reference model for every vector; 10,000+ random vectors with logged seed | Not run |
| ALU-04 | SLL/SRL/SRA shift 0, 1, 31; only rs2[4:0] used | Result equals reference model for every vector; 10,000+ random vectors with logged seed | Not run |
| ALU-05 | SRA of negative keeps sign | Result equals reference model for every vector; 10,000+ random vectors with logged seed | Not run |
| ALU-06 | SLT vs SLTU with 0x80000000 and 1 | Result equals reference model for every vector; 10,000+ random vectors with logged seed | Not run |
| ALU-07 | Branch compare all six conditions incl. equal and sign boundary | Result equals reference model for every vector; 10,000+ random vectors with logged seed | Not run |

## Register file — `register_file`

| ID | Scenario | Expected result | Status |
|---|---|---|---|
| REGISTER_FILE-01 | Reset state (value TBD or don't care) | Reads match last written value; x0 always 0 | Not run |
| REGISTER_FILE-02 | Write then read every register | Reads match last written value; x0 always 0 | Not run |
| REGISTER_FILE-03 | Write to x0 ignored; x0 reads 0 | Reads match last written value; x0 always 0 | Not run |
| REGISTER_FILE-04 | Two simultaneous reads of different and same registers | Reads match last written value; x0 always 0 | Not run |
| REGISTER_FILE-05 | Same-cycle write and read of same register | Reads match last written value; x0 always 0 | Not run |
| REGISTER_FILE-06 | we=0 does not change contents | Reads match last written value; x0 always 0 | Not run |

## Instruction decoder — `instruction_decoder`

| ID | Scenario | Expected result | Status |
|---|---|---|---|
| INSTRUCTION_DECODER-01 | Every RV32I opcode/funct3/funct7 combination | Fields and illegal flag match ISA tables | Not run |
| INSTRUCTION_DECODER-02 | Field extraction rd/rs1/rs2 | Fields and illegal flag match ISA tables | Not run |
| INSTRUCTION_DECODER-03 | Illegal opcodes and funct7 values flagged | Fields and illegal flag match ISA tables | Not run |

## Immediate generator — `immediate_generator`

| ID | Scenario | Expected result | Status |
|---|---|---|---|
| IMMEDIATE_GENERATOR-01 | I/S/B/U/J with all-zero, all-one and alternating bit patterns | Immediate equals ISA-manual bit assembly | Not run |
| IMMEDIATE_GENERATOR-02 | Sign bit 31 = 1 extends negatively | Immediate equals ISA-manual bit assembly | Not run |
| IMMEDIATE_GENERATOR-03 | B and J bit 0 = 0 | Immediate equals ISA-manual bit assembly | Not run |

## Control unit — `control_unit`

| ID | Scenario | Expected result | Status |
|---|---|---|---|
| CONTROL_UNIT-01 | Every instruction produces expected control vector | Control vector equals golden table in this document | Not run |
| CONTROL_UNIT-02 | Illegal instruction asserts no write side effects | Control vector equals golden table in this document | Not run |

## Pipeline registers — `if_id_reg / id_ex_reg / ex_mem_reg / mem_wb_reg`

| ID | Scenario | Expected result | Status |
|---|---|---|---|
| PIPE_REG-01 | Normal advancement | Values latch on posedge clk when valid=1 | Not run |
| PIPE_REG-02 | Stall assertion | Values held without change | Not run |
| PIPE_REG-03 | Flush assertion | Valid bit cleared, outputs zeroed | Not run |

## Hazard Detection Unit — `hazard_unit` (Phase 3)

| ID | Scenario | Expected result | Status |
|---|---|---|---|
| HAZARD-01 | Load-use hazard: rd matches rs1 | stall_if=1, stall_id=1, bubble_id_ex=1, flush_if_id=0 | Not run |
| HAZARD-02 | Load-use hazard: rd matches rs2 | stall_if=1, stall_id=1, bubble_id_ex=1, flush_if_id=0 | Not run |
| HAZARD-03 | Load-use with rd=x0 | No stall; all outputs 0 | Not run |
| HAZARD-04 | LUI false dependency (rs1 not used) | No stall; all outputs 0 | Not run |
| HAZARD-05 | rs2 not used by ID instruction | No stall; all outputs 0 | Not run |
| HAZARD-06 | ID/EX not valid | No stall; all outputs 0 | Not run |
| HAZARD-07 | ID/EX instruction is not a load | No stall; all outputs 0 | Not run |
| HAZARD-08 | Control hazard redirect in EX | stall_if=0, stall_id=0, bubble_id_ex=1, flush_if_id=1 | Not run |
| HAZARD-09 | No redirect in EX | All outputs 0 | Not run |
| HAZARD-10 | LSU busy: bus wait state | stall_if=1, stall_id=1, bubble_id_ex=0, flush_if_id=0 | Not run |
| HAZARD-11 | LSU busy + load-use pending | LSU busy priority; stalls hold, no bubble | Not run |
| HAZARD-12 | LSU busy + redirect pending | LSU busy priority; stalls hold, no flush | Not run |

## Forwarding Unit — `forwarding_unit` (Phase 3)

| ID | Scenario | Expected result | Status |
|---|---|---|---|
| FORWARD-01 | EX/MEM matches rs1 | fwd_sel_a = 2'b10 (EX/MEM forward) | Not run |
| FORWARD-02 | MEM/WB matches rs1 (EX/MEM no match) | fwd_sel_a = 2'b01 (MEM/WB forward) | Not run |
| FORWARD-03 | Both stages match rs1 | fwd_sel_a = 2'b10 (EX/MEM priority) | Not run |
| FORWARD-04 | EX/MEM rd = x0 | fwd_sel_a = 2'b00 (no forward for x0) | Not run |
| FORWARD-05 | EX/MEM reg_write = 0 | fwd_sel_a = 2'b00 (no forward) | Not run |
| FORWARD-06 | EX/MEM mem_read = 1 (load not ready) | fwd_sel_a = 2'b00 (EX/MEM load forward blocked) | Not run |
| FORWARD-07 | EX/MEM matches rs2 | fwd_sel_b = 2'b10 (EX/MEM forward) | Not run |
| FORWARD-08 | MEM/WB matches rs2 | fwd_sel_b = 2'b01 (MEM/WB forward) | Not run |
| FORWARD-09 | Both stages match rs2 | fwd_sel_b = 2'b10 (EX/MEM priority) | Not run |
| FORWARD-10 | MEM/WB rd = x0 | fwd_sel_b = 2'b00 (no forward) | Not run |
| FORWARD-11 | No match for rs1 or rs2 | fwd_sel_a = 2'b00, fwd_sel_b = 2'b00 | Not run |
| FORWARD-12 | EX/MEM load + MEM/WB match | fwd_sel_a = 2'b01 (MEM/WB forward applied) | Not run |

## System Integration Tests (Phase 3)

| ID | Program / Testbench | Scenario | Expected result | Status |
|---|---|---|---|---|
| SYS-HAZ-01 | `tb_hazard_integration` SEQ-A | RAW ALU chain (ADD->SUB->AND) | Register file: x3=8, x4=3, x5=0 | Not run |
| SYS-HAZ-02 | `tb_hazard_integration` SEQ-B | Load-use hazard (LW then ADD) | 1-cycle stall bubble, x3=42, x4=84 | Not run |
| SYS-HAZ-03 | `tb_hazard_integration` SEQ-C | Store data forwarding (ADD then SW) | M[0x1000_0004]=14, x4=14 | Not run |
| SYS-HAZ-04 | `tb_hazard_integration` SEQ-D | Triple-dependency chain | x2=2, x3=3, x4=5 | Not run |
| SYS-FWD-01 | `tb_cpu_forwarding` SEQ-A | Back-to-back ALU instructions | x2=20, x3=30 | Not run |
| SYS-FWD-02 | `tb_cpu_forwarding` SEQ-B | 2-stage back producer (MEM/WB) | x3=10 | Not run |
| SYS-FWD-03 | `tb_cpu_forwarding` SEQ-C | Branch operand forwarding (BEQ) | Branch taken, x3=1, bad path flushed | Not run |
| SYS-FWD-04 | `tb_cpu_forwarding` SEQ-D | JALR base-register forwarding | JALR targets correctly, x5=42 | Not run |
| SYS-FWD-05 | `tb_cpu_forwarding` SEQ-E | Store data forwarding | Memory stores correctly, x3=14 | Not run |
| SYS-FWD-06 | `tb_cpu_forwarding` SEQ-F | Load-use + MEM/WB forwarding | Stall bubble + forward, x4=198 | Not run |
