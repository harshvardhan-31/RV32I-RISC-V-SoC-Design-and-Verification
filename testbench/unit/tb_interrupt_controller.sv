// =============================================================================
// File: tb_interrupt_controller.sv
// Project: RV32I RISC-V SoC (Phase 4 - Interrupt Subsystem Verification)
// Description: Self-checking unit testbench for interrupt_controller.sv.
//              Verifies individual event latching into sticky pending bits,
//              masking via ENABLE register, aggregation into irq_o, W1C CLEAR,
//              and incoming assertion priority over W1C clear.
// =============================================================================

`timescale 1ns / 1ps

module tb_interrupt_controller;

    logic        clk;
    logic        rst_n;

    // Bus Slave
    logic        valid, we, ready, error;
    logic [31:0] addr, wdata, rdata;
    logic [3:0]  be;

    // Peripheral Interrupt Inputs
    logic        uart_irq;
    logic        spi_irq;
    logic        timer_irq;
    logic        ext_irq;

    // Output IRQ
    logic        irq;

    always #5 clk = ~clk; // 100 MHz clock

    interrupt_controller dut (
        .clk_i       (clk),
        .rst_ni      (rst_n),
        .valid_i     (valid),
        .we_i        (we),
        .addr_i      (addr),
        .wdata_i     (wdata),
        .be_i        (be),
        .ready_o     (ready),
        .rdata_o     (rdata),
        .error_o     (error),
        .uart_irq_i  (uart_irq),
        .spi_irq_i   (spi_irq),
        .timer_irq_i (timer_irq),
        .ext_irq_i   (ext_irq),
        .irq_o       (irq)
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
        $display("Starting Unit Test: tb_interrupt_controller");
        $display("=================================================================");

        clk       = 0;
        rst_n     = 0;
        valid     = 0;
        we        = 0;
        addr      = 0;
        wdata     = 0;
        be        = 0;
        uart_irq  = 0;
        spi_irq   = 0;
        timer_irq = 0;
        ext_irq   = 0;

        repeat (3) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // Test 1: Check Reset Defaults
        bus_read(32'h2000_3000, rd_val); // PENDING
        test_count++;
        if (rd_val == 32'h0) $display("[PASS] Reset PENDING is 0");
        else begin $display("[FAIL] Reset PENDING != 0: 0x%08h", rd_val); error_count++; end

        bus_read(32'h2000_3004, rd_val); // ENABLE
        test_count++;
        if (rd_val == 32'h0) $display("[PASS] Reset ENABLE is 0");
        else begin $display("[FAIL] Reset ENABLE != 0: 0x%08h", rd_val); error_count++; end

        // Test 2: Trigger UART IRQ pulse (bit 0) without enable
        @(posedge clk);
        uart_irq <= 1;
        @(posedge clk);
        uart_irq <= 0;
        @(posedge clk);

        // Verify sticky pending bit 0 is latched
        bus_read(32'h2000_3000, rd_val);
        test_count++;
        if (rd_val[0] == 1'b1) $display("[PASS] UART IRQ latched into PENDING[0]");
        else begin $display("[FAIL] UART IRQ not latched: 0x%08h", rd_val); error_count++; end

        // Since ENABLE is 0, irq output must remain 0
        test_count++;
        if (irq == 1'b0) $display("[PASS] Masked interrupt did not assert irq_o");
        else begin $display("[FAIL] Masked interrupt asserted irq_o unexpectedly"); error_count++; end

        // Test 3: Enable UART IRQ (bit 0) in ENABLE register
        bus_write(32'h2000_3004, 32'h0000_0001);
        #1;
        test_count++;
        if (irq == 1'b1) $display("[PASS] Enabling source 0 asserted irq_o");
        else begin $display("[FAIL] irq_o not asserted after enabling source 0"); error_count++; end

        // Test 4: W1C Clear source 0
        bus_write(32'h2000_3008, 32'h0000_0001); // CLEAR bit 0
        bus_read (32'h2000_3000, rd_val);
        test_count++;
        if (rd_val[0] == 1'b0 && irq == 1'b0) begin
            $display("[PASS] W1C cleared PENDING[0] and deasserted irq_o");
        end else begin
            $display("[FAIL] PENDING[0] or irq_o still asserted: %b, %b", rd_val[0], irq);
            error_count++;
        end

        // Test 5: Multi-source latching (SPI=bit 1, Timer=bit 2, Ext=bit 3)
        @(posedge clk);
        spi_irq   <= 1;
        timer_irq <= 1;
        ext_irq   <= 1;
        @(posedge clk);
        spi_irq   <= 0;
        timer_irq <= 0;
        ext_irq   <= 0;
        @(posedge clk);

        bus_read(32'h2000_3000, rd_val);
        test_count++;
        if (rd_val[3:1] == 3'b111) begin
            $display("[PASS] Multiple IRQ sources (SPI, Timer, Ext) latched simultaneously");
        end else begin
            $display("[FAIL] Multiple source latch mismatch: 0x%08h", rd_val);
            error_count++;
        end

        // Enable Timer only (bit 2 = 0x4)
        bus_write(32'h2000_3004, 32'h0000_0004);
        #1;
        test_count++;
        if (irq == 1'b1) $display("[PASS] irq_o asserted when matching enabled source");
        else begin $display("[FAIL] irq_o mismatch"); error_count++; end

        // Clear all pending (0xF)
        bus_write(32'h2000_3008, 32'h0000_000F);
        bus_read (32'h2000_3000, rd_val);
        test_count++;
        if (rd_val[3:0] == 4'b0000) $display("[PASS] All pending bits cleared");
        else begin $display("[FAIL] Clear all failed: 0x%08h", rd_val); error_count++; end

        // Test 6: Priority - Incoming active interrupt during W1C write keeps pending asserted
        @(posedge clk);
        valid <= 1; we <= 1; addr <= 32'h2000_3008; wdata <= 32'h0000_0002; be <= 4'b1111;
        spi_irq <= 1; // Incoming active at the same time
        @(posedge clk);
        while (!ready) @(posedge clk);
        valid <= 0; we <= 0;
        spi_irq <= 0;
        @(posedge clk);

        bus_read(32'h2000_3000, rd_val);
        test_count++;
        if (rd_val[1] == 1'b1) begin
            $display("[PASS] Incoming active event took priority over simultaneous W1C clear");
        end else begin
            $display("[FAIL] Incoming event lost due to simultaneous clear: PENDING=0x%08h", rd_val);
            error_count++;
        end

        // Summary
        $display("-----------------------------------------------------------------");
        $display("Test Summary: %0d Tests, %0d Failures", test_count, error_count);
        $display("-----------------------------------------------------------------");
        if (error_count > 0) $fatal(1, "tb_interrupt_controller FAILED with %0d errors", error_count);
        $finish;
    end

endmodule
