# Phase 4 Changelog

All notable changes and additions introduced in Phase 4 (Memory Subsystem and Peripheral Integration).

## [Phase 4] - 2026-11-28

### Added

#### RTL Design Modules
- `rtl/memory/instruction_memory.sv`: 64 KiB synchronous instruction memory model with 1-cycle latency, bounds checking, alignment verification, and `$readmemh` initialization.
- `rtl/memory/data_memory.sv`: 64 KiB synchronous data memory model supporting byte, halfword, and word accesses via 4-bit byte enables (`be_i[3:0]`).
- `rtl/bus/bus_interconnect.sv`: Single-master, 5-slave crossbar interconnect with complete address decode, one-hot slave selection, response muxing, and unmapped space error generation.
- `rtl/peripherals/uart_controller.sv`: 8-N-1 full-duplex UART controller with programmable baud divider, TX/RX FSMs, overrun/framing error detection, read-to-consume buffer, and interrupt generation.
- `rtl/peripherals/spi_master.sv`: 8-bit full-duplex SPI Master controller supporting Motorola Modes 0..3 (CPOL/CPHA), 4 active-low chip select lines, clock divider, and interrupt output.
- `rtl/peripherals/timer.sv`: 32-bit hardware timer with configurable compare threshold, sticky match status flag, W1C clear, set-over-clear priority, and interrupt output.
- `rtl/peripherals/interrupt_controller.sv`: Memory-mapped simple interrupt controller aggregating 4 sources (UART, SPI, Timer, External) with sticky pending latching, enable masks, and W1C clear.
- `rtl/top/rv32i_soc_top.sv`: Top-level System-on-Chip module integrating CPU core, instruction memory, data memory, bus interconnect, 4 MMIO peripherals, and 2-stage flip-flop synchronizers for asynchronous inputs (`uart_rx_i`, `spi_miso_i`, `ext_irq_i`).

#### Testbenches
- `testbench/unit/tb_instruction_memory.sv`: Self-checking unit test for instruction memory (latency, alignment, bounds, reset).
- `testbench/unit/tb_data_memory.sv`: Self-checking unit test for data memory (byte enables, partial writes, non-corruption, bounds).
- `testbench/unit/tb_bus_interconnect.sv`: Self-checking unit test for bus interconnect (all 5 slaves, unmapped errors, muxing).
- `testbench/unit/tb_uart_controller.sv`: Self-checking unit test for UART (baud generation, TX framing, RX sampling, overrun, IRQ).
- `testbench/unit/tb_spi_master.sv`: Self-checking unit test for SPI Master (Modes 0-3, 8-bit full duplex, CS assertion, IRQ).
- `testbench/unit/tb_timer.sv`: Self-checking unit test for timer (counting, compare match, W1C, IRQ).
- `testbench/unit/tb_interrupt_controller.sv`: Self-checking unit test for interrupt controller (latching, masking, W1C, priority).
- `testbench/system/tb_soc_bus_integration.sv`: System testbench verifying bus transactions to all 5 slave spaces and unmapped address trap response.
- `testbench/system/tb_rv32i_soc_top.sv`: Full top-level SoC testbench executing instructions, accessing DMEM, configuring Timer MMIO, verifying IRQ assertion, and testing 2-stage synchronizers.

#### Firmware & Tooling
- `programs/asm/phase4_memory_test.S`: Assembly test verifying SB/SH/SW and LB/LBU/LH/LHU/LW.
- `programs/asm/phase4_uart_test.S`: Assembly test transmitting "RV32I\n" via UART MMIO.
- `programs/asm/phase4_spi_test.S`: Assembly test performing SPI full-duplex transfer.
- `programs/asm/phase4_timer_test.S`: Assembly test setting compare threshold and polling match flag.
- `programs/asm/phase4_soc_smoke_test.S`: End-to-end SoC smoke test program.
- `programs/hex/README.md`: Firmware hex formatting and conversion guide.
- `programs/linker/link.ld`: Ratified Phase 4 linker script defining 64K IMEM, 64K DMEM, peripheral base symbols, and stack top.
- `scripts/run_phase4_sim.sh`: Simulation execution script with toolchain detection and logging.
- `scripts/lint_phase4.sh`: Verilator linting script for all Phase 4 modules and top-level SoC.
- `scripts/build_firmware.sh`: Automated firmware assembly, linking, and hex generation script.

#### Documentation
- `docs/phase4_implementation_decisions.md`
- `docs/phase4_memory_subsystem.md`
- `docs/phase4_bus_architecture.md`
- `docs/phase4_uart_specification.md`
- `docs/phase4_spi_specification.md`
- `docs/phase4_timer_specification.md`
- `docs/phase4_interrupt_architecture.md`
- `docs/phase4_verification_plan.md`
- `docs/phase4_test_results.md`
- `PHASE4_README.md`
- `PHASE4_CHANGELOG.md`
