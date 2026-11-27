// ============================================================================
// File: spi_master.sv
// Project: RV32I RISC-V SoC (Phase 4 — Memory Subsystem and Peripheral Integration)
// Description: Synthesizable 8-bit SPI Master supporting all 4 SPI modes (0, 1, 2, 3),
//              programmable clock divider, full-duplex transfer, and 4 active-low
//              chip-select outputs.
//
// Register Map (Base: 0x2000_1000):
//   Offset 0x00: TXDATA   (RW) [7:0] Data to transmit (write starts 8-bit transfer)
//   Offset 0x04: RXDATA   (RO) [7:0] Received byte (reading clears RX valid)
//   Offset 0x08: STATUS   (RO) [3:0] bit 0: Busy
//                                    bit 1: RX valid
//                                    bit 2: TX ready (!busy)
//                                    bit 3: RX overrun
//   Offset 0x0C: CONTROL  (RW) [3:0] bit 0: SPI enable
//                                    bit 1: CPOL (0: idle low, 1: idle high)
//                                    bit 2: CPHA (0: sample leading, 1: sample trailing)
//                                    bit 3: Interrupt enable
//   Offset 0x10: CLK_DIV  (RW) [15:0] Half-period divider (toggle SCLK every CLK_DIV+1 cycles)
//   Offset 0x14: CS       (RW) [1:0] Chip select index (0..3). Inactive high when idle.
// ============================================================================

