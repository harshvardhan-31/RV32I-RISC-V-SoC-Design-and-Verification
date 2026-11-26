#!/usr/bin/env bash
# ============================================================================
# Script: run_phase2_sim.sh
# Project: RV32I RISC-V SoC (Phase 2 - Simulation Runner)
# Description: Compiles and runs Phase 2 unit and system testbenches using
#              Icarus Verilog (-g2012). Stores execution logs under reports/simulation/phase2/.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build/phase2"
REPORT_DIR="$REPO_ROOT/reports/simulation/phase2"

mkdir -p "$BUILD_DIR"
mkdir -p "$REPORT_DIR"

# Check if Icarus Verilog is installed
if ! command -v iverilog &> /dev/null || ! command -v vvp &> /dev/null; then
    echo "======================================================================"
    echo "[ERROR] Icarus Verilog ('iverilog' / 'vvp') is not found in PATH."
    echo "To install Icarus Verilog:"
    echo "  - Ubuntu / Debian: sudo apt-get update && sudo apt-get install iverilog"
    echo "  - macOS (Homebrew): brew install icarus-verilog"
    echo "  - Windows (MSYS2 / Chocolatey): choco install icarus-verilog  OR  pacman -S mingw-w64-x86_64-iverilog"
    echo "======================================================================"
    exit 1
fi

RTL_CORE_SRCS=(
    "$REPO_ROOT/rtl/core/pc_unit.sv"
    "$REPO_ROOT/rtl/core/if_id_reg.sv"
    "$REPO_ROOT/rtl/core/instruction_decoder.sv"
    "$REPO_ROOT/rtl/core/immediate_generator.sv"
    "$REPO_ROOT/rtl/core/control_unit.sv"
    "$REPO_ROOT/rtl/core/register_file.sv"
    "$REPO_ROOT/rtl/core/id_ex_reg.sv"
    "$REPO_ROOT/rtl/core/alu.sv"
    "$REPO_ROOT/rtl/core/ex_mem_reg.sv"
    "$REPO_ROOT/rtl/core/load_store_unit.sv"
    "$REPO_ROOT/rtl/core/mem_wb_reg.sv"
    "$REPO_ROOT/rtl/core/cpu_core.sv"
)

TESTS=(
    "tb_alu:$REPO_ROOT/testbench/unit/tb_alu.sv:$REPO_ROOT/rtl/core/alu.sv"
    "tb_register_file:$REPO_ROOT/testbench/unit/tb_register_file.sv:$REPO_ROOT/rtl/core/register_file.sv"
    "tb_instruction_decoder:$REPO_ROOT/testbench/unit/tb_instruction_decoder.sv:$REPO_ROOT/rtl/core/instruction_decoder.sv"
    "tb_immediate_generator:$REPO_ROOT/testbench/unit/tb_immediate_generator.sv:$REPO_ROOT/rtl/core/immediate_generator.sv"
    "tb_control_unit:$REPO_ROOT/testbench/unit/tb_control_unit.sv:$REPO_ROOT/rtl/core/control_unit.sv"
    "tb_pipeline_registers:$REPO_ROOT/testbench/unit/tb_pipeline_registers.sv:$REPO_ROOT/rtl/core/if_id_reg.sv $REPO_ROOT/rtl/core/id_ex_reg.sv $REPO_ROOT/rtl/core/ex_mem_reg.sv $REPO_ROOT/rtl/core/mem_wb_reg.sv"
    "tb_load_store_unit:$REPO_ROOT/testbench/unit/tb_load_store_unit.sv:$REPO_ROOT/rtl/core/load_store_unit.sv"
    "tb_cpu_core:$REPO_ROOT/testbench/system/tb_cpu_core.sv:${RTL_CORE_SRCS[*]} $REPO_ROOT/testbench/models/instruction_memory_model.sv $REPO_ROOT/testbench/models/data_memory_bus_model.sv"
)

TARGET_TEST="${1:-all}"
OVERALL_STATUS=0

echo "======================================================================"
echo " Starting Phase 2 Simulation Suite (Icarus Verilog -g2012)"
echo " Tool version: $(iverilog -V | head -n 1)"
echo " Timestamp:    $(date -u)"
echo "======================================================================"

run_single_test() {
    local TB_NAME="$1"
    local TB_SRC="$2"
    shift 2
    local RTL_SRCS=("$@")

    local VVP_OUT="$BUILD_DIR/${TB_NAME}.vvp"
    local LOG_FILE="$REPORT_DIR/${TB_NAME}.log"

    echo "--- Compiling and Running: ${TB_NAME} ---"

    if [ -f "$LOG_FILE" ]; then
        cp "$LOG_FILE" "${LOG_FILE}.bak" 2>/dev/null || true
    fi

    # Compile
    if ! iverilog -g2012 -Wall -I "$REPO_ROOT/rtl/core" -o "$VVP_OUT" "$TB_SRC" "${RTL_SRCS[@]}"; then
        echo "[FAIL] Compilation error for ${TB_NAME}" | tee "$LOG_FILE"
        OVERALL_STATUS=1
        return
    fi

    # Execute simulation
    if vvp "$VVP_OUT" | tee "$LOG_FILE"; then
        echo "[PASS] ${TB_NAME} simulation completed successfully."
    else
        echo "[FAIL] ${TB_NAME} simulation failed with runtime error."
        OVERALL_STATUS=1
    fi
    echo ""
}

for item in "${TESTS[@]}"; do
    IFS=":" read -r TNAME TSRC TRTL <<< "$item"
    if [ "$TARGET_TEST" = "all" ] || [ "$TARGET_TEST" = "$TNAME" ]; then
        run_single_test "$TNAME" "$TSRC" $TRTL
    fi
done

if [ $OVERALL_STATUS -eq 0 ]; then
    echo "======================================================================"
    echo " ALL PHASE 2 SIMULATION TESTS COMPLETED SUCCESSFULLY!"
    echo "======================================================================"
else
    echo "======================================================================"
    echo " SOME TESTS FAILED. CHECK LOGS UNDER reports/simulation/phase2/"
    echo "======================================================================"
fi

exit $OVERALL_STATUS
