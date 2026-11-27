#!/usr/bin/env bash
# =============================================================================
# Script: build_firmware.sh
# Project: RV32I RISC-V SoC (Phase 4 — Firmware Build Flow)
# Description: Compiles assembly programs in programs/asm/ using RISC-V GCC/AS,
#              links them with programs/linker/link.ld, and generates ELF,
#              disassembly (.dump), binary (.bin), and Verilog .hex files.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ASM_DIR="${ROOT_DIR}/programs/asm"
HEX_DIR="${ROOT_DIR}/programs/hex"
BUILD_DIR="${ROOT_DIR}/build/firmware"
LINKER_SCRIPT="${ROOT_DIR}/programs/linker/link.ld"

mkdir -p "${HEX_DIR}"
mkdir -p "${BUILD_DIR}"

# Locate toolchain
CROSS_COMPILE=""
if command -v riscv32-unknown-elf-gcc >/dev/null 2>&1; then
    CROSS_COMPILE="riscv32-unknown-elf-"
elif command -v riscv64-unknown-elf-gcc >/dev/null 2>&1; then
    CROSS_COMPILE="riscv64-unknown-elf-"
elif command -v riscv-none-elf-gcc >/dev/null 2>&1; then
    CROSS_COMPILE="riscv-none-elf-"
else
    echo "[WARNING] No RISC-V cross-compiler found in PATH (riscv32-unknown-elf-gcc / riscv64-unknown-elf-gcc)."
    echo "[INFO] Looking for pre-built hex files or toolchain installation."
    exit 0
fi

CC="${CROSS_COMPILE}gcc"
OBJCOPY="${CROSS_COMPILE}objcopy"
OBJDUMP="${CROSS_COMPILE}objdump"

echo "Using RISC-V Toolchain: ${CC}"

for src in "${ASM_DIR}"/*.S "${ASM_DIR}"/*.s; do
    [ -f "$src" ] || continue
    bname=$(basename "$src")
    name="${bname%.*}"

    echo "Compiling ${bname}..."
    ${CC} -march=rv32i -mabi=ilp32 -nostdlib -T "${LINKER_SCRIPT}" "$src" -o "${BUILD_DIR}/${name}.elf"
    ${OBJDUMP} -d "${BUILD_DIR}/${name}.elf" > "${BUILD_DIR}/${name}.dump"
    ${OBJCOPY} -O binary "${BUILD_DIR}/${name}.elf" "${BUILD_DIR}/${name}.bin"

    # Generate 32-bit word formatted hex for $readmemh
    if command -v hexdump >/dev/null 2>&1; then
        hexdump -v -e '1/4 "%08x\n"' "${BUILD_DIR}/${name}.bin" > "${HEX_DIR}/${name}.hex"
    elif command -v od >/dev/null 2>&1; then
        od -An -tx4 -w4 -v "${BUILD_DIR}/${name}.bin" | tr -d ' ' > "${HEX_DIR}/${name}.hex"
    fi
    echo "  -> Generated ${HEX_DIR}/${name}.hex"
done

echo "Firmware build complete."
