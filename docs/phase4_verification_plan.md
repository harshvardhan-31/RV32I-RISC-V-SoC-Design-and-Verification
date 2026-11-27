# Phase 4 Verification Plan — Memory Subsystem and Peripheral Integration

## 1. Scope & Verification Strategy

The Phase 4 verification plan ensures comprehensive functional coverage of the RV32I memory subsystem, custom bus interconnect, MMIO peripheral controllers, and top-level SoC integration.

### Test Categories
1. **Subsystem Unit Testbenches (`testbench/unit/`)**:
   - `tb_instruction_memory.sv`: 64 KiB memory model, 1-cycle sync read latency, out-of-bounds rejection, word alignment validation, reset behavior.
   - `tb_data_memory.sv`: Byte enables `be_i[3:0]`, partial byte/halfword writes, full word writes, non-corruption of adjacent bytes, alignment checks, out-of-bounds checks.
   - `tb_bus_interconnect.sv`: Decoding across all 5 slave spaces, mutual exclusion of slave selects, unmapped address error and ready generation, response routing.
   - `tb_uart_controller.sv`: Baud rate clock generation, TX serialization (start, 8 data, stop), RX oversampling and center-sampling, RX overrun, framing error, read-to-consume buffer semantics, interrupt generation.
   - `tb_spi_master.sv`: Motorola SPI Modes 0, 1, 2, 3 clock polarity and phase, 8-bit full-duplex shifting, 4 chip select lines, clock divider prescaler, status flags, and IRQ generation.
   - `tb_timer.sv`: Free-running/gated counting, 32-bit compare match detection, sticky status flag, W1C semantics, set-over-clear priority, IRQ generation.
   - `tb_interrupt_controller.sv`: Multi-source event latching, sticky pending flags, individual enable masking, aggregated `irq_o`, W1C clear semantics, set-over-clear priority.

2. **System Integration Testbenches (`testbench/system/`)**:
   - `tb_soc_bus_integration.sv`: CPU bus master emulation accessing Data Memory and all 4 peripherals through `bus_interconnect`, verifying end-to-end MMIO register read/write paths and unmapped address trap response.
   - `tb_rv32i_soc_top.sv`: Full SoC top integration running genuine RV32I instructions from Instruction Memory, executing load/store operations to Data Memory, configuring MMIO peripherals, asserting timer compare-match interrupts, and verifying 2-stage synchronizers on external inputs (`uart_rx_i`, `spi_miso_i`, `ext_irq_i`).

---

## 2. Assertion & Checking Methodology

Every testbench is self-checking and includes:
- Automated signal checking tasks (`check_result`, `check`).
- Cycle-accurate assertions on interface handshakes (`valid`, `ready`, `error`).
- Cumulative `test_count` and `error_count` tracking.
- `$fatal(1, ...)` invocation on any assertion failure to ensure CI/regression failure detection.
