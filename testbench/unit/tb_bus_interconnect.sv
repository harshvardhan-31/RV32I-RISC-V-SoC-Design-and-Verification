// =============================================================================
// File: tb_bus_interconnect.sv
// Project: RV32I RISC-V SoC (Phase 4 - Interconnect Verification)
// Description: Self-checking unit testbench for bus_interconnect.sv.
//              Verifies address decoding for all 5 slaves, unmapped error
//              generation, one-hot slave selection, and response muxing.
// =============================================================================

`timescale 1ns / 1ps

module tb_bus_interconnect;

    logic        clk;
    logic        rst_n;

    // Master
    logic        m_valid, m_we, m_ready, m_error;
    logic [31:0] m_addr, m_wdata, m_rdata;
    logic [3:0]  m_be;

    // Slaves 0 to 4
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

    always #5 clk = ~clk;

    bus_interconnect dut (
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

    int test_count  = 0;
    int error_count = 0;

    // Slave model responders
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s0_ready <= 0; s0_rdata <= 0; s0_error <= 0;
            s1_ready <= 0; s1_rdata <= 0; s1_error <= 0;
            s2_ready <= 0; s2_rdata <= 0; s2_error <= 0;
            s3_ready <= 0; s3_rdata <= 0; s3_error <= 0;
            s4_ready <= 0; s4_rdata <= 0; s4_error <= 0;
        end else begin
            s0_ready <= s0_valid; s0_rdata <= 32'hAAAA_0000; s0_error <= 0;
            s1_ready <= s1_valid; s1_rdata <= 32'hBBBB_1111; s1_error <= 0;
            s2_ready <= s2_valid; s2_rdata <= 32'hCCCC_2222; s2_error <= 0;
            s3_ready <= s3_valid; s3_rdata <= 32'hDDDD_3333; s3_error <= 0;
            s4_ready <= s4_valid; s4_rdata <= 32'hEEEE_4444; s4_error <= 0;
        end
    end

    initial begin
        $display("=================================================================");
        $display("Starting Unit Test: tb_bus_interconnect");
        $display("=================================================================");

        clk     = 0;
        rst_n   = 0;
        m_valid = 0;
        m_we    = 0;
        m_addr  = 0;
        m_wdata = 0;
        m_be    = 0;

        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Test 1: Route to Slave 0 (Data Memory: 0x1000_0000)
        @(posedge clk);
        m_valid <= 1; m_addr <= 32'h1000_0040; m_we <= 0; m_be <= 4'b1111;
        @(posedge clk);
        test_count++;
        if (s0_valid && !s1_valid && !s2_valid && !s3_valid && !s4_valid) begin
            $display("[PASS] Slave 0 correctly selected for 0x1000_0040");
        end else begin
            $display("[FAIL] Slave selection error for 0x1000_0040: s0=%b s1=%b s2=%b s3=%b s4=%b",
                     s0_valid, s1_valid, s2_valid, s3_valid, s4_valid);
            error_count++;
        end
        @(posedge clk);
        m_valid <= 0;
        test_count++;
        if (m_ready && m_rdata == 32'hAAAA_0000 && !m_error) begin
            $display("[PASS] Slave 0 response correctly routed back to master");
        end else begin
            $display("[FAIL] Slave 0 response routing error: ready=%b rdata=0x%08h error=%b", m_ready, m_rdata, m_error);
            error_count++;
        end

        // Test 2: Route to Slave 1 (UART: 0x2000_0000)
        @(posedge clk);
        m_valid <= 1; m_addr <= 32'h2000_0004; m_we <= 0; m_be <= 4'b1111;
        @(posedge clk);
        test_count++;
        if (s1_valid && !s0_valid && !s2_valid && !s3_valid && !s4_valid) begin
            $display("[PASS] Slave 1 correctly selected for 0x2000_0004");
        end else begin
            $display("[FAIL] Slave selection error for UART");
            error_count++;
        end
        @(posedge clk);
        m_valid <= 0;
        test_count++;
        if (m_ready && m_rdata == 32'hBBBB_1111 && !m_error) begin
            $display("[PASS] Slave 1 response correctly routed back to master");
        end else begin
            $display("[FAIL] Slave 1 response routing error: ready=%b rdata=0x%08h error=%b", m_ready, m_rdata, m_error);
            error_count++;
        end

        // Test 3: Route to Slave 2 (SPI: 0x2000_1000)
        @(posedge clk);
        m_valid <= 1; m_addr <= 32'h2000_1008; m_we <= 0; m_be <= 4'b1111;
        @(posedge clk);
        test_count++;
        if (s2_valid) $display("[PASS] Slave 2 selected for 0x2000_1008");
        else begin $display("[FAIL] Slave 2 select failed"); error_count++; end
        @(posedge clk);
        m_valid <= 0;
        test_count++;
        if (m_ready && m_rdata == 32'hCCCC_2222) $display("[PASS] Slave 2 response routed");
        else begin $display("[FAIL] Slave 2 response failed"); error_count++; end

        // Test 4: Route to Slave 3 (Timer: 0x2000_2000)
        @(posedge clk);
        m_valid <= 1; m_addr <= 32'h2000_200C; m_we <= 0; m_be <= 4'b1111;
        @(posedge clk);
        test_count++;
        if (s3_valid) $display("[PASS] Slave 3 selected for 0x2000_200C");
        else begin $display("[FAIL] Slave 3 select failed"); error_count++; end
        @(posedge clk);
        m_valid <= 0;
        test_count++;
        if (m_ready && m_rdata == 32'hDDDD_3333) $display("[PASS] Slave 3 response routed");
        else begin $display("[FAIL] Slave 3 response failed"); error_count++; end

        // Test 5: Route to Slave 4 (Interrupt Controller: 0x2000_3000)
        @(posedge clk);
        m_valid <= 1; m_addr <= 32'h2000_3000; m_we <= 0; m_be <= 4'b1111;
        @(posedge clk);
        test_count++;
        if (s4_valid) $display("[PASS] Slave 4 selected for 0x2000_3000");
        else begin $display("[FAIL] Slave 4 select failed"); error_count++; end
        @(posedge clk);
        m_valid <= 0;
        test_count++;
        if (m_ready && m_rdata == 32'hEEEE_4444) $display("[PASS] Slave 4 response routed");
        else begin $display("[FAIL] Slave 4 response failed"); error_count++; end

        // Test 6: Unmapped Address (0x3000_0000)
        @(posedge clk);
        m_valid <= 1; m_addr <= 32'h3000_0000; m_we <= 0; m_be <= 4'b1111;
        @(posedge clk);
        m_valid <= 0;
        test_count++;
        if (m_ready && m_error && m_rdata == 32'h0) begin
            $display("[PASS] Unmapped address 0x3000_0000 flagged error with ready=1");
        end else begin
            $display("[FAIL] Unmapped address response error: ready=%b error=%b rdata=0x%08h", m_ready, m_error, m_rdata);
            error_count++;
        end

        // Summary
        $display("-----------------------------------------------------------------");
        $display("Test Summary: %0d Tests, %0d Failures", test_count, error_count);
        $display("-----------------------------------------------------------------");
        if (error_count > 0) $fatal(1, "tb_bus_interconnect FAILED with %0d errors", error_count);
        $finish;
    end

endmodule
