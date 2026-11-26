// ============================================================================
// File: tb_immediate_generator.sv
// Project: RV32I RISC-V SoC (Phase 2 - Unit Verification)
// Description: Self-checking testbench for immediate_generator.sv.
//              Tests I, S, B, U, and J immediate generation for positive,
//              negative, all-zero, all-one, and boundary bit-offset cases.
// ============================================================================

`timescale 1ns / 1ps

module tb_immediate_generator;

    logic [31:0] instr;
    logic [2:0]  imm_type;
    logic [31:0] imm;

    immediate_generator dut (
        .instr_i   (instr),
        .imm_type_i(imm_type),
        .imm_o     (imm)
    );

    localparam [2:0] IMM_I = 3'b000;
    localparam [2:0] IMM_S = 3'b001;
    localparam [2:0] IMM_B = 3'b010;
    localparam [2:0] IMM_U = 3'b011;
    localparam [2:0] IMM_J = 3'b100;

    int test_count = 0;
    int error_count = 0;

    task check_imm(input [31:0] exp_imm, input string test_name);
        test_count++;
        #1;
        if (imm !== exp_imm) begin
            $display("[ERROR] %s: instr=0x%08h, imm_type=%0d -> got 0x%08h, expected 0x%08h",
                     test_name, instr, imm_type, imm, exp_imm);
            error_count++;
            $fatal(1, "Immediate generator failure in %s", test_name);
        end
    endtask

    initial begin
        $display("=== Starting tb_immediate_generator Verification ===");

        // 1. I-type: Positive immediate (+5) -> instr[31:20] = 12'h005
        imm_type = IMM_I;
        instr = {12'h005, 20'h00000};
        check_imm(32'h0000_0005, "I-type positive");

        // I-type: Negative immediate (-1) -> instr[31:20] = 12'hFFF
        instr = {12'hFFF, 20'h00000};
        check_imm(32'hFFFF_FFFF, "I-type -1 sign extension");

        // I-type: Max negative (-2048 = 0x800)
        instr = {12'h800, 20'h00000};
        check_imm(32'hFFFF_F800, "I-type -2048");

        // 2. S-type: imm[11:5] = instr[31:25], imm[4:0] = instr[11:7]
        imm_type = IMM_S;
        // Positive: imm = 0x1A4 (imm[11:5] = 0x0D, imm[4:0] = 0x04)
        instr = {7'h0D, 13'h0000, 5'h04, 7'h00};
        check_imm(32'h0000_01A4, "S-type positive");

        // Negative: imm = -1 (0xFFF -> imm[11:5] = 7'h7F, imm[4:0] = 5'h1F)
        instr = {7'h7F, 13'h0000, 5'h1F, 7'h00};
        check_imm(32'hFFFF_FFFF, "S-type -1 sign extension");

        // 3. B-type: imm[12|10:5|4:1|11], bit 0 = 0
        imm_type = IMM_B;
        // Positive branch +16 (13'b0_0000_0001_0000):
        // imm[12]=0, imm[11]=0, imm[10:5]=0, imm[4:1]=1000 (0x8), bit0=0
        // instr[31]=0, instr[7]=0, instr[30:25]=0, instr[11:8]=8
        instr = {1'b0, 6'b000000, 13'b0, 4'b1000, 1'b0, 7'b0};
        check_imm(32'h0000_0010, "B-type +16");

        // Negative branch -4 (13'b1_1111_1111_1100):
        // imm[12]=1 (instr[31]=1), imm[11]=1 (instr[7]=1),
        // imm[10:5]=111111 (instr[30:25]=111111), imm[4:1]=1110 (instr[11:8]=1110)
        instr = {1'b1, 6'b111111, 13'b0, 4'b1110, 1'b1, 7'b0};
        check_imm(32'hFFFF_FFFC, "B-type -4 sign extension");

        // Verify bit 0 is strictly zero for B-type
        if (imm[0] !== 1'b0) begin
            $fatal(1, "B-type bit 0 must be 0!");
        end

        // 4. U-type: imm[31:12] = instr[31:12], lower 12 bits zero
        imm_type = IMM_U;
        instr = {20'h12345, 12'h000};
        check_imm(32'h1234_5000, "U-type positive");

        instr = {20'h80000, 12'h000};
        check_imm(32'h8000_0000, "U-type high bit 1");

        // 5. J-type: imm[20|10:1|11|19:12], bit 0 = 0
        imm_type = IMM_J;
        // Positive offset +2048 (21'b0_0000_0000_1000_0000_0000):
        // imm[20]=0, imm[19:12]=00000000, imm[11]=1, imm[10:1]=0000000000
        // instr[31]=0, instr[19:12]=8'h00, instr[20]=1'b1, instr[30:21]=10'h000
        instr = {1'b0, 10'h000, 1'b1, 8'h00, 12'h000};
        check_imm(32'h0000_0800, "J-type +2048");

        // Negative offset -2 (21'b1_1111_1111_1111_1111_1110):
        // imm[20]=1, imm[19:12]=8'hFF, imm[11]=1, imm[10:1]=10'h3FF
        instr = {1'b1, 10'h3FF, 1'b1, 8'hFF, 12'h000};
        check_imm(32'hFFFF_FFFE, "J-type -2 sign extension");

        // Verify bit 0 is strictly zero for J-type
        if (imm[0] !== 1'b0) begin
            $fatal(1, "J-type bit 0 must be 0!");
        end

        $display("=== tb_immediate_generator PASSED: All %0d checks passed ===", test_count);
        $finish;
    end

endmodule
