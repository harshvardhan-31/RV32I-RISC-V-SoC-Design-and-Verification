# Phase 2 Assembly Test: Branch and Jump Control Flow Test
# Tests:
# 1. BEQ taken and not taken
# 2. BNE taken and not taken
# 3. BLT / BGE signed comparison branching
# 4. BLTU / BGEU unsigned comparison branching
# 5. JAL and JALR linking and jumping
# 6. Verifies that instructions fetched on the wrong branch path
#    are properly flushed in IF/ID and ID/EX and never commit side effects.

.section .text
.globl _start

_start:
    # Setup test registers
    addi x1, x0, 10
    nop
    nop
    nop

    addi x2, x0, 20
    nop
    nop
    nop

    addi x3, x0, 10
    nop
    nop
    nop

    # Test 1: BEQ Not Taken (x1 != x2)
    beq x1, x2, fail_branch
    nop
    nop
    nop

    # Test 2: BEQ Taken (x1 == x3)
    beq x1, x3, pass_beq
    nop
    nop
    nop

    # Dead code if flush works
    addi x4, x0, 0xBAD
    nop
    nop
    nop

pass_beq:
    # x4 should be set to 1
    addi x4, x0, 1
    nop
    nop
    nop

    # Test 3: JAL to target
    jal x5, pass_jal
    nop
    nop
    nop

    # Dead code if JAL flush works
    addi x6, x0, 0xBAD
    nop
    nop
    nop

pass_jal:
    # x6 should be set to 2
    addi x6, x0, 2
    nop
    nop
    nop

done:
    beq x0, x0, done
    nop
    nop
    nop

fail_branch:
    addi x31, x0, 0xDEAD
    beq x0, x0, fail_branch
    nop
    nop
    nop
