// ============================================================================
// File: data_memory.sv
// Project: RV32I RISC-V SoC (Phase 4 — Memory Subsystem and Peripheral Integration)
// Description: Synthesizable 64 KiB Data RAM with byte-enable lane steering
//              for byte, halfword, and word transactions. Supports single-cycle
//              synchronous reads and writes over the custom SoC bus.
//
// Memory Map:  0x1000_0000 - 0x1000_FFFF (64 KiB, 16384 x 32-bit words)
// ============================================================================

`timescale 1ns / 1ps

module data_memory #(
    parameter [31:0] BASE_ADDR      = 32'h1000_0000,
    parameter int    MEM_SIZE_BYTES = 65536,
    parameter        INIT_FILE      = ""
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    // Bus Slave Interface
    input  logic        req_i,
    input  logic [31:0] addr_i,
    input  logic        we_i,
    input  logic [31:0] wdata_i,
    input  logic [3:0]  be_i,
    output logic [31:0] rdata_o,
    output logic        ready_o,
    output logic        error_o
);

    localparam int NUM_WORDS = MEM_SIZE_BYTES / 4;

    // 4 x 8-bit memory arrays (byte lanes) for synthesizable byte-masked RAM
    logic [7:0] mem_b0 [0:NUM_WORDS-1];
    logic [7:0] mem_b1 [0:NUM_WORDS-1];
    logic [7:0] mem_b2 [0:NUM_WORDS-1];
    logic [7:0] mem_b3 [0:NUM_WORDS-1];

    // Optional preloading from file
    initial begin
        if (INIT_FILE != "") begin
            // If initialized as 32-bit words:
            logic [31:0] temp_mem [0:NUM_WORDS-1];
            $readmemh(INIT_FILE, temp_mem);
            for (int i = 0; i < NUM_WORDS; i++) begin
                mem_b0[i] = temp_mem[i][7:0];
                mem_b1[i] = temp_mem[i][15:8];
                mem_b2[i] = temp_mem[i][23:16];
                mem_b3[i] = temp_mem[i][31:24];
            end
        end
    end

    // Address decoding & alignment checks
    logic [31:0] addr_offset;
    logic        addr_in_range;
    logic        addr_misaligned;
    logic [13:0] word_idx;

    assign addr_offset     = addr_i - BASE_ADDR;
    assign addr_in_range   = (addr_i >= BASE_ADDR) && (addr_offset < MEM_SIZE_BYTES);
    assign addr_misaligned = (addr_i[1:0] != 2'b00);
    assign word_idx        = addr_offset[15:2];

    // Synchronous memory access
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            ready_o <= 1'b0;
            error_o <= 1'b0;
            rdata_o <= 32'h0000_0000;
        end else begin
            if (req_i) begin
                ready_o <= 1'b1;
                if (addr_in_range && !addr_misaligned) begin
                    error_o <= 1'b0;
                    if (we_i) begin
                        // Byte-lane masked writes
                        if (be_i[0]) mem_b0[word_idx] <= wdata_i[7:0];
                        if (be_i[1]) mem_b1[word_idx] <= wdata_i[15:8];
                        if (be_i[2]) mem_b2[word_idx] <= wdata_i[23:16];
                        if (be_i[3]) mem_b3[word_idx] <= wdata_i[31:24];
                        rdata_o <= 32'h0000_0000;
                    end else begin
                        // Synchronous word read (little-endian assembly)
                        rdata_o <= {mem_b3[word_idx], mem_b2[word_idx], mem_b1[word_idx], mem_b0[word_idx]};
                    end
                end else begin
                    // Out-of-bounds or misaligned address
                    rdata_o <= 32'h0000_0000;
                    error_o <= 1'b1;
                end
            end else begin
                ready_o <= 1'b0;
                error_o <= 1'b0;
            end
        end
    end

endmodule
