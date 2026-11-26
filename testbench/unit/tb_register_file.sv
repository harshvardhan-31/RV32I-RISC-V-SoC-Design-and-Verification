// ============================================================================
// File: tb_register_file.sv
// Project: RV32I RISC-V SoC (Phase 2 - Unit Verification)
// Description: Self-checking testbench for register_file.sv.
//              Verifies reset initialization, writing and reading all registers
//              (x1 to x31), simultaneous dual-port reads, x0 hardwiring to zero,
//              write-to-x0 rejection, and write-enable deassertion.
// ============================================================================

`timescale 1ns / 1ps

module tb_register_file;

    logic        clk;
    logic        rst_n;
    logic [4:0]  rs1_addr;
    logic [4:0]  rs2_addr;
    logic        we;
    logic [4:0]  rd_addr;
    logic [31:0] rd_data;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;

    register_file dut (
        .clk_i     (clk),
        .rst_ni    (rst_n),
        .rs1_addr_i(rs1_addr),
        .rs2_addr_i(rs2_addr),
        .we_i      (we),
        .rd_addr_i (rd_addr),
        .rd_data_i (rd_data),
        .rs1_data_o(rs1_data),
        .rs2_data_o(rs2_data)
    );

    // Clock generation: 10ns period (100MHz)
    always #5 clk = ~clk;

    int test_count = 0;
    int error_count = 0;

    task check_ports(input [31:0] exp_rs1, input [31:0] exp_rs2, input string msg);
        test_count++;
        #1;
        if (rs1_data !== exp_rs1) begin
            $display("[ERROR] rs1_data mismatch at %s: got 0x%08h, expected 0x%08h", msg, rs1_data, exp_rs1);
            error_count++;
            $fatal(1, "Register file test failed on port 1: %s", msg);
        end
        if (rs2_data !== exp_rs2) begin
            $display("[ERROR] rs2_data mismatch at %s: got 0x%08h, expected 0x%08h", msg, rs2_data, exp_rs2);
            error_count++;
            $fatal(1, "Register file test failed on port 2: %s", msg);
        end
    endtask

    integer i;

    initial begin
        clk = 0;
        rst_n = 0;
        rs1_addr = 5'd0;
        rs2_addr = 5'd0;
        we = 0;
        rd_addr = 5'd0;
        rd_data = 32'd0;

        $display("=== Starting tb_register_file Verification ===");

        // Test 1: Reset behavior
        @(posedge clk);
        @(posedge clk);
        #1;
        for (i = 0; i < 32; i = i + 1) begin
            rs1_addr = i[4:0];
            rs2_addr = i[4:0];
            check_ports(32'h0000_0000, 32'h0000_0000, "Reset state verification");
        end

        // Release reset
        rst_n = 1;
        @(posedge clk);

        // Test 2: Write then read every register x1 to x31
        for (i = 1; i < 32; i = i + 1) begin
            @(posedge clk);
            we      = 1'b1;
            rd_addr = i[4:0];
            rd_data = 32'hA000_0000 + i;
        end

        @(posedge clk);
        we = 1'b0; // Deassert write enable

        // Read back each register on both ports
        for (i = 1; i < 32; i = i + 1) begin
            rs1_addr = i[4:0];
            rs2_addr = i[4:0];
            check_ports(32'hA000_0000 + i, 32'hA000_0000 + i, "Read back x1..x31");
        end

        // Test 3: Simultaneous reads of different registers on rs1 and rs2
        rs1_addr = 5'd5;
        rs2_addr = 5'd10;
        check_ports(32'hA000_0005, 32'hA000_000A, "Simultaneous different register read");

        // Test 4: Write to x0 must be ignored and x0 must always read zero
        @(posedge clk);
        we      = 1'b1;
        rd_addr = 5'd0;
        rd_data = 32'hDEAD_BEEF;

        @(posedge clk);
        we = 1'b0;
        rs1_addr = 5'd0;
        rs2_addr = 5'd0;
        check_ports(32'h0000_0000, 32'h0000_0000, "x0 write ignored and read 0");

        // Test 5: we = 0 must not modify register contents
        @(posedge clk);
        we      = 1'b0;
        rd_addr = 5'd7;
        rd_data = 32'h1122_3344;

        @(posedge clk);
        rs1_addr = 5'd7;
        rs2_addr = 5'd7;
        check_ports(32'hA000_0007, 32'hA000_0007, "we=0 does not corrupt data");

        // Test 6: Same-cycle write and read of same register
        // Write to x15; combinational read sees old value in cycle, updated next cycle
        @(posedge clk);
        we      = 1'b1;
        rd_addr = 5'd15;
        rd_data = 32'hCAFE_BABE;
        rs1_addr = 5'd15;
        #1;
        check_ports(32'hA000_000F, 32'h0000_0000, "Same cycle read gets registered value before posedge");

        @(posedge clk);
        we = 1'b0;
        #1;
        check_ports(32'hCAFE_BABE, 32'h0000_0000, "Read reflects updated value after posedge");

        $display("=== tb_register_file PASSED: All %0d checks passed successfully ===", test_count);
        $finish;
    end

endmodule
