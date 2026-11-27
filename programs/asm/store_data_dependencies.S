# ============================================================================
# File: store_data_dependencies.S
# Project: RV32I RISC-V SoC (Phase 3 — Hazard Detection and Forwarding)
# Description: Assembly test program for store data forwarding.
#
#   Tests that the data written by a SW instruction is correctly forwarded
#   from the EX stage (fwd_rs2_val) when the store data register (rs2) was
#   produced by the immediately preceding ALU instruction.
#
#   The forwarding path:
#     ADD x3, x2, x2    — result of ADD in EX/MEM stage
#     SW  x3, 0(x1)     — store data = x3 forwarded from EX/MEM into ex_mem_reg
#
#   Without forwarding, SW would use a stale (pre-write) x3 from the
#   register file. With Phase 3 forwarding, fwd_rs2_val is used instead.
#
# Expected memory state:
#   M[0x1000_0000] = 14   (ADD result stored correctly)
#   M[0x1000_0004] = 7    (verify second store-data fwd scenario)
#
# Expected register values:
#   x4 = 14  (loaded back from M[0x1000_0000], verifies store was correct)
#   x5 = 7   (loaded from M[0x1000_0004])
# ============================================================================

.section .text
.global _start
_start:
    lui   x1,  0x10000        # x1 = 0x1000_0000 (data memory base)
    addi  x2,  x0,  7        # x2 = 7

    # Store data forwarding: x3 computed immediately before SW
    add   x3,  x2,  x2       # x3 = 14 — in EX when SW is decoded
    sw    x3,  0(x1)          # SW: store data forwarded from EX/MEM (fwd_rs2_val)

    # Verify store: load back and check
    lw    x4,  0(x1)          # x4 = M[0x1000_0000] should be 14

    # Second scenario: immediate ADDI result stored
    addi  x6,  x0,  7        # x6 = 7
    sw    x6,  4(x1)          # SW: x6 forwarded from EX/MEM
    lw    x5,  4(x1)          # x5 = 7

    # Triple-write scenario — ensure only most recent value is forwarded
    addi  x7,  x0,  1        # x7 = 1
    addi  x7,  x7,  1        # x7 = 2  — EX/MEM overwrites
    sw    x7,  8(x1)          # M[0x1000_0008] = 2 (most recent x7 forwarded)
    lw    x8,  8(x1)          # x8 = 2

_halt:
    j     _halt

.end
