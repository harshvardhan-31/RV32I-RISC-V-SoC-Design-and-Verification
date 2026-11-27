# Phase 4 Hardware Timer Specification

## 1. Overview

The 32-bit Hardware Timer (`timer.sv`) provides real-time timekeeping, periodic event scheduling, and compare-match interrupt generation, mapped at `0x2000_2000`.

---

## 2. Register Memory Map (Base: 0x2000_2000)

| Offset | Name | Type | Reset Value | Description |
| :---: | :--- | :---: | :---: | :--- |
| `0x00` | `COUNT` | RO | `0x0000_0000` | 32-bit counter value. Increments every clock when enabled. |
| `0x04` | `COMPARE` | RW | `0xFFFF_FFFF` | 32-bit compare threshold. |
| `0x08` | `CONTROL` | RW | `0x0000_0000` | Bit 0: `timer_en`<br>Bit 1: `irq_en` |
| `0x0C` | `IRQ_STATUS`| W1C | `0x0000_0000` | Bit 0: `compare_match` (W1C flag) |

---

## 3. Functional Operation

### Counting Logic
- The counter increments by 1 on every positive clock edge where `CONTROL[0]` (`timer_en`) is asserted.
- When `timer_en` is deasserted, the counter preserves its current value.
- Writes to `COUNT` are ignored (read-only register).

### Compare Match & Interrupts
- On each clock cycle where `timer_en` is active:
  $$\text{if } (\text{COUNT} == \text{COMPARE}) \implies \text{IRQ\_STATUS}[0] \leftarrow 1$$
- The compare match flag is **sticky**: once set, it remains 1 until explicitly cleared by writing a `1` to `IRQ_STATUS[0]` (Write-1-to-Clear).
- Priority resolution: If a compare match condition occurs in the exact same clock cycle as a W1C write to clear `IRQ_STATUS`, the match event takes precedence and the flag remains asserted.
- Output interrupt:
  $$\text{irq\_o} = \text{IRQ\_STATUS}[0] \ \& \ \text{CONTROL}[1]$$
