// ============================================================================
// File: forwarding_unit.sv
// Project: RV32I RISC-V SoC (Phase 3 — Hazard Detection and Forwarding)
// Description: Data Forwarding Unit for the five-stage RV32I pipeline.
//
//   The forwarding unit resolves Read-After-Write (RAW) data hazards by
//   selecting the most recent valid producer of a register value and feeding
//   it directly to the EX stage operands, bypassing the register file.
//
//   Forwarding paths supported:
//   1. EX/MEM → EX  (Priority 1 — newest, 1-cycle-old result)
//   2. MEM/WB → EX  (Priority 2 — 2-cycle-old result or loaded data)
//   3. Register File (Priority 3 — default, no hazard)
//
//   Forwarding select encoding:
//   fwd_sel_a_o / fwd_sel_b_o:
//     2'b00  = Register file (no forwarding)
//     2'b10  = Forward from EX/MEM stage
//     2'b01  = Forward from MEM/WB stage
//
//   Rules enforced:
//   - Never forward when the producer rd = x0.
//   - Never forward when the producer reg_write = 0.
//   - Never forward from an invalid pipeline entry.
//   - EX/MEM has priority over MEM/WB for the same destination register.
//   - Store data (rs2) also uses the forwarding network.
//   - Branch operands (rs1 and rs2) also use the forwarding network.
//   - JALR base (rs1) uses the forwarding network.
// ============================================================================

`timescale 1ns / 1ps

module forwarding_unit (
    // ---- EX stage source registers (from ID/EX) ----------------------------
    input  logic [4:0]  ex_rs1_addr_i,   // Source register 1 address in EX
    input  logic [4:0]  ex_rs2_addr_i,   // Source register 2 address in EX

    // ---- EX/MEM pipeline register (potential producer) ---------------------
    input  logic        ex_mem_valid_i,       // EX/MEM register contains valid instr
    input  logic [4:0]  ex_mem_rd_addr_i,     // Destination register in EX/MEM
    input  logic        ex_mem_reg_write_i,   // EX/MEM instruction writes a register
    input  logic        ex_mem_mem_read_i,    // EX/MEM instruction is a load
                                              // (load result NOT yet available as fwd)

    // ---- MEM/WB pipeline register (potential producer) ---------------------
    input  logic        mem_wb_valid_i,       // MEM/WB register contains valid instr
    input  logic [4:0]  mem_wb_rd_addr_i,     // Destination register in MEM/WB
    input  logic        mem_wb_reg_write_i,   // MEM/WB instruction writes a register

    // ---- Forwarding select outputs -----------------------------------------
    output logic [1:0]  fwd_sel_a_o,  // Operand A (rs1) forwarding select
    output logic [1:0]  fwd_sel_b_o   // Operand B (rs2) forwarding select
);

    // Forwarding select encoding
    localparam [1:0] FWD_REG   = 2'b00; // Use register file value
    localparam [1:0] FWD_EXMEM = 2'b10; // Forward from EX/MEM
    localparam [1:0] FWD_MEMWB = 2'b01; // Forward from MEM/WB

    // ========================================================================
    // Operand A (rs1) forwarding selection
    // ========================================================================
    always_comb begin
        fwd_sel_a_o = FWD_REG; // Default: use register file

        // Priority 1: EX/MEM → EX forwarding for rs1
        // Condition: EX/MEM contains a valid instruction that writes rd,
        //            rd != x0, and rd matches the EX stage rs1 source.
        // Note: We do NOT forward a load result from EX/MEM because the
        //       load data is not available until after MEM completes.
        //       The load-use hazard is handled by hazard_unit (stall+bubble).
        //       After the stall, the value arrives in MEM/WB and is forwarded.
        if (ex_mem_valid_i &&
            ex_mem_reg_write_i &&
            (ex_mem_rd_addr_i != 5'd0) &&
            !ex_mem_mem_read_i &&
            (ex_mem_rd_addr_i == ex_rs1_addr_i)) begin
            fwd_sel_a_o = FWD_EXMEM;

        // Priority 2: MEM/WB → EX forwarding for rs1
        end else if (mem_wb_valid_i &&
                     mem_wb_reg_write_i &&
                     (mem_wb_rd_addr_i != 5'd0) &&
                     (mem_wb_rd_addr_i == ex_rs1_addr_i)) begin
            fwd_sel_a_o = FWD_MEMWB;
        end
    end

    // ========================================================================
    // Operand B (rs2) forwarding selection
    // ========================================================================
    always_comb begin
        fwd_sel_b_o = FWD_REG; // Default: use register file

        // Priority 1: EX/MEM → EX forwarding for rs2
        if (ex_mem_valid_i &&
            ex_mem_reg_write_i &&
            (ex_mem_rd_addr_i != 5'd0) &&
            !ex_mem_mem_read_i &&
            (ex_mem_rd_addr_i == ex_rs2_addr_i)) begin
            fwd_sel_b_o = FWD_EXMEM;

        // Priority 2: MEM/WB → EX forwarding for rs2
        end else if (mem_wb_valid_i &&
                     mem_wb_reg_write_i &&
                     (mem_wb_rd_addr_i != 5'd0) &&
                     (mem_wb_rd_addr_i == ex_rs2_addr_i)) begin
            fwd_sel_b_o = FWD_MEMWB;
        end
    end

endmodule
