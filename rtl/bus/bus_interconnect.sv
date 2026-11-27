// ============================================================================
// File: bus_interconnect.sv
// Project: RV32I RISC-V SoC (Phase 4 — Memory Subsystem and Peripheral Integration)
// Description: Custom single-master SoC bus interconnect.
//              - Implements full address decoding across 5 memory-mapped slaves:
//                  Slave 0: Data Memory          (0x1000_0000 - 0x1000_FFFF)
//                  Slave 1: UART Controller      (0x2000_0000 - 0x2000_0FFF)
//                  Slave 2: SPI Master           (0x2000_1000 - 0x2000_1FFF)
//                  Slave 3: Timer                (0x2000_2000 - 0x2000_2FFF)
//                  Slave 4: Interrupt Controller (0x2000_3000 - 0x2000_3FFF)
//              - Unmapped addresses return ready=1, error=1, rdata=0.
//              - Strict one-hot slave request routing with response multiplexing.
//              - Holds request routing stable during slave wait states.
// ============================================================================

`timescale 1ns / 1ps

module bus_interconnect (
    // Clock and Reset (used for protocol assertions and stability checks)
    input  logic        clk_i,
    input  logic        rst_ni,

    // CPU Data Bus Master Interface
    input  logic        m_req_i,
    input  logic [31:0] m_addr_i,
    input  logic        m_we_i,
    input  logic [31:0] m_wdata_i,
    input  logic [3:0]  m_be_i,
    output logic        m_ready_o,
    output logic [31:0] m_rdata_o,
    output logic        m_error_o,

    // Slave 0: Data Memory Interface (0x1000_0000 - 0x1000_FFFF)
    output logic        s0_req_o,
    output logic [31:0] s0_addr_o,
    output logic        s0_we_o,
    output logic [31:0] s0_wdata_o,
    output logic [3:0]  s0_be_o,
    input  logic        s0_ready_i,
    input  logic [31:0] s0_rdata_i,
    input  logic        s0_error_i,

    // Slave 1: UART Controller Interface (0x2000_0000 - 0x2000_0FFF)
    output logic        s1_req_o,
    output logic [31:0] s1_addr_o,
    output logic        s1_we_o,
    output logic [31:0] s1_wdata_o,
    output logic [3:0]  s1_be_o,
    input  logic        s1_ready_i,
    input  logic [31:0] s1_rdata_i,
    input  logic        s1_error_i,

    // Slave 2: SPI Master Interface (0x2000_1000 - 0x2000_1FFF)
    output logic        s2_req_o,
    output logic [31:0] s2_addr_o,
    output logic        s2_we_o,
    output logic [31:0] s2_wdata_o,
    output logic [3:0]  s2_be_o,
    input  logic        s2_ready_i,
    input  logic [31:0] s2_rdata_i,
    input  logic        s2_error_i,

    // Slave 3: Timer Interface (0x2000_2000 - 0x2000_2FFF)
    output logic        s3_req_o,
    output logic [31:0] s3_addr_o,
    output logic        s3_we_o,
    output logic [31:0] s3_wdata_o,
    output logic [3:0]  s3_be_o,
    input  logic        s3_ready_i,
    input  logic [31:0] s3_rdata_i,
    input  logic        s3_error_i,

    // Slave 4: Interrupt Controller Interface (0x2000_3000 - 0x2000_3FFF)
    output logic        s4_req_o,
    output logic [31:0] s4_addr_o,
    output logic        s4_we_o,
    output logic [31:0] s4_wdata_o,
    output logic [3:0]  s4_be_o,
    input  logic        s4_ready_i,
    input  logic [31:0] s4_rdata_i,
    input  logic        s4_error_i
);

    // Common request bus broadcast (only the selected slave receives req_o = 1)
    assign s0_addr_o  = m_addr_i;
    assign s0_we_o    = m_we_i;
    assign s0_wdata_o = m_wdata_i;
    assign s0_be_o    = m_be_i;

    assign s1_addr_o  = m_addr_i;
    assign s1_we_o    = m_we_i;
    assign s1_wdata_o = m_wdata_i;
    assign s1_be_o    = m_be_i;

    assign s2_addr_o  = m_addr_i;
    assign s2_we_o    = m_we_i;
    assign s2_wdata_o = m_wdata_i;
    assign s2_be_o    = m_be_i;

    assign s3_addr_o  = m_addr_i;
    assign s3_we_o    = m_we_i;
    assign s3_wdata_o = m_wdata_i;
    assign s3_be_o    = m_be_i;

    assign s4_addr_o  = m_addr_i;
    assign s4_we_o    = m_we_i;
    assign s4_wdata_o = m_wdata_i;
    assign s4_be_o    = m_be_i;

    // Full address decoding logic
    logic sel_dmem;
    logic sel_uart;
    logic sel_spi;
    logic sel_timer;
    logic sel_irq;
    logic sel_unmapped;

    always_comb begin
        sel_dmem     = 1'b0;
        sel_uart     = 1'b0;
        sel_spi      = 1'b0;
        sel_timer    = 1'b0;
        sel_irq      = 1'b0;
        sel_unmapped = 1'b0;

        if (m_req_i) begin
            // 0x1000_0000 - 0x1000_FFFF (64 KiB)
            if (m_addr_i[31:16] == 16'h1000) begin
                sel_dmem = 1'b1;
            // 0x2000_0000 - 0x2000_0FFF (4 KiB)
            end else if (m_addr_i[31:12] == 20'h20000) begin
                sel_uart = 1'b1;
            // 0x2000_1000 - 0x2000_1FFF (4 KiB)
            end else if (m_addr_i[31:12] == 20'h20001) begin
                sel_spi = 1'b1;
            // 0x2000_2000 - 0x2000_2FFF (4 KiB)
            end else if (m_addr_i[31:12] == 20'h20002) begin
                sel_timer = 1'b1;
            // 0x2000_3000 - 0x2000_3FFF (4 KiB)
            end else if (m_addr_i[31:12] == 20'h20003) begin
                sel_irq = 1'b1;
            end else begin
                sel_unmapped = 1'b1;
            end
        end
    end

    // Slave request generation (strictly one-hot)
    assign s0_req_o = m_req_i && sel_dmem;
    assign s1_req_o = m_req_i && sel_uart;
    assign s2_req_o = m_req_i && sel_spi;
    assign s3_req_o = m_req_i && sel_timer;
    assign s4_req_o = m_req_i && sel_irq;

    // Response multiplexer
    always_comb begin
        if (!m_req_i) begin
            m_ready_o = 1'b0;
            m_rdata_o = 32'h0000_0000;
            m_error_o = 1'b0;
        end else if (sel_dmem) begin
            m_ready_o = s0_ready_i;
            m_rdata_o = s0_rdata_i;
            m_error_o = s0_error_i;
        end else if (sel_uart) begin
            m_ready_o = s1_ready_i;
            m_rdata_o = s1_rdata_i;
            m_error_o = s1_error_i;
        end else if (sel_spi) begin
            m_ready_o = s2_ready_i;
            m_rdata_o = s2_rdata_i;
            m_error_o = s2_error_i;
        end else if (sel_timer) begin
            m_ready_o = s3_ready_i;
            m_rdata_o = s3_rdata_i;
            m_error_o = s3_error_i;
        end else if (sel_irq) begin
            m_ready_o = s4_ready_i;
            m_rdata_o = s4_rdata_i;
            m_error_o = s4_error_i;
        end else begin
            // Unmapped address: immediate error completion with zero data
            m_ready_o = 1'b1;
            m_rdata_o = 32'h0000_0000;
            m_error_o = 1'b1;
        end
    end

endmodule
