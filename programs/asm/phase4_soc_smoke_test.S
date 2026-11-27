# =============================================================================
# File: phase4_soc_smoke_test.S
# Project: RV32I RISC-V SoC (Phase 4 — End-to-End SoC Smoke Test)
# Description: Comprehensive assembly smoke test program exercising:
#                - ALU computation
#                - Data memory store and load
#                - UART MMIO initialization and transmission
#                - Timer configuration and compare-match assertion
#                - Interrupt Controller MMIO enable and status check
#                - Result reporting via Data Memory status mailbox (0x1000_0100)
# =============================================================================

.section .text.start
.global _start

_start:
    # Initialize base pointers
    lui   x2, 0x10000           # x2 = 0x1000_0000 (Data Memory base)
    lui   x3, 0x20000           # x3 = 0x2000_0000 (UART base)
    lui   x4, 0x20002           # x4 = 0x2000_2000 (Timer base)
    lui   x5, 0x20003           # x5 = 0x2000_3000 (Interrupt Controller base)

    # -------------------------------------------------------------------------
    # 1. Data Memory R/W Test
    # -------------------------------------------------------------------------
    lui   x6, 0xCAFE0
    addi  x6, x6, 0x555         # x6 = 0xCAFE_0555
    sw    x6, 0(x2)             # Store to DMEM[0]
    lw    x7, 0(x2)             # Load back
    bne   x6, x7, fail

    # -------------------------------------------------------------------------
    # 2. UART Output Test ('O', 'K', '\n')
    # -------------------------------------------------------------------------
    addi  x8, x0, 16            # BAUD_DIV = 16
    sw    x8, 8(x3)
    addi  x8, x0, 3             # CONTROL = rx_en | tx_en
    sw    x8, 12(x3)

    # Send 'O'
    addi  x10, x0, 79
    sw    x10, 0(x3)
poll_uart1:
    lw    x9, 4(x3)
    andi  x9, x9, 2
    bne   x9, x0, poll_uart1

    # Send 'K'
    addi  x10, x0, 75
    sw    x10, 0(x3)
poll_uart2:
    lw    x9, 4(x3)
    andi  x9, x9, 2
    bne   x9, x0, poll_uart2

    # Send '\n'
    addi  x10, x0, 10
    sw    x10, 0(x3)
poll_uart3:
    lw    x9, 4(x3)
    andi  x9, x9, 2
    bne   x9, x0, poll_uart3

    # -------------------------------------------------------------------------
    # 3. Timer & Interrupt Controller Setup
    # -------------------------------------------------------------------------
    # Set Timer COMPARE = 20
    addi  x11, x0, 20
    sw    x11, 4(x4)

    # Enable Timer IRQ in INTC: bit 2 (0x4)
    addi  x12, x0, 4
    sw    x12, 4(x5)

    # Start Timer: CONTROL = timer_en (bit 0) | irq_en (bit 1) = 3
    addi  x13, x0, 3
    sw    x13, 8(x4)

    # Poll INTC PENDING register until bit 2 (Timer) is set
poll_intc:
    lw    x14, 0(x5)
    andi  x15, x14, 4
    beq   x15, x0, poll_intc

    # Clear Timer IRQ in INTC: write 4 to CLEAR register (offset 0x08)
    addi  x16, x0, 4
    sw    x16, 8(x5)

    # Also clear Timer IRQ_STATUS: write 1 to offset 0x0C
    addi  x17, x0, 1
    sw    x17, 12(x4)

    # -------------------------------------------------------------------------
    # 4. Report PASS
    # -------------------------------------------------------------------------
    addi  x1, x0, 1
    sw    x1, 0x100(x2)         # Mailbox at 0x1000_0100 = 1

pass_loop:
    jal   x0, pass_loop

fail:
    lui   x1, 0xDEAD0
    addi  x1, x1, 1
    sw    x1, 0x100(x2)
fail_loop:
    jal   x0, fail_loop
