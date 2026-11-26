// ============================================================================
// File: instruction_memory_model.sv
// Project: RV32I RISC-V SoC (Phase 2 - Simulation Testbench Model)
// Description: Behavioral simulation-only model for Instruction Memory.
//              - Dedicated instruction fetch port.
//              - Models 1-cycle synchronous read latency.
//              - Byte-addressable storage with little-endian 32-bit word output.
//              - Supports loading hex program files via task or parameter.
// ============================================================================

`timescale 1ns / 1ps

module instruction_memory_model #(
    parameter int MEM_SIZE_BYTES = 65536,
    parameter     INIT_HEX_FILE  = ""
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        req_i,
    input  logic [31:0] addr_i,
    output logic [31:0] rdata_o,
    output logic        ready_o,
    output logic        error_o
);

    // Byte array storage
    logic [7:0] mem [0:MEM_SIZE_BYTES-1];

    // Initialize memory to RV32I NOP instructions (0x00000013)
    integer i;
    initial begin
        for (i = 0; i < MEM_SIZE_BYTES; i = i + 4) begin
            mem[i]   = 8'h13;
            mem[i+1] = 8'h00;
            mem[i+2] = 8'h00;
            mem[i+3] = 8'h00;
        end
        if (INIT_HEX_FILE != "") begin
            $readmemh(INIT_HEX_FILE, mem);
        end
    end

    // Task to write instructions dynamically from testbench
    task automatic write_word(input [31:0] byte_addr, input [31:0] data);
        if (byte_addr + 3 < MEM_SIZE_BYTES) begin
            mem[byte_addr]     = data[7:0];
            mem[byte_addr + 1] = data[15:8];
            mem[byte_addr + 2] = data[23:16];
            mem[byte_addr + 3] = data[31:24];
        end
    endtask

    // Synchronous 1-cycle read latency
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            rdata_o <= 32'h0000_0013; // Return NOP on reset
            ready_o <= 1'b0;
            error_o <= 1'b0;
        end else if (req_i) begin
            ready_o <= 1'b1;
            if (addr_i + 3 < MEM_SIZE_BYTES) begin
                error_o <= 1'b0;
                // Little-endian word assembly
                rdata_o <= {mem[addr_i + 3], mem[addr_i + 2], mem[addr_i + 1], mem[addr_i]};
            end else begin
                error_o <= 1'b1;
                rdata_o <= 32'h0000_0000;
            end
        end else begin
            ready_o <= 1'b0;
            error_o <= 1'b0;
        end
    end

endmodule
