# ============================================================================
# File: raw_alu_dependencies.S
# Project: RV32I RISC-V SoC (Phase 3 — Hazard Detection and Forwarding)
# Description: Assembly test program for RAW ALU data hazards.
#
#   Tests that back-to-back ALU instructions with data dependencies
#   execute correctly through EX/MEM and MEM/WB forwarding paths.
#   NO NOPs are inserted between dependent instructions — the hardware
#   forwarding unit resolves all hazards transparently.
#
#   Assemble with: riscv32-unknown-elf-as -march=rv32i -o raw_alu.o raw_alu_dependencies.S
#   Link with:     riscv32-unknown-elf-ld -Ttext=0x0 -o raw_alu.elf raw_alu.o
#   Convert:       riscv32-unknown-elf-objcopy -O verilog raw_alu.elf raw_alu.hex
#
# Expected register values after execution:
#   x1 = 5
#   x2 = 3
#   x3 = 8   (x1 + x2 — forwarded)
#   x4 = 3   (x3 - x1 — forwarded)
#   x5 = 0   (x3 & x4 — forwarded via MEM/WB and EX/MEM)
# ============================================================================

.section .text
.global _start
_start:
    addi  x1, x0,  5         # x1 = 5
    addi  x2, x0,  3         # x2 = 3
    add   x3, x1,  x2        # x3 = 8  — RAW: x1 and x2 forwarded from EX/MEM
    sub   x4, x3,  x1        # x4 = 3  — RAW: x3 forwarded from EX/MEM
    and   x5, x3,  x4        # x5 = 0  — RAW: x3 (MEM/WB), x4 (EX/MEM)

    # Back-to-back chain: each instruction depends on the previous
    addi  x6,  x0,  1        # x6 = 1
    add   x7,  x6,  x6       # x7 = 2  — EX/MEM fwd x6
    add   x8,  x7,  x6       # x8 = 3  — EX/MEM fwd x7, MEM/WB fwd x6
    add   x9,  x8,  x7       # x9 = 5  — EX/MEM fwd x8, MEM/WB fwd x7
    add   x10, x9,  x8       # x10= 8  — Fibonacci via forwarding

    # Instruction that does not read rs1 or rs2 (LUI) — no false hazard
    lui   x11, 0x12345        # x11 = 0x1234_5000 (no dep on prev)
    add   x12, x1,  x2       # x12 = 8  — MEM/WB fwd x1 and x2

_halt:
    j     _halt               # Spin: processor halts here

.end
