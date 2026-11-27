# =============================================================================
# File: phase4_spi_test.S
# Project: RV32I RISC-V SoC (Phase 4 — SPI Master Peripheral Test)
# Description: Assembly test program configuring SPI Master, selecting CS0,
#              and initiating an 8-bit full-duplex transfer via MMIO at 0x2000_1000.
# =============================================================================

.section .text.start
.global _start

_start:
    lui   x2, 0x20001           # x2 = 0x2000_1000 (SPI Base)
    lui   x3, 0x10000           # x3 = 0x1000_0000 (Data Memory)

    # 1. Set CLK_DIV = 8 (offset 0x08)
    addi  x4, x0, 8
    sw    x4, 8(x2)

    # 2. Select CS 0: CS_REG = 4'b1110 = 0x0E (offset 0x10)
    addi  x5, x0, 14
    sw    x5, 16(x2)

    # 3. Configure CONTROL: enable=1, cpol=0, cpha=0, irq_en=1 (value = 0x9) (offset 0x0C)
    addi  x6, x0, 9
    sw    x6, 12(x2)

    # 4. Transmit byte 0xAA via TX_DATA (offset 0x00)
    addi  x7, x0, 0xAA
    sw    x7, 0(x2)

    # 5. Poll STATUS (offset 0x04) until busy (bit 1) is 0 and done (bit 0) is 1
poll_spi:
    lw    x8, 4(x2)
    andi  x9, x8, 2             # bit 1: busy
    bne   x9, x0, poll_spi
    andi  x9, x8, 1             # bit 0: done
    beq   x9, x0, poll_spi

    # 6. Read received byte from RX_DATA (offset 0x00)
    lw    x10, 0(x2)

    # 7. Clear done flag via W1C on STATUS (offset 0x04)
    addi  x11, x0, 1
    sw    x11, 4(x2)

    # Record completion in Data Memory mailbox
    addi  x12, x0, 1
    sw    x12, 0x100(x3)

done:
    jal   x0, done
