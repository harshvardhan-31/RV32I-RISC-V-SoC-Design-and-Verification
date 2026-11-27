# ============================================================================
# File: jump_dependencies.S
# Project: RV32I RISC-V SoC (Phase 3 — Hazard Detection and Forwarding)
# Description: Assembly test program for jump instruction hazards.
#
#   Tests:
#   1. JAL control hazard: 2-cycle fetch penalty, wrong-path flush.
#   2. JALR immediate dependency:
#        ADDI x1, x0, 24
#        JALR x4, x1, 0
#      Verifies that forwarding supplies x1 directly to the JALR target calculation.
#
# Expected register values:
#   x1 = 24 (immediate dependency value)
#   x2 = 8  (JAL link value: addr of instr after JAL)
#   x3 = 0  (must not be set — flushed wrong-path slot)
#   x4 = 8  (JALR link value: PC+4 of JALR)
#   x5 = 42 (set at JALR target, proves jump resolved correctly)
# ============================================================================

.section .text
.global _start
_start:
    # Test 1: JAL — unconditional, no data dependency
    jal   x2, skip_one        # x2 = 4 (return addr); jump to skip_one
    addi  x3, x0, 0xBAD      # MUST be flushed (wrong path)

skip_one:
    # Test 2: Genuine immediate JALR dependency
    # Back-to-back: ADDI produces x1, JALR consumes x1 as base immediately
    addi  x1, x0, 24          # x1 = 24
    jalr  x4, x1, 0           # jump to x1=24; link x4 = PC+4 = 8 (forwarded from EX/MEM)

    addi  x3, x0, 0xBAD       # MUST be flushed (wrong path)
    addi  x3, x0, 0xBAD       # MUST be flushed (wrong path)
    nop
    nop

    # Target address 24:
    addi  x5, x0, 42          # x5 = 42 — proves JALR resolved correctly to target

_halt:
    j     _halt

.end
