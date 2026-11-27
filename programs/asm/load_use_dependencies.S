# ============================================================================
# File: load_use_dependencies.S
# Project: RV32I RISC-V SoC (Phase 3 — Hazard Detection and Forwarding)
# Description: Assembly test program for load-use data hazards.
#
#   Tests that an instruction immediately following a load instruction
#   that uses the loaded value is handled correctly by hardware:
#     1. hazard_unit detects the load-use dependency.
#     2. Exactly one bubble is inserted (the load advances to MEM).
#     3. The loaded value is forwarded from MEM/WB when the dependent
#        instruction arrives in EX on the next cycle.
#
#   NO NOPs between the LW and dependent instruction.
#
# Expected register values:
#   x3 = 42  (loaded from memory)
#   x4 = 84  (x3 + x2 — MEM/WB forwarding after load-use stall)
#   x5 = 42  (second load, verifying memory correctness)
#   x7 = 0   (LW to x0 must not change x0, no stall for x0 load-use)
# ============================================================================

.section .text
.global _start
_start:
    # Setup: store 42 to data memory at base address 0x1000_0000
    lui   x1,  0x10000        # x1 = 0x1000_0000 (data memory base)
    addi  x2,  x0,  42       # x2 = 42
    sw    x2,  0(x1)          # M[0x1000_0000] = 42

    # Load-use hazard: LW followed immediately by ADD using loaded value
    lw    x3,  0(x1)          # x3 = M[0x1000_0000] = 42  <-- LOAD
    add   x4,  x3,  x2        # x4 = 42+42 = 84  <-- LOAD-USE (hazard_unit stalls)

    # Second load-use with same base
    sw    x4,  4(x1)          # M[0x1000_0004] = 84
    lw    x5,  4(x1)          # x5 = 84
    add   x6,  x5,  x2        # x6 = 126  — load-use stall again

    # LW to x0 — load-use to x0 must NOT stall (x0 always zero)
    lw    x0,  0(x1)          # LW to x0: should be a no-op
    add   x7,  x0,  x0        # x7 = 0  — x0 always reads 0, no hazard

_halt:
    j     _halt

.end
