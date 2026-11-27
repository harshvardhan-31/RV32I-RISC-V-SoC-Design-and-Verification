# Phase 4 SPI Master Specification

## 1. Overview

The SPI Master controller (`spi_master.sv`) provides high-speed synchronous serial communication supporting standard Motorola SPI Modes 0, 1, 2, and 3, mapped at `0x2000_1000`.

---

## 2. Register Memory Map (Base: 0x2000_1000)

| Offset | Name | Type | Reset Value | Description |
| :---: | :--- | :---: | :---: | :--- |
| `0x00` | `DATA` | RW | `0x0000_0000` | Write: `TX_DATA[7:0]`; Read: `RX_DATA[7:0]` |
| `0x04` | `STATUS` | RO/W1C | `0x0000_0000` | Bit 0: `done` (W1C)<br>Bit 1: `busy` (RO) |
| `0x08` | `CLK_DIV` | RW | `32'd10` | SCLK prescaler ($f_{\text{sclk}} = f_{\text{clk}} / (2 \times \text{DIV})$) |
| `0x0C` | `CONTROL` | RW | `0x0000_0000` | Bit 0: `enable`<br>Bit 1: `cpol`<br>Bit 2: `cpha`<br>Bit 3: `irq_en` |
| `0x10` | `CS_REG` | RW | `32'h0000_000F` | Bits [3:0]: Active-low chip select lines (`spi_cs_no[3:0]`) |

---

## 3. SPI Modes & Protocol

| Mode | CPOL (Clock Polarity) | CPHA (Clock Phase) | Clock Idle State | Shift Out Edge | Sample Edge |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **Mode 0** | 0 | 0 | Low | Falling Edge | Rising Edge |
| **Mode 1** | 0 | 1 | Low | Rising Edge | Falling Edge |
| **Mode 2** | 1 | 0 | High | Rising Edge | Falling Edge |
| **Mode 3** | 1 | 1 | High | Falling Edge | Rising Edge |

### Transfer Operation
1. The CPU writes `CS_REG` to assert the target chip select line (e.g. `4'b1110` for slave 0).
2. The CPU configures `CLK_DIV` and `CONTROL` (enabling master and setting Mode).
3. Writing to `DATA` triggers the 8-bit full-duplex transfer:
   - `STATUS[1]` (`busy`) asserts immediately.
   - SCLK toggles for 8 full cycles.
   - MOSI shifts out bits MSB first.
   - MISO samples incoming bits synchronously.
4. When all 8 bits are shifted, `STATUS[0]` (`done`) asserts, `busy` deasserts, and `irq_o` pulses/asserts if `irq_en` is set.
5. CPU reads `DATA` to retrieve the received 8-bit word.
