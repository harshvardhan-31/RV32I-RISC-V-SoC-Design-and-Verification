// ============================================================================
// File: pc_unit.sv
// Project: RV32I RISC-V SoC (Phase 2/Phase 3 - CPU Core)
// Description: Program Counter unit for Instruction Fetch (IF) stage.
//              Handles reset vector, sequential PC increment (+4), branch/jump
//              redirection, and pipeline stall hold.
//              Priority: stall_i holds PC to preserve state during bus wait states;
//              redirect_i takes effect as soon as pipeline stall clears.
// ============================================================================

`timescale 1ns / 1ps

module pc_unit #(
    parameter [31:0] RESET_VECTOR = 32'h0000_0000
) (
    input  logic        clk_i,          // Rising-edge system clock
    input  logic        rst_ni,         // Synchronous active-low reset
    input  logic        stall_i,        // Pipeline stall (hold PC)
    input  logic        redirect_i,     // Redirection request from EX stage (branch/jump)
    input  logic [31:0] redirect_pc_i,  // Target PC for redirection
    output logic [31:0] pc_o,           // Current Program Counter
    output logic [31:0] pc_plus4_o,     // Next sequential PC (PC + 4)
    output logic        imem_req_o,     // Instruction memory fetch request
    output logic [31:0] imem_addr_o     // Instruction memory fetch address
);

    logic [31:0] pc_q;
    logic [31:0] next_pc;

    // Combinational calculation of sequential next PC
    assign pc_plus4_o = pc_q + 32'd4;

    // Next PC selection logic with priority:
    // When pipeline is stalled (e.g. LSU busy waiting for memory), PC must hold.
    // Redirection executes as soon as the stall clears.
    always_comb begin
        if (stall_i) begin
            next_pc = pc_q;
        end else if (redirect_i) begin
            next_pc = redirect_pc_i;
        end else begin
            next_pc = pc_plus4_o;
        end
    end

    // Sequential PC register update
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            pc_q <= RESET_VECTOR;
        end else begin
            pc_q <= next_pc;
        end
    end

    // Outputs driven to core and instruction memory
    assign pc_o        = pc_q;
    assign imem_addr_o = pc_q;
    assign imem_req_o  = rst_ni; // Fetch request active when not in reset

endmodule
