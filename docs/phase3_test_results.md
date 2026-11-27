# ============================================================================
# File: docs/phase3_test_results.md
# Project: RV32I RISC-V SoC — Phase 3: Hazard Detection and Forwarding
# ============================================================================

# Phase 3 Test Results

> [!IMPORTANT]
> All simulation results are marked **Not run**. Icarus Verilog and Verilator
> are not installed in the CI/sandbox environment used to generate this package.
> Run `bash scripts/run_phase3_sim.sh` with Icarus Verilog ≥ 11.0 installed
> to execute all tests.

---

## 1. Unit Test Results — Hazard Detection Unit

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

## 2. Unit Test Results — Forwarding Unit

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

---

## 3. Integration Test Results — tb_hazard_integration

| ID | Sequence | Status |
|----|----------|--------|
| SEQ-A | RAW ALU chain (EX/MEM + MEM/WB fwd) | Not run |
| SEQ-B | Load-use hazard with stall bubble | Not run |
| SEQ-C | Store data forwarding | Not run |
| SEQ-D | Triple-dependency chain | Not run |

---

## 4. Integration Test Results — tb_cpu_forwarding

| ID | Sequence | Status |
|----|----------|--------|
| FWD-SEQ-A | Consecutive ALU forwarding | Not run |
| FWD-SEQ-B | MEM/WB→EX forwarding | Not run |
| FWD-SEQ-C | Branch operand forwarding | Not run |
| FWD-SEQ-D | JALR base forwarding | Not run |
| FWD-SEQ-E | Store data forwarding | Not run |
| FWD-SEQ-F | Load-use + MEM/WB forward | Not run |

---

## 5. Lint Results

| Module | Verilator Status |
|--------|-----------------|
| hazard_unit.sv | Not run |
| forwarding_unit.sv | Not run |
| cpu_core.sv (all modules) | Not run |

---

## 6. How to Run

```bash
# Prerequisites: Icarus Verilog >= 11.0
mkdir -p sim_out reports/simulation/phase3

# Run all Phase 3 testbenches
bash scripts/run_phase3_sim.sh

# Unit tests only
bash scripts/run_phase3_sim.sh --unit-only

# Integration tests only
bash scripts/run_phase3_sim.sh --sys-only

# Lint check
bash scripts/lint_phase3.sh
```

---

## 7. Known Limitations

- No instruction-set simulator (ISS) comparison. Register values are verified
  against hand-computed golden values only.
- Assembly programs in `programs/asm/` are reference documentation.
  Hex files must be generated with `riscv32-unknown-elf-objcopy`.
- No formal verification coverage in Phase 3.
- Privileged ISA, CSR, and trap handling are not implemented.
- Misaligned memory access behavior is undefined.
