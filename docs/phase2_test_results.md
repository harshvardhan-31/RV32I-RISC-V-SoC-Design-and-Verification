# Phase 2 Verification and Test Results

> Status: Testbenches implemented; execution pending simulator installation in local environment.
> Policy: Under the project's engineering rules, no test is marked "Passed" without an actual committed tool log.

---

## 1. Test Status Matrix

| Testbench | Level | Scope | Status | Notes |
|---|---|---|---|---|
| `tb_alu` | Unit | Arithmetic, logical, shift, comparisons, branch conditions | Not run | Self-checking testbench implemented in `testbench/unit/tb_alu.sv` |
| `tb_register_file` | Unit | 32 registers, dual-port read, x0 hardwired 0, reset, write-enable | Not run | Self-checking testbench implemented in `testbench/unit/tb_register_file.sv` |
| `tb_instruction_decoder` | Unit | R, I, S, B, U, J field extraction, legal/illegal opcodes & funct | Not run | Self-checking testbench implemented in `testbench/unit/tb_instruction_decoder.sv` |
| `tb_immediate_generator` | Unit | I, S, B, U, J immediate sign/zero extension, boundary bit placement | Not run | Self-checking testbench implemented in `testbench/unit/tb_immediate_generator.sv` |
| `tb_control_unit` | Unit | Control matrix for all RV32I classes, illegal instruction isolation | Not run | Self-checking testbench implemented in `testbench/unit/tb_control_unit.sv` |
| `tb_pipeline_registers` | Unit | Reset, normal advance, stall hold, flush bubble for all 4 stages | Not run | Self-checking testbench implemented in `testbench/unit/tb_pipeline_registers.sv` |
| `tb_load_store_unit` | Unit | LB/LH/LW/LBU/LHU, SB/SH/SW, byte enables, bus handshake, errors | Not run | Self-checking testbench implemented in `testbench/unit/tb_load_store_unit.sv` |
| `tb_cpu_core` | System | 5-stage CPU integration, smoke program, register checks, DMEM SW/LW, branch flush | Not run | Self-checking testbench implemented in `testbench/system/tb_cpu_core.sv` |

---

## 2. Verification Execution Instructions

To execute the test suite using Icarus Verilog:

### Linux / macOS
```bash
# Make scripts executable
chmod +x scripts/run_phase2_sim.sh scripts/lint_phase2.sh

# Run all Phase 2 simulations
./scripts/run_phase2_sim.sh all

# Or run a single unit test:
./scripts/run_phase2_sim.sh tb_alu
./scripts/run_phase2_sim.sh tb_cpu_core

# Run via Makefile
make test
```

### Windows (PowerShell)
```powershell
.\scripts\run_phase2_sim.ps1 -TargetTest all
```

Simulation logs will be output directly to `reports/simulation/phase2/<testbench_name>.log`.
