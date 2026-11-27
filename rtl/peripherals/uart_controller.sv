// ============================================================================
// File: uart_controller.sv
// Project: RV32I RISC-V SoC (Phase 4 — Memory Subsystem and Peripheral Integration)
// Description: Synthesizable full-duplex UART controller with programmable baud rate.
//              - 8 data bits, 1 stop bit, no parity (8-N-1), LSB-first.
//              - Two-flop synchronizer for asynchronous uart_rx_i.
//              - Independent TX and RX state machines.
//              - Bus slave with stall handling on busy TX write and error on disabled TX.
//
// Register Map (Base: 0x2000_0000):
//   Offset 0x00: TXDATA   (WO) [7:0] Data to transmit (stalls if busy, error if disabled)
//   Offset 0x04: RXDATA   (RO) [7:0] Received byte (read consumes byte, clears RX valid)
//   Offset 0x08: STATUS   (RO) [4:0] Status bits:
//                                    bit 0: TX busy
//                                    bit 1: TX ready (!tx_busy)
//                                    bit 2: RX valid
//                                    bit 3: RX overrun
//                                    bit 4: RX framing error
//   Offset 0x0C: CONTROL  (RW) [3:0] Control bits:
//                                    bit 0: TX enable
//                                    bit 1: RX enable
//                                    bit 2: TX interrupt enable
//                                    bit 3: RX interrupt enable
//   Offset 0x10: BAUD_DIV (RW) [15:0] Baud rate clock divider (cycles per bit - 1)
// ============================================================================

