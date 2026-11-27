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
Status: Completed & Audited
- [x] RTL for all 12 CPU core modules in `rtl/core/` (`pc_unit.sv`, `if_id_reg.sv`, `instruction_decoder.sv`, `immediate_generator.sv`, `control_unit.sv`, `register_file.sv`, `id_ex_reg.sv`, `alu.sv`, `ex_mem_reg.sv`, `load_store_unit.sv`, `mem_wb_reg.sv`, `cpu_core.sv`)
- [x] Unit testbenches implemented in `testbench/unit/`
- [x] Behavioral memory models in `testbench/models/`
- [x] System-level CPU testbench in `testbench/system/tb_cpu_core.sv`
- [x] Assembly & machine code test programs in `programs/asm/` and `programs/hex/`
- [x] Simulation and lint scripts in `scripts/run_phase2_sim.sh`, `scripts/lint_phase2.sh`, `Makefile`

## Phase 3 — Hazard Detection and Forwarding
Status: Completed & Audited
- [x] `hazard_unit.sv` RTL implemented (`rtl/core/hazard_unit.sv`)
- [x] `forwarding_unit.sv` RTL implemented (`rtl/core/forwarding_unit.sv`)
- [x] Top-level integration into `cpu_core.sv` with per-stage stall/flush and forwarding muxes
- [x] Audited ECALL/EBREAK discrimination, JALR immediate dependencies, multi-cycle wait states, and branch redirect during memory stalls
- [x] Unit testbenches implemented in `testbench/unit/`: `tb_hazard_unit.sv`, `tb_forwarding_unit.sv`
- [x] System integration testbenches implemented in `testbench/system/`: `tb_hazard_integration.sv`, `tb_cpu_forwarding.sv`
- [x] Assembly test programs without NOP padding in `programs/asm/`

## Phase 4 — Memory Subsystem and Peripheral Integration
Status: Completed
- [x] Synthesizable 64 KiB Instruction RAM (`rtl/memory/instruction_memory.sv`)
- [x] Synthesizable 64 KiB Data RAM with byte enables (`rtl/memory/data_memory.sv`)
- [x] 1-Master, 5-Slave custom bus interconnect with unmapped address error trap (`rtl/bus/bus_interconnect.sv`)
- [x] 8-N-1 UART Controller with baud divider, TX/RX FSMs, and interrupt (`rtl/peripherals/uart_controller.sv`)
- [x] Motorola SPI Master (Modes 0-3, 4 CS lines, IRQ) (`rtl/peripherals/spi_master.sv`)
- [x] 32-bit Hardware Timer with compare match and W1C IRQ (`rtl/peripherals/timer.sv`)
- [x] 4-Source Interrupt Controller with sticky pending and W1C clear (`rtl/peripherals/interrupt_controller.sv`)
- [x] Full SoC top-level integration with 2-flop synchronizers (`rtl/top/rv32i_soc_top.sv`)
- [x] 7 Unit testbenches in `testbench/unit/`: `tb_instruction_memory.sv`, `tb_data_memory.sv`, `tb_bus_interconnect.sv`, `tb_uart_controller.sv`, `tb_spi_master.sv`, `tb_timer.sv`, `tb_interrupt_controller.sv`
- [x] 2 System testbenches in `testbench/system/`: `tb_soc_bus_integration.sv`, `tb_rv32i_soc_top.sv`
- [x] Assembly firmware test programs in `programs/asm/`: `phase4_memory_test.S`, `phase4_uart_test.S`, `phase4_spi_test.S`, `phase4_timer_test.S`, `phase4_soc_smoke_test.S`
- [x] Ratified linker script (`programs/linker/link.ld`) and firmware build script (`scripts/build_firmware.sh`)
- [x] Simulation and lint scripts in `scripts/run_phase4_sim.sh`, `scripts/lint_phase4.sh`, and updated `Makefile`

## Phase 5 — Verification & Validation
Status: Planned
- [ ] Compliance testing with official RISC-V architectural tests (riscv-arch-test)
- [ ] Random instruction regression testing against Spike / Sail reference models
- [ ] Code coverage collection (line, toggle, branch, FSM condition coverage)

## Phase 6 — Synthesis & Physical Design
Status: Planned
- [ ] Logic synthesis using Yosys and target standard cell library
- [ ] Static Timing Analysis (STA) with OpenSTA
- [ ] Place & Route with OpenROAD targeting SkyWater 130nm PDK

## Phase 7 — Optimization & Final Sign-off
Status: Planned
- [ ] Frequency, area, and power sign-off
- [ ] Final documentation and repository tagging
