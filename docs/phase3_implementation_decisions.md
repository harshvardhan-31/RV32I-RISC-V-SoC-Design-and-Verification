# ============================================================================
# File: docs/phase3_implementation_decisions.md
# Project: RV32I RISC-V SoC — Phase 3: Hazard Detection and Forwarding
# ============================================================================

# Phase 3 Implementation Decisions

This document records all design decisions made during Phase 3 — Hazard Detection
and Forwarding. These decisions apply only to Phase 3 and supplement the Phase 2
implementation decisions (`phase2_implementation_decisions.md`).

---

## 1. Forwarding Select Encoding

The `forwarding_unit` outputs two 2-bit select signals:

| `fwd_sel_a_o` / `fwd_sel_b_o` | Meaning |
|-------------------------------|---------|
| `2'b00` | Register file value (no forwarding; default) |
| `2'b10` | Forward from EX/MEM stage |
| `2'b01` | Forward from MEM/WB stage |

Rationale: `2'b10` and `2'b01` are distinct single-bit patterns, making the
encoding easy to decode in the ALU-operand mux `always_comb` block.

---

## 2. EX/MEM Load Result Not Forwarded

**Decision:** The forwarding_unit does **not** forward from the EX/MEM pipeline
register when `ex_mem_mem_read` is asserted.

**Reason:** When a load instruction is in the EX/MEM pipeline register, its
destination data (`mem_load_data`) is not yet available — it will only be
computed at the end of the MEM stage when the data bus responds.

**Handling:** The `hazard_unit` inserts exactly one stall bubble when a load-use
dependency is detected. After the stall, the load instruction advances to WB and
the loaded value is forwarded from MEM/WB via `wb_data` on the next cycle.

---

## 3. Load-Use Stall Bubble Count

**Decision:** Exactly **one** bubble is inserted for a load-use hazard.

**Mechanism:**
1. `hazard_unit` asserts `stall_if_o` and `stall_id_o` → PC and IF/ID are held.
2. `hazard_unit` asserts `bubble_id_ex_o` → ID/EX is flushed (inserting a NOP bubble).
3. The load instruction advances from EX to MEM in that cycle.
4. After one cycle, the loaded value is available in MEM/WB and forwarded to EX.

---

## 4. Stall Priority (Highest to Lowest)

| Priority | Condition | Action |
|----------|-----------|--------|
| 1 (highest) | Reset (`!rst_ni`) | All registers cleared by hardware reset |
| 2 | `lsu_busy` | Freeze entire pipeline (no flush, no bubble) |
| 3 | `load_use_hazard` | Stall PC + IF/ID; insert bubble into ID/EX |
| 4 | `redirect_valid` | Flush IF/ID; insert bubble into ID/EX |
| 5 (default) | None | Normal pipeline advance |

---

## 5. Per-Stage Stall Signal Assignment (Phase 3)

| Stage | Stall Source | Flush Source |
|-------|-------------|--------------|
| PC (`pc_unit`) | `lsu_busy \|\| hz_stall_if` | (redirect via `redirect_i`) |
| IF/ID | `lsu_busy \|\| hz_stall_id` | `hz_flush_if_id` |
| ID/EX | `lsu_busy` only | `hz_bubble_id_ex` |
| EX/MEM | `lsu_busy` only | `1'b0` (never flushed) |
| MEM/WB | `lsu_busy` only | `1'b0` |

**Key insight:** When `lsu_busy` is asserted, the entire pipeline is frozen.
The load-use stall and control-hazard flush are only active when `lsu_busy = 0`.
This is enforced by priority ordering in `hazard_unit`.

---

## 6. Branch Operand Forwarding

**Decision:** Branch operands are forwarded through the same mux as ALU operands.

The `alu.sv` module uses `op_a_i` and `op_b_i` for all comparisons (BEQ, BNE,
BLT, BGE, etc.) via `funct3_i`. Because the forwarding muxes produce
`fwd_rs1_val` and `fwd_rs2_val` which feed directly into `alu_op_a` and
`alu_op_b`, branch comparisons automatically use forwarded values.

No separate branch-operand forwarding path is needed.

---

## 7. JALR Target Forwarding

**Decision:** JALR target `= (fwd_rs1_val + ex_imm) & ~32'd1`

The base register for JALR uses the forwarded `fwd_rs1_val` (not the stale
`ex_rs1_data` from the register file). This ensures that:

```
ADDI x1, x0, func_addr   # x1 = target
JALR x2, x1, 0           # jump to x1 — forwarded from MEM/WB
```

resolves correctly without a NOP between the ADDI and JALR.

---

## 8. Store Data Forwarding

**Decision:** The `ex_mem_reg` input `rs2_data_i` is connected to `fwd_rs2_val`
(the forwarded rs2 value), not to the raw `ex_rs2_data` from the ID/EX register.

This ensures that:

```
ADD x3, x1, x2    # x3 computed in EX
SW  x3, 0(x4)     # store data forwarded from EX/MEM → ex_mem_reg
```

stores the correct freshly-computed value, not the stale register-file value.

---

## 9. Control Hazard — 2-Cycle Penalty

**Decision:** Branches and jumps resolved in EX incur a **2-cycle penalty**:
- Cycle 1 after branch: IF/ID flushed (wrong-path fetch discarded).
- Cycle 2 after branch: ID/EX flushed (instruction that entered decode from the wrong path is discarded).

This is correct for the static not-taken policy from Phase 2:
- Taken branches/jumps always flush 2 wrong-path instructions.
- Not-taken branches (correctly predicted not-taken) incur zero penalty.

---

## 10. Misaligned Access, Illegal Instructions, ECALL/EBREAK

**Decision (unchanged from Phase 2):**
- Misaligned instruction addresses: undefined behavior; no trap support.
- Illegal instructions: `illegal_instr_o` from decoder propagates through pipeline; no trap raised.
- ECALL/EBREAK: control signals asserted but no privilege-mode trap handler; processor stalls or behaves undefined.
- These are documented Phase 3 limitations, not bugs.

---

## 11. x0 Register Handling

**Decision:**
- Register file: writes to x0 are discarded; reads always return 0.
- Forwarding unit: `ex_mem_rd_addr_i == 0` and `mem_wb_rd_addr_i == 0` conditions disable forwarding.
- Hazard unit: `id_ex_rd_i == 0` disables load-use stall detection.

---

## 12. No Phase 4 Content in Phase 3

Phase 3 strictly adds `hazard_unit.sv`, `forwarding_unit.sv`, and an updated
`cpu_core.sv`. No peripherals, SoC interconnect, interrupt controllers, or
privilege modes are included. These belong to future phases.
