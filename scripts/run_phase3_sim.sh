#!/usr/bin/env bash
# ============================================================================
# File: scripts/run_phase3_sim.sh
# Project: RV32I RISC-V SoC (Phase 3 — Hazard Detection and Forwarding)
# Description: Compile and simulate all Phase 3 testbenches using Icarus Verilog.
#
#   Usage: bash scripts/run_phase3_sim.sh [--unit-only] [--sys-only] [--help]
#
#   Prerequisites:
#     - Icarus Verilog >= 11.0  (iverilog, vvp)
#     - SystemVerilog 2012 support (-g2012)
#
#   Output:
#     - VCD waveforms in sim_out/
#     - Log file in reports/simulation/phase3/phase3_sim.log
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RTL_DIR="$REPO_ROOT/rtl/core"
TB_UNIT="$REPO_ROOT/testbench/unit"
TB_SYS="$REPO_ROOT/testbench/system"
TB_MOD="$REPO_ROOT/testbench/models"
SIM_OUT="$REPO_ROOT/sim_out"
REPORT_DIR="$REPO_ROOT/reports/simulation/phase3"

mkdir -p "$SIM_OUT" "$REPORT_DIR"

LOG="$REPORT_DIR/phase3_sim.log"
: > "$LOG"
log() { echo "$@" | tee -a "$LOG"; }

PASS=0; FAIL=0

# --- RTL source list (all Phase 2 + Phase 3 core modules) ---
RTL_SRCS=(
    "$RTL_DIR/pc_unit.sv"
    "$RTL_DIR/if_id_reg.sv"
    "$RTL_DIR/instruction_decoder.sv"
    "$RTL_DIR/immediate_generator.sv"
    "$RTL_DIR/control_unit.sv"
    "$RTL_DIR/register_file.sv"
    "$RTL_DIR/id_ex_reg.sv"
    "$RTL_DIR/alu.sv"
    "$RTL_DIR/ex_mem_reg.sv"
    "$RTL_DIR/load_store_unit.sv"
    "$RTL_DIR/mem_wb_reg.sv"
    "$RTL_DIR/hazard_unit.sv"
    "$RTL_DIR/forwarding_unit.sv"
    "$RTL_DIR/cpu_core.sv"
)

MODEL_SRCS=(
    "$TB_MOD/instruction_memory_model.sv"
    "$TB_MOD/data_memory_bus_model.sv"
)

# ---- Helper: compile and run one testbench ----
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

    # Compile
    if iverilog -g2012 -Wall \
        "${extra_srcs[@]}" \
        "$tb_file" \
        -o "$vvp_file" >> "$LOG" 2>&1; then
        log "  Compile: OK"
    else
        log "  Compile: FAILED"
        FAIL=$((FAIL + 1))
        return
    fi

    # Simulate
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
        --help)
            echo "Usage: $0 [--unit-only] [--sys-only] [--help]"
            exit 0 ;;
    esac
done

log "============================================================"
log " RV32I SoC Phase 3 Simulation Suite"
log " $(date)"
log "============================================================"

# ---- Unit testbenches ----
if [[ $RUN_UNIT -eq 1 ]]; then
    log ""
    log "=== UNIT TESTS ==="

    run_tb "tb_hazard_unit" \
        "$TB_UNIT/tb_hazard_unit.sv" \
        "$RTL_DIR/hazard_unit.sv"

    run_tb "tb_forwarding_unit" \
        "$TB_UNIT/tb_forwarding_unit.sv" \
        "$RTL_DIR/forwarding_unit.sv"
fi

# ---- System/integration testbenches ----
if [[ $RUN_SYS -eq 1 ]]; then
    log ""
    log "=== INTEGRATION TESTS ==="

    run_tb "tb_hazard_integration" \
        "$TB_SYS/tb_hazard_integration.sv" \
        "${RTL_SRCS[@]}" \
        "${MODEL_SRCS[@]}"

    run_tb "tb_cpu_forwarding" \
        "$TB_SYS/tb_cpu_forwarding.sv" \
        "${RTL_SRCS[@]}" \
        "${MODEL_SRCS[@]}"
fi

# ---- Summary ----
log ""
log "============================================================"
log " Results: $PASS passed, $FAIL failed"
log "============================================================"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
