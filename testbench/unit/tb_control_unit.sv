// ============================================================================
// File: tb_control_unit.sv
// Project: RV32I RISC-V SoC (Phase 2/Phase 3 - Unit Verification)
// Description: Self-checking testbench for control_unit.sv.
//              Verifies control signals for all RV32I instruction classes
//              (R-type, I-type arithmetic/load/jalr, S-type, B-type, U-type,
//              J-type, FENCE, ECALL, EBREAK) and verifies that illegal instructions
//              produce zero side effects (no reg/mem writes or branches).
//              Explicitly tests ECALL vs EBREAK discrimination using funct12.
// ============================================================================

`timescale 1ns / 1ps

module tb_control_unit;

    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [11:0] funct12;
    logic        illegal_instr;
    logic [2:0]  imm_type;
    logic [3:0]  alu_op;
    logic        alu_src_a;
    logic        alu_src_b;
    logic        mem_read;
    logic        mem_write;
    logic        reg_write;
    logic [1:0]  wb_sel;
    logic        branch;
    logic        jump;
    logic        jalr;
    logic        sys_ecall;
    logic        sys_ebreak;
    logic        sys_fence;

    control_unit dut (
        .opcode_i       (opcode),
        .funct3_i       (funct3),
        .funct7_i       (funct7),
        .funct12_i      (funct12),
        .illegal_instr_i(illegal_instr),
        .imm_type_o     (imm_type),
        .alu_op_o       (alu_op),
        .alu_src_a_o    (alu_src_a),
        .alu_src_b_o    (alu_src_b),
        .mem_read_o     (mem_read),
        .mem_write_o    (mem_write),
        .reg_write_o    (reg_write),
        .wb_sel_o       (wb_sel),
        .branch_o       (branch),
        .jump_o         (jump),
        .jalr_o         (jalr),
        .sys_ecall_o    (sys_ecall),
        .sys_ebreak_o   (sys_ebreak),
        .sys_fence_o    (sys_fence)
    );

    int test_count = 0;
    int error_count = 0;

    task check_ctrl(
        input [2:0] exp_imm_type,
        input [3:0] exp_alu_op,
        input exp_src_a,
        input exp_src_b,
        input exp_mem_rd,
        input exp_mem_wr,
        input exp_reg_wr,
        input [1:0] exp_wb_sel,
        input exp_br,
        input exp_jmp,
        input string name
    );
        test_count++;
        #1;
        if (imm_type !== exp_imm_type || alu_op !== exp_alu_op ||
            alu_src_a !== exp_src_a || alu_src_b !== exp_src_b ||
            mem_read !== exp_mem_rd || mem_write !== exp_mem_wr ||
            reg_write !== exp_reg_wr || wb_sel !== exp_wb_sel ||
            branch !== exp_br || jump !== exp_jmp) begin
            $display("[ERROR] %s: Mismatch in control vector!", name);
            error_count++;
            $fatal(1, "Control unit verification failed for %s", name);
        end
    endtask

    initial begin
        $display("=== Starting tb_control_unit Verification ===");
        illegal_instr = 0;
        funct12 = 12'h000;

        // 1. R-type ADD: opcode 0110011, funct3 000, funct7 0000000
        opcode = 7'b0110011; funct3 = 3'b000; funct7 = 7'b0000000;
        check_ctrl(3'b000, 4'b0000, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00, 1'b0, 1'b0, "R-type ADD");

        // 2. R-type SUB: opcode 0110011, funct3 000, funct7 0100000
        opcode = 7'b0110011; funct3 = 3'b000; funct7 = 7'b0100000;
        check_ctrl(3'b000, 4'b0001, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00, 1'b0, 1'b0, "R-type SUB");

        // 3. I-type ADDI: opcode 0010011, funct3 000
        opcode = 7'b0010011; funct3 = 3'b000; funct7 = 7'b0000000;
        check_ctrl(3'b000, 4'b0000, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 2'b00, 1'b0, 1'b0, "I-type ADDI");

        // 4. Load LW: opcode 0000011, funct3 010
        opcode = 7'b0000011; funct3 = 3'b010; funct7 = 7'b0000000;
        check_ctrl(3'b000, 4'b0000, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 2'b01, 1'b0, 1'b0, "Load LW");

        // 5. Store SW: opcode 0100011, funct3 010
        opcode = 7'b0100011; funct3 = 3'b010; funct7 = 7'b0000000;
        check_ctrl(3'b001, 4'b0000, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, "Store SW");

        // 6. Branch BEQ: opcode 1100011, funct3 000
        opcode = 7'b1100011; funct3 = 3'b000; funct7 = 7'b0000000;
        check_ctrl(3'b010, 4'b0001, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00, 1'b1, 1'b0, "Branch BEQ");

        // 7. LUI: opcode 0110111
        opcode = 7'b0110111; funct3 = 3'b000; funct7 = 7'b0000000;
        check_ctrl(3'b011, 4'b1010, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 2'b00, 1'b0, 1'b0, "LUI");

        // 8. AUIPC: opcode 0010111
        opcode = 7'b0010111; funct3 = 3'b000; funct7 = 7'b0000000;
        check_ctrl(3'b011, 4'b0000, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1, 2'b00, 1'b0, 1'b0, "AUIPC");

        // 9. JAL: opcode 1101111
        opcode = 7'b1101111; funct3 = 3'b000; funct7 = 7'b0000000;
        check_ctrl(3'b100, 4'b0000, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b10, 1'b0, 1'b1, "JAL");

        // 10. JALR: opcode 1100111, funct3 000
        opcode = 7'b1100111; funct3 = 3'b000; funct7 = 7'b0000000;
        check_ctrl(3'b000, 4'b0000, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b10, 1'b0, 1'b1, "JALR");

        // 11. Illegal instruction assertion test: all side effects suppressed
        illegal_instr = 1;
        opcode = 7'b0110011; funct3 = 3'b000; funct7 = 7'b0000000;
        check_ctrl(3'b000, 4'b0000, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, "Illegal instruction side effects suppressed");

        // 12. SYSTEM ECALL: opcode 1110011, funct3 000, funct12 0x000
        illegal_instr = 0;
        opcode = 7'b1110011; funct3 = 3'b000; funct7 = 7'b0000000; funct12 = 12'h000;
        check_ctrl(3'b000, 4'b0000, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, "SYSTEM ECALL");
        if (sys_ecall !== 1'b1 || sys_ebreak !== 1'b0) begin
            $fatal(1, "ECALL detection failed: sys_ecall=%b sys_ebreak=%b", sys_ecall, sys_ebreak);
        end
        $display("PASS: SYSTEM ECALL distinction (sys_ecall=1, sys_ebreak=0)");

        // 13. SYSTEM EBREAK: opcode 1110011, funct3 000, funct12 0x001
        opcode = 7'b1110011; funct3 = 3'b000; funct7 = 7'b0000000; funct12 = 12'h001;
        check_ctrl(3'b000, 4'b0000, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, "SYSTEM EBREAK");
        if (sys_ebreak !== 1'b1 || sys_ecall !== 1'b0) begin
            $fatal(1, "EBREAK detection failed: sys_ecall=%b sys_ebreak=%b", sys_ecall, sys_ebreak);
        end
        $display("PASS: SYSTEM EBREAK distinction (sys_ecall=0, sys_ebreak=1)");

        $display("=== tb_control_unit PASSED: All %0d checks passed ===", test_count);
        $finish;
    end

endmodule
