# Verification Testbenches

Phase 2 Testbenches for RV32I Processor.

## Directory Structure:
- `unit/`: Self-checking SystemVerilog testbenches for all CPU core modules:
  - `tb_alu.sv`
  - `tb_register_file.sv`
  - `tb_instruction_decoder.sv`
  - `tb_immediate_generator.sv`
  - `tb_control_unit.sv`
  - `tb_pipeline_registers.sv`
  - `tb_load_store_unit.sv`
- `system/`: System-level processor testbench:
  - `tb_cpu_core.sv` — Integrates CPU with simulation memory models to run assembly programs.
- `models/`: Behavioral simulation-only memory models:
  - `instruction_memory_model.sv` — 1-cycle synchronous read latency.
  - `data_memory_bus_model.sv` — Byte-addressable data bus slave with configurable wait states.
