// ============================================================================
// File: hazard_unit.sv
// Project: RV32I RISC-V SoC (Phase 3 — Hazard Detection and Forwarding)
// Description: Hazard Detection Unit for the five-stage RV32I pipeline.
//
//   Responsibilities:
//   1. Load-use hazard detection: Detects when an instruction in ID needs
//      a register value that is currently being loaded from memory in EX.
//      Inserts exactly one bubble into ID/EX and holds PC and IF/ID.
//   2. Control hazard handling: On a taken branch or jump resolved in EX,
//      asserts flush of IF/ID and ID/EX to remove wrong-path instructions.
//   3. Bus wait-state interaction: When LSU is busy, stalls the entire
//      pipeline. A pending redirect is preserved and applied only after the
//      outstanding memory transaction completes.
//
//   Stall/Flush Priority (highest to lowest):
//     1. Reset (handled by pipeline register reset logic)
//     2. Bus wait stall  (lsu_busy) — holds all stages including MEM
//     3. Load-use stall  — holds PC and IF/ID; inserts bubble into ID/EX
//     4. Control flush   — flush IF/ID and ID/EX when branch/jump resolves
//     5. Normal advance
//
//   NOTE: redirect_valid comes from the EX stage combinationally. When
//   lsu_busy is asserted (a MEM-stage transaction is waiting for ready),
//   the entire pipeline is frozen and no flush is applied — the redirect_valid
//   from a *younger* EX instruction cannot occur while MEM is stalled, because
//   EX does not contain a valid instruction during a stall cycle. This is safe
//   as long as the cpu_core stall_pipeline logic is correct.
// ============================================================================

`timescale 1ns / 1ps

module hazard_unit (
    // ---- IF/ID stage signals ------------------------------------------------
    input  logic        if_id_valid_i,   // Valid bit of IF/ID register
    input  logic [4:0]  if_id_rs1_i,     // rs1 field of instruction in IF/ID
    input  logic [4:0]  if_id_rs2_i,     // rs2 field of instruction in IF/ID
    input  logic        if_id_rs1_used_i,// rs1 is actually read by this instruction
    input  logic        if_id_rs2_used_i,// rs2 is actually read by this instruction

    // ---- ID/EX stage signals ------------------------------------------------
    input  logic        id_ex_valid_i,   // Valid bit of ID/EX register
    input  logic [4:0]  id_ex_rd_i,      // Destination register in ID/EX
    input  logic        id_ex_mem_read_i,// ID/EX instruction is a load

    // ---- EX stage redirect signals ------------------------------------------
    input  logic        redirect_valid_i, // Branch/jump taken redirect from EX
    input  logic        lsu_busy_i,       // LSU busy: data bus not ready

    // ---- Pipeline control outputs -------------------------------------------
    output logic        stall_if_o,      // Hold PC (prevent PC from advancing)
    output logic        stall_id_o,      // Hold IF/ID register
    output logic        bubble_id_ex_o,  // Insert bubble (flush) into ID/EX
    output logic        flush_if_id_o    // Flush IF/ID register (control hazard)
);

    // ========================================================================
    // Load-Use Hazard Detection
    // ========================================================================
    // Triggered when:
    //  - ID/EX contains a valid load instruction
    //  - Destination register is not x0
    //  - The instruction currently in IF/ID (about to enter EX) uses that reg
    logic load_use_hazard;

    assign load_use_hazard =
        id_ex_valid_i &&
        id_ex_mem_read_i &&
        (id_ex_rd_i != 5'd0) &&
        if_id_valid_i &&
        (
            (if_id_rs1_used_i && (if_id_rs1_i == id_ex_rd_i)) ||
            (if_id_rs2_used_i && (if_id_rs2_i == id_ex_rd_i))
        );

    // ========================================================================
    // Pipeline Control Signal Generation
    // Priority: lsu_busy > load_use_hazard > redirect_valid > normal
    // ========================================================================
    always_comb begin
        // Defaults: no stall, no flush
        stall_if_o      = 1'b0;
        stall_id_o      = 1'b0;
        bubble_id_ex_o  = 1'b0;
        flush_if_id_o   = 1'b0;

        if (lsu_busy_i) begin
            // Bus wait: freeze the entire pipeline.
            // PC, IF/ID, ID/EX, EX/MEM are all stalled by cpu_core stall_pipeline.
            // No flush or bubble is generated here — handled via stall_pipeline in cpu_core.
            stall_if_o     = 1'b1;
            stall_id_o     = 1'b1;
            bubble_id_ex_o = 1'b0;
            flush_if_id_o  = 1'b0;
        end else if (load_use_hazard) begin
            // Load-use hazard: hold PC and IF/ID; insert bubble into ID/EX.
            // Redirect detection does not happen simultaneously (the EX stage
            // holds the load, not a branch/jump).
            stall_if_o     = 1'b1;
            stall_id_o     = 1'b1;
            bubble_id_ex_o = 1'b1;
            flush_if_id_o  = 1'b0;
        end else if (redirect_valid_i) begin
            // Control hazard: taken branch or jump resolved in EX.
            // Flush IF/ID (wrong-path fetch) and ID/EX (wrong-path decode).
            stall_if_o     = 1'b0;
            stall_id_o     = 1'b0;
            bubble_id_ex_o = 1'b1;  // flush ID/EX via bubble_id_ex
            flush_if_id_o  = 1'b1;
        end
    end

endmodule
