// =============================================================================
// File: rv32i_soc_top.sv
// Module Name: rv32i_soc_top
// Description: Top-level SoC integrating the RV32I 5-stage CPU core, custom
//              bus interconnect, dedicated instruction memory, data memory,
//              and MMIO peripherals (UART, SPI Master, Timer, Interrupt Controller).
//
// Subsystems:
//   - CPU Core: Five-stage in-order RV32I pipeline with hazard & forwarding units.
//   - Instruction Memory: 64 KiB dedicated fetch memory (0x0000_0000 - 0x0000_FFFF).
//   - Data Memory: 64 KiB byte-masked RAM (0x1000_0000 - 0x1000_FFFF).
//   - Bus Interconnect: 1 Master (CPU LSU), 5 Slaves, unmapped error generation.
//   - UART Controller: 8-N-1 full duplex, TX/RX FSM, 2-flop RX synchronizer.
//   - SPI Master: Modes 0-3, 4 active-low CS lines, full duplex.
//   - Timer: 32-bit counter, compare match, W1C IRQ.
//   - Interrupt Controller: 4-channel sticky pending, individual mask, W1C clear.
//   - Asynchronous Input Synchronizers: 2-stage flip-flop synchronizers on external
//     asynchronous pins (uart_rx_i, spi_miso_i, ext_irq_i).
// =============================================================================

