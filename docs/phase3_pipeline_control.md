# ============================================================================
# File: docs/phase3_pipeline_control.md
# Project: RV32I RISC-V SoC — Phase 3: Hazard Detection and Forwarding
# ============================================================================

# Phase 3 Pipeline Control Signal Reference

## 1. Per-Stage Control Signal Assignment

This table shows the exact stall and flush signals connected to each pipeline
register and to `pc_unit` in the Phase 3 `cpu_core.sv`.

| Component | `stall_i` | `flush_i` |
|-----------|-----------|-----------|
| `pc_unit` | `lsu_busy \|\| hz_stall_if` | — (redirect via `redirect_i`) |
| `if_id_reg` | `lsu_busy \|\| hz_stall_id` | `hz_flush_if_id` |
| `id_ex_reg` | `lsu_busy` | `hz_bubble_id_ex` |
| `ex_mem_reg` | `lsu_busy` | `1'b0` |
| `mem_wb_reg` | `lsu_busy` | `1'b0` |

---

## 2. Pipeline Behavior per Scenario

### 2.1 Normal Operation (no hazard, no stall)

| Signal | Value |
|--------|-------|
| `pc_stall` | 0 |
| `if_id_stall` | 0 |
| `if_id_flush` | 0 |
| `id_ex_stall` | 0 |
| `hz_bubble_id_ex` | 0 |
| All stages | Advance |

---

### 2.2 Load-Use Hazard

Triggered when `hazard_unit` detects a load-use dependency (`lsu_busy = 0`).

| Signal | Value |
|--------|-------|
| `hz_stall_if` | 1 |
| `hz_stall_id` | 1 |
| `hz_bubble_id_ex` | 1 |
| `hz_flush_if_id` | 0 |
| `pc_stall` | 1 |
| `if_id_stall` | 1 |
| `id_ex_stall` | 0 → ID/EX gets bubble |
| EX/MEM, MEM/WB | Advance normally |

**Effect:**
- PC holds → same instruction fetched again.
- IF/ID holds → instruction stays in ID for one more cycle.
- ID/EX gets flush → bubble inserted into EX.
- Load advances from EX to MEM, then WB.

---

### 2.3 Control Hazard (Branch/Jump Taken)

Triggered when `redirect_valid = 1` from EX stage (`lsu_busy = 0`).

| Signal | Value |
|--------|-------|
| `hz_stall_if` | 0 |
| `hz_stall_id` | 0 |
| `hz_bubble_id_ex` | 1 |
| `hz_flush_if_id` | 1 |
| `pc_stall` | 0 |
| `redirect_valid` to `pc_unit` | 1 |
| All EX/MEM, MEM/WB | Advance normally |

**Effect:**
- PC redirected to `redirect_pc` on the next rising edge.
- IF/ID flushed → wrong-path fetch discarded.
- ID/EX bubbled → wrong-path decode discarded.
- 2-instruction wrong-path penalty.

---

### 2.4 LSU Bus Stall

Triggered when `lsu_busy = 1` (data memory not ready).

| Signal | Value |
|--------|-------|
| `hz_stall_if` | 1 |
| `hz_stall_id` | 1 |
| `hz_bubble_id_ex` | 0 |
| `hz_flush_if_id` | 0 |
| `pc_stall` | 1 |
| `if_id_stall` | 1 |
| `id_ex_stall` | 1 |
| `exmem_stall` | 1 |
| `memwb_stall` | 1 |

**Effect:** Entire pipeline frozen. The LSU continues driving the data memory
bus until `dmem_ready_i` asserts, at which point `lsu_busy` deasserts and
normal advancement resumes.

---

## 3. Signal Dependency Diagram

```
  lsu_busy ──────────────────────────────────────────────────────────────┐
                                                                          │
  load_use ───────────────────────────────────────────────┐              │
  (from hazard_unit)                                       │              │
                                                           ▼              ▼
  redirect_valid ──────────── hazard_unit ──────── hz_stall_if ──┬── pc_stall ──► pc_unit
                                │                                 │
                                │                  hz_stall_id ──┴── if_id_stall ──► if_id_reg stall
                                │
                                │                  hz_flush_if_id ────────────────► if_id_reg flush
                                │
                                │                  hz_bubble_id_ex ────────────────► id_ex_reg flush
                                │
  lsu_busy ───────────────────────────────────────────────────────────────► id_ex_reg stall
  lsu_busy ───────────────────────────────────────────────────────────────► ex_mem_reg stall
  lsu_busy ───────────────────────────────────────────────────────────────► mem_wb_reg stall
```

---

## 4. Forwarding Signal Paths

```
  EX/MEM ─── mem_alu_result ──► fwd_rs1_val mux (fwd_sel_a=10) ──► alu_op_a
                              ──► fwd_rs2_val mux (fwd_sel_b=10) ──► alu_op_b / store_data

  MEM/WB ─── wb_data ──────────► fwd_rs1_val mux (fwd_sel_a=01) ──► alu_op_a
                              ──► fwd_rs2_val mux (fwd_sel_b=01) ──► alu_op_b

  ID/EX ──── ex_rs1_data ──────► fwd_rs1_val mux (fwd_sel_a=00) ──► alu_op_a (default)
  ID/EX ──── ex_rs2_data ──────► fwd_rs2_val mux (fwd_sel_b=00) ──► alu_op_b (default)

  fwd_rs1_val ─── (alu_src_a? ex_pc : fwd_rs1_val) ──► alu_op_a ──► ALU
  fwd_rs2_val ─── (alu_src_b? ex_imm : fwd_rs2_val) ──► alu_op_b ──► ALU

  fwd_rs1_val ───────────────────────────────────────► jalr_target base
  fwd_rs2_val ───────────────────────────────────────► ex_mem_reg rs2_data_i (store data)
```

---

## 5. Reset Behavior

On `rst_ni = 0` (active-low synchronous reset):
- All pipeline registers assert valid = 0 (clear their contents).
- PC resets to `RESET_VECTOR` (0x0000_0000 by default).
- Hazard and forwarding units are combinational — their outputs are
  defined by their inputs; no internal state.
