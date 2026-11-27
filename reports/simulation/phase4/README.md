# Phase 4 Simulation Reports & Execution Status

This directory contains simulation logs, test execution records, and lint reports for Phase 4 (Memory Subsystem and Peripheral Integration).

## Test Execution Status Matrix

| Testbench | Level | Target Module | Scope | Container Execution Status | Local Toolchain Command |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `tb_instruction_memory.sv` | Unit | `instruction_memory.sv` | 64 KiB sync read, bounds, alignment | Not run (toolchain unavailable in container) | `make test_imem` |
| `tb_data_memory.sv` | Unit | `data_memory.sv` | 64 KiB byte enables (SB, SH, SW) | Not run (toolchain unavailable in container) | `make test_dmem` |
| `tb_bus_interconnect.sv` | Unit | `bus_interconnect.sv` | 1-master, 5-slave decoding, unmapped error | Not run (toolchain unavailable in container) | `make test_bus` |
| `tb_uart_controller.sv` | Unit | `uart_controller.sv` | 8-N-1 TX/RX FSM, baud divider, overrun, IRQ | Not run (toolchain unavailable in container) | `make test_uart` |
| `tb_spi_master.sv` | Unit | `spi_master.sv` | Modes 0-3, 8-bit full duplex, 4 CS lines, IRQ | Not run (toolchain unavailable in container) | `make test_spi` |
| `tb_timer.sv` | Unit | `timer.sv` | 32-bit counter, compare match, W1C status, IRQ | Not run (toolchain unavailable in container) | `make test_timer` |
| `tb_interrupt_controller.sv`| Unit | `interrupt_controller.sv`| 4 sticky channels, mask enable, W1C clear | Not run (toolchain unavailable in container) | `make test_intc` |
| `tb_soc_bus_integration.sv` | System | Bus Subsystem | MMIO roundtrip across all 5 slave spaces | Not run (toolchain unavailable in container) | `make test_soc_bus` |
| `tb_rv32i_soc_top.sv` | System | `rv32i_soc_top.sv` | CPU execution, DMEM, MMIO timer/intc, 2-flop sync | Not run (toolchain unavailable in container) | `make test_soc_top` |

## Local Simulation Execution Instructions

To execute all tests locally on a machine with Icarus Verilog and Verilator installed:

```bash
# Run all Phase 4 simulations:
bash scripts/run_phase4_sim.sh

# Run Verilator linting:
bash scripts/lint_phase4.sh

# Or via Makefile:
make test_phase4
make lint_phase4
```
