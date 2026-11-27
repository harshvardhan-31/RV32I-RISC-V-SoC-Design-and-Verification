// =============================================================================
// File: tb_data_memory.sv
// Project: RV32I RISC-V SoC (Phase 4 - Memory Subsystem)
// Description: Self-checking unit testbench for data_memory.sv.
//              Verifies 64 KiB byte-masked operations (byte, halfword, word writes
//              and reads), byte enable control, alignment and bounds checks.
// =============================================================================

`timescale 1ns / 1ps

module tb_data_memory;

    logic        clk;
    logic        rst_n;
    logic        valid;
    logic        we;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [3:0]  be;
    logic        ready;
    logic [31:0] rdata;
    logic        error;

    always #5 clk = ~clk;

    data_memory #(
        .SIZE_BYTES (4096),
        .INIT_FILE  ("")
    ) dut (
        .clk_i   (clk),
        .rst_ni  (rst_n),
        .valid_i (valid),
        .we_i    (we),
        .addr_i  (addr),
        .wdata_i (wdata),
        .be_i    (be),
        .ready_o (ready),
        .rdata_o (rdata),
        .error_o (error)
    );

    int test_count  = 0;
    int error_count = 0;

    task do_write(input [31:0] w_addr, input [31:0] w_data, input [3:0] w_be, input string name);
        @(posedge clk);
        valid <= 1;
        we    <= 1;
        addr  <= w_addr;
        wdata <= w_data;
        be    <= w_be;
        @(posedge clk);
        valid <= 0;
        we    <= 0;
        test_count++;
        if (!ready || error) begin
            $display("[FAIL] %s: write failed, ready=%b, error=%b", name, ready, error);
            error_count++;
        end else begin
            $display("[PASS] %s: write successful", name);
        end
    endtask

    task do_read(input [31:0] r_addr, input [31:0] exp_data, input string name);
        @(posedge clk);
        valid <= 1;
        we    <= 0;
        addr  <= r_addr;
        be    <= 4'b1111;
        @(posedge clk);
        valid <= 0;
        test_count++;
        if (!ready || error || rdata !== exp_data) begin
            $display("[FAIL] %s: got ready=%b error=%b rdata=0x%08h, expected 0x%08h", name, ready, error, rdata, exp_data);
            error_count++;
        end else begin
            $display("[PASS] %s: read 0x%08h", name, rdata);
        end
    endtask

    initial begin
        $display("=================================================================");
        $display("Starting Unit Test: tb_data_memory");
        $display("=================================================================");

        clk   = 0;
        rst_n = 0;
        valid = 0;
        we    = 0;
        addr  = 32'h0;
        wdata = 32'h0;
        be    = 4'b0000;

        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Test 1: Full 32-bit Word write and read back
        do_write(32'h1000_0000, 32'hAABBCCDD, 4'b1111, "Write Word 0xAABBCCDD at 0x1000_0000");
        do_read (32'h1000_0000, 32'hAABBCCDD, "Read Word from 0x1000_0000");

        // Test 2: Byte 0 write to 0x1000_0000
        do_write(32'h1000_0000, 32'h0000_0011, 4'b0001, "Write Byte 0 (0x11) at 0x1000_0000");
        do_read (32'h1000_0000, 32'hAABBCC11, "Read Word after Byte 0 modification");

        // Test 3: Byte 2 write to 0x1000_0000
        do_write(32'h1000_0000, 32'h0022_0000, 4'b0100, "Write Byte 2 (0x22) at 0x1000_0000");
        do_read (32'h1000_0000, 32'hAA22CC11, "Read Word after Byte 2 modification");

        // Test 4: Halfword write to 0x1000_0002 (upper halfword: bytes 2 & 3)
        do_write(32'h1000_0000, 32'h3344_0000, 4'b1100, "Write Upper Halfword (0x3344) at 0x1000_0000");
        do_read (32'h1000_0000, 32'h3344CC11, "Read Word after Upper Halfword write");

        // Test 5: Out of bounds access (0x1000_1000 for 4 KiB size)
        @(posedge clk);
        valid <= 1;
        we    <= 0;
        addr  <= 32'h1000_1000;
        be    <= 4'b1111;
        @(posedge clk);
        valid <= 0;
        test_count++;
        if (ready && error) begin
            $display("[PASS] Out of bounds read correctly flagged error");
        end else begin
            $display("[FAIL] Out of bounds read failed to flag error: ready=%b, error=%b", ready, error);
            error_count++;
        end

        // Test 6: Misaligned word access (0x1000_0001)
        @(posedge clk);
        valid <= 1;
        we    <= 0;
        addr  <= 32'h1000_0001;
        be    <= 4'b1111;
        @(posedge clk);
        valid <= 0;
        test_count++;
        if (ready && error) begin
            $display("[PASS] Misaligned read correctly flagged error");
        end else begin
            $display("[FAIL] Misaligned read failed to flag error: ready=%b, error=%b", ready, error);
            error_count++;
        end

        // Summary
        $display("-----------------------------------------------------------------");
        $display("Test Summary: %0d Tests, %0d Failures", test_count, error_count);
        $display("-----------------------------------------------------------------");
        if (error_count > 0) $fatal(1, "tb_data_memory FAILED with %0d errors", error_count);
        $finish;
    end

endmodule
