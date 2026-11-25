# Verification Plan

> No simulation has been executed. All results columns are **Not run**. A test is marked Passed only after its log is committed under `reports/simulation/` with commit hash, tool version, command and seed.

## Strategy
- Self-checking SystemVerilog testbenches per module (`testbench/unit/`).
- System testbench loads RV32I programs from `programs/` into instruction memory.
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
| REGISTER_FILE-05 | Same-cycle write and read of same register (behaviour per decision) | Reads match last written value; x0 always 0 | Not run |
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
| CONTROL_UNIT-01 | Every instruction produces expected control vector | Control vector equals golden table in this document (to be added) | Not run |
| CONTROL_UNIT-02 | Illegal instruction asserts no write side effects | Control vector equals golden table in this document (to be added) | Not run |

## Pipeline registers — `if_id_reg / id_ex_reg / ex_mem_reg / mem_wb_reg`

| ID | Scenario | Expected result | Status |
|---|---|---|---|
| IF_ID_REG-01 | Reset clears valid | Contents per priority table; flushed entries never write | Not run |
| IF_ID_REG-02 | Advance captures inputs | Contents per priority table; flushed entries never write | Not run |
| IF_ID_REG-03 | Stall holds contents | Contents per priority table; flushed entries never write | Not run |
| IF_ID_REG-04 | Flush clears valid and side-effect controls | Contents per priority table; flushed entries never write | Not run |
| IF_ID_REG-05 | Stall and flush same cycle follows priority | Contents per priority table; flushed entries never write | Not run |

## Hazard detection unit — `hazard_unit`

| ID | Scenario | Expected result | Status |
|---|---|---|---|
| HAZARD_UNIT-01 | Load followed by dependent ALU on rs1, rs2, both | Exactly one bubble for load-use; correct flush signals | Not run |
| HAZARD_UNIT-02 | Load followed by independent instruction: no stall | Exactly one bubble for load-use; correct flush signals | Not run |
| HAZARD_UNIT-03 | Load to x0: no stall | Exactly one bubble for load-use; correct flush signals | Not run |
| HAZARD_UNIT-04 | Source not used (e.g. LUI): no stall | Exactly one bubble for load-use; correct flush signals | Not run |
| HAZARD_UNIT-05 | Taken branch/jump flush | Exactly one bubble for load-use; correct flush signals | Not run |
| HAZARD_UNIT-06 | Bus wait hold | Exactly one bubble for load-use; correct flush signals | Not run |

## Forwarding unit — `forwarding_unit`

| ID | Scenario | Expected result | Status |
|---|---|---|---|
| FORWARDING_UNIT-01 | EX/MEM match | Select signals match priority rules | Not run |
| FORWARDING_UNIT-02 | MEM/WB match | Select signals match priority rules | Not run |
| FORWARDING_UNIT-03 | Both match: EX/MEM wins | Select signals match priority rules | Not run |
| FORWARDING_UNIT-04 | rd = x0: no forward | Select signals match priority rules | Not run |
| FORWARDING_UNIT-05 | reg_write = 0: no forward | Select signals match priority rules | Not run |
| FORWARDING_UNIT-06 | Store data forwarding | Select signals match priority rules | Not run |

## Complete processor — `rv32i_soc_top`

| ID | Scenario | Expected result | Status |
|---|---|---|---|
| RV32I_SOC_TOP-01 | One directed program per instruction class | Register file and memory signatures match the reference; retirement trace equal | Not run |
| RV32I_SOC_TOP-02 | Back-to-back dependent instructions | Register file and memory signatures match the reference; retirement trace equal | Not run |
| RV32I_SOC_TOP-03 | Load-use sequences | Register file and memory signatures match the reference; retirement trace equal | Not run |
| RV32I_SOC_TOP-04 | Taken / not-taken branches, JAL, JALR | Register file and memory signatures match the reference; retirement trace equal | Not run |
| RV32I_SOC_TOP-05 | Byte/half/word loads and stores at all offsets | Register file and memory signatures match the reference; retirement trace equal | Not run |
| RV32I_SOC_TOP-06 | Peripheral register read/write and IRQ | Register file and memory signatures match the reference; retirement trace equal | Not run |
| RV32I_SOC_TOP-07 | Random RV32I programs compared with Spike or a reference ISS (tool TBD) | Register file and memory signatures match the reference; retirement trace equal | Not run |

## Exit criteria (Phase 5)
All directed tests pass, random regression with documented seeds passes, coverage targets (TBD) met, no open critical bugs.
