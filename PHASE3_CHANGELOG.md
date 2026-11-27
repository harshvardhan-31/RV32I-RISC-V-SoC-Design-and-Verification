# Phase 3 Changelog — Hazard Detection and Forwarding

All notable changes and deliverables implemented for Phase 3 of the RV32I RISC-V SoC design, including the engineering audit updates.

---

## 1. Summary of Changes
Phase 3 transitions the five-stage RV32I CPU core from a baseline design requiring software-inserted NOPs to an autonomous pipelined processor with dynamic hazard detection and hardware data forwarding.

---

## 2. Synthesizable RTL Modules (`rtl/core/`)

- `rtl/core/hazard_unit.sv`:
  - Implements load-use RAW hazard detection logic.
  - Implements control-hazard flush generation for taken branches and jumps.
  - Implements bus wait-state freeze when `lsu_busy` is high.
  - Evaluates register usage flags to eliminate false dependencies.
  - Prioritizes LSU stalls to ensure no pending branch redirects are dropped.
- `rtl/core/forwarding_unit.sv`:
  - Implements EX/MEM (Priority 1) and MEM/WB (Priority 2) operand forwarding.
  - Enforces `x0` protection (no forwarding for destination `x0`).
  - Blocks EX/MEM load forwarding (`mem_read = 1`) to allow load-use stall resolution.
  - Evaluates validity (`ex_mem_valid`, `mem_wb_valid`) and `reg_write` enables before forwarding.
- `rtl/core/cpu_core.sv`:
  - Integrated `hazard_unit` and `forwarding_unit`.
  - Wired `id_funct12` between decoder and control unit.
  - Added 3-way forwarding multiplexers for `rs1` and `rs2`.
  - Wired forwarded `rs2` (`fwd_rs2_val`) to `ex_mem_reg` for store data forwarding.
  - Wired forwarded `rs1` (`fwd_rs1_val`) to `jalr_target` calculation.
  - Replaced single `stall_pipeline` with fine-grained per-stage stall/flush control logic.

---

## 3. Testbenches & Verification Suite (`testbench/`)

- `testbench/unit/tb_hazard_unit.sv`: Unit testbench covering 12 hazard cases (`HAZARD-01..12`) with `$fatal`.
- `testbench/unit/tb_forwarding_unit.sv`: Extended unit testbench covering 20 forwarding cases (`FORWARD-01..20`) including invalid entries, x0 immunity, reg-write qualification, and back-to-back producer priority.
- `testbench/system/tb_hazard_integration.sv`:
  - System testbench for RAW ALU chains, store data forwarding, and triple-dependency chains.
  - Cycle-level counter assertion verifying **exactly 1 stall cycle and 1 bubble insertion** for an isolated load-use dependency (`SEQ-B`).
  - Multi-cycle memory wait states test (`SEQ-E`, `WAIT_CYCLES = 2`).
  - Branch redirect occurring while older memory transaction is outstanding (`SEQ-F`), verifying no redirect or instruction is lost.
- `testbench/system/tb_cpu_forwarding.sv`:
  - System testbench for ALU forwarding, branch operand forwarding, and store data forwarding.
  - **Genuine immediate JALR dependency:** `ADDI x1, x0, 24` immediately followed by `JALR x4, x1, 0` (`FWD-SEQ-D`), verifying that forwarding supplies `x1` to the JALR target calculation.
  - Pipeline register x0 protection (`FWD-SEQ-G`).
  - Datapath back-to-back producer priority (`FWD-SEQ-H`).

---

## 4. Assembly Programs (`programs/asm/`)
- `programs/asm/raw_alu_dependencies.S`
- `programs/asm/load_use_dependencies.S`
- `programs/asm/branch_dependencies.S`
- `programs/asm/jump_dependencies.S` (updated with back-to-back `ADDI` -> `JALR`)
- `programs/asm/store_data_dependencies.S`

---

## 5. Documentation & Engineering Records (`docs/`, `reports/`)
- `docs/phase3_implementation_decisions.md`
- `docs/phase3_hazard_architecture.md`
- `docs/phase3_forwarding_architecture.md`
- `docs/phase3_pipeline_control.md`
- `docs/phase3_test_plan.md` (updated test matrices)
- `docs/phase3_test_results.md` (audit status, genuine results)
- `reports/simulation/phase2/execution_status.log`
- `reports/simulation/phase3/execution_status.log`
- `PHASE3_README.md`
- `PHASE3_CHANGELOG.md`
- `README.md`
