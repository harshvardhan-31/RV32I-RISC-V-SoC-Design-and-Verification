// ============================================================================
// File: tb_load_store_unit.sv
// Project: RV32I RISC-V SoC (Phase 2 - Unit Verification)
// Description: Self-checking testbench for load_store_unit.sv.
//              Verifies:
//              - Load operations (LB, LH, LW, LBU, LHU) with sign/zero extension
//              - Store operations (SB, SH, SW) with byte enables and data steering
//              - Bus handshake, busy stalling on wait cycles, and error handling.
// ============================================================================

`timescale 1ns / 1ps

module tb_load_store_unit;

    logic        clk;
    logic        rst_n;
    logic        valid;
    logic        mem_read;
    logic        mem_write;
    logic [2:0]  funct3;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [31:0] load_data;
    logic        busy;
    logic        error;

    // Bus signals
    logic        dmem_req;
    logic [31:0] dmem_addr;
    logic        dmem_we;
    logic [31:0] dmem_wdata;
    logic [3:0]  dmem_be;
    logic        dmem_ready;
    logic [31:0] dmem_rdata;
    logic        dmem_error;

    load_store_unit dut (
        .clk_i       (clk),
        .rst_ni      (rst_n),
        .valid_i     (valid),
        .mem_read_i  (mem_read),
        .mem_write_i (mem_write),
        .funct3_i    (funct3),
        .addr_i      (addr),
        .wdata_i     (wdata),
        .load_data_o (load_data),
        .busy_o      (busy),
        .error_o     (error),

        .dmem_req_o  (dmem_req),
        .dmem_addr_o (dmem_addr),
        .dmem_we_o   (dmem_we),
        .dmem_wdata_o(dmem_wdata),
        .dmem_be_o   (dmem_be),
        .dmem_ready_i(dmem_ready),
        .dmem_rdata_i(dmem_rdata),
        .dmem_error_i(dmem_error)
    );

    always #5 clk = ~clk;

    int test_count = 0;

    initial begin
        clk = 0; rst_n = 0; valid = 0; mem_read = 0; mem_write = 0;
        funct3 = 0; addr = 0; wdata = 0;
        dmem_ready = 1; dmem_rdata = 0; dmem_error = 0;

        $display("=== Starting tb_load_store_unit Verification ===");

        @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // 1. Store Word (SW): addr = 0x1000_0000, wdata = 0xA1B2C3D4
        valid = 1; mem_write = 1; mem_read = 0; funct3 = 3'b010;
        addr = 32'h1000_0000; wdata = 32'hA1B2C3D4;
        #1;
        if (dmem_req !== 1 || dmem_we !== 1 || dmem_be !== 4'b1111 || dmem_wdata !== 32'hA1B2C3D4 || dmem_addr !== 32'h1000_0000) begin
            $fatal(1, "SW bus request mismatch!");
        end
        test_count++;

        // 2. Store Halfword (SH) at offset 2: addr = 0x1000_0002, wdata = 0x5678
        addr = 32'h1000_0002; funct3 = 3'b001; wdata = 32'h0000_5678;
        #1;
        if (dmem_be !== 4'b1100 || dmem_wdata !== 32'h5678_5678) begin
            $fatal(1, "SH offset 2 byte enable mismatch!");
        end
        test_count++;

        // 3. Store Byte (SB) at offset 3: addr = 0x1000_0003, wdata = 0xFF
        addr = 32'h1000_0003; funct3 = 3'b000; wdata = 32'h0000_00FF;
        #1;
        if (dmem_be !== 4'b1000 || dmem_wdata !== 32'hFFFF_FFFF) begin
            $fatal(1, "SB offset 3 byte enable mismatch!");
        end
        test_count++;

        // 4. Load Word (LW): rdata = 0x89ABCDEF
        mem_write = 0; mem_read = 1; funct3 = 3'b010; addr = 32'h1000_0000;
        dmem_rdata = 32'h89ABCDEF;
        #1;
        if (load_data !== 32'h89ABCDEF) $fatal(1, "LW read data mismatch!");
        test_count++;

        // 5. Load Byte Signed (LB) at offset 0 (0xEF is negative: -17)
        funct3 = 3'b000; addr = 32'h1000_0000;
        #1;
        if (load_data !== 32'hFFFF_FFEF) $fatal(1, "LB sign extension mismatch: got 0x%08h", load_data);
        test_count++;

        // 6. Load Byte Unsigned (LBU) at offset 0
        funct3 = 3'b100; addr = 32'h1000_0000;
        #1;
        if (load_data !== 32'h0000_00EF) $fatal(1, "LBU zero extension mismatch: got 0x%08h", load_data);
        test_count++;

        // 7. Load Halfword Signed (LH) at offset 2 (0x89AB is negative)
        funct3 = 3'b001; addr = 32'h1000_0002;
        #1;
        if (load_data !== 32'hFFFF_89AB) $fatal(1, "LH sign extension mismatch: got 0x%08h", load_data);
        test_count++;

        // 8. Load Halfword Unsigned (LHU) at offset 2
        funct3 = 3'b101; addr = 32'h1000_0002;
        #1;
        if (load_data !== 32'h0000_89AB) $fatal(1, "LHU zero extension mismatch: got 0x%08h", load_data);
        test_count++;

        // 9. Busy wait state test: dmem_ready is 0 -> busy_o must be 1
        dmem_ready = 0;
        #1;
        if (busy !== 1'b1) $fatal(1, "LSU busy signal not asserted when waiting for ready!");
        test_count++;

        // Ready asserted -> busy drops
        dmem_ready = 1;
        #1;
        if (busy !== 1'b0) $fatal(1, "LSU busy signal did not deassert when ready arrived!");
        test_count++;

        // 10. Error response
        dmem_error = 1;
        #1;
        if (error !== 1'b1) $fatal(1, "LSU error signal did not propagate!");
        test_count++;

        $display("=== tb_load_store_unit PASSED: All %0d checks passed ===", test_count);
        $finish;
    end

endmodule
