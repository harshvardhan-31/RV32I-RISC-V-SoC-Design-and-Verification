# Phase 4 Firmware Hex Files and Generation Guidelines

This directory (`programs/hex/`) contains memory initialization hex files used for simulation preloading of the 64 KiB Instruction Memory and Data Memory.

## Memory Hex Format Specification

The Verilog `$readmemh` system task expects 32-bit hexadecimal words formatted one word per line (without `0x` prefix), with little-endian byte ordering within each 32-bit word:

```text
// Example memory hex content:
00000013 // nop (addi x0, x0, 0)
10000137 // lui  x2, 0x10000
04200093 // addi x1, x0, 0x42
00112023 // sw   x1, 0(x2)
```

## How to Build Firmware Hex from Assembly

Use the included build script:
```bash
bash scripts/build_firmware.sh
```

Or manually using the RISC-V GNU Toolchain:

```bash
# 1. Assemble to object file
riscv32-unknown-elf-as -march=rv32i -mabi=ilp32 programs/asm/phase4_soc_smoke_test.S -o build/smoke.o

# 2. Link using the ratified Phase 4 linker script
riscv32-unknown-elf-ld -T programs/linker/link.ld build/smoke.o -o build/smoke.elf

# 3. Disassemble for verification
riscv32-unknown-elf-objdump -d build/smoke.elf > build/smoke.dump

# 4. Convert ELF to binary
riscv32-unknown-elf-objcopy -O binary build/smoke.elf build/smoke.bin

# 5. Convert binary to 32-bit word hex for Verilog $readmemh
hexdump -v -e '1/4 "%08x\n"' build/smoke.bin > programs/hex/phase4_soc_smoke_test.hex
```
