# Phase 2 Implementation Decisions

> Document status: Approved Baseline for Phase 2 Implementation.
> Scope: RV32I Five-Stage Pipelined Processor Core (IF, ID, EX, MEM, WB).

This document formalizes the architectural choices, interface conventions, and baseline assumptions established for the Phase 2 implementation of the RV32I RISC-V CPU core. These decisions resolve open assumptions from Phase 1 for the scope of the Phase 2 deliverable, while preserving planned interfaces for Phase 3 (Hazard Detection and Forwarding) and Phase 4 (SoC Interconnect and Peripherals).

---

## 1. Documented Baseline Assumptions

The following 10 baseline decisions govern all Phase 2 RTL modules:

1. **Clocking:**
   - Single global rising-edge clock domain (`clk_i`).
   - All sequential elements (PC, pipeline registers, register file write port) sample on the rising edge of `clk_i`.

2. **Reset:**
   - Synchronous active-low reset named `rst_ni`.
   - On reset assertion (`!rst_ni` sampled at `posedge clk_i`), the pipeline registers clear their `valid` flags to zero, PC resets to the reset vector, and control signals default to benign values (no writes).

3. **Reset Vector:**
   - `0x0000_0000`.
   - The Program Counter (`pc_unit`) initializes to `32'h0000_0000` upon reset release.

4. **Endianness:**
   - Little-endian memory and byte ordering throughout the datapath, load-store unit, and memory interfaces.
   - Byte 0 occupies data bits `[7:0]`, Byte 1 occupies `[15:8]`, Byte 2 occupies `[23:16]`, and Byte 3 occupies `[31:24]`.

5. **Instruction Memory Latency:**
   - The instruction memory interface models a 1-cycle synchronous read latency in simulation.
   - The fetch stage issues `imem_req_o` and `imem_addr_o`; instruction data `imem_rdata_i` arrives along with `imem_ready_i`.

6. **Branch and Jump Resolution:**
   - Control-flow instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU, JAL, JALR) are evaluated and resolved exclusively in the **Execute (EX)** stage.
   - When a branch is taken or a jump is executed, the EX stage generates `redirect_valid = 1` and `redirect_pc`, causing the PC unit to update to the target address on the next clock cycle and triggering a synchronous flush of younger instructions in `IF/ID` and `ID/EX`.

7. **Fetch Branch Policy:**
   - Static **not-taken** fetch policy.
   - Next PC defaults sequentially to `PC + 4` until redirected by EX.

8. **Register File Timing:**
   - 32 general-purpose 32-bit registers (`x0` through `x31`).
   - Two combinational (asynchronous) read ports (`rs1_data_o`, `rs2_data_o`).
   - One synchronous rising-edge write port (`rd_addr_i`, `rd_data_i`, `we_i`).
   - Reading and writing the same register in the same clock cycle returns the currently stored value in Phase 2; full forwarding bypass is integrated in Phase 3.

9. **Register x0 Hardwiring:**
   - Register `x0` is permanently hardwired to `32'h0000_0000`.
   - Writes directed to `rd == 5'b00000` are explicitly ignored and discarded.

10. **Phase 2 Hazard Policy (Strict Phase Boundary):**
    - **No hardware forwarding unit** and **no automatic RAW/load-use hazard detection unit** are instantiated in Phase 2 RTL.
    - Code executed on the Phase 2 processor must insert sufficient `NOP` (`addi x0, x0, 0`) instructions between dependent operations:
      - 3 NOPs between an ALU/register write and a subsequent register read.
      - 3 NOPs between a Load instruction and a dependent instruction.
    - Hardware forwarding and the dynamic hazard detection unit are scheduled for Phase 3.

---

## 2. Unresolved Behavior and Phase 2 Policies

### 2.1 Misaligned Memory Access
- **Policy:** The Phase 2 `load_store_unit` operates on natural alignment.
  - Word access (`LW`, `SW`): Address bits `addr[1:0]` must be `2'b00`. The hardware drives byte enables `be = 4'b1111` and aligns data to `addr[31:2]`.
  - Halfword access (`LH`, `LHU`, `SH`): `addr[0]` must be `1'b0`. Byte enables are `4'b0011` (for `addr[1] == 0`) or `4'b1100` (for `addr[1] == 1`).
  - Byte access (`LB`, `LBU`, `SB`): Byte enables activate exactly one lane corresponding to `addr[1:0]`.
- **Limitation:** Misaligned access does not raise a trap or exception in Phase 2, because privileged exception/CSR architecture is not implemented. Accesses with misaligned address bits mask lower bits or steer to lane offsets.

### 2.2 Illegal Instructions
- **Policy:** The `instruction_decoder` verifies opcode, funct3, and funct7 against valid RV32I encodings.
- If an illegal encoding is encountered, `illegal_o` is asserted.
- The `control_unit` treats illegal instructions as no-ops: all write enables (`reg_write_o`, `mem_write_o`, `mem_read_o`, `branch_o`, `jump_o`) are deasserted to prevent any architectural side effects.
- **Limitation:** No trap or exception vector is entered; the CPU silently completes the cycle without modifying registers or memory.

### 2.3 System Instructions (ECALL, EBREAK, FENCE)
- **ECALL & EBREAK:** Decoded distinctly by `instruction_decoder` and flagged to the control/pipeline interface. In Phase 2, they do not trigger architectural trap handling. In simulation testbenches, the signals may be used as test breakpoints or program termination indicators.
- **FENCE / FENCE.I:** In this in-order, single-issue core with non-overlapping Harvard instruction and data ports and no cache/write-buffer hierarchy, `FENCE` is treated as a benign NOP.

### 2.4 Stall and Flush Priority Hierarchy
The pipeline control hierarchy is strictly defined as follows:
```
Reset (rst_ni = 0)
  > Redirect / Flush (Branch taken / Jump in EX)
    > Hold / Stall (Data bus transaction wait: req & !ready)
      > Normal Pipeline Advancement
```
- A bus stall caused by an in-flight load or store holds all upstream pipeline stages (`PC`, `IF/ID`, `ID/EX`, `EX/MEM`) until `ready_i` is returned.
- Flushed instructions clear `valid_o` to `1'b0` and zero out write-enable control signals, preventing spurious state updates.
