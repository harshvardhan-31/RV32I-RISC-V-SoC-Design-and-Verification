// ============================================================================
// File: tb_alu.sv
// Project: RV32I RISC-V SoC (Phase 2 - Unit Verification)
// Description: Self-checking testbench for ALU (alu.sv).
//              Verifies all arithmetic, logical, shift, comparison, and branch
//              condition operations with edge cases (overflow, sign boundaries, shamt).
// ============================================================================

`timescale 1ns / 1ps

module tb_alu;

    logic [31:0] op_a;
    logic [31:0] op_b;
    logic [3:0]  alu_op;
    logic [2:0]  funct3;
    logic [31:0] result;
    logic        branch_taken;

    // Instantiate Device Under Test
    alu dut (
        .op_a_i        (op_a),
        .op_b_i        (op_b),
        .alu_op_i      (alu_op),
        .funct3_i      (funct3),
        .result_o      (result),
        .branch_taken_o(branch_taken)
    );

    // ALU Operation Codes
    localparam [3:0] ALU_ADD    = 4'b0000;
    localparam [3:0] ALU_SUB    = 4'b0001;
    localparam [3:0] ALU_SLL    = 4'b0010;
    localparam [3:0] ALU_SLT    = 4'b0011;
    localparam [3:0] ALU_SLTU   = 4'b0100;
    localparam [3:0] ALU_XOR    = 4'b0101;
    localparam [3:0] ALU_SRL    = 4'b0110;
    localparam [3:0] ALU_SRA    = 4'b0111;
    localparam [3:0] ALU_OR     = 4'b1000;
    localparam [3:0] ALU_AND    = 4'b1001;
    localparam [3:0] ALU_PASS_B = 4'b1010;

    int test_count = 0;
    int error_count = 0;

    task check_result(input [31:0] exp_res, input string op_name);
        test_count++;
        #1;
        if (result !== exp_res) begin
            $display("[ERROR] %s: op_a=0x%08h, op_b=0x%08h -> got 0x%08h, expected 0x%08h",
                     op_name, op_a, op_b, result, exp_res);
            error_count++;
            $fatal(1, "ALU test failure in %s", op_name);
        end
    endtask

    task check_branch(input exp_taken, input string cond_name);
        test_count++;
        #1;
        if (branch_taken !== exp_taken) begin
            $display("[ERROR] Branch %s: op_a=0x%08h, op_b=0x%08h -> got %b, expected %b",
                     cond_name, op_a, op_b, branch_taken, exp_taken);
            error_count++;
            $fatal(1, "Branch comparison failure in %s", cond_name);
        end
    endtask

    initial begin
        $display("=== Starting tb_alu Verification ===");

        // 1. ADD / SUB Tests including overflow wraparound
        alu_op = ALU_ADD; funct3 = 3'b000;
        op_a = 32'd15; op_b = 32'd27; check_result(32'd42, "ADD basic");
        op_a = 32'h7FFF_FFFF; op_b = 32'd1; check_result(32'h8000_0000, "ADD positive overflow");
        op_a = 32'hFFFF_FFFF; op_b = 32'd1; check_result(32'h0000_0000, "ADD wraparound to zero");

        alu_op = ALU_SUB;
        op_a = 32'd50; op_b = 32'd20; check_result(32'd30, "SUB basic");
        op_a = 32'd0; op_b = 32'd1; check_result(32'hFFFF_FFFF, "SUB 0 - 1 (-1)");
        op_a = 32'h8000_0000; op_b = 32'd1; check_result(32'h7FFF_FFFF, "SUB negative underflow");

        // 2. Logical operations (AND, OR, XOR)
        alu_op = ALU_AND;
        op_a = 32'hF0F0_AAAA; op_b = 32'h0FF0_5555; check_result(32'h00F0_0000, "AND");

        alu_op = ALU_OR;
        op_a = 32'hF0F0_0000; op_b = 32'h000F_FFFF; check_result(32'hF0FF_FFFF, "OR");

        alu_op = ALU_XOR;
        op_a = 32'hAAAA_5555; op_b = 32'hFFFF_FFFF; check_result(32'h5555_AAAA, "XOR invert");

        // 3. Shift operations (SLL, SRL, SRA) with shift amounts 0, 1, 31, and upper bits ignored
        alu_op = ALU_SLL;
        op_a = 32'h0000_0001; op_b = 32'd0; check_result(32'h0000_0001, "SLL shamt 0");
        op_a = 32'h0000_0001; op_b = 32'd1; check_result(32'h0000_0002, "SLL shamt 1");
        op_a = 32'h0000_0001; op_b = 32'd31; check_result(32'h8000_0000, "SLL shamt 31");
        op_a = 32'h0000_0001; op_b = 32'hFFFFFFE2; check_result(32'h0000_0004, "SLL shamt masked (2)");

        alu_op = ALU_SRL;
        op_a = 32'h8000_0000; op_b = 32'd0; check_result(32'h8000_0000, "SRL shamt 0");
        op_a = 32'h8000_0000; op_b = 32'd1; check_result(32'h4000_0000, "SRL shamt 1");
        op_a = 32'h8000_0000; op_b = 32'd31; check_result(32'h0000_0001, "SRL shamt 31");

        alu_op = ALU_SRA;
        op_a = 32'h8000_0000; op_b = 32'd1; check_result(32'hC000_0000, "SRA sign preserved shamt 1");
        op_a = 32'h8000_0000; op_b = 32'd31; check_result(32'hFFFF_FFFF, "SRA sign preserved shamt 31");
        op_a = 32'h7FFF_0000; op_b = 32'd4; check_result(32'h07FF_F000, "SRA positive value");

        // 4. Comparison operations (SLT vs SLTU)
        alu_op = ALU_SLT; // Signed comparison
        op_a = 32'h8000_0000; op_b = 32'd1; check_result(32'd1, "SLT -2^31 < 1 (True)");
        op_a = 32'd1; op_b = 32'h8000_0000; check_result(32'd0, "SLT 1 < -2^31 (False)");
        op_a = 32'hFFFF_FFFF; op_b = 32'd0; check_result(32'd1, "SLT -1 < 0 (True)");
        op_a = 32'd5; op_b = 32'd5; check_result(32'd0, "SLT 5 < 5 (False)");

        alu_op = ALU_SLTU; // Unsigned comparison
        op_a = 32'h8000_0000; op_b = 32'd1; check_result(32'd0, "SLTU 0x80000000 < 1 (False)");
        op_a = 32'd1; op_b = 32'h8000_0000; check_result(32'd1, "SLTU 1 < 0x80000000 (True)");
        op_a = 32'hFFFF_FFFF; op_b = 32'd0; check_result(32'd0, "SLTU 0xFFFFFFFF < 0 (False)");

        // 5. Branch comparisons (BEQ, BNE, BLT, BGE, BLTU, BGEU)
        // BEQ (funct3 = 000)
        funct3 = 3'b000;
        op_a = 32'd42; op_b = 32'd42; check_branch(1'b1, "BEQ Equal");
        op_a = 32'd42; op_b = 32'd43; check_branch(1'b0, "BEQ Not Equal");

        // BNE (funct3 = 001)
        funct3 = 3'b001;
        op_a = 32'd42; op_b = 32'd43; check_branch(1'b1, "BNE Not Equal");
        op_a = 32'd42; op_b = 32'd42; check_branch(1'b0, "BNE Equal");

        // BLT (funct3 = 100, signed)
        funct3 = 3'b100;
        op_a = 32'hFFFF_FFFF; op_b = 32'd1; check_branch(1'b1, "BLT -1 < 1 (True)");
        op_a = 32'd1; op_b = 32'hFFFF_FFFF; check_branch(1'b0, "BLT 1 < -1 (False)");

        // BGE (funct3 = 101, signed)
        funct3 = 3'b101;
        op_a = 32'd1; op_b = 32'hFFFF_FFFF; check_branch(1'b1, "BGE 1 >= -1 (True)");
        op_a = 32'd10; op_b = 32'd10; check_branch(1'b1, "BGE Equal (True)");
        op_a = 32'hFFFF_FFFF; op_b = 32'd1; check_branch(1'b0, "BGE -1 >= 1 (False)");

        // BLTU (funct3 = 110, unsigned)
        funct3 = 3'b110;
        op_a = 32'd10; op_b = 32'd20; check_branch(1'b1, "BLTU 10 < 20 (True)");
        op_a = 32'hFFFF_FFFF; op_b = 32'd1; check_branch(1'b0, "BLTU MAX < 1 (False)");

        // BGEU (funct3 = 111, unsigned)
        funct3 = 3'b111;
        op_a = 32'hFFFF_FFFF; op_b = 32'd1; check_branch(1'b1, "BGEU MAX >= 1 (True)");
        op_a = 32'd1; op_b = 32'hFFFF_FFFF; check_branch(1'b0, "BGEU 1 >= MAX (False)");

        // 6. ALU_PASS_B
        alu_op = ALU_PASS_B;
        op_a = 32'h1234_5678; op_b = 32'hDEAD_BEEF; check_result(32'hDEAD_BEEF, "PASS_B");

        $display("=== tb_alu PASSED: %0d test vectors passed successfully without errors ===", test_count);
        $finish;
    end

endmodule
