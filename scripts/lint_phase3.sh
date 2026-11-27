#!/usr/bin/env bash
# ============================================================================
# File: scripts/lint_phase3.sh
# Project: RV32I RISC-V SoC (Phase 3 — Hazard Detection and Forwarding)
# Description: Run Verilator lint checks on all Phase 3 RTL modules.
#
#   Usage: bash scripts/lint_phase3.sh [--phase2-only] [--phase3-only] [--help]
#
#   Prerequisites:
#     - Verilator >= 4.200
#
#   Flags used:
#     --lint-only     Run lint checks without compiling
#     --Wall          Enable all Verilator warnings
#     --sv            Enable SystemVerilog mode
#     -Wno-TIMESCALEMOD  Suppress timescale warnings in lint mode
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RTL_DIR="$REPO_ROOT/rtl/core"
REPORT_DIR="$REPO_ROOT/reports/simulation/phase3"
mkdir -p "$REPORT_DIR"

LOG="$REPORT_DIR/lint_phase3.log"
: > "$LOG"

PASS=0; FAIL=0

lint_module() {
    local modfile="$1"
    local modname
    modname="$(basename "$modfile" .sv)"
    echo -n "  Linting $modname ... " | tee -a "$LOG"
    if verilator --lint-only --sv --Wall -Wno-TIMESCALEMOD "$modfile" >> "$LOG" 2>&1; then
        echo "PASS" | tee -a "$LOG"
        PASS=$((PASS + 1))
    else
        echo "FAIL (see $LOG)" | tee -a "$LOG"
        FAIL=$((FAIL + 1))
    fi
}

echo "====================================================" | tee -a "$LOG"
echo " RV32I SoC Phase 3 Lint Check (Verilator)" | tee -a "$LOG"
echo " $(date)" | tee -a "$LOG"
echo "====================================================" | tee -a "$LOG"

RUN_P2=1; RUN_P3=1
for arg in "$@"; do
    case "$arg" in
        --phase2-only) RUN_P3=0 ;;
        --phase3-only) RUN_P2=0 ;;
        --help) echo "Usage: $0 [--phase2-only] [--phase3-only] [--help]"; exit 0 ;;
    esac
done

if [[ $RUN_P2 -eq 1 ]]; then
    echo "" | tee -a "$LOG"
    echo "--- Phase 2 Modules ---" | tee -a "$LOG"
    for f in \
        pc_unit instruction_decoder immediate_generator control_unit \
        register_file if_id_reg id_ex_reg alu ex_mem_reg \
        load_store_unit mem_wb_reg; do
        lint_module "$RTL_DIR/$f.sv"
    done
fi

if [[ $RUN_P3 -eq 1 ]]; then
    echo "" | tee -a "$LOG"
    echo "--- Phase 3 Modules ---" | tee -a "$LOG"
    lint_module "$RTL_DIR/hazard_unit.sv"
    lint_module "$RTL_DIR/forwarding_unit.sv"

    echo "" | tee -a "$LOG"
    echo "--- Top-level (cpu_core) ---" | tee -a "$LOG"
    # cpu_core requires all submodules on the command line
    echo -n "  Linting cpu_core (all modules) ... " | tee -a "$LOG"
    if verilator --lint-only --sv --Wall -Wno-TIMESCALEMOD \
        "$RTL_DIR/pc_unit.sv" \
        "$RTL_DIR/if_id_reg.sv" \
        "$RTL_DIR/instruction_decoder.sv" \
        "$RTL_DIR/immediate_generator.sv" \
        "$RTL_DIR/control_unit.sv" \
        "$RTL_DIR/register_file.sv" \
        "$RTL_DIR/id_ex_reg.sv" \
        "$RTL_DIR/alu.sv" \
        "$RTL_DIR/ex_mem_reg.sv" \
        "$RTL_DIR/load_store_unit.sv" \
        "$RTL_DIR/mem_wb_reg.sv" \
        "$RTL_DIR/hazard_unit.sv" \
        "$RTL_DIR/forwarding_unit.sv" \
        "$RTL_DIR/cpu_core.sv" >> "$LOG" 2>&1; then
        echo "PASS" | tee -a "$LOG"
        PASS=$((PASS + 1))
    else
        echo "FAIL (see $LOG)" | tee -a "$LOG"
        FAIL=$((FAIL + 1))
    fi
fi

echo "" | tee -a "$LOG"
echo "====================================================" | tee -a "$LOG"
echo " Lint Results: $PASS passed, $FAIL failed" | tee -a "$LOG"
echo "====================================================" | tee -a "$LOG"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
