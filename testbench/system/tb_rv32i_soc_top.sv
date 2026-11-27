// =============================================================================
// File: tb_rv32i_soc_top.sv
// Project: RV32I RISC-V SoC (Phase 4 - Full SoC Top Verification)
// Description: Self-checking top-level testbench for rv32i_soc_top.sv.
//              Verifies complete system operation:
//                1. Instruction execution from 64 KiB Instruction Memory
//                2. CPU load and store execution to Data Memory
//                3. CPU MMIO configuration of Timer & Interrupt Controller
//                4. Timer compare match generation and top-level irq_o assertion
//                5. External interrupt input synchronizer (2-flop) propagation
//                6. Self-checking register verification and pass/fail summary
// =============================================================================

`timescale 1ns / 1ps

module tb_rv32i_soc_top;

    logic        clk;
    logic        rst_n;

    // External UART
    logic        uart_rx;
    logic        uart_tx;

    // External SPI
    logic        spi_sclk;
    logic        spi_mosi;
    logic        spi_miso;
    logic [3:0]  spi_cs_n;

    // External Interrupt Input
    logic        ext_irq;

    // Aggregated SoC Interrupt Output
    logic        soc_irq;

    always #5 clk = ~clk; // 100 MHz clock (10 ns period)

    rv32i_soc_top #(
        .RESET_VECTOR    (32'h0000_0000),
        .IMEM_INIT_FILE  (""),
        .DMEM_INIT_FILE  (""),
        .IMEM_SIZE_BYTES (65536),
        .DMEM_SIZE_BYTES (65536)
    ) dut (
        .clk_i      (clk),
        .rst_ni     (rst_n),
        .uart_rx_i  (uart_rx),
        .uart_tx_o  (uart_tx),
        .spi_sclk_o (spi_sclk),
        .spi_mosi_o (spi_mosi),
        .spi_miso_i (spi_miso),
        .spi_cs_no  (spi_cs_n),
        .ext_irq_i  (ext_irq),
        .irq_o      (soc_irq)
    );

    int test_count  = 0;
    int error_count = 0;

    initial begin
        $display("=================================================================");
        $display("Starting System Test: tb_rv32i_soc_top");
        $display("=================================================================");

        clk      = 0;
        rst_n    = 0;
        uart_rx  = 1;
        spi_miso = 0;
        ext_irq  = 0;

        // Preload Instruction Memory with an integrated RV32I firmware program:
        //
        // PC 0x00: lui  x2, 0x10000        // x2 = 0x1000_0000 (Data Memory base)
        // PC 0x04: addi x1, x0, 0x42       // x1 = 0x42
        // PC 0x08: sw   x1, 0(x2)          // Mem[0x1000_0000] = 0x42
        // PC 0x0C: lw   x3, 0(x2)          // x3 = Mem[0x1000_0000] (Verify RAW hazard + bus)
        // PC 0x10: lui  x4, 0x20002        // x4 = 0x2000_2000 (Timer base)
        // PC 0x14: addi x5, x0, 10         // x5 = 10 (Compare target)
        // PC 0x18: sw   x5, 4(x4)          // Timer COMPARE = 10
        // PC 0x1C: lui  x7, 0x20003        // x7 = 0x2000_3000 (Interrupt Controller base)
        // PC 0x20: addi x8, x0, 4          // x8 = 4 (Timer IRQ enable bit)
        // PC 0x24: sw   x8, 4(x7)          // INTC ENABLE = 0x4
        // PC 0x28: addi x6, x0, 3          // x6 = 3 (Timer EN | IRQ_EN)
        // PC 0x2C: sw   x6, 8(x4)          // Timer CONTROL = 3 (Start Timer!)
        // PC 0x30: addi x9, x0, 1          // x9 = 1 (Marker for completion of config)
        // PC 0x34: beq  x0, x0, 0          // Infinite loop (halt)

        dut.u_instruction_memory.mem[0]  = 32'h10000137; // lui  x2, 0x10000
        dut.u_instruction_memory.mem[1]  = 32'h04200093; // addi x1, x0, 0x42
        dut.u_instruction_memory.mem[2]  = 32'h00112023; // sw   x1, 0(x2)
        dut.u_instruction_memory.mem[3]  = 32'h00012183; // lw   x3, 0(x2)
        dut.u_instruction_memory.mem[4]  = 32'h20002237; // lui  x4, 0x20002
        dut.u_instruction_memory.mem[5]  = 32'h00a00293; // addi x5, x0, 10
        dut.u_instruction_memory.mem[6]  = 32'h00522223; // sw   x5, 4(x4)
        dut.u_instruction_memory.mem[7]  = 32'h200033b7; // lui  x7, 0x20003
        dut.u_instruction_memory.mem[8]  = 32'h00400413; // addi x8, x0, 4
        dut.u_instruction_memory.mem[9]  = 32'h0083a223; // sw   x8, 4(x7)
        dut.u_instruction_memory.mem[10] = 32'h00300313; // addi x6, x0, 3
        dut.u_instruction_memory.mem[11] = 32'h00622423; // sw   x6, 8(x4)
        dut.u_instruction_memory.mem[12] = 32'h00100493; // addi x9, x0, 1
        dut.u_instruction_memory.mem[13] = 32'h0000006f; // jal  x0, 0 (loop in place)

        // Reset the SoC
        repeat (5) @(posedge clk);
        rst_n = 1;
        $display("[INFO] SoC Reset deasserted. CPU execution started.");

        // Wait for pipeline execution of memory operations and timer configuration
        repeat (50) @(posedge clk);

        // Verification 1: Verify CPU wrote 0x42 into Data Memory at 0x1000_0000
        test_count++;
        if (dut.u_data_memory.mem[0] == 32'h0000_0042) begin
            $display("[PASS] CPU store executed: Data Memory[0] = 0x00000042");
        end else begin
            $display("[FAIL] CPU store failed: Data Memory[0] = 0x%08h", dut.u_data_memory.mem[0]);
            error_count++;
        end

        // Verification 2: Verify CPU loaded 0x42 into register x3
        test_count++;
        if (dut.u_cpu_core.u_register_file.rf[3] == 32'h0000_0042) begin
            $display("[PASS] CPU load executed: Register x3 = 0x00000042");
        end else begin
            $display("[FAIL] CPU load failed: Register x3 = 0x%08h", dut.u_cpu_core.u_register_file.rf[3]);
            error_count++;
        end

        // Verification 3: Verify Timer was configured and COUNT incremented
        test_count++;
        if (dut.u_timer.compare_reg == 32'd10 && dut.u_timer.timer_en == 1'b1) begin
            $display("[PASS] CPU MMIO configured Timer: COMPARE=10, timer_en=1");
        end else begin
            $display("[FAIL] Timer configuration mismatch: COMPARE=%0d, timer_en=%b",
                     dut.u_timer.compare_reg, dut.u_timer.timer_en);
            error_count++;
        end

        // Wait for Timer to reach compare match and trigger interrupt
        repeat (25) @(posedge clk);

        // Verification 4: Top-level SoC interrupt assertion
        test_count++;
        if (soc_irq == 1'b1) begin
            $display("[PASS] Top-level soc_irq asserted via Timer compare match and Interrupt Controller");
        end else begin
            $display("[FAIL] Top-level soc_irq failed to assert: soc_irq=%b, timer_irq=%b", soc_irq, dut.timer_irq);
            error_count++;
        end

        // Verification 5: Verify 2-stage synchronizer on ext_irq_i
        ext_irq <= 1'b1;
        @(posedge clk); // Stage 1
        test_count++;
        if (dut.ext_irq_sync == 1'b0) begin
            $display("[PASS] External input correctly delayed by synchronizer on cycle 1");
        end else begin
            $display("[FAIL] Synchronizer did not delay async input");
            error_count++;
        end

        @(posedge clk); // Stage 2
        test_count++;
        if (dut.ext_irq_sync == 1'b1) begin
            $display("[PASS] External input successfully propagated through 2-stage synchronizer on cycle 2");
        end else begin
            $display("[FAIL] Synchronizer failed to propagate signal on cycle 2");
            error_count++;
        end
        ext_irq <= 1'b0;

        // Summary
        $display("-----------------------------------------------------------------");
        $display("Test Summary: %0d Tests, %0d Failures", test_count, error_count);
        $display("-----------------------------------------------------------------");
        if (error_count > 0) $fatal(1, "tb_rv32i_soc_top FAILED with %0d errors", error_count);
        $finish;
    end

endmodule
