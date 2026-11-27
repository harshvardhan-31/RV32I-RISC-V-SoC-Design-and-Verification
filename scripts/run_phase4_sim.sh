#!/usr/bin/env bash
# =============================================================================
# File: scripts/run_phase4_sim.sh
# Project: RV32I RISC-V SoC (Phase 4 — Memory Subsystem and Peripheral Integration)
# Description: Compile and simulate all Phase 4 unit and system testbenches
#              using Icarus Verilog (iverilog / vvp).
#
#   Usage: bash scripts/run_phase4_sim.sh [--unit-only] [--sys-only] [--help]
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RTL_CORE="$REPO_ROOT/rtl/core"
RTL_MEM="$REPO_ROOT/rtl/memory"
RTL_BUS="$REPO_ROOT/rtl/bus"
RTL_PERIPH="$REPO_ROOT/rtl/peripherals"
RTL_TOP="$REPO_ROOT/rtl/top"

TB_UNIT="$REPO_ROOT/testbench/unit"
TB_SYS="$REPO_ROOT/testbench/system"
SIM_OUT="$REPO_ROOT/sim_out"
REPORT_DIR="$REPO_ROOT/reports/simulation/phase4"

mkdir -p "$SIM_OUT" "$REPORT_DIR"

LOG="$REPORT_DIR/phase4_sim.log"
: > "$LOG"
log() { echo "$@" | tee -a "$LOG"; }

# Toolchain check
if ! command -v iverilog >/dev/null 2>&1 || ! command -v vvp >/dev/null 2>&1; then
    log "======================================================================"
    log "NOTICE: Icarus Verilog (iverilog / vvp) not found in execution PATH."
    log "Environment: Container / CI without pre-installed EDA tools."
    log "Status: Test execution marked as 'Not run (toolchain unavailable in container)'."
    log "To run locally: Install Icarus Verilog >= 11.0 and run: bash scripts/run_phase4_sim.sh"
    log "======================================================================"
    exit 0
fi

PASS=0; FAIL=0

run_tb() {
    local tb_name="$1"
    local tb_file="$2"
    shift 2
    local extra_srcs=("$@")

    local vvp_file="$SIM_OUT/${tb_name}.vvp"

    log ""
    log "----------------------------------------------------------------------"
    log "Running: $tb_name"
    log "----------------------------------------------------------------------"

    if iverilog -g2012 -Wall -I "$RTL_CORE" -I "$RTL_MEM" -I "$RTL_BUS" -I "$RTL_PERIPH" -I "$RTL_TOP" \
        "${extra_srcs[@]}" \
        "$tb_file" \
        -o "$vvp_file" >> "$LOG" 2>&1; then
        log "  Compile: OK"
    else
        log "  Compile: FAILED"
        FAIL=$((FAIL + 1))
        return
    fi

    if vvp "$vvp_file" >> "$LOG" 2>&1; then
        log "  Simulate: PASS"
        PASS=$((PASS + 1))
    else
        log "  Simulate: FAIL (see $LOG)"
        FAIL=$((FAIL + 1))
    fi
}

RUN_UNIT=1
RUN_SYS=1

for arg in "$@"; do
    case "$arg" in
        --unit-only) RUN_SYS=0 ;;
        --sys-only)  RUN_UNIT=0 ;;
        --help|-h)
            echo "Usage: $0 [--unit-only] [--sys-only] [--help]"
            exit 0
            ;;
    esac
done

# Phase 2 & 3 Core RTL Sources
CORE_SRCS=(
    "$RTL_CORE/pc_unit.sv"
    "$RTL_CORE/if_id_reg.sv"
    "$RTL_CORE/instruction_decoder.sv"
    "$RTL_CORE/immediate_generator.sv"
    "$RTL_CORE/control_unit.sv"
    "$RTL_CORE/register_file.sv"
    "$RTL_CORE/id_ex_reg.sv"
    "$RTL_CORE/alu.sv"
    "$RTL_CORE/ex_mem_reg.sv"
    "$RTL_CORE/load_store_unit.sv"
    "$RTL_CORE/mem_wb_reg.sv"
    "$RTL_CORE/hazard_unit.sv"
    "$RTL_CORE/forwarding_unit.sv"
    "$RTL_CORE/cpu_core.sv"
)

# Phase 4 Subsystem RTL Sources
MEM_SRCS=(
    "$RTL_MEM/instruction_memory.sv"
    "$RTL_MEM/data_memory.sv"
)

BUS_SRCS=(
    "$RTL_BUS/bus_interconnect.sv"
)

PERIPH_SRCS=(
    "$RTL_PERIPH/uart_controller.sv"
    "$RTL_PERIPH/spi_master.sv"
    "$RTL_PERIPH/timer.sv"
    "$RTL_PERIPH/interrupt_controller.sv"
)

ALL_SOC_SRCS=(
    "${CORE_SRCS[@]}"
    "${MEM_SRCS[@]}"
    "${BUS_SRCS[@]}"
    "${PERIPH_SRCS[@]}"
    "$RTL_TOP/rv32i_soc_top.sv"
)

log "======================================================================"
log "RV32I RISC-V SoC — Phase 4 Simulation Suite"
log "Started at: $(date)"
log "======================================================================"

if [ "$RUN_UNIT" -eq 1 ]; then
    log ""
    log ">>> PHASE 4 UNIT TESTBENCHES <<<"
    run_tb "tb_instruction_memory"   "$TB_UNIT/tb_instruction_memory.sv"   "$RTL_MEM/instruction_memory.sv"
    run_tb "tb_data_memory"          "$TB_UNIT/tb_data_memory.sv"          "$RTL_MEM/data_memory.sv"
    run_tb "tb_bus_interconnect"     "$TB_UNIT/tb_bus_interconnect.sv"     "$RTL_BUS/bus_interconnect.sv"
    run_tb "tb_uart_controller"      "$TB_UNIT/tb_uart_controller.sv"      "$RTL_PERIPH/uart_controller.sv"
    run_tb "tb_spi_master"           "$TB_UNIT/tb_spi_master.sv"           "$RTL_PERIPH/spi_master.sv"
    run_tb "tb_timer"                "$TB_UNIT/tb_timer.sv"                "$RTL_PERIPH/timer.sv"
    run_tb "tb_interrupt_controller" "$TB_UNIT/tb_interrupt_controller.sv" "$RTL_PERIPH/interrupt_controller.sv"
fi

if [ "$RUN_SYS" -eq 1 ]; then
    log ""
    log ">>> PHASE 4 SYSTEM INTEGRATION TESTBENCHES <<<"
    run_tb "tb_soc_bus_integration" "$TB_SYS/tb_soc_bus_integration.sv" "${MEM_SRCS[@]}" "${BUS_SRCS[@]}" "${PERIPH_SRCS[@]}"
    run_tb "tb_rv32i_soc_top"       "$TB_SYS/tb_rv32i_soc_top.sv"       "${ALL_SOC_SRCS[@]}"
fi

log ""
log "======================================================================"
log "Phase 4 Simulation Summary:"
log "  Passed: $PASS"
log "  Failed: $FAIL"
log "  Finished at: $(date)"
log "======================================================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
