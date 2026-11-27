# Verification Plan — RV32I RISC-V SoC (Phases 1 through 4)

## 1. Overview & Verification Strategy

The verification strategy progresses through stratified layers:
1. **Unit Verification**: Individual RTL modules verified in isolation with cycle-accurate, self-checking testbenches.
2. **Subsystem Integration**: Verification of interacting modules (e.g. Pipeline with Hazard/Forwarding units, Interconnect with Memory and Peripherals).
3. **SoC System Integration**: Full top-level processor verification executing firmware instructions, exercising memory and MMIO peripherals.

---

## 2. Testbench Matrix by Phase

### Phase 2 & Phase 3 Core Testbenches
| Testbench | Level | Targets | Checks |
|---|---|---|---|
| `tb_alu.sv` | Unit | `alu.sv` | All 11 ALU ops, branch conditions, signed/unsigned edges |
| `tb_register_file.sv` | Unit | `register_file.sv` | Dual read, synchronous write, x0=0 invariance |
| `tb_instruction_decoder.sv` | Unit | `instruction_decoder.sv` | Opcode slicing, ECALL/EBREAK discrimination, illegal instructions |
| `tb_immediate_generator.sv` | Unit | `immediate_generator.sv` | Sign extension of I, S, B, U, J format immediates |
| `tb_control_unit.sv` | Unit | `control_unit.sv` | Control signal matrix, branch/jump/memory decoding |
| `tb_pipeline_registers.sv` | Unit | Pipeline registers | Synchronous latching, stall, and bubble/flush operations |
| `tb_load_store_unit.sv` | Unit | `load_store_unit.sv` | Alignment, byte enables, LB/LH/LW sign/zero extension |
| `tb_hazard_unit.sv` | Unit | `hazard_unit.sv` | 12 hazard cases (load-use stall, control flush, LSU busy priority) |
| `tb_forwarding_unit.sv` | Unit | `forwarding_unit.sv` | 20 forwarding cases (EX/MEM, MEM/WB, x0 protection, store fwd) |
| `tb_hazard_integration.sv` | System | CPU Pipeline | Dynamic bubble insertion, wait-state hold, branch redirect during stall |
| `tb_cpu_forwarding.sv` | System | CPU Pipeline | Back-to-back dependency execution, JALR base forwarding |

### Phase 4 Memory & Peripheral Testbenches
| Testbench | Level | Targets | Checks |
|---|---|---|---|
| `tb_instruction_memory.sv` | Unit | `instruction_memory.sv` | 1-cycle latency, bounds check, misaligned address rejection, preload |
| `tb_data_memory.sv` | Unit | `data_memory.sv` | Byte enables `be_i[3:0]`, partial writes, non-corruption, bounds |
| `tb_bus_interconnect.sv` | Unit | `bus_interconnect.sv` | 5-slave address decode, unmapped error generation, response muxing |
| `tb_uart_controller.sv` | Unit | `uart_controller.sv` | Baud divider, TX framing, RX sampling, overrun, read-to-consume, IRQ |
| `tb_spi_master.sv` | Unit | `spi_master.sv` | Modes 0-3, 8-bit full duplex, 4 CS lines, clock divider, IRQ |
| `tb_timer.sv` | Unit | `timer.sv` | Free-running count, compare match, sticky status, W1C clear, IRQ |
| `tb_interrupt_controller.sv`| Unit | `interrupt_controller.sv`| 4 sticky pending channels, enable masking, W1C clear, priority |
| `tb_soc_bus_integration.sv` | System | Bus Subsystem | MMIO roundtrips across all 5 slave spaces, unmapped error response |
| `tb_rv32i_soc_top.sv` | System | `rv32i_soc_top.sv` | CPU execution, DMEM store/load, Timer MMIO, 2-flop synchronizers, IRQ |
