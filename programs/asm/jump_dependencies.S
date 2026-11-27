# ============================================================================
# File: jump_dependencies.S
# Project: RV32I RISC-V SoC (Phase 3 — Hazard Detection and Forwarding)
# Description: Assembly test program for jump instruction hazards.
#
#   Tests:
#   1. JAL control hazard: 2-cycle fetch penalty, wrong-path flush.
#   2. JALR base-register forwarding: the JALR base register (rs1) is
#      forwarded from EX/MEM or MEM/WB so a dependent JALR works correctly.
#
# Expected register values:
#   x2 = 8  (JAL link value: addr of instr after JAL)
#   x3 = 0  (must not be set — was in JAL wrong-path slot, should be flushed)
#   x4 = link to instr after JALR
#   x5 = 1  (set at JALR target, proves correct jump resolution)
# ============================================================================

.section .text
.global _start
_start:
    # Test 1: JAL — unconditional, no data dependency
    # JAL at addr 0 → target = 8 (skips instr at addr 4)
    jal   x2, skip_one        # x2 = 4 (return addr); jump to skip_one
    addi  x3, x0, 0xBAD      # MUST be flushed (wrong path)

skip_one:
    # x3 must still be 0 here

    # Test 2: JALR with computed base address
    # Compute target address in register, then JALR — tests forwarding
    addi  x1, x0, jalr_tgt   # x1 = address of jalr_tgt label
    jalr  x4, x1, 0           # jump to x1 (forwarded from MEM/WB); x4 = PC+4

    addi  x5, x0, 0xBAD      # flushed — wrong path after JALR

jalr_tgt:
    addi  x5, x0, 1          # x5 = 1 — proves JALR resolved correctly

_halt:
    j     _halt

.end
