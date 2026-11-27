# =============================================================================
# File: phase4_timer_test.S
# Project: RV32I RISC-V SoC (Phase 4 — Timer Peripheral Test)
# Description: Assembly test program configuring Timer compare threshold,
#              starting timer, polling for compare match, and clearing IRQ status.
# =============================================================================

.section .text.start
.global _start

_start:
    lui   x2, 0x20002           # x2 = 0x2000_2000 (Timer Base)
    lui   x3, 0x10000           # x3 = 0x1000_0000 (Data Memory)

    # 1. Set COMPARE = 50 (offset 0x04)
    addi  x4, x0, 50
    sw    x4, 4(x2)

    # 2. Start Timer: CONTROL = timer_en (bit 0) | irq_en (bit 1) = 3 (offset 0x08)
    addi  x5, x0, 3
    sw    x5, 8(x2)

    # 3. Poll IRQ_STATUS (offset 0x0C) until compare match (bit 0 == 1)
poll_timer:
    lw    x6, 12(x2)
    andi  x7, x6, 1
    beq   x7, x0, poll_timer

    # 4. Read COUNT value (offset 0x00)
    lw    x8, 0(x2)

    # 5. Clear compare match via W1C on IRQ_STATUS (offset 0x0C)
    addi  x9, x0, 1
    sw    x9, 12(x2)

    # 6. Verify IRQ_STATUS is cleared
    lw    x10, 12(x2)
    andi  x11, x10, 1
    bne   x11, x0, fail

    # Write PASS to mailbox
    addi  x12, x0, 1
    sw    x12, 0x100(x3)
pass_loop:
    jal   x0, pass_loop

fail:
    lui   x13, 0xDEAD0
    addi  x13, x13, 1
    sw    x13, 0x100(x3)
fail_loop:
    jal   x0, fail_loop
