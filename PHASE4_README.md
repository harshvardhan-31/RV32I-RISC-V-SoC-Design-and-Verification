# RV32I RISC-V SoC — Phase 4: Memory Subsystem and Peripheral Integration

## 1. Overview

Phase 4 transitions the RV32I processor from a standalone CPU core with hazard and forwarding units into a complete, integrated **System-on-Chip (SoC)**.

The resulting SoC architecture (`rv32i_soc_top.sv`) integrates:
1. **CPU Core**: Five-stage in-order RV32I pipeline with full RAW forwarding, load-use stall insertion, and branch/jump hazard resolution.
2. **Instruction Memory**: 64 KiB dedicated synchronous fetch memory (`0x0000_0000 - 0x0000_FFFF`).
3. **Data Memory**: 64 KiB byte-addressable synchronous RAM with byte enables `be_i[3:0]` (`0x1000_0000 - 0x1000_FFFF`).
4. **Bus Interconnect**: Custom single-master, 5-slave crossbar interconnect with complete address decoding, response multiplexing, and unmapped address trap generation.
5. **UART Controller**: 8-N-1 full-duplex UART with baud rate prescaler, TX/RX FSMs, overrun/frame error detection, and interrupt generation (`0x2000_0000 - 0x2000_0FFF`).
6. **SPI Master**: Motorola SPI Modes 0, 1, 2, 3 controller with 4 active-low chip select lines, clock divider, full-duplex transfer, and interrupt generation (`0x2000_1000 - 0x2000_1FFF`).
7. **Hardware Timer**: 32-bit counter with configurable compare threshold, sticky match status, W1C semantics, and interrupt generation (`0x2000_2000 - 0x2000_2FFF`).
8. **Interrupt Controller**: 4-channel sticky interrupt controller with individual mask enable, W1C clear, set-over-clear priority, and aggregated `irq_o` output (`0x2000_3000 - 0x2000_3FFF`).
9. **Metastability Protection**: Two-stage flip-flop synchronizers on external asynchronous inputs (`uart_rx_i`, `spi_miso_i`, `ext_irq_i`).

---

## 2. Directory Structure

```text
├── rtl/
│   ├── core/                  # Phase 2 & 3 CPU pipeline (cpu_core, alu, hazard_unit, etc.)
│   ├── memory/
│   │   ├── instruction_memory.sv   # 64 KiB Instruction RAM
│   │   └── data_memory.sv          # 64 KiB Data RAM with byte enables
│   ├── bus/
│   │   └── bus_interconnect.sv     # 1-Master, 5-Slave Address Interconnect
│   ├── peripherals/
│   │   ├── uart_controller.sv      # 8-N-1 UART Controller
│   │   ├── spi_master.sv           # SPI Modes 0-3 Master (4 CS lines)
│   │   ├── timer.sv                # 32-bit Hardware Timer
│   │   └── interrupt_controller.sv # 4-Source Interrupt Controller
│   └── top/
│       └── rv32i_soc_top.sv        # Top-level SoC Integration with 2-flop synchronizers
├── testbench/
│   ├── unit/                  # Self-checking unit testbenches for all memory/peripherals
│   └── system/
│       ├── tb_soc_bus_integration.sv # Interconnect and MMIO bus testbench
│       └── tb_rv32i_soc_top.sv       # Full SoC top CPU + Memory + MMIO testbench
├── programs/
│   ├── asm/                   # Assembly firmware tests for memory, uart, spi, timer, smoke
│   ├── hex/                   # Preloaded hex generation documentation
│   └── linker/link.ld         # Ratified Phase 4 linker script (64K IMEM, 64K DMEM)
├── scripts/
│   ├── run_phase4_sim.sh      # Simulation execution script
│   ├── lint_phase4.sh         # Verilator linting script
│   └── build_firmware.sh      # Firmware compilation and hex generation script
├── docs/                      # Phase 4 specifications and verification plan
├── Makefile                   # Updated build and simulation targets
└── reports/simulation/phase4/ # Simulation logs and status matrix
```

---

## 3. Quick Start

### Run Unit and System Simulations
```bash
make test_phase4
```

### Run Verilator Lint
```bash
make lint_phase4
```

### Build Firmware
```bash
make firmware
```
