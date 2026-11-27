// =============================================================================
// Module Name: timer
// Description: 32-bit Memory-Mapped Hardware Timer for RV32I SoC
//
// Register Map (Base: 0x2000_2000, 4 KiB aperture):
//   Offset 0x00: COUNT      (RO, 32-bit free-running / enabled counter)
//   Offset 0x04: COMPARE    (RW, 32-bit compare threshold, reset = 32'hFFFF_FFFF)
//   Offset 0x08: CONTROL    (RW, bit 0: timer enable, bit 1: irq_en)
//   Offset 0x0C: IRQ_STATUS (W1C, bit 0: compare match flag)
//
// Handshake:
//   Single-cycle synchronous bus slave. When valid_i is asserted, ready_o
//   is asserted on the same cycle (or registered with 1-cycle latency).
//   For this peripheral, ready_o asserts 1 cycle after valid_i to adhere
//   consistently to the SoC bus standard.
// =============================================================================

`timescale 1ns / 1ps

module timer (
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

    // Interrupt Output
    output logic        irq_o
);

    // Register Offsets
    localparam logic [11:0] ADDR_COUNT      = 12'h000;
    localparam logic [11:0] ADDR_COMPARE    = 12'h004;
    localparam logic [11:0] ADDR_CONTROL    = 12'h008;
    localparam logic [11:0] ADDR_IRQ_STATUS = 12'h00C;

    // Registers
    logic [31:0] count_reg;
    logic [31:0] compare_reg;
    logic        timer_en;
    logic        irq_en;
    logic        irq_status_reg;

    // Offset decode
    logic [11:0] reg_offset;
    assign reg_offset = addr_i[11:0];

    // Bus handshake and response registers
    logic        ready_q;
    logic [31:0] rdata_q;
    logic        error_q;

    assign ready_o = ready_q;
    assign rdata_o = rdata_q;
    assign error_o = error_q;

    // Interrupt generation: active while status is 1 and interrupt is enabled
    assign irq_o = irq_status_reg & irq_en;

    // Counter and Compare Match Logic
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            count_reg      <= 32'h0000_0000;
            compare_reg    <= 32'hFFFF_FFFF;
            timer_en       <= 1'b0;
            irq_en         <= 1'b0;
            irq_status_reg <= 1'b0;
            ready_q        <= 1'b0;
            rdata_q        <= 32'h0000_0000;
            error_q        <= 1'b0;
        end else begin
            // Default 1-cycle response handshake pulse
            ready_q <= 1'b0;
            error_q <= 1'b0;

            // Timer counting logic
            if (timer_en) begin
                count_reg <= count_reg + 32'd1;
                if (count_reg == compare_reg) begin
                    irq_status_reg <= 1'b1; // Sticky compare-match flag
                end
            end

            // Bus Transaction Handling
            if (valid_i && !ready_q) begin
                ready_q <= 1'b1;
                // Check word alignment
                if (addr_i[1:0] != 2'b00) begin
                    error_q <= 1'b1;
                    rdata_q <= 32'h0000_0000;
                end else begin
                    case (reg_offset)
                        ADDR_COUNT: begin
                            rdata_q <= count_reg;
                            // COUNT is Read-Only; writes ignored (no error)
                        end

                        ADDR_COMPARE: begin
                            rdata_q <= compare_reg;
                            if (we_i) begin
                                if (be_i[0]) compare_reg[7:0]   <= wdata_i[7:0];
                                if (be_i[1]) compare_reg[15:8]  <= wdata_i[15:8];
                                if (be_i[2]) compare_reg[23:16] <= wdata_i[23:16];
                                if (be_i[3]) compare_reg[31:24] <= wdata_i[31:24];
                            end
                        end

                        ADDR_CONTROL: begin
                            rdata_q <= {30'h0, irq_en, timer_en};
                            if (we_i) begin
                                if (be_i[0]) begin
                                    timer_en <= wdata_i[0];
                                    irq_en   <= wdata_i[1];
                                end
                            end
                        end

                        ADDR_IRQ_STATUS: begin
                            rdata_q <= {31'h0, irq_status_reg};
                            if (we_i) begin
                                // Write-1-to-Clear (W1C)
                                // If compare match occurs in the exact same cycle as W1C, match takes priority
                                if (be_i[0] && wdata_i[0]) begin
                                    if (!(timer_en && (count_reg == compare_reg))) begin
                                        irq_status_reg <= 1'b0;
                                    end
                                end
                            end
                        end

                        default: begin
                            // Unmapped register within the 4 KiB aperture
                            rdata_q <= 32'h0000_0000;
                            error_q <= 1'b1;
                        end
                    endcase
                end
            end
        end
    end

endmodule
