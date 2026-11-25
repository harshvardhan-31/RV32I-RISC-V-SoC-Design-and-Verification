# Instruction Set — RV32I

Reference: *The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA*. Only the RV32I base integer ISA is targeted. Status of every instruction: **planned, not implemented**.

## Formats
| Format | Fields [31:0] |
|---|---|
| R | funct7 rs2 rs1 funct3 rd opcode |
| I | imm[11:0] rs1 funct3 rd opcode |
| S | imm[11:5] rs2 rs1 funct3 imm[4:0] opcode |
| B | imm[12|10:5] rs2 rs1 funct3 imm[4:1|11] opcode |
| U | imm[31:12] rd opcode |
| J | imm[20|10:1|11|19:12] rd opcode |

## Instructions
| Instruction | Format | Operation |
|---|---|---|
| LUI | U | rd = imm<<12 |
| AUIPC | U | rd = pc + (imm<<12) |
| JAL | J | rd = pc+4; pc += imm |
| JALR | I | rd = pc+4; pc = (rs1+imm) & ~1 |
| BEQ | B | branch if rs1 == rs2 |
| BNE | B | branch if rs1 != rs2 |
| BLT | B | signed < |
| BGE | B | signed >= |
| BLTU | B | unsigned < |
| BGEU | B | unsigned >= |
| LB | I | sign-extend byte |
| LH | I | sign-extend half |
| LW | I | word |
| LBU | I | zero-extend byte |
| LHU | I | zero-extend half |
| SB | S | store byte |
| SH | S | store half |
| SW | S | store word |
| ADDI | I | rs1 + imm |
| SLTI | I | signed rs1 < imm |
| SLTIU | I | unsigned rs1 < imm |
| XORI | I | rs1 ^ imm |
| ORI | I | rs1 | imm |
| ANDI | I | rs1 & imm |
| SLLI | I | rs1 << shamt |
| SRLI | I | logical >> |
| SRAI | I | arithmetic >> |
| ADD | R | rs1 + rs2 |
| SUB | R | rs1 - rs2 |
| SLL | R | rs1 << rs2[4:0] |
| SLT | R | signed < |
| SLTU | R | unsigned < |
| XOR | R | ^ |
| SRL | R | logical >> |
| SRA | R | arithmetic >> |
| OR | R | | |
| AND | R | & |
| FENCE | I | treated as NOP / serialize (TBD) |
| ECALL | I | decoded; behaviour TBD |
| EBREAK | I | decoded; behaviour TBD |

## Not supported
CSR instructions (Zicsr), FENCE.I, M/A/F/D/C extensions, privileged instructions (MRET, WFI). Misaligned access and illegal-instruction handling: **TBD**.
