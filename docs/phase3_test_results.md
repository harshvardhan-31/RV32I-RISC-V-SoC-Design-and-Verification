# ============================================================================
# File: docs/phase3_test_results.md
# Project: RV32I RISC-V SoC — Phase 3: Hazard Detection and Forwarding
# ============================================================================

# Phase 3 Test Results (Audit Status)

> [!IMPORTANT]
> All simulation tests remain marked **Not run** because Icarus Verilog (`iverilog`)
> and Verilator are not installed in the local CI/sandbox environment.
> In accordance with project engineering rules, results are never fabricated.
> Run `bash scripts/run_phase3_sim.sh` locally once Icarus Verilog is installed.

---

## 1. Unit Test Results — Hazard Detection Unit (`tb_hazard_unit.sv`)

| ID | Test Name | Status |
|----|-----------|--------|
| HAZARD-01 | Load-use hazard via rs1 | Not run |
| HAZARD-02 | Load-use hazard via rs2 | Not run |
| HAZARD-03 | Load-use to x0 — no stall | Not run |
| HAZARD-04 | LUI false dep — rs1 not used | Not run |
| HAZARD-05 | rs2 not used — no stall | Not run |
| HAZARD-06 | id_ex not valid — no stall | Not run |
| HAZARD-07 | ALU instruction — no stall | Not run |
| HAZARD-08 | Control hazard redirect | Not run |
| HAZARD-09 | No redirect — no flush | Not run |
| HAZARD-10 | LSU busy only | Not run |
| HAZARD-11 | LSU busy + load-use | Not run |
| HAZARD-12 | LSU busy + redirect | Not run |

---

## 2. Unit Test Results — Forwarding Unit (`tb_forwarding_unit.sv`)

| ID | Test Name | Status |
|----|-----------|--------|
| FORWARD-01 | EX/MEM → rs1 | Not run |
| FORWARD-02 | MEM/WB → rs1 | Not run |
| FORWARD-03 | Both match rs1: EX/MEM wins | Not run |
| FORWARD-04 | rd=x0 in EX/MEM | Not run |
| FORWARD-05 | reg_write=0 in EX/MEM | Not run |
| FORWARD-06 | EX/MEM load (mem_read=1) | Not run |
| FORWARD-07 | EX/MEM → rs2 | Not run |
| FORWARD-08 | MEM/WB → rs2 | Not run |
| FORWARD-09 | Both match rs2: EX/MEM wins | Not run |
| FORWARD-10 | rd=x0 in MEM/WB | Not run |
| FORWARD-11 | No match | Not run |
| FORWARD-12 | EX/MEM load; MEM/WB fallback | Not run |
| FORWARD-13 | EX/MEM invalid entry (valid=0) | Not run |
| FORWARD-14 | MEM/WB invalid entry (valid=0) | Not run |
| FORWARD-15 | EX/MEM invalid entry for rs2 | Not run |
| FORWARD-16 | MEM/WB invalid entry for rs2 | Not run |
| FORWARD-17 | MEM/WB reg_write=0 for rs1 | Not run |
| FORWARD-18 | MEM/WB reg_write=0 for rs2 | Not run |
| FORWARD-19 | MEM/WB rd=x0 for rs1 | Not run |
| FORWARD-20 | Dual-stage simultaneous priority | Not run |

---

## 3. Integration Test Results — `tb_hazard_integration.sv`

| ID | Sequence | Status |
|----|----------|--------|
| SEQ-A | RAW ALU chain (EX/MEM + MEM/WB fwd) | Not run |
| SEQ-B | Isolated Load-use dependency (1 cycle & 1 bubble assert) | Not run |
| SEQ-C | Store data forwarding | Not run |
| SEQ-D | Triple-dependency chain | Not run |
| SEQ-E | Multi-cycle memory wait states (WAIT_CYCLES=2) | Not run |
| SEQ-F | Branch redirect during outstanding memory transaction | Not run |

---

## 4. Integration Test Results — `tb_cpu_forwarding.sv`

| ID | Sequence | Status |
|----|----------|--------|
| FWD-SEQ-A | Consecutive ALU forwarding | Not run |
| FWD-SEQ-B | MEM/WB→EX forwarding | Not run |
| FWD-SEQ-C | Branch operand forwarding | Not run |
| FWD-SEQ-D | Genuine immediate JALR dependency | Not run |
| FWD-SEQ-E | Store data forwarding | Not run |
| FWD-SEQ-F | Load-use + MEM/WB forward | Not run |
| FWD-SEQ-G | Register x0 protection | Not run |
| FWD-SEQ-H | Back-to-back producer priority | Not run |

---

## 5. Decoder & Control Unit Results

| ID | Scenario | Status |
|----|----------|--------|
| DEC-SYS-01 | ECALL instruction decoding | Not run |
| DEC-SYS-02 | EBREAK instruction decoding | Not run |
| DEC-SYS-03 | Invalid SYSTEM opcode decoding | Not run |
| DEC-SYS-04 | ECALL with non-zero rd | Not run |
| CTRL-SYS-01 | ECALL control signals (sys_ecall=1) | Not run |
| CTRL-SYS-02 | EBREAK control signals (sys_ebreak=1) | Not run |

---

## 6. How to Run Locally

```bash
# Run all Phase 3 simulations
bash scripts/run_phase3_sim.sh

# Or with Make
make test_phase3

# Run lint checks
bash scripts/lint_phase3.sh
```
