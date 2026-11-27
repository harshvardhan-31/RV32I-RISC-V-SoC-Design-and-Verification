# Development Roadmap

Progress is measured only by completed acceptance criteria with evidence.

## Phase 1 — Project Foundation and Architecture
Status: Completed
- [x] Scope and assumptions documented (`docs/project_scope.md`)
- [x] 22-module inventory (`docs/module_specification.md`)
- [x] Memory map and bus protocol proposed (`docs/memory_map.md`, `docs/architecture.md`)
- [x] Verification plan (`docs/verification_plan.md`)
- [x] Repository structure and tool templates
- [x] Open TBD decisions reviewed and baseline documented (`docs/phase2_implementation_decisions.md`)

## Phase 2 — RV32I Pipelined Processor
Status: RTL Implemented and Verification Suite Prepared
- [x] RTL for all 12 CPU core modules in `rtl/core/`
  - `pc_unit.sv`
  - `if_id_reg.sv`
  - `instruction_decoder.sv`
  - `immediate_generator.sv`
  - `control_unit.sv`
  - `register_file.sv`
  - `id_ex_reg.sv`
  - `alu.sv`
  - `ex_mem_reg.sv`
  - `load_store_unit.sv`
  - `mem_wb_reg.sv`
  - `cpu_core.sv`
- [x] Unit testbenches implemented in `testbench/unit/`
  - `tb_alu.sv`
  - `tb_register_file.sv`
  - `tb_instruction_decoder.sv`
  - `tb_immediate_generator.sv`
  - `tb_control_unit.sv`
  - `tb_pipeline_registers.sv`
  - `tb_load_store_unit.sv`
- [x] Behavioral memory models in `testbench/models/`
  - `instruction_memory_model.sv`
  - `data_memory_bus_model.sv`
- [x] System-level CPU testbench in `testbench/system/tb_cpu_core.sv`
- [x] Assembly & machine code test programs in `programs/asm/` and `programs/hex/`
- [x] Simulation and lint scripts in `scripts/run_phase2_sim.sh`, `scripts/lint_phase2.sh`, `Makefile`

## Phase 3 — Hazard Detection and Forwarding
Status: RTL Implemented and Verification Suite Prepared
- [x] `hazard_unit.sv` RTL implemented (`rtl/core/hazard_unit.sv`)
- [x] `forwarding_unit.sv` RTL implemented (`rtl/core/forwarding_unit.sv`)
- [x] Top-level integration into `cpu_core.sv` with per-stage stall/flush and forwarding muxes
- [x] Unit testbenches implemented in `testbench/unit/`:
  - `tb_hazard_unit.sv` (12 test cases HAZARD-01..12)
  - `tb_forwarding_unit.sv` (12 test cases FORWARD-01..12)
- [x] System integration testbenches implemented in `testbench/system/`:
  - `tb_hazard_integration.sv` (RAW ALU chain, load-use stall bubble, store data fwd)
  - `tb_cpu_forwarding.sv` (back-to-back ALU, 2-stage back, branch & JALR fwd, store fwd)
- [x] Assembly test programs without NOP padding in `programs/asm/`:
  - `raw_alu_dependencies.S`
  - `load_use_dependencies.S`
  - `branch_dependencies.S`
  - `jump_dependencies.S`
  - `store_data_dependencies.S`
- [x] Phase 3 simulation and lint scripts:
  - `scripts/run_phase3_sim.sh`
  - `scripts/lint_phase3.sh`
- [x] Phase 3 documentation:
  - `docs/phase3_implementation_decisions.md`
  - `docs/phase3_hazard_architecture.md`
  - `docs/phase3_forwarding_architecture.md`
  - `docs/phase3_pipeline_control.md`
  - `docs/phase3_test_plan.md`
  - `docs/phase3_test_results.md`
- [ ] Tool execution logs committed to `reports/simulation/phase3/` (Pending simulator run)

## Phase 4 — Memory Subsystem and Peripheral Integration
Status: Not started

Acceptance criteria:
- [ ] Memories, bus, decoder RTL
- [ ] UART, SPI, timer, interrupt controller RTL
- [ ] Peripheral directed tests

## Phase 5 — Verification and Validation
Status: Not started

Acceptance criteria:
- [ ] Full RV32I directed suite
- [ ] Random regression vs reference ISS
- [ ] Coverage report
- [ ] Assertions

## Phase 6 — Synthesis and Physical Design
Status: Not started

Acceptance criteria:
- [ ] PDK chosen; SDC finalized
- [ ] Yosys netlist and reports
- [ ] OpenROAD flow to routed design
- [ ] STA, DRC, LVS logs; GDSII

## Phase 7 — Optimization and Final Documentation
Status: Not started

Acceptance criteria:
- [ ] Timing/area improvements backed by before/after reports
- [ ] Final report and diagrams
- [ ] Release tag