`timescale 1ns / 1ps

module rv32i_soc_top #(
    parameter [31:0] RESET_VECTOR     = 32'h0000_0000,
    parameter        IMEM_INIT_FILE   = "",
    parameter        DMEM_INIT_FILE   = "",
    parameter int    IMEM_SIZE_BYTES  = 65536,
    parameter int    DMEM_SIZE_BYTES  = 65536
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    // External UART Interface
    input  logic        uart_rx_i,
    output logic        uart_tx_o,

    // External SPI Master Interface
    output logic        spi_sclk_o,
    output logic        spi_mosi_o,
    input  logic        spi_miso_i,
    output logic [3:0]  spi_cs_no,

    // External Interrupt Input
    input  logic        ext_irq_i,

    // Aggregated Interrupt Output (External Observation / Verifier)
    output logic        irq_o
);

    // =========================================================================
    // 1. Two-Stage Flip-Flop Synchronizers for Asynchronous External Inputs
    // =========================================================================
    logic uart_rx_sync_stage1, uart_rx_sync_stage2;
    logic spi_miso_sync_stage1, spi_miso_sync_stage2;
    logic ext_irq_sync_stage1, ext_irq_sync_stage2;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            uart_rx_sync_stage1  <= 1'b1; // UART idle state is high
            uart_rx_sync_stage2  <= 1'b1;
            spi_miso_sync_stage1 <= 1'b0;
            spi_miso_sync_stage2 <= 1'b0;
            ext_irq_sync_stage1  <= 1'b0;
            ext_irq_sync_stage2  <= 1'b0;
        end else begin
            uart_rx_sync_stage1  <= uart_rx_i;
            uart_rx_sync_stage2  <= uart_rx_sync_stage1;
            spi_miso_sync_stage1 <= spi_miso_i;
            spi_miso_sync_stage2 <= spi_miso_sync_stage1;
            ext_irq_sync_stage1  <= ext_irq_i;
            ext_irq_sync_stage2  <= ext_irq_sync_stage1;
        end
    end

    // Synchronized signals
    wire uart_rx_sync  = uart_rx_sync_stage2;
    wire spi_miso_sync = spi_miso_sync_stage2;
    wire ext_irq_sync  = ext_irq_sync_stage2;

    // =========================================================================
    // 2. CPU Instruction Memory Interconnect
    // =========================================================================
    logic        imem_req;
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;
    logic        imem_ready;
    logic        imem_error;

    // =========================================================================
    // 3. CPU Data Master Bus Interface
    // =========================================================================
    logic        dmem_req;
    logic [31:0] dmem_addr;
    logic        dmem_we;
    logic [31:0] dmem_wdata;
    logic [3:0]  dmem_be;
    logic        dmem_ready;
    logic [31:0] dmem_rdata;
    logic        dmem_error;

    // =========================================================================
    // 4. Bus Interconnect Slave Interfaces (0 through 4)
    // =========================================================================
    // Slave 0: Data Memory (0x1000_0000 - 0x1000_FFFF)
    logic        s0_valid, s0_we, s0_ready, s0_error;
    logic [31:0] s0_addr, s0_wdata, s0_rdata;
    logic [3:0]  s0_be;

    // Slave 1: UART Controller (0x2000_0000 - 0x2000_0FFF)
    logic        s1_valid, s1_we, s1_ready, s1_error;
    logic [31:0] s1_addr, s1_wdata, s1_rdata;
    logic [3:0]  s1_be;

    // Slave 2: SPI Master (0x2000_1000 - 0x2000_1FFF)
    logic        s2_valid, s2_we, s2_ready, s2_error;
    logic [31:0] s2_addr, s2_wdata, s2_rdata;
    logic [3:0]  s2_be;

    // Slave 3: Timer (0x2000_2000 - 0x2000_2FFF)
    logic        s3_valid, s3_we, s3_ready, s3_error;
    logic [31:0] s3_addr, s3_wdata, s3_rdata;
    logic [3:0]  s3_be;

    // Slave 4: Interrupt Controller (0x2000_3000 - 0x2000_3FFF)
    logic        s4_valid, s4_we, s4_ready, s4_error;
    logic [31:0] s4_addr, s4_wdata, s4_rdata;
    logic [3:0]  s4_be;

    // =========================================================================
    // 5. Peripheral Interrupt Signals
    // =========================================================================
    logic uart_irq;
    logic spi_irq;
    logic timer_irq;

    // =========================================================================
    // 6. CPU Core Instance
    // =========================================================================
    cpu_core #(
        .RESET_VECTOR (RESET_VECTOR)
    ) u_cpu_core (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),

        // Instruction fetch interface
        .imem_req_o   (imem_req),
        .imem_addr_o  (imem_addr),
        .imem_rdata_i (imem_rdata),
        .imem_ready_i (imem_ready),
        .imem_error_i (imem_error),

        // Data memory bus master interface
        .dmem_req_o   (dmem_req),
        .dmem_addr_o  (dmem_addr),
        .dmem_we_o    (dmem_we),
        .dmem_wdata_o (dmem_wdata),
        .dmem_be_o    (dmem_be),
        .dmem_ready_i (dmem_ready),
        .dmem_rdata_i (dmem_rdata),
        .dmem_error_i (dmem_error)
    );

    // =========================================================================
    // 7. Instruction Memory Instance (Dedicated Fetch Port)
    // =========================================================================
    instruction_memory #(
        .SIZE_BYTES (IMEM_SIZE_BYTES),
        .INIT_FILE  (IMEM_INIT_FILE)
    ) u_instruction_memory (
        .clk_i   (clk_i),
        .rst_ni  (rst_ni),
        .req_i   (imem_req),
        .addr_i  (imem_addr),
        .ready_o (imem_ready),
        .rdata_o (imem_rdata),
        .error_o (imem_error)
    );

    // =========================================================================
    // 8. Bus Interconnect Instance (1 Master, 5 Slaves)
    // =========================================================================
    bus_interconnect u_bus_interconnect (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),

        // Master Port (from CPU LSU)
        .m_valid_i  (dmem_req),
        .m_we_i     (dmem_we),
        .m_addr_i   (dmem_addr),
        .m_wdata_i  (dmem_wdata),
        .m_be_i     (dmem_be),
        .m_ready_o  (dmem_ready),
        .m_rdata_o  (dmem_rdata),
        .m_error_o  (dmem_error),

        // Slave 0: Data Memory
        .s0_valid_o (s0_valid),
        .s0_we_o    (s0_we),
        .s0_addr_o  (s0_addr),
        .s0_wdata_o (s0_wdata),
        .s0_be_o    (s0_be),
        .s0_ready_i (s0_ready),
        .s0_rdata_i (s0_rdata),
        .s0_error_i (s0_error),

        // Slave 1: UART Controller
        .s1_valid_o (s1_valid),
        .s1_we_o    (s1_we),
        .s1_addr_o  (s1_addr),
        .s1_wdata_o (s1_wdata),
        .s1_be_o    (s1_be),
        .s1_ready_i (s1_ready),
        .s1_rdata_i (s1_rdata),
        .s1_error_i (s1_error),

        // Slave 2: SPI Master
        .s2_valid_o (s2_valid),
        .s2_we_o    (s2_we),
        .s2_addr_o  (s2_addr),
        .s2_wdata_o (s2_wdata),
        .s2_be_o    (s2_be),
        .s2_ready_i (s2_ready),
        .s2_rdata_i (s2_rdata),
        .s2_error_i (s2_error),

        // Slave 3: Timer
        .s3_valid_o (s3_valid),
        .s3_we_o    (s3_we),
        .s3_addr_o  (s3_addr),
        .s3_wdata_o (s3_wdata),
        .s3_be_o    (s3_be),
        .s3_ready_i (s3_ready),
        .s3_rdata_i (s3_rdata),
        .s3_error_i (s3_error),

        // Slave 4: Interrupt Controller
        .s4_valid_o (s4_valid),
        .s4_we_o    (s4_we),
        .s4_addr_o  (s4_addr),
        .s4_wdata_o (s4_wdata),
        .s4_be_o    (s4_be),
        .s4_ready_i (s4_ready),
        .s4_rdata_i (s4_rdata),
        .s4_error_i (s4_error)
    );

    // =========================================================================
    // 9. Data Memory Instance (Slave 0)
    // =========================================================================
    data_memory #(
        .SIZE_BYTES (DMEM_SIZE_BYTES),
        .INIT_FILE  (DMEM_INIT_FILE)
    ) u_data_memory (
        .clk_i   (clk_i),
        .rst_ni  (rst_ni),
        .valid_i (s0_valid),
        .we_i    (s0_we),
        .addr_i  (s0_addr),
        .wdata_i (s0_wdata),
        .be_i    (s0_be),
        .ready_o (s0_ready),
        .rdata_o (s0_rdata),
        .error_o (s0_error)
    );

    // =========================================================================
    // 10. UART Controller Instance (Slave 1)
    // =========================================================================
    uart_controller u_uart_controller (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .valid_i   (s1_valid),
        .we_i      (s1_we),
        .addr_i    (s1_addr),
        .wdata_i   (s1_wdata),
        .be_i      (s1_be),
        .ready_o   (s1_ready),
        .rdata_o   (s1_rdata),
        .error_o   (s1_error),
        .uart_rx_i (uart_rx_sync),
        .uart_tx_o (uart_tx_o),
        .irq_o     (uart_irq)
    );

    // =========================================================================
    // 11. SPI Master Instance (Slave 2)
    // =========================================================================
    spi_master u_spi_master (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .valid_i    (s2_valid),
        .we_i       (s2_we),
        .addr_i     (s2_addr),
        .wdata_i    (s2_wdata),
        .be_i       (s2_be),
        .ready_o    (s2_ready),
        .rdata_o    (s2_rdata),
        .error_o    (s2_error),
        .spi_sclk_o (spi_sclk_o),
        .spi_mosi_o (spi_mosi_o),
        .spi_miso_i (spi_miso_sync),
        .spi_cs_no  (spi_cs_no),
        .irq_o      (spi_irq)
    );

    // =========================================================================
    // 12. Timer Instance (Slave 3)
    // =========================================================================
    timer u_timer (
        .clk_i   (clk_i),
        .rst_ni  (rst_ni),
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

    // =========================================================================
    // 13. Interrupt Controller Instance (Slave 4)
    // =========================================================================
    interrupt_controller u_interrupt_controller (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
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
        .ext_irq_i   (ext_irq_sync),
        .irq_o       (irq_o)
    );

endmodule
