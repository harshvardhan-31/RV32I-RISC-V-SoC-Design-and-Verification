# Phase 4 Implementation Decisions — Memory Subsystem and Peripheral Integration

## 1. Architectural Baseline & Scope

In Phase 4, the five-stage RV32I processor core developed in Phase 2 and enhanced with hazard detection and data forwarding in Phase 3 is integrated into a complete System-on-Chip (SoC).

### Key Architectural Decisions:
1. **CPU Integration**:
   - The five-stage pipeline (`cpu_core.sv`), forwarding unit (`forwarding_unit.sv`), and hazard unit (`hazard_unit.sv`) are retained without architectural alterations.
   - The CPU's instruction fetch interface connects directly to a dedicated 64 KiB Instruction RAM (`instruction_memory.sv`).
   - The CPU's data master interface (from `load_store_unit.sv`) drives the single-master custom bus interconnect (`bus_interconnect.sv`).
2. **Harvard Architecture Memory Organization**:
   - Instruction memory and data memory maintain separate physical address spaces and ports.
   - Instruction RAM is located at `0x0000_0000 - 0x0000_FFFF` (64 KiB).
   - Data RAM is located at `0x1000_0000 - 0x1000_FFFF` (64 KiB) as Slave 0 on the system bus.
   - This eliminates structural fetch/load contention while preserving full single-cycle access bandwidth.
3. **Custom Single-Master Bus Protocol**:
   - No AXI, AHB, or APB overhead is introduced; a clean, single-master handshake protocol is used:
     - Master outputs: `valid`, `we`, `addr[31:0]`, `wdata[31:0]`, `be[3:0]`.
     - Slave outputs: `ready`, `rdata[31:0]`, `error`.
   - Transactions are completed in 1 cycle when `ready` asserts.
   - Unmapped address space returns an immediate error cycle (`ready = 1`, `error = 1`, `rdata = 0`).
4. **Peripheral Memory-Mapped I/O (MMIO)**:
   - Four dedicated peripheral apertures are defined in the `0x2000_0000` region:
     - `0x2000_0000 - 0x2000_0FFF`: UART Controller
     - `0x2000_1000 - 0x2000_1FFF`: SPI Master
     - `0x2000_2000 - 0x2000_2FFF`: 32-bit Timer
     - `0x2000_3000 - 0x2000_3FFF`: Interrupt Controller
5. **Interrupt Architecture**:
   - No CPU CSRs or trap vectors are implemented in Phase 4 (deferred to privileged extension in Phase 5).
   - A dedicated memory-mapped Interrupt Controller aggregates peripheral events (UART, SPI, Timer, External).
   - The aggregated interrupt line `irq_o` is brought out to the top-level SoC boundary for external observation and testbench verification.
6. **Clock Domain Crossing & Asynchronous Inputs**:
   - External asynchronous input pins (`uart_rx_i`, `spi_miso_i`, `ext_irq_i`) are passed through 2-stage D-flip-flop synchronizers at `rv32i_soc_top` to prevent metastability.
