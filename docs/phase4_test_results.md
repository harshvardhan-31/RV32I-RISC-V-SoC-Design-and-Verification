# Phase 4 Test Results & Execution Matrix

## 1. Executive Summary

This report documents the verification results and test coverage matrix for Phase 4 (Memory Subsystem and Peripheral Integration) of the RV32I RISC-V SoC.

In accordance with engineering rigor and project policy, tests are marked with genuine execution status. When executed in an environment without pre-installed EDA toolchains (Icarus Verilog / Verilator), tests are explicitly documented as **Not run (toolchain unavailable in container environment)**.

---

## 2. Phase 4 Test Suite Matrix

| Testbench | Level | Primary Target | Checks Performed | Container Status | Local Command |
| :--- | :---: | :--- | :--- | :---: | :--- |
| `tb_instruction_memory.sv` | Unit | `instruction_memory.sv` | 1-cycle latency, bounds check, alignment error, memory preload | Not run | `make test_imem` |
| `tb_data_memory.sv` | Unit | `data_memory.sv` | Byte/halfword/word R/W, `be_i[3:0]` masking, bounds check | Not run | `make test_dmem` |
| `tb_bus_interconnect.sv` | Unit | `bus_interconnect.sv` | 5-slave address decode, unmapped error, response muxing | Not run | `make test_bus` |
| `tb_uart_controller.sv` | Unit | `uart_controller.sv` | TX framing, baud divider, RX sampling, overrun, IRQ | Not run | `make test_uart` |
| `tb_spi_master.sv` | Unit | `spi_master.sv` | Modes 0-3, 8-bit full duplex, 4 CS lines, IRQ | Not run | `make test_spi` |
| `tb_timer.sv` | Unit | `timer.sv` | Counting, compare match, sticky status, W1C, IRQ | Not run | `make test_timer` |
| `tb_interrupt_controller.sv`| Unit | `interrupt_controller.sv`| 4-channel sticky pending, mask enable, W1C clear, IRQ | Not run | `make test_intc` |
| `tb_soc_bus_integration.sv` | System | Bus Subsystem | MMIO roundtrips across all 5 slaves, unmapped error | Not run | `make test_soc_bus` |
| `tb_rv32i_soc_top.sv` | System | `rv32i_soc_top.sv` | CPU instruction execution, DMEM store/load, Timer MMIO, 2-flop sync | Not run | `make test_soc_top` |

---

## 3. How to Run Locally

```bash
# Execute complete Phase 4 simulation test suite
bash scripts/run_phase4_sim.sh

# Execute Verilator linting
bash scripts/lint_phase4.sh

# Run via Makefile
make test_phase4
make lint_phase4
```