`timescale 1ns / 1ps

module spi_master (
    input  logic        clk_i,
    input  logic        rst_ni,

    // Bus Slave Interface
    input  logic        req_i,
    input  logic [31:0] addr_i,
    input  logic        we_i,
    input  logic [31:0] wdata_i,
    input  logic [3:0]  be_i,
    output logic [31:0] rdata_o,
    output logic        ready_o,
    output logic        error_o,

    // External SPI Interface
    input  logic        spi_miso_i,
    output logic        spi_sclk_o,
    output logic        spi_mosi_o,
    output logic [3:0]  spi_cs_no,

    // Interrupt Request Output
    output logic        irq_o
);

    // Register Offsets
    localparam [11:0] REG_TXDATA  = 12'h000;
    localparam [11:0] REG_RXDATA  = 12'h004;
    localparam [11:0] REG_STATUS  = 12'h008;
    localparam [11:0] REG_CONTROL = 12'h00C;
    localparam [11:0] REG_CLK_DIV = 12'h010;
    localparam [11:0] REG_CS      = 12'h014;

    // Registers
    logic [7:0]  tx_data_q;
    logic [7:0]  rx_data_q;
    logic        rx_valid_q;
    logic        rx_overrun_q;

    logic        ctrl_en_q;
    logic        ctrl_cpol_q;
    logic        ctrl_cpha_q;
    logic        ctrl_irq_en_q;

    logic [15:0] clk_div_q;
    logic [1:0]  cs_sel_q;

    // SPI Transfer Engine FSM
    typedef enum logic [1:0] {
        SPI_IDLE     = 2'b00,
        SPI_LEADING  = 2'b01,
        SPI_TRAILING = 2'b10
    } spi_state_e;

    spi_state_e  state;
    logic [15:0] div_cnt;
    logic [3:0]  bit_cnt;
    logic [7:0]  tx_shift;
    logic [7:0]  rx_shift;
    logic        sclk_reg;
    logic        busy;

    assign busy = (state != SPI_IDLE);

    // Chip select: all 1 (inactive high) when idle; selected line 0 (active low) during transfer
    always_comb begin
        spi_cs_no = 4'b1111;
        if (busy && ctrl_en_q) begin
            spi_cs_no[cs_sel_q] = 1'b0;
        end
    end

    assign spi_sclk_o = busy ? sclk_reg : ctrl_cpol_q;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            state        <= SPI_IDLE;
            div_cnt      <= 16'd0;
            bit_cnt      <= 4'd0;
            tx_shift     <= 8'd0;
            rx_shift     <= 8'd0;
            rx_data_q    <= 8'd0;
            rx_valid_q   <= 1'b0;
            rx_overrun_q <= 1'b0;
            spi_mosi_o   <= 1'b0;
            sclk_reg     <= 1'b0;
        end else begin
            // Clear RX valid when RXDATA is read over bus
            if (req_i && !we_i && (addr_i[11:0] == REG_RXDATA)) begin
                rx_valid_q   <= 1'b0;
                rx_overrun_q <= 1'b0;
            end

            case (state)
                SPI_IDLE: begin
                    sclk_reg   <= ctrl_cpol_q;
                    spi_mosi_o <= 1'b0;
                    div_cnt    <= clk_div_q;

                    // Trigger transmission on write to TXDATA when enabled
                    if (req_i && we_i && (addr_i[11:0] == REG_TXDATA) && ctrl_en_q && be_i[0]) begin
                        tx_shift <= wdata_i[7:0];
                        bit_cnt  <= 4'd0;
                        state    <= SPI_LEADING;

                        if (!ctrl_cpha_q) begin
                            // CPHA=0: Drive first data bit immediately on CS assertion
                            spi_mosi_o <= wdata_i[7];
                        end
                    end
                end

                SPI_LEADING: begin
                    // SCLK moves to active edge (!CPOL)
                    sclk_reg <= ~ctrl_cpol_q;

                    if (div_cnt == 16'd0) begin
                        div_cnt <= clk_div_q;

                        if (!ctrl_cpha_q) begin
                            // CPHA=0: Sample MISO on leading edge
                            rx_shift <= {rx_shift[6:0], spi_miso_i};
                        end else begin
                            // CPHA=1: Shift next MOSI bit on leading edge
                            spi_mosi_o <= tx_shift[7 - bit_cnt];
                        end

                        state <= SPI_TRAILING;
                    end else begin
                        div_cnt <= div_cnt - 1'b1;
                    end
                end

                SPI_TRAILING: begin
                    // SCLK moves back to idle edge (CPOL)
                    sclk_reg <= ctrl_cpol_q;

                    if (div_cnt == 16'd0) begin
                        div_cnt <= clk_div_q;

                        if (!ctrl_cpha_q) begin
                            // CPHA=0: Shift next MOSI bit on trailing edge
                            if (bit_cnt < 4'd7) begin
                                spi_mosi_o <= tx_shift[6 - bit_cnt];
                            end
                        end else begin
                            // CPHA=1: Sample MISO on trailing edge
                            rx_shift <= {rx_shift[6:0], spi_miso_i};
                        end

                        if (bit_cnt == 4'd7) begin
                            // 8 bits completed
                            rx_data_q  <= (!ctrl_cpha_q) ? rx_shift : {rx_shift[6:0], spi_miso_i};
                            rx_valid_q <= 1'b1;
                            if (rx_valid_q) begin
                                rx_overrun_q <= 1'b1;
                            end
                            state <= SPI_IDLE;
                        end else begin
                            bit_cnt <= bit_cnt + 1'b1;
                            state   <= SPI_LEADING;
                        end
                    end else begin
                        div_cnt <= div_cnt - 1'b1;
                    end
                end
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Bus Interface & Register Access
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            ctrl_en_q     <= 1'b0;
            ctrl_cpol_q   <= 1'b0;
            ctrl_cpha_q   <= 1'b0;
            ctrl_irq_en_q <= 1'b0;
            clk_div_q     <= 16'd0;
            cs_sel_q      <= 2'd0;
            tx_data_q     <= 8'd0;
            ready_o       <= 1'b0;
            error_o       <= 1'b0;
            rdata_o       <= 32'h0;
        end else begin
            if (req_i) begin
                case (addr_i[11:0])
                    REG_TXDATA: begin
                        if (we_i) begin
                            if (!ctrl_en_q) begin
                                // Writing when SPI is disabled returns error
                                ready_o <= 1'b1;
                                error_o <= 1'b1;
                                rdata_o <= 32'h0;
                            end else if (busy) begin
                                // Stall bus if busy
                                ready_o <= 1'b0;
                                error_o <= 1'b0;
                                rdata_o <= 32'h0;
                            end else begin
                                ready_o <= 1'b1;
                                error_o <= 1'b0;
                                if (be_i[0]) tx_data_q <= wdata_i[7:0];
                                rdata_o <= 32'h0;
                            end
                        end else begin
                            ready_o <= 1'b1;
                            error_o <= 1'b0;
                            rdata_o <= {24'd0, tx_data_q};
                        end
                    end

                    REG_RXDATA: begin
                        if (!we_i) begin
                            ready_o <= 1'b1;
                            error_o <= 1'b0;
                            rdata_o <= {24'd0, rx_data_q};
                        end else begin
                            ready_o <= 1'b1;
                            error_o <= 1'b1; // RXDATA is Read-Only
                            rdata_o <= 32'h0;
                        end
                    end

                    REG_STATUS: begin
                        if (!we_i) begin
                            ready_o <= 1'b1;
                            error_o <= 1'b0;
                            rdata_o <= {28'd0, rx_overrun_q, !busy, rx_valid_q, busy};
                        end else begin
                            ready_o <= 1'b1;
                            error_o <= 1'b1; // STATUS is Read-Only
                            rdata_o <= 32'h0;
                        end
                    end

                    REG_CONTROL: begin
                        ready_o <= 1'b1;
                        error_o <= 1'b0;
                        if (we_i) begin
                            if (be_i[0]) begin
                                ctrl_en_q     <= wdata_i[0];
                                ctrl_cpol_q   <= wdata_i[1];
                                ctrl_cpha_q   <= wdata_i[2];
                                ctrl_irq_en_q <= wdata_i[3];
                            end
                            rdata_o <= 32'h0;
                        end else begin
                            rdata_o <= {28'd0, ctrl_irq_en_q, ctrl_cpha_q, ctrl_cpol_q, ctrl_en_q};
                        end
                    end

                    REG_CLK_DIV: begin
                        ready_o <= 1'b1;
                        error_o <= 1'b0;
                        if (we_i) begin
                            if (be_i[0]) clk_div_q[7:0]  <= wdata_i[7:0];
                            if (be_i[1]) clk_div_q[15:8] <= wdata_i[15:8];
                            rdata_o <= 32'h0;
                        end else begin
                            rdata_o <= {16'd0, clk_div_q};
                        end
                    end

                    REG_CS: begin
                        ready_o <= 1'b1;
                        error_o <= 1'b0;
                        if (we_i) begin
                            if (be_i[0]) cs_sel_q <= wdata_i[1:0];
                            rdata_o <= 32'h0;
                        end else begin
                            rdata_o <= {30'd0, cs_sel_q};
                        end
                    end

                    default: begin
                        ready_o <= 1'b1;
                        error_o <= 1'b1;
                        rdata_o <= 32'h0;
                    end
                endcase
            end else begin
                ready_o <= 1'b0;
                error_o <= 1'b0;
            end
        end
    end

    assign irq_o = ctrl_irq_en_q && rx_valid_q;

endmodule
