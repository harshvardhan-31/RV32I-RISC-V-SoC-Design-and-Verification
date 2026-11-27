# =============================================================================
# File: phase4_memory_test.S
# Project: RV32I RISC-V SoC (Phase 4 — Memory Subsystem Test)
# Description: Self-checking assembly test program verifying 64 KiB Data Memory
#              read/write operations: SB, SH, SW, LB, LBU, LH, LHU, LW.
#              Writes result flags to 0x1000_0100:
#                0x0000_0001 = PASS
#                0xDEAD_0001 = FAIL
# =============================================================================

.section .text.start
.global _start

_start:
    # Initialize pointer to Data Memory test region
    lui   x2, 0x10000           # x2 = 0x1000_0000
    addi  x3, x2, 0x100         # x3 = 0x1000_0100 (Status mailbox)

    # -------------------------------------------------------------------------
    # Test 1: Full word store and load (SW / LW)
    # -------------------------------------------------------------------------
    lui   x4, 0x12345
    addi  x4, x4, 0x678         # x4 = 0x1234_5678
    sw    x4, 0(x2)             # Mem[0x1000_0000] = 0x1234_5678
    lw    x5, 0(x2)             # x5 = Mem[0x1000_0000]
    bne   x4, x5, fail_test

    # -------------------------------------------------------------------------
    # Test 2: Byte operations (SB / LB / LBU)
    # -------------------------------------------------------------------------
    addi  x6, x0, 0x8F          # Negative byte in signed representation (-113)
    sb    x6, 4(x2)             # Mem[0x1000_0004] = 0x8F
    lb    x7, 4(x2)             # x7 = Sign-extended 0xFFFFFF8F
    lbu   x8, 4(x2)             # x8 = Zero-extended 0x0000008F

    # Verify sign extension
    addi  x9, x0, -113
    bne   x7, x9, fail_test

    # Verify zero extension
    addi  x9, x0, 0x8F
    bne   x8, x9, fail_test

    # -------------------------------------------------------------------------
    # Test 3: Halfword operations (SH / LH / LHU)
    # -------------------------------------------------------------------------
    lui   x10, 0x0
    addi  x10, x0, -2500        # x10 = 0xFFFF_F63C (lower halfword 0xF63C)
    sh    x10, 8(x2)            # Mem[0x1000_0008] = 0xF63C
    lh    x11, 8(x2)            # x11 = Sign-extended (-2500)
    lhu   x12, 8(x2)            # x12 = Zero-extended (0x0000F63C)

    bne   x11, x10, fail_test
    lui   x13, 0x0
    addi  x13, x13, 0xF63C
    # Verify halfword zero extension
    srli  x14, x12, 16          # Upper 16 bits must be 0
    bne   x14, x0, fail_test

    # -------------------------------------------------------------------------
    # Test 4: Individual byte enables do not corrupt adjacent bytes
    # -------------------------------------------------------------------------
    lui   x15, 0xAAAAA
    addi  x15, x15, 0x2AA       # x15 = 0xAAAA_AAAA
    sw    x15, 12(x2)           # Mem[0x1000_000C] = 0xAAAA_AAAA
    addi  x16, x0, 0x55
    sb    x16, 13(x2)           # Modify byte 1 only
    lw    x17, 12(x2)
    lui   x18, 0xAAAAA
    addi  x18, x18, 0x2AA
    # Check byte 0 is still 0xAA and byte 1 is 0x55
    lbu   x19, 12(x2)
    addi  x20, x0, 0xAA
    bne   x19, x20, fail_test
    lbu   x19, 13(x2)
    bne   x19, x16, fail_test

    # -------------------------------------------------------------------------
    # Success
    # -------------------------------------------------------------------------
    addi  x1, x0, 1
    sw    x1, 0(x3)             # Write 1 (PASS) to mailbox
pass_loop:
    jal   x0, pass_loop

fail_test:
    lui   x1, 0xDEAD0
    addi  x1, x1, 1             # 0xDEAD_0001
    sw    x1, 0(x3)             # Write FAIL to mailbox
fail_loop:
    jal   x0, fail_loop
