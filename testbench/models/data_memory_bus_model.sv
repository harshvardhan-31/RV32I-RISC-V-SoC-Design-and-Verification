// ============================================================================
// File: data_memory_bus_model.sv
// Project: RV32I RISC-V SoC (Phase 2/Phase 3 - Simulation Testbench Model)
// Description: Behavioral simulation-only model for Data Memory Bus Slave.
//              - Conforms to proposed single-outstanding-transaction protocol.
//              - Byte-addressable storage with byte-enable lane steering.
//              - Supports configurable wait states (wait cycles).
//              - Flags unmapped addresses with ready + error.
// ============================================================================

`timescale 1ns / 1ps

module data_memory_bus_model #(
    parameter [31:0] BASE_ADDR      = 32'h1000_0000,
    parameter int    MEM_SIZE_BYTES = 65536,
    parameter int    WAIT_CYCLES    = 0
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

    // Byte array storage
    logic [7:0] mem [0:MEM_SIZE_BYTES-1];

    // Configurable wait cycles (defaults to parameter WAIT_CYCLES, can be overridden dynamically)
    int wait_cycles_cfg = WAIT_CYCLES;

    // Initialize data memory to zero
    integer i;
    initial begin
        for (i = 0; i < MEM_SIZE_BYTES; i = i + 1) begin
            mem[i] = 8'h00;
        end
    end

    // Task to read word directly for verification in testbench
    task automatic read_word_direct(input [31:0] byte_addr, output [31:0] data);
        logic [31:0] offset;
        offset = byte_addr - BASE_ADDR;
        if (offset + 3 < MEM_SIZE_BYTES) begin
            data = {mem[offset + 3], mem[offset + 2], mem[offset + 1], mem[offset]};
        end else begin
            data = 32'hDEAD_BEEF;
        end
    endtask

    // Task to write word directly from testbench
    task automatic write_word_direct(input [31:0] byte_addr, input [31:0] data);
        logic [31:0] offset;
        offset = byte_addr - BASE_ADDR;
        if (offset + 3 < MEM_SIZE_BYTES) begin
            mem[offset]     = data[7:0];
            mem[offset + 1] = data[15:8];
            mem[offset + 2] = data[23:16];
            mem[offset + 3] = data[31:24];
        end
    endtask

    // Wait states counter
    integer wait_count;
    logic in_transaction;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            ready_o        <= 1'b0;
            error_o        <= 1'b0;
            rdata_o        <= 32'h0000_0000;
            wait_count     <= 0;
            in_transaction <= 1'b0;
        end else begin
            if (req_i) begin
                if (!in_transaction) begin
                    in_transaction <= 1'b1;
                    wait_count     <= 0;
                end else begin
                    wait_count <= wait_count + 1;
                end

                if (wait_count >= wait_cycles_cfg) begin
                    ready_o <= 1'b1;

                    // Address validation
                    if ((addr_i >= BASE_ADDR) && (addr_i + 3 < BASE_ADDR + MEM_SIZE_BYTES)) begin
                        logic [31:0] offset;
                        offset = addr_i - BASE_ADDR;
                        error_o <= 1'b0;

                        if (we_i) begin
                            // Write with byte enables
                            if (be_i[0]) mem[offset]     <= wdata_i[7:0];
                            if (be_i[1]) mem[offset + 1] <= wdata_i[15:8];
                            if (be_i[2]) mem[offset + 2] <= wdata_i[23:16];
                            if (be_i[3]) mem[offset + 3] <= wdata_i[31:24];
                        end else begin
                            // Read full 32-bit word little-endian
                            rdata_o <= {mem[offset + 3], mem[offset + 2], mem[offset + 1], mem[offset]};
                        end
                    end else begin
                        // Unmapped or out-of-bounds access
                        error_o <= 1'b1;
                        rdata_o <= 32'h0000_0000;
                    end
                end else begin
                    ready_o <= 1'b0;
                    error_o <= 1'b0;
                end
            end else begin
                ready_o        <= 1'b0;
                error_o        <= 1'b0;
                in_transaction <= 1'b0;
                wait_count     <= 0;
            end
        end
    end

endmodule
