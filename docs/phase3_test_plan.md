# ============================================================================
# File: docs/phase3_test_plan.md
# Project: RV32I RISC-V SoC — Phase 3: Hazard Detection and Forwarding
# ============================================================================

# Phase 3 Test Plan

## 1. Unit Tests — Hazard Detection Unit (`tb_hazard_unit.sv`)

| ID | Test Name | Input Conditions | Expected Outputs |
|----|-----------|-----------------|------------------|
| HAZARD-01 | Load-use hazard via rs1 | `id_ex_valid=1, id_ex_mem_read=1, id_ex_rd=3, if_id_rs1=3, rs1_used=1` | `stall_if=1, stall_id=1, bubble=1, flush=0` |
| HAZARD-02 | Load-use hazard via rs2 | `id_ex_rd=3, if_id_rs2=3, rs2_used=1` | `stall_if=1, stall_id=1, bubble=1, flush=0` |
| HAZARD-03 | Load-use to x0 — no stall | `id_ex_rd=0, if_id_rs2=0, rs2_used=1` | All zero |
| HAZARD-04 | LUI false dep — rs1 not used | `id_ex_rd=5, if_id_rs1=5, rs1_used=0` | All zero |
| HAZARD-05 | rs2 not used — no stall | `id_ex_rd=5, if_id_rs2=5, rs2_used=0` | All zero |
| HAZARD-06 | id_ex not valid — no stall | `id_ex_valid=0, if_id_rs1=5, rs1_used=1` | All zero |
| HAZARD-07 | ALU instruction — no stall | `id_ex_valid=1, id_ex_mem_read=0` | All zero |
| HAZARD-08 | Control hazard redirect | `redirect_valid=1` | `stall_if=0, stall_id=0, bubble=1, flush=1` |
| HAZARD-09 | No redirect — no flush | `redirect_valid=0` | All zero |
| HAZARD-10 | LSU busy only | `lsu_busy=1` | `stall_if=1, stall_id=1, bubble=0, flush=0` |
| HAZARD-11 | LSU busy + load-use | `lsu_busy=1, load_use=1` | `stall_if=1, stall_id=1, bubble=0, flush=0` (lsu priority) |
| HAZARD-12 | LSU busy + redirect | `lsu_busy=1, redirect_valid=1` | `stall_if=1, stall_id=1, bubble=0, flush=0` (lsu priority) |

---

## 2. Unit Tests — Forwarding Unit (`tb_forwarding_unit.sv`)

| ID | Test Name | Input Conditions | Expected Outputs |
|----|-----------|-----------------|------------------|
| FORWARD-01 | EX/MEM → rs1 | `ex_mem_valid=1, ex_mem_rd=5, reg_write=1, mem_read=0, ex_rs1=5` | `fwd_sel_a=2'b10` |
| FORWARD-02 | MEM/WB → rs1 | `mem_wb_valid=1, mem_wb_rd=5, reg_write=1, ex_rs1=5` (EX/MEM no match) | `fwd_sel_a=2'b01` |
| FORWARD-03 | Both → rs1: EX/MEM wins | Both `ex_mem_rd=5` and `mem_wb_rd=5` match `ex_rs1=5` | `fwd_sel_a=2'b10` |
| FORWARD-04 | rd=x0 in EX/MEM | `ex_mem_rd=0, ex_rs1=0` | `fwd_sel_a=2'b00` |
| FORWARD-05 | reg_write=0 in EX/MEM | `ex_mem_reg_write=0` | `fwd_sel_a=2'b00` |
| FORWARD-06 | EX/MEM load (mem_read=1) | `ex_mem_mem_read=1` | `fwd_sel_a=2'b00` |
| FORWARD-07 | EX/MEM → rs2 | `ex_mem_rd=5, ex_rs2=5, reg_write=1, mem_read=0` | `fwd_sel_b=2'b10` |
| FORWARD-08 | MEM/WB → rs2 | `mem_wb_rd=5, ex_rs2=5, reg_write=1` (EX/MEM no match) | `fwd_sel_b=2'b01` |
| FORWARD-09 | Both → rs2: EX/MEM wins | Both match | `fwd_sel_b=2'b10` |
| FORWARD-10 | rd=x0 in MEM/WB | `mem_wb_rd=0` | `fwd_sel_b=2'b00` |
| FORWARD-11 | No match | No `rd` matches any `rs` | `fwd_sel_a=00, fwd_sel_b=00` |
| FORWARD-12 | EX/MEM load; MEM/WB matches | `ex_mem_mem_read=1`, `mem_wb_rd=4=ex_rs1` | `fwd_sel_a=2'b01` |

---

## 3. System Integration Tests — `tb_hazard_integration.sv`

| ID | Sequence | Program | Expected Outcome |
|----|----------|---------|-----------------|
| SEQ-A | RAW ALU chain (5 instructions) | `ADDI→ADDI→ADD→SUB→AND` | `x3=8, x4=3, x5=0` |
| SEQ-B | Load-use: LW + ADD | LW x3; ADD x4, x3, x2 | `x3=42, x4=84` (1 stall bubble) |
| SEQ-C | Store data forwarding | ADD x3; SW x3, 0(x1); LW x4 | `x4=14` |
| SEQ-D | Triple-dependency chain | ADDI + 3×ADD | `x2=2, x3=3, x4=5` |

---

## 4. System Integration Tests — `tb_cpu_forwarding.sv`

| ID | Sequence | Scenario | Expected Outcome |
|----|----------|---------|-----------------|
| FWD-SEQ-A | 3 consecutive ALU instructions | EX/MEM + MEM/WB fwd | `x2=20, x3=30` |
| FWD-SEQ-B | Producer 2 instructions back | MEM/WB fwd | `x3=10` |
| FWD-SEQ-C | Branch operand forwarding | BEQ on forwarded operands | Branch taken; `x3=1` |
| FWD-SEQ-D | JALR with forwarded base | JALR base from MEM/WB | JALR resolves; `x5=42` |
| FWD-SEQ-E | Store data forwarding | SW rs2 from EX/MEM | `x3=14` in memory |
| FWD-SEQ-F | Load-use + MEM/WB fwd | LW then ADD (load-use stall) | `x4=198` |

---

## 5. Test Environment

| Item | Status |
|------|--------|
| Icarus Verilog | Not installed in CI environment |
| Verilator | Not installed in CI environment |
| riscv-gnu-toolchain | Not installed (asm files are reference only) |
| Simulation command | `bash scripts/run_phase3_sim.sh` |
| Lint command | `bash scripts/lint_phase3.sh` |

---

## 6. Pass/Fail Criteria

- **Unit tests:** All `$display("PASS ...")` lines printed; no `$fatal` triggered.
- **Integration tests:** All register values match golden expected values; no `$fatal`.
- **Lint:** Verilator exits with code 0; no errors.
