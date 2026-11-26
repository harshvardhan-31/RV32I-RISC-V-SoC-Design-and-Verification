// ============================================================================
// File: tb_instruction_decoder.sv
// Project: RV32I RISC-V SoC (Phase 2 - Unit Verification)
// Description: Self-checking testbench for instruction_decoder.sv.
//              Verifies field extraction for all RV32I instruction formats
//              (R, I, S, B, U, J) and validates detection of legal and illegal encodings.
// ============================================================================

`timescale 1ns / 1ps

module tb_instruction_decoder;

    logic [31:0] instr;
    logic [6:0]  opcode;
    logic [4:0]  rd;
    logic [2:0]  funct3;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [6:0]  funct7;
    logic        rs1_used;
    logic        rs2_used;
    logic        rd_used;
    logic        illegal_instr;

    instruction_decoder dut (
        .instr_i        (instr),
        .opcode_o       (opcode),
        .rd_o           (rd),
        .funct3_o       (funct3),
        .rs1_o          (rs1),
        .rs2_o          (rs2),
        .funct7_o       (funct7),
        .rs1_used_o     (rs1_used),
        .rs2_used_o     (rs2_used),
        .rd_used_o      (rd_used),
        .illegal_instr_o(illegal_instr)
    );

    int test_count = 0;
    int error_count = 0;

    task check_decode(
        input [6:0] exp_op,
        input [4:0] exp_rd,
        input [2:0] exp_f3,
        input [4:0] exp_rs1,
        input [4:0] exp_rs2,
        input [6:0] exp_f7,
        input exp_rs1_u,
        input exp_rs2_u,
        input exp_rd_u,
        input exp_illegal,
        input string test_name
    );
        test_count++;
        #1;
        if (opcode !== exp_op || rd !== exp_rd || funct3 !== exp_f3 ||
            rs1 !== exp_rs1 || rs2 !== exp_rs2 || funct7 !== exp_f7 ||
            rs1_used !== exp_rs1_u || rs2_used !== exp_rs2_u || rd_used !== exp_rd_u ||
            illegal_instr !== exp_illegal) begin
            $display("[ERROR] %s: instr=0x%08h\n  Got: op=0x%02h rd=%0d f3=%0d rs1=%0d rs2=%0d f7=0x%02h rs1_u=%b rs2_u=%b rd_u=%b ill=%b\n  Exp: op=0x%02h rd=%0d f3=%0d rs1=%0d rs2=%0d f7=0x%02h rs1_u=%b rs2_u=%b rd_u=%b ill=%b",
                     test_name, instr, opcode, rd, funct3, rs1, rs2, funct7, rs1_used, rs2_used, rd_used, illegal_instr,
                     exp_op, exp_rd, exp_f3, exp_rs1, exp_rs2, exp_f7, exp_rs1_u, exp_rs2_u, exp_rd_u, exp_illegal);
            error_count++;
            $fatal(1, "Decoder failure in %s", test_name);
        end
    endtask

    initial begin
        $display("=== Starting tb_instruction_decoder Verification ===");

        // Test 1: R-type ADD x1, x2, x3 -> funct7=0000000, rs2=3, rs1=2, funct3=000, rd=1, opcode=0110011
        // 0000000 00011 00010 000 00001 0110011 = 32'h003100B3
        instr = 32'h003100B3;
        check_decode(7'b0110011, 5'd1, 3'b000, 5'd2, 5'd3, 7'b0000000, 1'b1, 1'b1, 1'b1, 1'b0, "R-type ADD");

        // Test 2: R-type SUB x4, x5, x6 -> funct7=0100000, rs2=6, rs1=5, funct3=000, rd=4, opcode=0110011
        // 0100000 00110 00101 000 00100 0110011 = 32'h40628233
        instr = 32'h40628233;
        check_decode(7'b0110011, 5'd4, 3'b000, 5'd5, 5'd6, 7'b0100000, 1'b1, 1'b1, 1'b1, 1'b0, "R-type SUB");

        // Test 3: I-type ADDI x10, x11, -1 -> imm=-1 (0xFFF), rs1=11, funct3=000, rd=10, opcode=0010011
        // 111111111111 01011 000 01010 0010011 = 32'hFFF58513
        instr = 32'hFFF58513;
        check_decode(7'b0010011, 5'd10, 3'b000, 5'd11, 5'd31, 7'b1111111, 1'b1, 1'b0, 1'b1, 1'b0, "I-type ADDI");

        // Test 4: I-type LW x8, 16(x9) -> imm=16, rs1=9, funct3=010, rd=8, opcode=0000011
        // 000000010000 01001 010 01000 0000011 = 32'h0104A403
        instr = 32'h0104A403;
        check_decode(7'b0000011, 5'd8, 3'b010, 5'd9, 5'd0, 7'b0000000, 1'b1, 1'b0, 1'b1, 1'b0, "I-type LW");

        // Test 5: S-type SW x12, 8(x13) -> rs2=12, rs1=13, funct3=010, imm=8, opcode=0100011
        // imm[11:5]=0, rs2=12, rs1=13, funct3=010, imm[4:0]=8, opcode=0100011
        // 0000000 01100 01101 010 01000 0100011 = 32'h00C6A423
        instr = 32'h00C6A423;
        check_decode(7'b0100011, 5'd8, 3'b010, 5'd13, 5'd12, 7'b0000000, 1'b1, 1'b1, 1'b0, 1'b0, "S-type SW");

        // Test 6: B-type BEQ x14, x15, 12 -> rs2=15, rs1=14, funct3=000, opcode=1100011
        // imm=12 (12'b000000001100) -> imm[12]=0, imm[10:5]=000000, imm[4:1]=0110, imm[11]=0
        // 0 000000 01111 01110 000 0110 0 1100011 = 32'h00F70663
        instr = 32'h00F70663;
        check_decode(7'b1100011, 5'd12, 3'b000, 5'd14, 5'd15, 7'b0000000, 1'b1, 1'b1, 1'b0, 1'b0, "B-type BEQ");

        // Test 7: U-type LUI x16, 0x12345 -> imm=0x12345, rd=16, opcode=0110111
        // 00010010001101000101 10000 0110111 = 32'h12345837
        instr = 32'h12345837;
        check_decode(7'b0110111, 5'd16, 3'b100, 5'd4, 5'd26, 7'b0001001, 1'b0, 1'b0, 1'b1, 1'b0, "U-type LUI");

        // Test 8: J-type JAL x1, 40 -> rd=1, opcode=1101111
        // imm=40 (20'b00000000000000101000)
        // imm[20]=0, imm[10:1]=0000010100, imm[11]=0, imm[19:12]=00000000
        // 0 0000010100 0 00000000 00001 1101111 = 32'h028000EF
        instr = 32'h028000EF;
        check_decode(7'b1101111, 5'd1, 3'b000, 5'd0, 5'd0, 7'b0000001, 1'b0, 1'b0, 1'b1, 1'b0, "J-type JAL");

        // Test 9: Illegal Opcode -> opcode=7'b1111111
        instr = 32'hFFFF_FFFF;
        check_decode(7'b1111111, 5'd31, 3'b111, 5'd31, 5'd31, 7'b1111111, 1'b0, 1'b0, 1'b0, 1'b1, "Illegal Opcode");

        // Test 10: Illegal Funct7 for R-type ADD -> funct7=7'b0000001
        instr = 32'h023100B3;
        check_decode(7'b0110011, 5'd1, 3'b000, 5'd2, 5'd3, 7'b0000001, 1'b1, 1'b1, 1'b1, 1'b1, "Illegal Funct7");

        $display("=== tb_instruction_decoder PASSED: All %0d checks passed ===", test_count);
        $finish;
    end

endmodule
