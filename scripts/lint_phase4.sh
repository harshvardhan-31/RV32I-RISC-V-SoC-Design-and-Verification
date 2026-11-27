#!/usr/bin/env bash
# =============================================================================
# File: scripts/lint_phase4.sh
# Project: RV32I RISC-V SoC (Phase 4 — Linting Suite)
# Description: Runs Verilator linting (-Wall --lint-only) over all Phase 4
#              RTL modules and the full rv32i_soc_top hierarchy.
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RTL_CORE="$REPO_ROOT/rtl/core"
RTL_MEM="$REPO_ROOT/rtl/memory"
RTL_BUS="$REPO_ROOT/rtl/bus"
RTL_PERIPH="$REPO_ROOT/rtl/peripherals"
RTL_TOP="$REPO_ROOT/rtl/top"

REPORT_DIR="$REPO_ROOT/reports/simulation/phase4"
mkdir -p "$REPORT_DIR"

LOG="$REPORT_DIR/lint_phase4.log"
: > "$LOG"
log() { echo "$@" | tee -a "$LOG"; }

if ! command -v verilator >/dev/null 2>&1; then
    log "======================================================================"
    log "NOTICE: Verilator not found in execution PATH."
    log "Environment: Container / CI without pre-installed EDA tools."
    log "Status: Lint execution marked as 'Not run (toolchain unavailable in container)'."
    log "To run locally: Install Verilator >= 4.0 and run: bash scripts/lint_phase4.sh"
    log "======================================================================"
    exit 0
fi

log "======================================================================"
log "Running Verilator Lint on Phase 4 Subsystems and SoC Top"
log "======================================================================"

verilator --lint-only -Wall \
    -I"$RTL_CORE" -I"$RTL_MEM" -I"$RTL_BUS" -I"$RTL_PERIPH" -I"$RTL_TOP" \
    --top-module rv32i_soc_top \
    "$RTL_CORE"/*.sv \
    "$RTL_MEM"/*.sv \
    "$RTL_BUS"/*.sv \
    "$RTL_PERIPH"/*.sv \
    "$RTL_TOP"/*.sv 2>&1 | tee -a "$LOG"

log "Phase 4 Linting Complete."
