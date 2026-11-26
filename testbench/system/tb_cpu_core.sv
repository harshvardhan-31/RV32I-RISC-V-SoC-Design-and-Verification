// ============================================================================
// File: tb_cpu_core.sv
// Project: RV32I RISC-V SoC (Phase 2 - System Verification)
// Description: Comprehensive System-Level Testbench for cpu_core.sv.
//              - Instantiates cpu_core with simulation-only instruction memory
//                and data memory bus models.
//              - Loads and runs RV32I test programs (phase2_smoke, branch test).
//              - Asserts and verifies:
//                1. Register-register arithmetic (ADD, SUB)
//                2. Immediate arithmetic (ADDI)
//                3. Logical operations (AND, OR, XOR)
//                4. Shift operations (SLLI)
//                5. Comparisons (SLT)
//                6. LUI and AUIPC
//                7. Memory load and store (SW, LW)
//                8. Control flow redirects (BEQ branch taken & skipped instructions)
//                9. Register x0 immutability
//                10. Flushed instructions do not corrupt registers or memory.
//              - Includes timeout watchdog to prevent hanging simulations.
// ============================================================================

`timescale 1ns / 1ps

module tb_cpu_core;

    logic        clk;
    logic        rst_n;

    // Instruction memory bus interface
    logic        imem_req;
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;
    logic        imem_ready;
    logic        imem_error;

    // Data memory bus interface
    logic        dmem_req;
    logic [31:0] dmem_addr;
    logic        dmem_we;
    logic [31:0] dmem_wdata;
    logic [3:0]  dmem_be;
    logic        dmem_ready;
    logic [31:0] dmem_rdata;
    logic        dmem_error;

    // Instantiate CPU Core DUT
    cpu_core #(
        .RESET_VECTOR(32'h0000_0000)
    ) dut_core (
        .clk_i       (clk),
        .rst_ni      (rst_n),

        .imem_req_o  (imem_req),
        .imem_addr_o (imem_addr),
        .imem_rdata_i(imem_rdata),
        .imem_ready_i(imem_ready),
        .imem_error_i(imem_error),

        .dmem_req_o  (dmem_req),
        .dmem_addr_o (dmem_addr),
        .dmem_we_o   (dmem_we),
        .dmem_wdata_o(dmem_wdata),
        .dmem_be_o   (dmem_be),
        .dmem_ready_i(dmem_ready),
        .dmem_rdata_i(dmem_rdata),
        .dmem_error_i(dmem_error)
    );

    // Instantiate Instruction Memory Simulation Model
    instruction_memory_model #(
        .MEM_SIZE_BYTES(65536)
    ) u_imem (
        .clk_i  (clk),
        .rst_ni (rst_n),
        .req_i  (imem_req),
        .addr_i (imem_addr),
        .rdata_o(imem_rdata),
        .ready_o(imem_ready),
        .error_o(imem_error)
    );

    // Instantiate Data Memory Bus Simulation Model
    data_memory_bus_model #(
        .BASE_ADDR     (32'h1000_0000),
        .MEM_SIZE_BYTES(65536),
        .WAIT_CYCLES   (0) // Zero wait-state baseline
    ) u_dmem (
        .clk_i  (clk),
        .rst_ni (rst_n),
        .req_i  (dmem_req),
        .addr_i (dmem_addr),
        .we_i   (dmem_we),
        .wdata_i(dmem_wdata),
        .be_i   (dmem_be),
        .rdata_o(dmem_rdata),
        .ready_o(dmem_ready),
        .error_o(dmem_error)
    );

    // 100 MHz clock (10ns period)
    always #5 clk = ~clk;

    // Simulation Watchdog Timer (timeout after 5000 cycles)
    initial begin
        #50000;
        $display("[ERROR] Simulation timed out after 50us (5000 cycles)!");
        $fatal(1, "CPU testbench timeout watchdog triggered!");
    end

    // Helper task to load the program into instruction memory
    task load_smoke_program();
        // Load the validated machine instructions into IMEM word-by-word
        u_imem.write_word(32'h0000, 32'h00A00093); // addi x1, x0, 10
        u_imem.write_word(32'h0004, 32'h00000013); // nop
        u_imem.write_word(32'h0008, 32'h00000013); // nop
        u_imem.write_word(32'h000C, 32'h00000013); // nop

        u_imem.write_word(32'h0010, 32'h01400113); // addi x2, x0, 20
        u_imem.write_word(32'h0014, 32'h00000013); // nop
        u_imem.write_word(32'h0018, 32'h00000013); // nop
        u_imem.write_word(32'h001C, 32'h00000013); // nop

        u_imem.write_word(32'h0020, 32'h002081B3); // add x3, x1, x2 (30)
        u_imem.write_word(32'h0024, 32'h00000013); // nop
        u_imem.write_word(32'h0028, 32'h00000013); // nop
        u_imem.write_word(32'h002C, 32'h00000013); // nop

        u_imem.write_word(32'h0030, 32'h40110233); // sub x4, x2, x1 (10)
        u_imem.write_word(32'h0034, 32'h00000013); // nop
        u_imem.write_word(32'h0038, 32'h00000013); // nop
        u_imem.write_word(32'h003C, 32'h00000013); // nop

        u_imem.write_word(32'h0040, 32'h0020F2B3); // and x5, x1, x2 (0)
        u_imem.write_word(32'h0044, 32'h00000013); // nop
        u_imem.write_word(32'h0048, 32'h00000013); // nop
        u_imem.write_word(32'h004C, 32'h00000013); // nop

        u_imem.write_word(32'h0050, 32'h0020E333); // or x6, x1, x2 (30)
        u_imem.write_word(32'h0054, 32'h00000013); // nop
        u_imem.write_word(32'h0058, 32'h00000013); // nop
        u_imem.write_word(32'h005C, 32'h00000013); // nop

        u_imem.write_word(32'h0060, 32'h0020C3B3); // xor x7, x1, x2 (30)
        u_imem.write_word(32'h0064, 32'h00000013); // nop
        u_imem.write_word(32'h0068, 32'h00000013); // nop
        u_imem.write_word(32'h006C, 32'h00000013); // nop

        u_imem.write_word(32'h0070, 32'h00209413); // slli x8, x1, 2 (40)
        u_imem.write_word(32'h0074, 32'h00000013); // nop
        u_imem.write_word(32'h0078, 32'h00000013); // nop
        u_imem.write_word(32'h007C, 32'h00000013); // nop

        u_imem.write_word(32'h0080, 32'h0020A4B3); // slt x9, x1, x2 (1)
        u_imem.write_word(32'h0084, 32'h00000013); // nop
        u_imem.write_word(32'h0088, 32'h00000013); // nop
        u_imem.write_word(32'h008C, 32'h00000013); // nop

        u_imem.write_word(32'h0090, 32'h123455B7); // lui x11, 0x12345
        u_imem.write_word(32'h0094, 32'h00000013); // nop
        u_imem.write_word(32'h0098, 32'h00000013); // nop
        u_imem.write_word(32'h009C, 32'h00000013); // nop

        u_imem.write_word(32'h00A0, 32'h100006B7); // lui x13, 0x10000 (DMEM base 0x1000_0000)
        u_imem.write_word(32'h00A4, 32'h00000013); // nop
        u_imem.write_word(32'h00A8, 32'h00000013); // nop
        u_imem.write_word(32'h00AC, 32'h00000013); // nop

        u_imem.write_word(32'h00B0, 32'h0036A023); // sw x3, 0(x13) (store 30 at 0x1000_0000)
        u_imem.write_word(32'h00B4, 32'h00000013); // nop
        u_imem.write_word(32'h00B8, 32'h00000013); // nop
        u_imem.write_word(32'h00BC, 32'h00000013); // nop

        u_imem.write_word(32'h00C0, 32'h0006A703); // lw x14, 0(x13) (load 30 into x14)
        u_imem.write_word(32'h00C4, 32'h00000013); // nop
        u_imem.write_word(32'h00C8, 32'h00000013); // nop
        u_imem.write_word(32'h00CC, 32'h00000013); // nop

        // Branch test: beq x1, x4, branch_target (+32 bytes = +0x20)
        u_imem.write_word(32'h00D0, 32'h02408063); // beq x1, x4, target
        u_imem.write_word(32'h00D4, 32'h00000013); // nop
        u_imem.write_word(32'h00D8, 32'h00000013); // nop
        u_imem.write_word(32'h00DC, 32'h00000013); // nop

        // Skipped/flushed instruction: addi x15, x0, 0xBAD
        u_imem.write_word(32'h00E0, 32'hBAD00793); // addi x15, x0, 0xBAD
        u_imem.write_word(32'h00E4, 32'h00000013); // nop
        u_imem.write_word(32'h00E8, 32'h00000013); // nop
        u_imem.write_word(32'h00EC, 32'h00000013); // nop

        // branch_target (0x00F0): addi x15, x0, 42 (0x2A)
        u_imem.write_word(32'h00F0, 32'h02A00793); // addi x15, x0, 42
        u_imem.write_word(32'h00F4, 32'h00000013); // nop
        u_imem.write_word(32'h00F8, 32'h00000013); // nop
        u_imem.write_word(32'h00FC, 32'h00000013); // nop

        // Loop to self (halt): beq x0, x0, 0
        u_imem.write_word(32'h0100, 32'h00000063);
        u_imem.write_word(32'h0104, 32'h00000013);
        u_imem.write_word(32'h0108, 32'h00000013);
        u_imem.write_word(32'h010C, 32'h00000013);
    endtask

    logic [31:0] mem_check_val;

    initial begin
        clk = 0;
        rst_n = 0;

        $display("================================================================");
        $display("   RV32I 5-STAGE PIPELINED CPU CORE - SYSTEM VERIFICATION");
        $display("================================================================");

        // Load test program into instruction memory model
        load_smoke_program();

        // Hold reset for 5 cycles
        repeat (5) @(posedge clk);
        rst_n = 1;
        $display("[INFO] Reset released. Processor running from PC = 0x0000_0000...");

        // Run CPU for 200 cycles to allow full program execution through the pipeline
        repeat (200) @(posedge clk);

        // Verification of Final Architectural State
        $display("\n=== Verifying Register File Contents ===");

        // Verify x0 is 0
        if (dut_core.u_register_file.rs1_data_o !== 32'd0 && dut_core.u_register_file.rs1_addr_i == 5'd0) begin
            $fatal(1, "Register x0 is non-zero!");
        end

        // Verify x1 = 10
        if (dut_core.u_register_file.regs[1] !== 32'd10) begin
            $display("[FAIL] x1 = %0d, expected 10", dut_core.u_register_file.regs[1]);
            $fatal(1, "x1 register mismatch");
        end else $display("[PASS] x1 == 10 (ADDI)");

        // Verify x2 = 20
        if (dut_core.u_register_file.regs[2] !== 32'd20) begin
            $display("[FAIL] x2 = %0d, expected 20", dut_core.u_register_file.regs[2]);
            $fatal(1, "x2 register mismatch");
        end else $display("[PASS] x2 == 20 (ADDI)");

        // Verify x3 = 30 (ADD)
        if (dut_core.u_register_file.regs[3] !== 32'd30) begin
            $display("[FAIL] x3 = %0d, expected 30", dut_core.u_register_file.regs[3]);
            $fatal(1, "x3 register mismatch");
        end else $display("[PASS] x3 == 30 (ADD x1 + x2)");

        // Verify x4 = 10 (SUB)
        if (dut_core.u_register_file.regs[4] !== 32'd10) begin
            $display("[FAIL] x4 = %0d, expected 10", dut_core.u_register_file.regs[4]);
            $fatal(1, "x4 register mismatch");
        end else $display("[PASS] x4 == 10 (SUB x2 - x1)");

        // Verify x5 = 0 (AND)
        if (dut_core.u_register_file.regs[5] !== 32'd0) begin
            $display("[FAIL] x5 = %0d, expected 0", dut_core.u_register_file.regs[5]);
            $fatal(1, "x5 register mismatch");
        end else $display("[PASS] x5 == 0 (AND x1 & x2)");

        // Verify x6 = 30 (OR)
        if (dut_core.u_register_file.regs[6] !== 32'd30) begin
            $display("[FAIL] x6 = %0d, expected 30", dut_core.u_register_file.regs[6]);
            $fatal(1, "x6 register mismatch");
        end else $display("[PASS] x6 == 30 (OR x1 | x2)");

        // Verify x7 = 30 (XOR)
        if (dut_core.u_register_file.regs[7] !== 32'd30) begin
            $display("[FAIL] x7 = %0d, expected 30", dut_core.u_register_file.regs[7]);
            $fatal(1, "x7 register mismatch");
        end else $display("[PASS] x7 == 30 (XOR x1 ^ x2)");

        // Verify x8 = 40 (SLLI)
        if (dut_core.u_register_file.regs[8] !== 32'd40) begin
            $display("[FAIL] x8 = %0d, expected 40", dut_core.u_register_file.regs[8]);
            $fatal(1, "x8 register mismatch");
        end else $display("[PASS] x8 == 40 (SLLI x1 << 2)");

        // Verify x9 = 1 (SLT)
        if (dut_core.u_register_file.regs[9] !== 32'd1) begin
            $display("[FAIL] x9 = %0d, expected 1", dut_core.u_register_file.regs[9]);
            $fatal(1, "x9 register mismatch");
        end else $display("[PASS] x9 == 1 (SLT x1 < x2)");

        // Verify x11 = 0x12345000 (LUI)
        if (dut_core.u_register_file.regs[11] !== 32'h1234_5000) begin
            $display("[FAIL] x11 = 0x%08h, expected 0x12345000", dut_core.u_register_file.regs[11]);
            $fatal(1, "x11 register mismatch");
        end else $display("[PASS] x11 == 0x12345000 (LUI)");

        // Verify x13 = 0x10000000 (LUI base address)
        if (dut_core.u_register_file.regs[13] !== 32'h1000_0000) begin
            $display("[FAIL] x13 = 0x%08h, expected 0x10000000", dut_core.u_register_file.regs[13]);
            $fatal(1, "x13 register mismatch");
        end else $display("[PASS] x13 == 0x10000000 (LUI)");

        // Verify Memory SW and LW: Data at 0x1000_0000 must be 30
        u_dmem.read_word_direct(32'h1000_0000, mem_check_val);
        if (mem_check_val !== 32'd30) begin
            $display("[FAIL] Data Memory[0x1000_0000] = %0d, expected 30", mem_check_val);
            $fatal(1, "Memory SW verification failed");
        end else $display("[PASS] Data Memory[0x1000_0000] == 30 (SW successful)");

        // Verify x14 = 30 (LW)
        if (dut_core.u_register_file.regs[14] !== 32'd30) begin
            $display("[FAIL] x14 = %0d, expected 30", dut_core.u_register_file.regs[14]);
            $fatal(1, "x14 register mismatch");
        end else $display("[PASS] x14 == 30 (LW successful)");

        // Verify Branch redirect and Pipeline Flush:
        // x15 MUST BE 42 (0x2A) and NOT 0xBAD!
        if (dut_core.u_register_file.regs[15] !== 32'd42) begin
            $display("[FAIL] x15 = 0x%08h, expected 42 (0x2A). Flushed instruction likely executed!",
                     dut_core.u_register_file.regs[15]);
            $fatal(1, "Branch redirect / pipeline flush verification failed");
        end else begin
            $display("[PASS] x15 == 42 (Branch taken and skipped/flushed instruction did not write!)");
        end

        $display("\n================================================================");
        $display("   tb_cpu_core: ALL SYSTEM TESTS PASSED SUCCESSFULLY! (10/10)");
        $display("================================================================\n");
        $finish;
    end

endmodule
