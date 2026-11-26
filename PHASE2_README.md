# Phase 2 — RV32I Five-Stage Pipelined Processor Core

This package contains the complete, synthesizable SystemVerilog hardware RTL implementation, self-checking verification testbenches, simulation memory models, assembly test programs, simulation scripts, and architectural engineering documentation for **Phase 2** of the RV32I RISC-V SoC project.

---

## 1. Package Directory Structure

```
RV32I_Phase2_RTL_Package/
├── rtl/
│   └── core/
│       ├── pc_unit.sv              # Program Counter generator & redirect multiplexer
│       ├── if_id_reg.sv            # IF/ID pipeline register with stall/flush
│       ├── instruction_decoder.sv  # RV32I field extractor & illegal instruction validator
│       ├── immediate_generator.sv  # Sign/zero extension for I, S, B, U, J formats
│       ├── control_unit.sv         # Main opcode & ALU control decoder
│       ├── register_file.sv        # 32x32 integer register file (x0 hardwired 0)
│       ├── id_ex_reg.sv            # ID/EX pipeline register
│       ├── alu.sv                  # 32-bit ALU & branch condition comparator
│       ├── ex_mem_reg.sv           # EX/MEM pipeline register
│       ├── load_store_unit.sv      # Load-Store Unit bus master (LB..LW, SB..SW)
│       ├── mem_wb_reg.sv           # MEM/WB pipeline register
│       └── cpu_core.sv             # Top-level 5-stage CPU core integration
├── testbench/
│   ├── unit/
│   │   ├── tb_alu.sv               # Self-checking ALU unit testbench
│   │   ├── tb_register_file.sv     # Self-checking register file testbench
│   │   ├── tb_instruction_decoder.sv # Self-checking decoder testbench
│   │   ├── tb_immediate_generator.sv # Self-checking immediate generator testbench
│   │   ├── tb_control_unit.sv      # Self-checking control unit testbench
│   │   ├── tb_pipeline_registers.sv # Self-checking pipeline registers testbench
│   │   └── tb_load_store_unit.sv   # Self-checking LSU testbench
│   ├── system/
│   │   └── tb_cpu_core.sv          # System-level CPU core integration testbench
│   └── models/
│       ├── instruction_memory_model.sv # 1-cycle synchronous read latency IMEM model
│       └── data_memory_bus_model.sv    # Byte-addressable bus slave model with wait states
├── programs/
│   ├── asm/
│   │   ├── phase2_smoke.s          # Comprehensive smoke test assembly program
│   │   └── phase2_branch.s         # Branch redirect & flush test assembly program
│   └── hex/
│       ├── phase2_smoke.hex        # Validated RV32I machine-code hex
│       └── phase2_branch.hex       # Validated RV32I machine-code hex
├── scripts/
│   ├── run_phase2_sim.sh           # Linux/macOS simulation suite runner (iverilog -g2012)
│   ├── lint_phase2.sh              # Verilator linting script
│   └── run_phase2_sim.ps1          # Windows PowerShell simulation runner
├── docs/
│   ├── phase2_implementation_decisions.md # Baseline assumptions and design decisions
│   ├── phase2_rtl_architecture.md         # Detailed datapath and interface specification
│   └── phase2_test_results.md             # Verification status and execution instructions
├── reports/
│   └── simulation/
│       └── phase2/
│           ├── README.md           # Instructions for generating and committing real logs
│           └── REPORT_TEMPLATE.md  # Standard simulation report template
├── Makefile                        # Build and test orchestration
├── PHASE2_README.md                # This package overview
└── PHASE2_CHANGELOG.md             # Complete record of added files and phase boundaries
```

---

## 2. Key Architecture Features

- **Standard RV32I Base Integer ISA:** Implements all 37 base integer instructions plus FENCE, ECALL, and EBREAK decoding.
- **Classic 5-Stage In-Order Pipeline:** IF, ID, EX, MEM, WB.
- **Branch Resolution in EX:** Static not-taken fetch policy; branches and jumps resolve in EX, triggering synchronous flush of `IF/ID` and `ID/EX` (2-cycle penalty).
- **Harvard-Style Bus Interfaces:** Separate instruction fetch interface and custom single-outstanding data memory bus interface.
- **Hardware Register File:** Dual combinational read ports, single synchronous write port; `x0` permanently hardwired to `32'h0000_0000`.

---

## 3. How to Run Simulations

### Using Icarus Verilog on Linux or macOS:
```bash
chmod +x scripts/run_phase2_sim.sh scripts/lint_phase2.sh
./scripts/run_phase2_sim.sh all
```
or via Makefile:
```bash
make test
```

### Using Windows PowerShell:
```powershell
.\scripts\run_phase2_sim.ps1 -TargetTest all
```

---

## 4. Phase Boundaries

- **Phase 2 (This Release):** CPU Core pipeline RTL, simulation memory models, unit and system testbenches, test programs with NOP padding.
- **Phase 3 (Next Phase):** Hardware hazard detection unit (`hazard_unit.sv`) and hardware data forwarding unit (`forwarding_unit.sv`).
- **Phase 4:** Permanent SoC interconnect, SRAM controllers, and memory-mapped peripherals (UART, SPI, Timer, Interrupt Controller).
