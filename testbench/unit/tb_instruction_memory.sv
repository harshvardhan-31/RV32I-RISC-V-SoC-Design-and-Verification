// =============================================================================
// File: tb_instruction_memory.sv
// Project: RV32I RISC-V SoC (Phase 4 - Memory Subsystem)
// Description: Self-checking unit testbench for instruction_memory.sv.
//              Verifies reset behavior, 1-cycle synchronous read latency,
//              word alignment check, boundary bounds checking, and data loading.
// =============================================================================

`timescale 1ns / 1ps

module tb_instruction_memory;

    logic        clk;
    logic        rst_n;
    logic        req;
    logic [31:0] addr;
    logic        ready;
    logic [31:0] rdata;
    logic        error;

    // 100 MHz clock (10 ns period)
    always #5 clk = ~clk;

    instruction_memory #(
        .SIZE_BYTES (4096),
        .INIT_FILE  ("")
    ) dut (
        .clk_i   (clk),
        .rst_ni  (rst_n),
        .req_i   (req),
        .addr_i  (addr),
        .ready_o (ready),
        .rdata_o (rdata),
        .error_o (error)
    );

    int test_count  = 0;
    int error_count = 0;

    task check(input logic exp_ready, input logic exp_error, input logic [31:0] exp_rdata, input string test_name);
        test_count++;
        if (ready !== exp_ready || error !== exp_error || (exp_ready && !exp_error && rdata !== exp_rdata)) begin
            $display("[FAIL] %s: got ready=%b, error=%b, rdata=0x%08h; expected ready=%b, error=%b, rdata=0x%08h",
                     test_name, ready, error, rdata, exp_ready, exp_error, exp_rdata);
            error_count++;
        end else begin
            $display("[PASS] %s: ready=%b, error=%b, rdata=0x%08h", test_name, ready, error, rdata);
        end
    endtask

    initial begin
        $display("=================================================================");
        $display("Starting Unit Test: tb_instruction_memory");
        $display("=================================================================");

        clk   = 0;
        rst_n = 0;
        req   = 0;
        addr  = 32'h0;

        // Preload memory directly for test verification
        dut.mem[0] = 32'h00500093; // addi x1, x0, 5
        dut.mem[1] = 32'h00A00113; // addi x2, x0, 10
        dut.mem[2] = 32'h002081B3; // add  x3, x1, x2
        dut.mem[1023] = 32'hDEADBEEF;

        // Reset check
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Test 1: Idle state
        test_count++;
        if (ready !== 0 || error !== 0) begin
            $display("[FAIL] Idle state: ready or error asserted unexpectedly");
            error_count++;
        end else begin
            $display("[PASS] Idle state: ready=0, error=0");
        end

        // Test 2: Synchronous read word at 0x0000_0000 (1-cycle latency)
        @(posedge clk);
        req  <= 1;
        addr <= 32'h0000_0000;
        @(posedge clk);
        req  <= 0;
        check(1'b1, 1'b0, 32'h00500093, "Read Word at 0x0000_0000");

        // Test 3: Read word at 0x0000_0004
        @(posedge clk);
        req  <= 1;
        addr <= 32'h0000_0004;
        @(posedge clk);
        req  <= 0;
        check(1'b1, 1'b0, 32'h00A00113, "Read Word at 0x0000_0004");

        // Test 4: Read word at 0x0000_0008
        @(posedge clk);
        req  <= 1;
        addr <= 32'h0000_0008;
        @(posedge clk);
        req  <= 0;
        check(1'b1, 1'b0, 32'h002081B3, "Read Word at 0x0000_0008");

        // Test 5: Boundary read at top of 4 KiB memory (0x0000_0FFC)
        @(posedge clk);
        req  <= 1;
        addr <= 32'h0000_0FFC;
        @(posedge clk);
        req  <= 0;
        check(1'b1, 1'b0, 32'hDEADBEEF, "Read Word at 0x0000_0FFC (Top boundary)");

        // Test 6: Out-of-bounds read (0x0000_1000)
        @(posedge clk);
        req  <= 1;
        addr <= 32'h0000_1000;
        @(posedge clk);
        req  <= 0;
        check(1'b1, 1'b1, 32'h0000_0000, "Out-of-bounds Address 0x0000_1000 Error Response");

        // Test 7: Misaligned address read (0x0000_0002)
        @(posedge clk);
        req  <= 1;
        addr <= 32'h0000_0002;
        @(posedge clk);
        req  <= 0;
        check(1'b1, 1'b1, 32'h0000_0000, "Misaligned Address 0x0000_0002 Error Response");

        // Summary
        $display("-----------------------------------------------------------------");
        $display("Test Summary: %0d Tests, %0d Failures", test_count, error_count);
        $display("-----------------------------------------------------------------");
        if (error_count > 0) $fatal(1, "tb_instruction_memory FAILED with %0d errors", error_count);
        $finish;
    end

endmodule
