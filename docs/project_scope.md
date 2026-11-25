# Project Scope

## Objective
Design, verify and implement a 32-bit RV32I RISC-V SoC with a five-stage pipelined processor and memory-mapped peripherals, taken through an open-source RTL-to-GDSII flow.

## In scope
- RV32I base integer ISA (37 user-level instructions + FENCE, ECALL, EBREAK decoding).
- 32-bit datapath, 32-bit byte addresses, 32 general-purpose registers, x0 hardwired to zero.
- Five-stage in-order pipeline with hazard detection, forwarding and branch flush.
- Separate instruction memory port and data memory/peripheral bus (Harvard-style fetch).
- Custom single-master, single-outstanding-transaction bus.
- Peripherals: UART, SPI master, 32-bit timer, interrupt controller.
- Self-checking SystemVerilog testbenches, directed and randomized RV32I programs.
- Yosys synthesis, OpenROAD placement and routing, STA, DRC/LVS, GDSII.

## Out of scope (not claimed)
M, A, F, D, C extensions; CSRs and privileged architecture (unless approved later); caches; MMU; branch prediction beyond static not-taken; multiple bus masters; AXI (a future AXI-Lite bridge is only a consideration); off-chip memory controllers; FPGA prototyping (optional, TBD).

## Proposed assumptions (not signed off)
| ID | Assumption | Status |
|---|---|---|
| A-01 | Single clock domain, rising edge | Proposed |
| A-02 | Synchronous active-low reset `rst_ni` | Proposed |
| A-03 | Reset vector 0x0000_0000 | Proposed |
| A-04 | Little-endian | Proposed |
| A-05 | Instruction memory: 1-cycle synchronous read | Proposed |
| A-06 | Branches/jumps resolved in EX, static not-taken | Proposed |

## Open decisions (TBD)
Target clock frequency; memory sizes and implementation (SRAM macro vs flip-flops); register-file write-before-read behaviour; misaligned access behaviour; illegal instruction handling; interrupt/trap contract; target PDK and standard-cell library; tool versions.
