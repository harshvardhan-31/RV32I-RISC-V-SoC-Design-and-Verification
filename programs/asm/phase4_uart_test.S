# =============================================================================
# File: phase4_uart_test.S
# Project: RV32I RISC-V SoC (Phase 4 — UART Peripheral Test)
# Description: Assembly test program configuring UART and transmitting string:
#              "RV32I\n" via MMIO registers at 0x2000_0000.
# =============================================================================

.section .text.start
.global _start

_start:
    # Base addresses
    lui   x2, 0x20000           # x2 = 0x2000_0000 (UART Base)
    lui   x3, 0x10000           # x3 = 0x1000_0000 (Data Memory)

    # 1. Set BAUD_DIV = 16 (0x2000_0008)
    addi  x4, x0, 16
    sw    x4, 8(x2)

    # 2. Configure CONTROL: rx_en=1, tx_en=1 (bits [1:0] = 0x3) (0x2000_000C)
    addi  x5, x0, 3
    sw    x5, 12(x2)

    # 3. Transmit characters 'R', 'V', '3', '2', 'I', '\n'
    addi  x10, x0, 82           # 'R'
    jal   x1, uart_putc
    addi  x10, x0, 86           # 'V'
    jal   x1, uart_putc
    addi  x10, x0, 51           # '3'
    jal   x1, uart_putc
    addi  x10, x0, 50           # '2'
    jal   x1, uart_putc
    addi  x10, x0, 73           # 'I'
    jal   x1, uart_putc
    addi  x10, x0, 10           # '\n'
    jal   x1, uart_putc

    # Report pass in Data Memory mailbox (0x1000_0100)
    addi  x6, x0, 1
    sw    x6, 0x100(x3)

done:
    jal   x0, done

# Function: uart_putc
# Sends byte in x10, waits for tx_busy (bit 1 of STATUS at offset 4) to be 0
uart_putc:
    # Poll until tx_busy is 0
wait_tx:
    lw    x7, 4(x2)             # Read STATUS
    andi  x8, x7, 2             # Mask bit 1 (tx_busy)
    bne   x8, x0, wait_tx

    # Write byte to TX_DATA (offset 0)
    sw    x10, 0(x2)
    jalr  x0, 0(x1)
