# ============================================================================
# File: docs/phase3_test_plan.md
# Project: RV32I RISC-V SoC — Phase 3: Hazard Detection and Forwarding
# ============================================================================

# Phase 3 Test Plan (Audited & Extended)

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
| FORWARD-13 | EX/MEM invalid entry (valid=0) | `ex_mem_valid=0, ex_mem_rd=7, ex_rs1=7, reg_write=1` | `fwd_sel_a=2'b00` |
| FORWARD-14 | MEM/WB invalid entry (valid=0) | `mem_wb_valid=0, mem_wb_rd=7, ex_rs1=7, reg_write=1` | `fwd_sel_a=2'b00` |
| FORWARD-15 | EX/MEM invalid entry for rs2 | `ex_mem_valid=0, ex_mem_rd=11, ex_rs2=11, reg_write=1` | `fwd_sel_b=2'b00` |
| FORWARD-16 | MEM/WB invalid entry for rs2 | `mem_wb_valid=0, mem_wb_rd=11, ex_rs2=11, reg_write=1` | `fwd_sel_b=2'b00` |
| FORWARD-17 | MEM/WB reg_write=0 for rs1 | `mem_wb_valid=1, mem_wb_rd=15, ex_rs1=15, reg_write=0` | `fwd_sel_a=2'b00` |
| FORWARD-18 | MEM/WB reg_write=0 for rs2 | `mem_wb_valid=1, mem_wb_rd=16, ex_rs2=16, reg_write=0` | `fwd_sel_b=2'b00` |
| FORWARD-19 | MEM/WB rd=x0 for rs1 | `mem_wb_valid=1, mem_wb_rd=0, ex_rs1=0, reg_write=1` | `fwd_sel_a=2'b00` |
| FORWARD-20 | Dual-stage simultaneous priority | EX/MEM writes x20 (rs1), MEM/WB writes x20 & x21 (rs2) | `fwd_sel_a=2'b10, fwd_sel_b=2'b01` |

---

## 3. System Integration Tests — `tb_hazard_integration.sv`

| ID | Sequence | Program | Expected Outcome |
|----|----------|---------|-----------------|
| SEQ-A | RAW ALU chain (5 instructions) | `ADDI→ADDI→ADD→SUB→AND` | `x3=8, x4=3, x5=0` |
| SEQ-B | Isolated Load-use dependency | `LW x3, 0(x1); ADD x4, x3, x2` | `x3=42, x4=84`, **assert exactly 1 stall cycle and 1 bubble** |
| SEQ-C | Store data forwarding | `ADD x2; SW x2, 4(x3); LW x4` | `x4=14` |
| SEQ-D | Triple-dependency chain | `ADDI + 3×ADD` | `x2=2, x3=3, x4=5` |
| SEQ-E | Multi-cycle memory wait states | `SW + LW + ADDI` with `WAIT_CYCLES=2` | Pipeline freezes during bus wait; `x3=123, x4=124` |
| SEQ-F | Branch redirect during outstanding memory load | `LW x6 (2 wait cycles) + BEQ taken` | `LW` completes (`x6=77`), branch redirect taken (`x8=99`), wrong path flushed (`x7=0`), **no redirect or instruction lost** |

---

## 4. System Integration Tests — `tb_cpu_forwarding.sv`

| ID | Sequence | Scenario | Expected Outcome |
|----|----------|---------|-----------------|
| FWD-SEQ-A | 3 consecutive ALU instructions | EX/MEM + MEM/WB fwd | `x2=20, x3=30` |
| FWD-SEQ-B | Producer 2 instructions back | MEM/WB fwd | `x3=10` |
| FWD-SEQ-C | Branch operand forwarding | BEQ on forwarded operands | Branch taken; `x3=1` |
| FWD-SEQ-D | Genuine immediate JALR dependency | `ADDI x1, x0, 24; JALR x4, x1, 0` | Target 24 reached; `x1=24, x4=8, x3=0 (flushed), x5=42` |
| FWD-SEQ-E | Store data forwarding | SW rs2 from EX/MEM | `x3=14` in memory |
| FWD-SEQ-F | Load-use + MEM/WB forward | LW then ADD (load-use stall) | `x4=198` |
| FWD-SEQ-G | x0 protection in pipeline | `ADDI x0, x0, 99; ADD x6, x0, x0` | `x6=0` (writes to x0 never forwarded) |
| FWD-SEQ-H | Back-to-back producer priority | `ADDI x7, 10; ADDI x7, 20; ADD x8, x7, x0` | `x8=20` (EX/MEM has priority over MEM/WB) |

---

## 5. Decoder & Control Unit Verification

| ID | Testbench | Scenario | Expected Outcome |
|----|-----------|---------|-----------------|
| DEC-SYS-01 | `tb_instruction_decoder` | ECALL (`32'h0000_0073`) | `illegal_instr=0, funct12=12'h000` |
| DEC-SYS-02 | `tb_instruction_decoder` | EBREAK (`32'h0010_0073`) | `illegal_instr=0, funct12=12'h001` |
| DEC-SYS-03 | `tb_instruction_decoder` | Invalid SYSTEM encoding (`32'h0020_0073`) | `illegal_instr=1` |
| DEC-SYS-04 | `tb_instruction_decoder` | ECALL with non-zero rd (`32'h0000_00F3`) | `illegal_instr=1` |
| CTRL-SYS-01 | `tb_control_unit` | ECALL (`funct12=12'h000`) | `sys_ecall=1, sys_ebreak=0`, no write side effects |
| CTRL-SYS-02 | `tb_control_unit` | EBREAK (`funct12=12'h001`) | `sys_ecall=0, sys_ebreak=1`, no write side effects |
