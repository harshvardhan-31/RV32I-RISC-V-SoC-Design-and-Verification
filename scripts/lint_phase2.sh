#!/usr/bin/env bash
# ============================================================================
# Script: lint_phase2.sh
# Project: RV32I RISC-V SoC (Phase 2 - Linting Script)
# Description: Lints Phase 2 SystemVerilog RTL modules using Verilator.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v verilator &> /dev/null; then
    echo "======================================================================"
    echo "[INFO] Verilator is not installed or not in PATH."
    echo "To install Verilator:"
    echo "  - Ubuntu / Debian: sudo apt-get install verilator"
    echo "  - macOS: brew install verilator"
    echo "  - Windows: pacman -S mingw-w64-x86_64-verilator"
    echo "======================================================================"
    exit 1
fi

echo "======================================================================"
echo " Running Verilator Lint on Phase 2 CPU Core RTL"
echo " Verilator: $(verilator --version)"
echo "======================================================================"

verilator --lint-only -Wall \
    -I"$REPO_ROOT/rtl/core" \
    --top-module cpu_core \
    "$REPO_ROOT/rtl/core/pc_unit.sv" \
    "$REPO_ROOT/rtl/core/if_id_reg.sv" \
    "$REPO_ROOT/rtl/core/instruction_decoder.sv" \
    "$REPO_ROOT/rtl/core/immediate_generator.sv" \
    "$REPO_ROOT/rtl/core/control_unit.sv" \
    "$REPO_ROOT/rtl/core/register_file.sv" \
    "$REPO_ROOT/rtl/core/id_ex_reg.sv" \
    "$REPO_ROOT/rtl/core/alu.sv" \
    "$REPO_ROOT/rtl/core/ex_mem_reg.sv" \
    "$REPO_ROOT/rtl/core/load_store_unit.sv" \
    "$REPO_ROOT/rtl/core/mem_wb_reg.sv" \
    "$REPO_ROOT/rtl/core/cpu_core.sv"

echo "[PASS] Phase 2 RTL passed Verilator lint checks cleanly."
