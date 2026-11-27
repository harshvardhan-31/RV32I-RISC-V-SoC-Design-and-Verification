// =============================================================================
// File: tb_timer.sv
// Project: RV32I RISC-V SoC (Phase 4 - Peripheral Verification)
// Description: Self-checking unit testbench for timer.sv.
//              Verifies counter counting, compare match flag setting, sticky
//              behavior, W1C clear semantics, and interrupt generation.
// =============================================================================

`timescale 1ns / 1ps

module tb_timer;

    logic        clk;
    logic        rst_n;

    // Bus Slave
    logic        valid, we, ready, error;
    logic [31:0] addr, wdata, rdata;
    logic [3:0]  be;

    // Interrupt
    logic        irq;

    always #5 clk = ~clk; // 100 MHz clock

    timer dut (
        .clk_i   (clk),
        .rst_ni  (rst_n),
        .valid_i (valid),
        .we_i    (we),
        .addr_i  (addr),
        .wdata_i (wdata),
        .be_i    (be),
        .ready_o (ready),
        .rdata_o (rdata),
        .error_o (error),
        .irq_o   (irq)
    );

    int test_count  = 0;
    int error_count = 0;

    task bus_write(input [31:0] reg_addr, input [31:0] data);
        @(posedge clk);
        valid <= 1; we <= 1; addr <= reg_addr; wdata <= data; be <= 4'b1111;
        @(posedge clk);
        while (!ready) @(posedge clk);
        valid <= 0; we <= 0;
        @(posedge clk);
    endtask

    task bus_read(input [31:0] reg_addr, output [31:0] data);
        @(posedge clk);
        valid <= 1; we <= 0; addr <= reg_addr; be <= 4'b1111;
        @(posedge clk);
        while (!ready) @(posedge clk);
        data = rdata;
        valid <= 0;
        @(posedge clk);
    endtask

    logic [31:0] rd_val;

    initial begin
        $display("=================================================================");
        $display("Starting Unit Test: tb_timer");
        $display("=================================================================");

        clk   = 0;
        rst_n = 0;
        valid = 0;
        we    = 0;
        addr  = 0;
        wdata = 0;
        be    = 0;

        repeat (3) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // Test 1: Check Reset Defaults
        bus_read(32'h2000_2000, rd_val); // COUNT
        test_count++;
        if (rd_val == 32'h0) $display("[PASS] Reset COUNT is 0");
        else begin $display("[FAIL] Reset COUNT != 0: 0x%08h", rd_val); error_count++; end

        bus_read(32'h2000_2004, rd_val); // COMPARE
        test_count++;
        if (rd_val == 32'hFFFF_FFFF) $display("[PASS] Reset COMPARE is 0xFFFFFFFF");
        else begin $display("[FAIL] Reset COMPARE != 0xFFFFFFFF: 0x%08h", rd_val); error_count++; end

        // Test 2: Set COMPARE threshold = 10
        bus_write(32'h2000_2004, 32'd10);
        bus_read (32'h2000_2004, rd_val);
        test_count++;
        if (rd_val == 32'd10) $display("[PASS] COMPARE set to 10");
        else begin $display("[FAIL] COMPARE set failed: %0d", rd_val); error_count++; end

        // Test 3: Enable timer and IRQ (CONTROL = 2'b11 = 0x3)
        bus_write(32'h2000_2008, 32'h0000_0003);

        // Wait for counter to exceed 10
        repeat (15) @(posedge clk);

        // Verify count has incremented
        bus_read(32'h2000_2000, rd_val);
        test_count++;
        if (rd_val >= 32'd10) begin
            $display("[PASS] Timer counted up: COUNT = %0d", rd_val);
        end else begin
            $display("[FAIL] Timer did not increment properly: COUNT = %0d", rd_val);
            error_count++;
        end

        // Verify IRQ_STATUS bit 0 is asserted
        bus_read(32'h2000_200C, rd_val);
        test_count++;
        if (rd_val[0] == 1'b1) begin
            $display("[PASS] Compare match status asserted");
        end else begin
            $display("[FAIL] Compare match status not asserted: 0x%08h", rd_val);
            error_count++;
        end

        test_count++;
        if (irq == 1'b1) begin
            $display("[PASS] Timer IRQ asserted to system");
        end else begin
            $display("[FAIL] Timer IRQ line not asserted");
            error_count++;
        end

        // Test 4: Write-1-to-Clear (W1C) IRQ_STATUS
        bus_write(32'h2000_200C, 32'h0000_0001);
        bus_read (32'h2000_200C, rd_val);
        test_count++;
        if (rd_val[0] == 1'b0 && irq == 1'b0) begin
            $display("[PASS] W1C successfully cleared IRQ status and IRQ line");
        end else begin
            $display("[FAIL] W1C failed to clear IRQ status: %b, IRQ=%b", rd_val[0], irq);
            error_count++;
        end

        // Summary
        $display("-----------------------------------------------------------------");
        $display("Test Summary: %0d Tests, %0d Failures", test_count, error_count);
        $display("-----------------------------------------------------------------");
        if (error_count > 0) $fatal(1, "tb_timer FAILED with %0d errors", error_count);
        $finish;
    end

endmodule
