# ============================================================================
# File: docs/phase3_hazard_architecture.md
# Project: RV32I RISC-V SoC — Phase 3: Hazard Detection and Forwarding
# ============================================================================

# Phase 3 Hazard Detection Architecture

## 1. Overview

The `hazard_unit` module detects and resolves three classes of pipeline hazards
in the five-stage RV32I processor:

| Hazard Class | Source | Resolution |
|-------------|--------|------------|
| Load-use RAW | LW in EX, dependent instr in ID | 1 stall bubble |
| Control hazard | Branch/jump resolved in EX | Flush IF/ID + bubble ID/EX |
| Bus wait | LSU busy: data memory not ready | Freeze entire pipeline |

---

## 2. Load-Use Hazard Detection

A load-use hazard occurs when the instruction currently in **ID/EX** is a
memory load (`mem_read = 1`) and the instruction about to enter EX (currently
in **IF/ID**) reads the register that the load is writing.

### Formal Expression

```
load_use_hazard =
    id_ex_valid   &&
    id_ex_mem_read &&
    (id_ex_rd != 5'd0) &&
    if_id_valid   &&
    (
        (if_id_rs1_used && if_id_rs1 == id_ex_rd) ||
        (if_id_rs2_used && if_id_rs2 == id_ex_rd)
    )
```

### Conditions Explained

- `id_ex_valid`: the EX stage contains a real instruction (not a bubble).
- `id_ex_mem_read`: the EX instruction is a load (LW, LH, LB, LHU, LBU).
- `id_ex_rd != 0`: writing to x0 never creates a hazard (x0 is always 0).
- `if_id_valid`: the ID stage contains a real instruction.
- `if_id_rs1_used`: the ID instruction actually reads rs1 (excludes LUI, AUIPC, JAL).
- `if_id_rs2_used`: the ID instruction actually reads rs2 (excludes I-type, U-type, JAL).

### False Dependency Prevention

Instructions that do not use rs1 or rs2 (e.g., `LUI`, `AUIPC`) have
`rs1_used = 0` and `rs2_used = 0` from the `instruction_decoder`. This
prevents false stalls when the register field encodes to the same number as
the load destination purely by coincidence.

---

## 3. Load-Use Stall Timing Diagram

```
Cycle:        1       2       3       4       5
IF:          ADD    (held)  next2   next3   next4
ID:          LW     ADD    (held)  next2   next3
EX:                 LW     [NOP]   ADD     next2
MEM:                        LW     [NOP]   ADD
WB:                                 LW     [NOP]

             ↑ hazard_unit detects load-use at end of cycle 1
             ↑ Cycle 2: IF and ID held; bubble inserted into EX
             ↑ Cycle 3: load data available in MEM/WB; forwarded to ADD in EX
```

---

## 4. Control Hazard Handling

When a branch is taken or a jump instruction executes in the EX stage,
`redirect_valid` is asserted and `redirect_pc` selects the correct target.

Two wrong-path instructions have already been fetched:
- One in the **IF/ID** register (fetched while branch was in ID).
- One entering **ID/EX** (fetched while branch was in EX).

Both are discarded:
- `flush_if_id_o = 1` → IF/ID register clears (valid bit = 0).
- `bubble_id_ex_o = 1` → ID/EX register clears (valid bit = 0).

```
Cycle:        1       2       3       4
IF:          BEQ     W1      W2    [correct]
ID:                  BEQ     W1    [correct]
EX:                          BEQ   [bubble1]
             ↑ redirect_valid asserted end of cycle 3
             ↑ W1 in IF/ID flushed; W2 entering ID/EX flushed as bubble
             ↑ Cycle 4: correct target instruction fetched
```

Where W1 and W2 are wrong-path instructions that are discarded.

---

## 5. Bus Wait-State Handling

When `lsu_busy` is asserted (data memory has not asserted `ready`):
- **All stages** are frozen: PC, IF/ID, ID/EX, EX/MEM, MEM/WB all hold.
- No flush or bubble is generated — the pending redirect or hazard condition
  is preserved for the next cycle when `lsu_busy` deasserts.
- The LSU holds the memory bus transaction until `dmem_ready_i` arrives.

---

## 6. Stall Signal Table

| Signal | Source | Consumer | Active when |
|--------|--------|----------|-------------|
| `stall_if_o` | hazard_unit | pc_unit `stall_i` | lsu_busy OR load-use |
| `stall_id_o` | hazard_unit | if_id_reg `stall_i` | lsu_busy OR load-use |
| `bubble_id_ex_o` | hazard_unit | id_ex_reg `flush_i` | load-use bubble OR redirect |
| `flush_if_id_o` | hazard_unit | if_id_reg `flush_i` | redirect (control hazard) |

> **Note:** `stall_i` to `pc_unit` = `lsu_busy \|\| hz_stall_if`; to
> `if_id_reg` = `lsu_busy \|\| hz_stall_id`. These are composed in `cpu_core`.

---

## 7. Priority Encoding in hazard_unit

```systemverilog
always_comb begin
    // defaults
    stall_if_o = 0; stall_id_o = 0;
    bubble_id_ex_o = 0; flush_if_id_o = 0;

    if (lsu_busy_i) begin
        // Highest: freeze all; no flush/bubble
        stall_if_o = 1; stall_id_o = 1;

    end else if (load_use_hazard) begin
        // Mid: stall IF+ID; bubble ID/EX
        stall_if_o = 1; stall_id_o = 1;
        bubble_id_ex_o = 1;

    end else if (redirect_valid_i) begin
        // Control hazard: flush IF/ID; bubble ID/EX
        bubble_id_ex_o = 1; flush_if_id_o = 1;
    end
end
```
