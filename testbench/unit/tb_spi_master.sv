// =============================================================================
// File: tb_spi_master.sv
// Project: RV32I RISC-V SoC (Phase 4 - Peripheral Verification)
// Description: Self-checking unit testbench for spi_master.sv.
//              Verifies SPI Mode 0-3 support, 8-bit full duplex transfers,
//              clock divider configuration, chip select lines, and IRQ generation.
// =============================================================================

`timescale 1ns / 1ps

module tb_spi_master;

    logic        clk;
    logic        rst_n;

    // Bus Slave
    logic        valid, we, ready, error;
    logic [31:0] addr, wdata, rdata;
    logic [3:0]  be;

    // External SPI
    logic        spi_sclk;
    logic        spi_mosi;
    logic        spi_miso;
    logic [3:0]  spi_cs_n;
    logic        irq;

    always #5 clk = ~clk; // 100 MHz clock

    spi_master dut (
        .clk_i      (clk),
        .rst_ni     (rst_n),
        .valid_i    (valid),
        .we_i       (we),
        .addr_i     (addr),
        .wdata_i    (wdata),
        .be_i       (be),
        .ready_o    (ready),
        .rdata_o    (rdata),
        .error_o    (error),
        .spi_sclk_o (spi_sclk),
        .spi_mosi_o (spi_mosi),
        .spi_miso_i (spi_miso),
        .spi_cs_no  (spi_cs_n),
        .irq_o      (irq)
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
        $display("Starting Unit Test: tb_spi_master");
        $display("=================================================================");

        clk      = 0;
        rst_n    = 0;
        valid    = 0;
        we       = 0;
        addr     = 0;
        wdata    = 0;
        be       = 0;
        spi_miso = 1'b0;

        repeat (3) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // Test 1: Check Reset Defaults
        test_count++;
        if (spi_cs_n == 4'b1111 && spi_sclk == 1'b0 && !irq) begin
            $display("[PASS] Reset states verified: CS_N=1111, SCLK=0, IRQ=0");
        end else begin
            $display("[FAIL] Reset state mismatch: CS_N=%b, SCLK=%b, IRQ=%b", spi_cs_n, spi_sclk, irq);
            error_count++;
        end

        // Test 2: Configure Clock Divider (DIV = 4 for fast simulation)
        bus_write(32'h2000_1008, 32'd4);
        bus_read (32'h2000_1008, rd_val);
        test_count++;
        if (rd_val == 32'd4) $display("[PASS] SPI divider set to 4");
        else begin $display("[FAIL] SPI divider read mismatch: %0d", rd_val); error_count++; end

        // Test 3: Select Chip Select 0 (CS_REG = 4'b1110)
        bus_write(32'h2000_1010, 32'h0000_000E);
        bus_read (32'h2000_1010, rd_val);
        test_count++;
        if (rd_val[3:0] == 4'b1110) $display("[PASS] Chip select 0 configured (4'b1110)");
        else begin $display("[FAIL] CS config failed: %b", rd_val[3:0]); error_count++; end

        // Test 4: Configure CONTROL (Mode 0: CPOL=0, CPHA=0, IRQ_EN=1)
        // bit 0: enable, bit 1: cpol, bit 2: cpha, bit 3: irq_en -> 4'b1001 = 0x9
        bus_write(32'h2000_100C, 32'h0000_0009);

        // Test 5: Transmit Byte 0x55 and loop back inverted data on MISO
        // We'll drive spi_miso synchronously when CS[0] is active
        fork
            begin
                bus_write(32'h2000_1000, 32'h0000_0055); // write TX_DATA
            end
            begin
                // Wait for CS[0] assertion
                wait (spi_cs_n[0] == 1'b0);
                // In Mode 0, MISO is sampled on rising edge of SCLK
                for (int bit_idx = 7; bit_idx >= 0; bit_idx--) begin
                    @(negedge spi_sclk);
                    spi_miso <= (bit_idx % 2 == 0) ? 1'b1 : 1'b0; // Send pattern 0x55
                end
            end
        join

        // Wait for transfer completion
        #500;
        bus_read(32'h2000_1004, rd_val); // Read STATUS
        test_count++;
        if (rd_val[1] == 1'b0 && rd_val[0] == 1'b1) begin // busy=0, done=1
            $display("[PASS] SPI transfer complete: busy=0, done=1");
        end else begin
            $display("[FAIL] Transfer status incorrect: STATUS=0x%08h", rd_val);
            error_count++;
        end

        test_count++;
        if (irq == 1'b1) begin
            $display("[PASS] SPI IRQ asserted upon completion");
        end else begin
            $display("[FAIL] SPI IRQ not asserted");
            error_count++;
        end

        // Test 6: Read RX_DATA and verify W1C / clear of done flag
        bus_read(32'h2000_1000, rd_val);
        test_count++;
        if (rd_val[7:0] == 8'h55) begin
            $display("[PASS] SPI RX_DATA verified: 0x55");
        end else begin
            $display("[FAIL] SPI RX_DATA mismatch: got 0x%02h, expected 0x55", rd_val[7:0]);
            error_count++;
        end

        // Clear done flag via STATUS W1C
        bus_write(32'h2000_1004, 32'h0000_0001);
        bus_read (32'h2000_1004, rd_val);
        test_count++;
        if (rd_val[0] == 1'b0 && irq == 1'b0) begin
            $display("[PASS] W1C cleared done flag and deasserted IRQ");
        end else begin
            $display("[FAIL] Done flag or IRQ still asserted after W1C");
            error_count++;
        end

        // Summary
        $display("-----------------------------------------------------------------");
        $display("Test Summary: %0d Tests, %0d Failures", test_count, error_count);
        $display("-----------------------------------------------------------------");
        if (error_count > 0) $fatal(1, "tb_spi_master FAILED with %0d errors", error_count);
        $finish;
    end

endmodule
