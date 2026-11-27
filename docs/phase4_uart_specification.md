# Phase 4 UART Controller Specification

## 1. Overview

The UART Controller (`uart_controller.sv`) provides an 8-N-1 (8 data bits, no parity, 1 stop bit) full-duplex asynchronous serial communication interface, mapped at `0x2000_0000`.

---

## 2. Register Memory Map (Base: 0x2000_0000)

| Offset | Name | Type | Reset Value | Description |
| :---: | :--- | :---: | :---: | :--- |
| `0x00` | `DATA` | RW | `0x0000_0000` | Write: `TX_DATA[7:0]`; Read: `RX_DATA[7:0]` (read-to-consume) |
| `0x04` | `STATUS` | RO/W1C | `0x0000_0000` | Bit 0: `rx_data_ready`<br>Bit 1: `tx_busy`<br>Bit 2: `rx_overrun` (W1C)<br>Bit 3: `rx_frame_error` (W1C) |
| `0x08` | `BAUD_DIV` | RW | `32'd868` | 32-bit clock divider ($N = \text{freq}_{\text{clk}} / \text{baud}$) |
| `0x0C` | `CONTROL` | RW | `0x0000_0000` | Bit 0: `rx_en`<br>Bit 1: `tx_en`<br>Bit 2: `irq_en` |

---

## 3. Theory of Operation

### Baud Rate Generation
The baud divider generates internal baud clock pulses:
$$\text{Divider} = \frac{f_{\text{clk}}}{\text{Baud Rate}}$$
For $f_{\text{clk}} = 100\text{ MHz}$ and $115,200\text{ baud}$, $\text{Divider} \approx 868$.
RX oversamples the incoming `uart_rx_i` pin by running a mid-bit sample counter ($\text{Divider} / 2$) to establish robust bit center sampling.

### Transmitter FSM
- **IDLE**: Line holds `1`. Writing to `DATA` loads transmit buffer and transitions to `START`.
- **START**: Line drives `0` for 1 bit period.
- **DATA**: Serializes 8 bits LSB-first.
- **STOP**: Line drives `1` for 1 bit period, then returns to `IDLE` and deasserts `tx_busy`.

### Receiver FSM
- **IDLE**: Watches for falling edge of synchronized `uart_rx_i`.
- **START**: Samples at mid-bit period. If still `0`, advances to `DATA`; else false start.
- **DATA**: Samples 8 bits at each bit center.
- **STOP**: Samples stop bit (expected `1`). If `0`, sets `rx_frame_error`.
- Upon valid byte reception, asserts `rx_data_ready` and sets internal buffer.
- Reading `DATA` automatically consumes the byte and deasserts `rx_data_ready`. If a new byte arrives before consumption, `rx_overrun` is asserted.

### Interrupt Generation
`irq_o = (rx_data_ready | rx_overrun | rx_frame_error) & CONTROL[2]`.
