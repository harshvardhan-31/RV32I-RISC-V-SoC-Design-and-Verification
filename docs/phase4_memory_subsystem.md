# Phase 4 Memory Subsystem Specification

## 1. Overview

The Phase 4 memory subsystem provides high-speed, deterministic memory storage for the RV32I processor, comprising:
- **Instruction Memory (`instruction_memory.sv`)**: 64 KiB dedicated synchronous ROM/RAM for instruction fetching.
- **Data Memory (`data_memory.sv`)**: 64 KiB byte-addressable, byte-enable masked synchronous RAM for load/store data storage.

Both memories are implemented as synthesizable SystemVerilog models with word alignment checking, boundary bounds checking, and support for file initialization via `$readmemh`.

---

## 2. Instruction Memory (`instruction_memory.sv`)

### Interface Ports
| Port | Direction | Width | Description |
| :--- | :---: | :---: | :--- |
| `clk_i` | Input | 1 | System clock (rising edge) |
| `rst_ni` | Input | 1 | Synchronous active-low reset |
| `req_i` | Input | 1 | Fetch request strobe |
| `addr_i` | Input | 32 | Instruction fetch byte address |
| `ready_o` | Output | 1 | 1-cycle synchronous response ready |
| `rdata_o` | Output | 32 | 32-bit instruction data |
| `error_o` | Output | 1 | Alignment or out-of-bounds error flag |

### Timing & Handshake
- Instruction fetching features deterministic **1-cycle read latency**.
- When `req_i` is asserted on cycle $T$, `ready_o` and `rdata_o` assert on cycle $T+1$.
- Any misaligned address (`addr_i[1:0] != 2'b00`) or address beyond the 64 KiB aperture (`addr_i >= 0x0001_0000`) triggers `error_o = 1` and returns `rdata_o = 32'h0000_0000`.

---

## 3. Data Memory (`data_memory.sv`)

### Interface Ports
| Port | Direction | Width | Description |
| :--- | :---: | :---: | :--- |
| `clk_i` | Input | 1 | System clock |
| `rst_ni` | Input | 1 | Synchronous active-low reset |
| `valid_i` | Input | 1 | Bus transaction request strobe |
| `we_i` | Input | 1 | Write enable (1=Write, 0=Read) |
| `addr_i` | Input | 32 | Data byte address (`0x1000_0000 - 0x1000_FFFF`) |
| `wdata_i` | Input | 32 | Write data |
| `be_i` | Input | 4 | Byte write enables (`be_i[3:0]`) |
| `ready_o` | Output | 1 | Bus handshake ready |
| `rdata_o` | Output | 32 | Read data |
| `error_o` | Output | 1 | Misalignment or out-of-bounds error flag |

### Byte Enables & Addressing
The data memory supports byte (`SB`), halfword (`SH`), and word (`SW`) stores using the 4-bit byte-enable mask:
- Byte 0 (`be_i[0]`): controls byte at offset 0 (`addr_i[1:0] == 2'b00`) -> bits `[7:0]`
- Byte 1 (`be_i[1]`): controls byte at offset 1 (`addr_i[1:0] == 2'b01`) -> bits `[15:8]`
- Byte 2 (`be_i[2]`): controls byte at offset 2 (`addr_i[1:0] == 2'b10`) -> bits `[23:16]`
- Byte 3 (`be_i[3]`): controls byte at offset 3 (`addr_i[1:0] == 2'b11`) -> bits `[31:24]`

Stores only update bytes whose corresponding `be_i` bit is asserted, preventing corruption of neighboring bytes.
Misaligned transfers or accesses outside `0x1000_0000 - 0x1000_FFFF` assert `error_o = 1`.
