// =============================================================================
// File: tb_soc_bus_integration.sv
// Project: RV32I RISC-V SoC (Phase 4 - System Bus Integration Test)
// Description: System-level testbench verifying bus connectivity, address
//              decoding, and register read/write operations across all 5
//              subsystems connected to bus_interconnect:
//                Slave 0: Data Memory       (0x1000_0000)
//                Slave 1: UART Controller   (0x2000_0000)
//                Slave 2: SPI Master        (0x2000_1000)
//                Slave 3: Timer             (0x2000_2000)
//                Slave 4: Interrupt Ctrl    (0x2000_3000)
//                Unmapped space error check (0x3000_0000)
// =============================================================================

`timescale 1ns / 1ps

module tb_soc_bus_integration;

    logic        clk;
    logic        rst_n;

    // Bus Master (Emulated CPU LSU Master)
    logic        m_valid, m_we, m_ready, m_error;
    logic [31:0] m_addr, m_wdata, m_rdata;
    logic [3:0]  m_be;

    // Interconnect to Slaves
    logic        s0_valid, s0_we, s0_ready, s0_error;
    logic [31:0] s0_addr, s0_wdata, s0_rdata;
    logic [3:0]  s0_be;

    logic        s1_valid, s1_we, s1_ready, s1_error;
    logic [31:0] s1_addr, s1_wdata, s1_rdata;
    logic [3:0]  s1_be;

    logic        s2_valid, s2_we, s2_ready, s2_error;
    logic [31:0] s2_addr, s2_wdata, s2_rdata;
    logic [3:0]  s2_be;

    logic        s3_valid, s3_we, s3_ready, s3_error;
    logic [31:0] s3_addr, s3_wdata, s3_rdata;
    logic [3:0]  s3_be;

    logic        s4_valid, s4_we, s4_ready, s4_error;
    logic [31:0] s4_addr, s4_wdata, s4_rdata;
    logic [3:0]  s4_be;

    // Peripherals external pins
    logic        uart_rx, uart_tx, uart_irq;
    logic        spi_sclk, spi_mosi, spi_miso;
    logic [3:0]  spi_cs_n;
    logic        spi_irq;
    logic        timer_irq;
    logic        ext_irq;
    logic        soc_irq;

    always #5 clk = ~clk;

    // 1. Bus Interconnect
    bus_interconnect u_interconnect (
        .clk_i      (clk),
        .rst_ni     (rst_n),
        .m_valid_i  (m_valid),
        .m_we_i     (m_we),
        .m_addr_i   (m_addr),
        .m_wdata_i  (m_wdata),
        .m_be_i     (m_be),
        .m_ready_o  (m_ready),
        .m_rdata_o  (m_rdata),
        .m_error_o  (m_error),

        .s0_valid_o (s0_valid), .s0_we_o (s0_we), .s0_addr_o (s0_addr), .s0_wdata_o (s0_wdata), .s0_be_o (s0_be),
        .s0_ready_i (s0_ready), .s0_rdata_i (s0_rdata), .s0_error_i (s0_error),

        .s1_valid_o (s1_valid), .s1_we_o (s1_we), .s1_addr_o (s1_addr), .s1_wdata_o (s1_wdata), .s1_be_o (s1_be),
        .s1_ready_i (s1_ready), .s1_rdata_i (s1_rdata), .s1_error_i (s1_error),

        .s2_valid_o (s2_valid), .s2_we_o (s2_we), .s2_addr_o (s2_addr), .s2_wdata_o (s2_wdata), .s2_be_o (s2_be),
        .s2_ready_i (s2_ready), .s2_rdata_i (s2_rdata), .s2_error_i (s2_error),

        .s3_valid_o (s3_valid), .s3_we_o (s3_we), .s3_addr_o (s3_addr), .s3_wdata_o (s3_wdata), .s3_be_o (s3_be),
        .s3_ready_i (s3_ready), .s3_rdata_i (s3_rdata), .s3_error_i (s3_error),

        .s4_valid_o (s4_valid), .s4_we_o (s4_we), .s4_addr_o (s4_addr), .s4_wdata_o (s4_wdata), .s4_be_o (s4_be),
        .s4_ready_i (s4_ready), .s4_rdata_i (s4_rdata), .s4_error_i (s4_error)
    );

    // 2. Data Memory (Slave 0)
    data_memory #(.SIZE_BYTES(4096)) u_data_memory (
        .clk_i   (clk),
        .rst_ni  (rst_n),
        .valid_i (s0_valid),
        .we_i    (s0_we),
        .addr_i  (s0_addr),
        .wdata_i (s0_wdata),
        .be_i    (s0_be),
        .ready_o (s0_ready),
        .rdata_o (s0_rdata),
        .error_o (s0_error)
    );

    // 3. UART Controller (Slave 1)
    uart_controller u_uart (
        .clk_i     (clk),
        .rst_ni    (rst_n),
        .valid_i   (s1_valid),
        .we_i      (s1_we),
        .addr_i    (s1_addr),
        .wdata_i   (s1_wdata),
        .be_i      (s1_be),
        .ready_o   (s1_ready),
        .rdata_o   (s1_rdata),
        .error_o   (s1_error),
        .uart_rx_i (uart_rx),
        .uart_tx_o (uart_tx),
        .irq_o     (uart_irq)
    );

    // 4. SPI Master (Slave 2)
    spi_master u_spi (
        .clk_i      (clk),
        .rst_ni     (rst_n),
        .valid_i    (s2_valid),
        .we_i       (s2_we),
        .addr_i     (s2_addr),
        .wdata_i    (s2_wdata),
        .be_i       (s2_be),
        .ready_o    (s2_ready),
        .rdata_o    (s2_rdata),
        .error_o    (s2_error),
        .spi_sclk_o (spi_sclk),
        .spi_mosi_o (spi_mosi),
        .spi_miso_i (spi_miso),
        .spi_cs_no  (spi_cs_n),
        .irq_o      (spi_irq)
    );

    // 5. Timer (Slave 3)
    timer u_timer (
        .clk_i   (clk),
        .rst_ni  (rst_n),
        .valid_i (s3_valid),
        .we_i    (s3_we),
        .addr_i  (s3_addr),
        .wdata_i (s3_wdata),
        .be_i    (s3_be),
        .ready_o (s3_ready),
        .rdata_o (s3_rdata),
        .error_o (s3_error),
        .irq_o   (timer_irq)
    );

    // 6. Interrupt Controller (Slave 4)
    interrupt_controller u_intc (
        .clk_i       (clk),
        .rst_ni      (rst_n),
        .valid_i     (s4_valid),
        .we_i        (s4_we),
        .addr_i      (s4_addr),
        .wdata_i     (s4_wdata),
        .be_i        (s4_be),
        .ready_o     (s4_ready),
        .rdata_o     (s4_rdata),
        .error_o     (s4_error),
        .uart_irq_i  (uart_irq),
        .spi_irq_i   (spi_irq),
        .timer_irq_i (timer_irq),
        .ext_irq_i   (ext_irq),
        .irq_o       (soc_irq)
    );

    int test_count  = 0;
    int error_count = 0;

    task bus_master_write(input [31:0] target_addr, input [31:0] data, input [3:0] byte_en);
        @(posedge clk);
        m_valid <= 1; m_we <= 1; m_addr <= target_addr; m_wdata <= data; m_be <= byte_en;
        @(posedge clk);
        while (!m_ready) @(posedge clk);
        m_valid <= 0; m_we <= 0;
        @(posedge clk);
    endtask

    task bus_master_read(input [31:0] target_addr, output [31:0] data, output logic err);
        @(posedge clk);
        m_valid <= 1; m_we <= 0; m_addr <= target_addr; m_be <= 4'b1111;
        @(posedge clk);
        while (!m_ready) @(posedge clk);
        data = m_rdata;
        err  = m_error;
        m_valid <= 0;
        @(posedge clk);
    endtask

    logic [31:0] rd_data;
    logic        rd_err;

    initial begin
        $display("=================================================================");
        $display("Starting System Test: tb_soc_bus_integration");
        $display("=================================================================");

        clk      = 0;
        rst_n    = 0;
        m_valid  = 0;
        m_we     = 0;
        m_addr   = 0;
        m_wdata  = 0;
        m_be     = 0;
        uart_rx  = 1;
        spi_miso = 0;
        ext_irq  = 0;

        repeat (3) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // 1. Test Data Memory through Interconnect (Slave 0: 0x1000_0000)
        bus_master_write(32'h1000_0020, 32'hCAFE_BABE, 4'b1111);
        bus_master_read (32'h1000_0020, rd_data, rd_err);
        test_count++;
        if (!rd_err && rd_data == 32'hCAFE_BABE) begin
            $display("[PASS] Data Memory read/write via Interconnect: 0xCAFEBABE");
        end else begin
            $display("[FAIL] Data Memory access failed: rd_data=0x%08h, err=%b", rd_data, rd_err);
            error_count++;
        end

        // 2. Test UART Controller through Interconnect (Slave 1: 0x2000_0000)
        bus_master_write(32'h2000_0008, 32'd50, 4'b1111); // BAUD_DIV
        bus_master_read (32'h2000_0008, rd_data, rd_err);
        test_count++;
        if (!rd_err && rd_data == 32'd50) begin
            $display("[PASS] UART Controller register access via Interconnect: BAUD_DIV=50");
        end else begin
            $display("[FAIL] UART access failed: rd_data=%0d, err=%b", rd_data, rd_err);
            error_count++;
        end

        // 3. Test SPI Master through Interconnect (Slave 2: 0x2000_1000)
        bus_master_write(32'h2000_1008, 32'd8, 4'b1111); // CLK_DIV
        bus_master_read (32'h2000_1008, rd_data, rd_err);
        test_count++;
        if (!rd_err && rd_data == 32'd8) begin
            $display("[PASS] SPI Master register access via Interconnect: CLK_DIV=8");
        end else begin
            $display("[FAIL] SPI access failed: rd_data=%0d, err=%b", rd_data, rd_err);
            error_count++;
        end

        // 4. Test Timer through Interconnect (Slave 3: 0x2000_2000)
        bus_master_write(32'h2000_2004, 32'h0000_1234, 4'b1111); // COMPARE
        bus_master_read (32'h2000_2004, rd_data, rd_err);
        test_count++;
        if (!rd_err && rd_data == 32'h0000_1234) begin
            $display("[PASS] Timer register access via Interconnect: COMPARE=0x1234");
        end else begin
            $display("[FAIL] Timer access failed: rd_data=0x%08h, err=%b", rd_data, rd_err);
            error_count++;
        end

        // 5. Test Interrupt Controller through Interconnect (Slave 4: 0x2000_3000)
        bus_master_write(32'h2000_3004, 32'h0000_0007, 4'b1111); // ENABLE
        bus_master_read (32'h2000_3004, rd_data, rd_err);
        test_count++;
        if (!rd_err && rd_data[2:0] == 3'b111) begin
            $display("[PASS] Interrupt Controller register access via Interconnect: ENABLE=0x7");
        end else begin
            $display("[FAIL] Interrupt Controller access failed: rd_data=0x%08h, err=%b", rd_data, rd_err);
            error_count++;
        end

        // 6. Test Unmapped address error response (0x4000_0000)
        bus_master_read(32'h4000_0000, rd_data, rd_err);
        test_count++;
        if (rd_err && rd_data == 32'h0) begin
            $display("[PASS] Unmapped address 0x4000_0000 correctly returned error");
        end else begin
            $display("[FAIL] Unmapped address did not return error: err=%b, rd_data=0x%08h", rd_err, rd_data);
            error_count++;
        end

        // Summary
        $display("-----------------------------------------------------------------");
        $display("Test Summary: %0d Tests, %0d Failures", test_count, error_count);
        $display("-----------------------------------------------------------------");
        if (error_count > 0) $fatal(1, "tb_soc_bus_integration FAILED with %0d errors", error_count);
        $finish;
    end

endmodule
