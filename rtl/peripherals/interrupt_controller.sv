// =============================================================================
// Module Name: interrupt_controller
// Description: Memory-Mapped Simple Interrupt Controller for RV32I SoC
//
// Register Map (Base: 0x2000_3000, 4 KiB aperture):
//   Offset 0x00: PENDING   (RO, bits [3:0]: 0=UART, 1=SPI, 2=Timer, 3=External)
//   Offset 0x04: ENABLE    (RW, bits [3:0]: individual source mask enable)
//   Offset 0x08: CLEAR     (W1C, bits [3:0]: write 1 to clear pending bit)
//   Offset 0x0C: PRIORITY  (Reserved, reads 32'h0, writes ignored)
//
// Interrupt Aggregation:
//   irq_o = |(PENDING & ENABLE)
//
// Priority / Race Resolution:
//   If an incoming interrupt source is asserted in the same cycle as a W1C
//   write to CLEAR for that bit, the incoming event takes priority and the
//   pending bit remains asserted.
// =============================================================================

`timescale 1ns / 1ps

module interrupt_controller (
    input  logic        clk_i,
    input  logic        rst_ni,

    // Bus Slave Interface
    input  logic        valid_i,
    input  logic        we_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic [3:0]  be_i,
    output logic        ready_o,
    output logic [31:0] rdata_o,
    output logic        error_o,

    // Peripheral Interrupt Sources
    input  logic        uart_irq_i,
    input  logic        spi_irq_i,
    input  logic        timer_irq_i,
    input  logic        ext_irq_i,

    // Aggregated SoC Interrupt Output
    output logic        irq_o
);

    // Register Offsets
    localparam logic [11:0] ADDR_PENDING  = 12'h000;
    localparam logic [11:0] ADDR_ENABLE   = 12'h004;
    localparam logic [11:0] ADDR_CLEAR    = 12'h008;
    localparam logic [11:0] ADDR_PRIORITY = 12'h00C;

    // Registers
    logic [3:0] pending_reg;
    logic [3:0] enable_reg;

    // Bus response signals
    logic        ready_q;
    logic [31:0] rdata_q;
    logic        error_q;

    assign ready_o = ready_q;
    assign rdata_o = rdata_q;
    assign error_o = error_q;

    // Aggregated output interrupt
    assign irq_o = |(pending_reg & enable_reg);

    // Group incoming interrupt sources
    logic [3:0] raw_irq_sources;
    assign raw_irq_sources = {ext_irq_i, timer_irq_i, spi_irq_i, uart_irq_i};

    // Edge / level detection registers for latching events
    logic [3:0] raw_irq_prev;

    // Bus address offset
    logic [11:0] reg_offset;
    assign reg_offset = addr_i[11:0];

    // Main Sequential Block
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            pending_reg  <= 4'b0000;
            enable_reg   <= 4'b0000;
            raw_irq_prev <= 4'b0000;
            ready_q      <= 1'b0;
            rdata_q      <= 32'h0000_0000;
            error_q      <= 1'b0;
        end else begin
            // Default response registers
            ready_q <= 1'b0;
            error_q <= 1'b0;
            raw_irq_prev <= raw_irq_sources;

            // 1. Latch incoming interrupt events into sticky pending register
            // Level-sensitive or rising-edge detected: if line is active high, latch it
            for (int i = 0; i < 4; i++) begin
                if (raw_irq_sources[i]) begin
                    pending_reg[i] <= 1'b1;
                end
            end

            // 2. Handle Bus Transactions
            if (valid_i && !ready_q) begin
                ready_q <= 1'b1;
                if (addr_i[1:0] != 2'b00) begin
                    error_q <= 1'b1;
                    rdata_q <= 32'h0000_0000;
                end else begin
                    case (reg_offset)
                        ADDR_PENDING: begin
                            rdata_q <= {28'h0, pending_reg};
                            // Read-only; writes ignored
                        end

                        ADDR_ENABLE: begin
                            rdata_q <= {28'h0, enable_reg};
                            if (we_i) begin
                                if (be_i[0]) begin
                                    enable_reg <= wdata_i[3:0];
                                end
                            end
                        end

                        ADDR_CLEAR: begin
                            rdata_q <= 32'h0000_0000;
                            if (we_i) begin
                                if (be_i[0]) begin
                                    for (int j = 0; j < 4; j++) begin
                                        if (wdata_i[j]) begin
                                            // Priority to newly arriving / active interrupt
                                            if (!raw_irq_sources[j]) begin
                                                pending_reg[j] <= 1'b0;
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        ADDR_PRIORITY: begin
                            // Reserved for future priority schemes
                            rdata_q <= 32'h0000_0000;
                        end

                        default: begin
                            // Unmapped register within aperture
                            rdata_q <= 32'h0000_0000;
                            error_q <= 1'b1;
                        end
                    endcase
                end
            end
        end
    end

endmodule