`timescale 1ns / 1ps

module uart_controller (
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

    // External UART Serial Interface
    input  logic        uart_rx_i,
    output logic        uart_tx_o,

    // Interrupt Request Output
    output logic        irq_o
);

    // Register Offsets
    localparam [11:0] REG_TXDATA   = 12'h000;
    localparam [11:0] REG_RXDATA   = 12'h004;
    localparam [11:0] REG_STATUS   = 12'h008;
    localparam [11:0] REG_CONTROL  = 12'h00C;
    localparam [11:0] REG_BAUD_DIV = 12'h010;

    // Registers
    logic [7:0]  tx_holding_reg;
    logic        tx_holding_valid;
    logic [7:0]  rx_holding_reg;
    logic        rx_valid_q;
    logic        rx_overrun_q;
    logic        rx_framing_err_q;

    logic        ctrl_tx_en_q;
    logic        ctrl_rx_en_q;
    logic        ctrl_tx_irq_en_q;
    logic        ctrl_rx_irq_en_q;
    logic [15:0] baud_div_q;

    // 2-Flop RX Synchronizer
    logic rx_sync_m;
    logic rx_sync;
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            rx_sync_m <= 1'b1;
            rx_sync   <= 1'b1;
        end else begin
            rx_sync_m <= uart_rx_i;
            rx_sync   <= rx_sync_m;
        end
    end

    // ------------------------------------------------------------------------
    // Transmitter FSM & Logic
    // ------------------------------------------------------------------------
    typedef enum logic [1:0] {
        TX_IDLE  = 2'b00,
        TX_START = 2'b01,
        TX_DATA  = 2'b10,
        TX_STOP  = 2'b11
    } tx_state_e;

    tx_state_e   tx_state;
    logic [15:0] tx_baud_cnt;
    logic [2:0]  tx_bit_idx;
    logic [7:0]  tx_shift_reg;
    logic        tx_busy;

    assign tx_busy = (tx_state != TX_IDLE) || tx_holding_valid;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            tx_state         <= TX_IDLE;
            uart_tx_o        <= 1'b1;
            tx_baud_cnt      <= 16'd0;
            tx_bit_idx       <= 3'd0;
            tx_shift_reg     <= 8'd0;
            tx_holding_valid <= 1'b0;
            tx_holding_reg   <= 8'd0;
        end else begin
            // Latch new TX data from bus write
            if (req_i && we_i && (addr_i[11:0] == REG_TXDATA) && ctrl_tx_en_q) begin
                if (be_i[0]) begin
                    tx_holding_reg   <= wdata_i[7:0];
                    tx_holding_valid <= 1'b1;
                end
            end

            case (tx_state)
                TX_IDLE: begin
                    uart_tx_o <= 1'b1;
                    if (ctrl_tx_en_q && tx_holding_valid) begin
                        tx_shift_reg     <= tx_holding_reg;
                        tx_holding_valid <= 1'b0;
                        tx_baud_cnt      <= baud_div_q;
                        uart_tx_o        <= 1'b0; // Start bit
                        tx_state         <= TX_START;
                    end
                end

                TX_START: begin
                    if (tx_baud_cnt == 16'd0) begin
                        tx_baud_cnt <= baud_div_q;
                        tx_bit_idx  <= 3'd0;
                        uart_tx_o   <= tx_shift_reg[0];
                        tx_state    <= TX_DATA;
                    end else begin
                        tx_baud_cnt <= tx_baud_cnt - 1'b1;
                    end
                end

                TX_DATA: begin
                    if (tx_baud_cnt == 16'd0) begin
                        tx_baud_cnt <= baud_div_q;
                        if (tx_bit_idx == 3'd7) begin
                            uart_tx_o <= 1'b1; // Stop bit
                            tx_state  <= TX_STOP;
                        end else begin
                            tx_bit_idx   <= tx_bit_idx + 1'b1;
                            uart_tx_o    <= tx_shift_reg[tx_bit_idx + 1'b1];
                        end
                    end else begin
                        tx_baud_cnt <= tx_baud_cnt - 1'b1;
                    end
                end

                TX_STOP: begin
                    if (tx_baud_cnt == 16'd0) begin
                        uart_tx_o <= 1'b1;
                        if (ctrl_tx_en_q && tx_holding_valid) begin
                            tx_shift_reg     <= tx_holding_reg;
                            tx_holding_valid <= 1'b0;
                            tx_baud_cnt      <= baud_div_q;
                            uart_tx_o        <= 1'b0; // Start next frame
                            tx_state         <= TX_START;
                        end else begin
                            tx_state <= TX_IDLE;
                        end
                    end else begin
                        tx_baud_cnt <= tx_baud_cnt - 1'b1;
                    end
                end
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Receiver FSM & Logic
    // ------------------------------------------------------------------------
    typedef enum logic [1:0] {
        RX_IDLE  = 2'b00,
        RX_START = 2'b01,
        RX_DATA  = 2'b10,
        RX_STOP  = 2'b11
    } rx_state_e;

    rx_state_e   rx_state;
    logic [15:0] rx_baud_cnt;
    logic [2:0]  rx_bit_idx;
    logic [7:0]  rx_shift_reg;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            rx_state         <= RX_IDLE;
            rx_baud_cnt      <= 16'd0;
            rx_bit_idx       <= 3'd0;
            rx_shift_reg     <= 8'd0;
            rx_holding_reg   <= 8'd0;
            rx_valid_q       <= 1'b0;
            rx_overrun_q     <= 1'b0;
            rx_framing_err_q <= 1'b0;
        end else begin
            // Bus read of RXDATA consumes the byte
            if (req_i && !we_i && (addr_i[11:0] == REG_RXDATA)) begin
                rx_valid_q   <= 1'b0;
                rx_overrun_q <= 1'b0;
            end

            case (rx_state)
                RX_IDLE: begin
                    if (ctrl_rx_en_q && !rx_sync) begin
                        // Falling edge detected (Start bit candidate): sample at middle of bit
                        rx_baud_cnt <= {1'b0, baud_div_q[15:1]};
                        rx_state    <= RX_START;
                    end
                end

                RX_START: begin
                    if (rx_baud_cnt == 16'd0) begin
                        if (!rx_sync) begin // Valid start bit confirmed
                            rx_baud_cnt <= baud_div_q;
                            rx_bit_idx  <= 3'd0;
                            rx_state    <= RX_DATA;
                        end else begin
                            rx_state <= RX_IDLE; // False glitch
                        end
                    end else begin
                        rx_baud_cnt <= rx_baud_cnt - 1'b1;
                    end
                end

                RX_DATA: begin
                    if (rx_baud_cnt == 16'd0) begin
                        rx_baud_cnt                <= baud_div_q;
                        rx_shift_reg[rx_bit_idx]   <= rx_sync;
                        if (rx_bit_idx == 3'd7) begin
                            rx_state <= RX_STOP;
                        end else begin
                            rx_bit_idx <= rx_bit_idx + 1'b1;
                        end
                    end else begin
                        rx_baud_cnt <= rx_baud_cnt - 1'b1;
                    end
                end

                RX_STOP: begin
                    if (rx_baud_cnt == 16'd0) begin
                        if (rx_sync) begin // Valid stop bit
                            rx_framing_err_q <= 1'b0;
                        end else begin
                            rx_framing_err_q <= 1'b1;
                        end

                        if (rx_valid_q) begin
                            rx_overrun_q <= 1'b1; // Previous byte unread!
                        end else begin
                            rx_valid_q <= 1'b1;
                        end

                        rx_holding_reg <= rx_shift_reg;
                        rx_state       <= RX_IDLE;
                    end else begin
                        rx_baud_cnt <= rx_baud_cnt - 1'b1;
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
            ctrl_tx_en_q     <= 1'b0;
            ctrl_rx_en_q     <= 1'b0;
            ctrl_tx_irq_en_q <= 1'b0;
            ctrl_rx_irq_en_q <= 1'b0;
            baud_div_q       <= 16'd0;
            ready_o          <= 1'b0;
            error_o          <= 1'b0;
            rdata_o          <= 32'h0;
        end else begin
            if (req_i) begin
                case (addr_i[11:0])
                    REG_TXDATA: begin
                        if (we_i) begin
                            if (!ctrl_tx_en_q) begin
                                // Writing TXDATA when TX is disabled produces error
                                ready_o <= 1'b1;
                                error_o <= 1'b1;
                                rdata_o <= 32'h0;
                            end else if (tx_holding_valid) begin
                                // Stall bus until holding register accepts new byte
                                ready_o <= 1'b0;
                                error_o <= 1'b0;
                                rdata_o <= 32'h0;
                            end else begin
                                ready_o <= 1'b1;
                                error_o <= 1'b0;
                                rdata_o <= 32'h0;
                            end
                        end else begin
                            // TXDATA is Write-Only
                            ready_o <= 1'b1;
                            error_o <= 1'b1;
                            rdata_o <= 32'h0;
                        end
                    end

                    REG_RXDATA: begin
                        if (!we_i) begin
                            ready_o <= 1'b1;
                            error_o <= 1'b0;
                            rdata_o <= {24'd0, rx_holding_reg};
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
                            rdata_o <= {27'd0, rx_framing_err_q, rx_overrun_q, rx_valid_q, !tx_busy, tx_busy};
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
                                ctrl_tx_en_q     <= wdata_i[0];
                                ctrl_rx_en_q     <= wdata_i[1];
                                ctrl_tx_irq_en_q <= wdata_i[2];
                                ctrl_rx_irq_en_q <= wdata_i[3];
                            end
                            rdata_o <= 32'h0;
                        end else begin
                            rdata_o <= {28'd0, ctrl_rx_irq_en_q, ctrl_tx_irq_en_q, ctrl_rx_en_q, ctrl_tx_en_q};
                        end
                    end

                    REG_BAUD_DIV: begin
                        ready_o <= 1'b1;
                        error_o <= 1'b0;
                        if (we_i) begin
                            if (be_i[0]) baud_div_q[7:0]  <= wdata_i[7:0];
                            if (be_i[1]) baud_div_q[15:8] <= wdata_i[15:8];
                            rdata_o <= 32'h0;
                        end else begin
                            rdata_o <= {16'd0, baud_div_q};
                        end
                    end

                    default: begin
                        // Unaligned or unsupported register offset in UART range
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

    // Interrupt Generation
    assign irq_o = (ctrl_tx_irq_en_q && !tx_busy) || (ctrl_rx_irq_en_q && rx_valid_q);

endmodule
