// ============================================================================
// File: tb_pipeline_registers.sv
// Project: RV32I RISC-V SoC (Phase 2 - Unit Verification)
// Description: Self-checking testbench for all four pipeline registers:
//              if_id_reg, id_ex_reg, ex_mem_reg, and mem_wb_reg.
//              Tests reset clearing, normal pipeline advance, stall (hold),
//              and flush (bubble insertion).
// ============================================================================

`timescale 1ns / 1ps

module tb_pipeline_registers;

    logic clk;
    logic rst_n;
    logic stall;
    logic flush;

    // IF/ID signals
    logic        if_valid;
    logic [31:0] if_pc, if_pc4, if_instr;
    logic        id_valid;
    logic [31:0] id_pc, id_pc4, id_instr;

    if_id_reg dut_if_id (
        .clk_i     (clk),
        .rst_ni    (rst_n),
        .stall_i   (stall),
        .flush_i   (flush),
        .valid_i   (if_valid),
        .pc_i      (if_pc),
        .pc_plus4_i(if_pc4),
        .instr_i   (if_instr),
        .valid_o   (id_valid),
        .pc_o      (id_pc),
        .pc_plus4_o(id_pc4),
        .instr_o   (id_instr)
    );

    // ID/EX signals
    logic        id_ex_val_in, id_ex_val_out;
    logic [31:0] id_ex_pc_in, id_ex_pc_out;
    logic [31:0] id_ex_pc4_in, id_ex_pc4_out;
    logic [31:0] id_ex_r1_in, id_ex_r1_out;
    logic [31:0] id_ex_r2_in, id_ex_r2_out;
    logic [31:0] id_ex_imm_in, id_ex_imm_out;
    logic [4:0]  id_ex_rd_in, id_ex_rd_out;
    logic [3:0]  id_ex_op_in, id_ex_op_out;
    logic        id_ex_rw_in, id_ex_rw_out;

    id_ex_reg dut_id_ex (
        .clk_i      (clk),
        .rst_ni     (rst_n),
        .stall_i    (stall),
        .flush_i    (flush),
        .valid_i    (id_ex_val_in),
        .pc_i       (id_ex_pc_in),
        .pc_plus4_i (id_ex_pc4_in),
        .rs1_data_i (id_ex_r1_in),
        .rs2_data_i (id_ex_r2_in),
        .imm_i      (id_ex_imm_in),
        .rs1_addr_i (5'd1),
        .rs2_addr_i (5'd2),
        .rd_addr_i  (id_ex_rd_in),
        .funct3_i   (3'd0),
        .alu_op_i   (id_ex_op_in),
        .alu_src_a_i(1'b0),
        .alu_src_b_i(1'b0),
        .branch_i   (1'b0),
        .jump_i     (1'b0),
        .jalr_i     (1'b0),
        .mem_read_i (1'b0),
        .mem_write_i(1'b0),
        .reg_write_i(id_ex_rw_in),
        .wb_sel_i   (2'b00),

        .valid_o    (id_ex_val_out),
        .pc_o       (id_ex_pc_out),
        .pc_plus4_o (id_ex_pc4_out),
        .rs1_data_o (id_ex_r1_out),
        .rs2_data_o (id_ex_r2_out),
        .imm_o      (id_ex_imm_out),
        .rs1_addr_o (),
        .rs2_addr_o (),
        .rd_addr_o  (id_ex_rd_out),
        .funct3_o   (),
        .alu_op_o   (id_ex_op_out),
        .alu_src_a_o(),
        .alu_src_b_o(),
        .branch_o   (),
        .jump_o     (),
        .jalr_o     (),
        .mem_read_o (),
        .mem_write_o(),
        .reg_write_o(id_ex_rw_out),
        .wb_sel_o   ()
    );

    // EX/MEM signals
    logic        ex_mem_val_in, ex_mem_val_out;
    logic [31:0] ex_mem_res_in, ex_mem_res_out;
    logic [4:0]  ex_mem_rd_in, ex_mem_rd_out;
    logic        ex_mem_rw_in, ex_mem_rw_out;

    ex_mem_reg dut_ex_mem (
        .clk_i       (clk),
        .rst_ni      (rst_n),
        .stall_i     (stall),
        .flush_i     (flush),
        .valid_i     (ex_mem_val_in),
        .pc_plus4_i  (32'h0000_0004),
        .alu_result_i(ex_mem_res_in),
        .rs2_data_i  (32'h0000_0000),
        .rd_addr_i   (ex_mem_rd_in),
        .funct3_i    (3'd0),
        .mem_read_i  (1'b0),
        .mem_write_i (1'b0),
        .reg_write_i (ex_mem_rw_in),
        .wb_sel_i    (2'b00),

        .valid_o     (ex_mem_val_out),
        .pc_plus4_o  (),
        .alu_result_o(ex_mem_res_out),
        .rs2_data_o  (),
        .rd_addr_o   (ex_mem_rd_out),
        .funct3_o    (),
        .mem_read_o  (),
        .mem_write_o (),
        .reg_write_o (ex_mem_rw_out),
        .wb_sel_o    ()
    );

    // MEM/WB signals
    logic        mem_wb_val_in, mem_wb_val_out;
    logic [31:0] mem_wb_data_out;
    logic [4:0]  mem_wb_rd_in, mem_wb_rd_out;
    logic        mem_wb_rw_in, mem_wb_rw_out;

    mem_wb_reg dut_mem_wb (
        .clk_i       (clk),
        .rst_ni      (rst_n),
        .stall_i     (stall),
        .flush_i     (flush),
        .valid_i     (mem_wb_val_in),
        .alu_result_i(32'h1234_5678),
        .load_data_i (32'h0000_0000),
        .pc_plus4_i  (32'h0000_0000),
        .rd_addr_i   (mem_wb_rd_in),
        .reg_write_i (mem_wb_rw_in),
        .wb_sel_i    (2'b00),

        .valid_o     (mem_wb_val_out),
        .rd_addr_o   (mem_wb_rd_out),
        .reg_write_o (mem_wb_rw_out),
        .wb_data_o   (mem_wb_data_out)
    );

    always #5 clk = ~clk;

    int test_count = 0;

    initial begin
        clk = 0; rst_n = 0; stall = 0; flush = 0;
        if_valid = 0; if_pc = 0; if_pc4 = 0; if_instr = 0;
        id_ex_val_in = 0; id_ex_pc_in = 0; id_ex_pc4_in = 0; id_ex_r1_in = 0; id_ex_r2_in = 0;
        id_ex_imm_in = 0; id_ex_rd_in = 0; id_ex_op_in = 0; id_ex_rw_in = 0;
        ex_mem_val_in = 0; ex_mem_res_in = 0; ex_mem_rd_in = 0; ex_mem_rw_in = 0;
        mem_wb_val_in = 0; mem_wb_rd_in = 0; mem_wb_rw_in = 0;

        $display("=== Starting tb_pipeline_registers Verification ===");

        // Test 1: Reset check
        @(posedge clk);
        #1;
        if (id_valid !== 0 || id_ex_val_out !== 0 || ex_mem_val_out !== 0 || mem_wb_val_out !== 0) begin
            $fatal(1, "Reset failed to clear valid flags!");
        end
        test_count++;

        // Test 2: Normal advance
        rst_n = 1;
        if_valid = 1; if_pc = 32'h0000_0100; if_pc4 = 32'h0000_0104; if_instr = 32'h00A00513;
        id_ex_val_in = 1; id_ex_pc_in = 32'h0000_00FC; id_ex_rd_in = 5'd10; id_ex_rw_in = 1;
        ex_mem_val_in = 1; ex_mem_res_in = 32'h0000_002A; ex_mem_rd_in = 5'd11; ex_mem_rw_in = 1;
        mem_wb_val_in = 1; mem_wb_rd_in = 5'd12; mem_wb_rw_in = 1;

        @(posedge clk);
        #1;
        if (id_valid !== 1 || id_pc !== 32'h0000_0100 || id_instr !== 32'h00A00513) $fatal(1, "IF/ID advance failed");
        if (id_ex_val_out !== 1 || id_ex_rd_out !== 5'd10 || id_ex_rw_out !== 1) $fatal(1, "ID/EX advance failed");
        if (ex_mem_val_out !== 1 || ex_mem_res_out !== 32'h0000_002A) $fatal(1, "EX/MEM advance failed");
        if (mem_wb_val_out !== 1 || mem_wb_data_out !== 32'h1234_5678) $fatal(1, "MEM/WB advance failed");
        test_count++;

        // Test 3: Stall check (freeze registers while inputs change)
        stall = 1;
        if_pc = 32'h0000_0200; if_instr = 32'hDEAD_BEEF;
        id_ex_rd_in = 5'd31;
        ex_mem_res_in = 32'hFFFF_FFFF;

        @(posedge clk);
        #1;
        if (id_pc !== 32'h0000_0100 || id_instr !== 32'h00A00513) $fatal(1, "IF/ID failed to hold during stall");
        if (id_ex_rd_out !== 5'd10) $fatal(1, "ID/EX failed to hold during stall");
        if (ex_mem_res_out !== 32'h0000_002A) $fatal(1, "EX/MEM failed to hold during stall");
        test_count++;

        // Test 4: Flush check (clears valid flags and converts to bubble)
        stall = 0;
        flush = 1;

        @(posedge clk);
        #1;
        if (id_valid !== 0) $fatal(1, "IF/ID flush failed to clear valid");
        if (id_ex_val_out !== 0 || id_ex_rw_out !== 0) $fatal(1, "ID/EX flush failed to clear valid/controls");
        test_count++;

        $display("=== tb_pipeline_registers PASSED: All %0d checks passed ===", test_count);
        $finish;
    end

endmodule
