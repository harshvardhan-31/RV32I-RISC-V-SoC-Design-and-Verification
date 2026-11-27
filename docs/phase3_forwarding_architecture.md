# ============================================================================
# File: docs/phase3_forwarding_architecture.md
# Project: RV32I RISC-V SoC — Phase 3: Hazard Detection and Forwarding
# ============================================================================

# Phase 3 Data Forwarding Architecture

## 1. Overview

The `forwarding_unit` resolves Read-After-Write (RAW) data hazards by selecting
the most recent valid producer of a register value and feeding it directly to
the EX stage operands, bypassing the register file.

---

## 2. Forwarding Paths

```
                        ┌─────────────────────────────────────┐
   ID/EX                │  EX/MEM                 MEM/WB      │
   ┌───────┐            │  ┌────────┐              ┌────────┐  │
   │ rs1   ├────────────┼──┤        │              │        │  │
   │ rs2   ├─────────┐  │  │ rd     │──EX/MEM fwd──▶ mux A │  │
   │ rd    │         │  │  │ result │              │        │  │
   └───────┘         │  │  └────────┘              └────────┘  │
                     │  │                                      │
                     │  │  MEM/WB                              │
                     │  │  ┌────────┐              ┌────────┐  │
                     └──┼──┤ rd     │──MEM/WB fwd──▶ mux B │  │
                        │  │ wb_data│              │        │  │
                        │  └────────┘              └────────┘  │
                        └─────────────────────────────────────┘
                                                 ↓ ↓
                                            fwd_rs1_val  fwd_rs2_val
                                                 ↓ ↓
                                        alu_op_a / alu_op_b (ALU inputs)
```

---

## 3. Forwarding Priority

For each source register (rs1, rs2) the following priority applies:

| Priority | Condition | fwd_sel value | Data Source |
|----------|-----------|---------------|-------------|
| 1 (highest) | EX/MEM valid, `reg_write=1`, `mem_read=0`, `rd==rs` | `2'b10` | `mem_alu_result` |
| 2 | MEM/WB valid, `reg_write=1`, `rd==rs` | `2'b01` | `wb_data` |
| 3 (default) | No match | `2'b00` | `ex_rs1_data` / `ex_rs2_data` |

**EX/MEM load result is not forwarded** (`mem_read=1` blocks EX/MEM forward).
The load data is unavailable until after the MEM stage completes.
Instead, the `hazard_unit` inserts a stall bubble, and after one cycle
the loaded value is in MEM/WB and forwarded via path 2.

---

## 4. Forwarding Select Encoding

| `fwd_sel_a_o` / `fwd_sel_b_o` | Meaning |
|-------------------------------|---------|
| `2'b00` | Use register-file value (no forwarding) |
| `2'b10` | Forward from EX/MEM (`mem_alu_result`) |
| `2'b01` | Forward from MEM/WB (`wb_data`) |

---

## 5. Forwarding Mux Implementation (in cpu_core)

```systemverilog
// Operand A (rs1) forwarding mux
always_comb begin
    case (fwd_sel_a)
        2'b10:   fwd_rs1_val = mem_alu_result;  // from EX/MEM
        2'b01:   fwd_rs1_val = wb_data;          // from MEM/WB
        default: fwd_rs1_val = ex_rs1_data;      // from register file
    endcase
    // Operand B (rs2)
    case (fwd_sel_b)
        2'b10:   fwd_rs2_val = mem_alu_result;
        2'b01:   fwd_rs2_val = wb_data;
        default: fwd_rs2_val = ex_rs2_data;
    endcase
end

// ALU src mux uses forwarded values
assign alu_op_a = ex_alu_src_a ? ex_pc       : fwd_rs1_val;
assign alu_op_b = ex_alu_src_b ? ex_imm      : fwd_rs2_val;
```

---

## 6. Store Data Forwarding

Store instructions (SW, SH, SB) write register `rs2` to data memory.
The `rs2_data_i` input to `ex_mem_reg` is connected to `fwd_rs2_val` so that:

```
ADD x3, x1, x2    # x3 produced in EX
SW  x3, 0(x4)     # x3 forwarded from EX/MEM → store data correct
```

Without forwarding, the SW would read a stale x3 from the register file (the
ADD result hasn't been written back yet).

---

## 7. Branch Operand Forwarding

Branch instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU) compare `rs1` and `rs2`.
In `alu.sv`, the comparison uses `op_a_i` and `op_b_i`. Because these are driven
from `alu_op_a` and `alu_op_b` which use `fwd_rs1_val` / `fwd_rs2_val`, branch
comparisons automatically receive forwarded operands.

```
ADDI x1, x0, 10     # x1 = 10
ADDI x2, x0, 10     # x2 = 10
BEQ  x1, x2, target # x1 and x2 forwarded from EX/MEM, MEM/WB
```

---

## 8. JALR Base-Register Forwarding

```
ADDI x1, x0, func_addr  # x1 = target address
JALR x2, x1, 0           # base = x1, forwarded from MEM/WB
```

The JALR target `= (fwd_rs1_val + ex_imm) & ~32'd1` uses `fwd_rs1_val`.
This ensures a dependent JALR resolves to the correct address.

---

## 9. x0 Forwarding Rules

- The forwarding unit never forwards when `rd == 5'd0` (x0 is always 0).
- Register file reads to x0 always return 0 regardless of writes.
- Load-use stall for load-to-x0 is never triggered.

---

## 10. Forwarding Timing Example

```
Cycle:    1         2         3         4
IF:      SUB      ADDI     AND       ...
ID:      ADD      SUB      ADDI     AND
EX:      (nop)    ADD      SUB      ADDI
MEM:              (nop)    ADD      SUB
WB:                        (nop)    ADD

ADD x1,x2,x3 → result available in MEM(cycle 3)
SUB x4,x1,x5 → needs x1 in EX(cycle 3): EX/MEM forward 2'b10 ✓
AND x6,x1,x4 → needs x1 in EX(cycle 4): MEM/WB forward 2'b01 ✓
              → needs x4 in EX(cycle 4): EX/MEM forward 2'b10 ✓
```
