// ============================================================================
// File: cpu_core.sv
// Project: RV32I RISC-V SoC (Phase 2 - CPU Core)
// Description: Top-level CPU Core wrapper integrating the 5-stage RV32I pipeline:
//              - Instruction Fetch (IF): pc_unit, instruction fetch interface
//              - Instruction Decode (ID): if_id_reg, decoder, imm_gen, control, regfile
//              - Execute (EX): id_ex_reg, alu, branch/jump redirect logic
//              - Memory Access (MEM): ex_mem_reg, load_store_unit, data bus interface
//              - Write Back (WB): mem_wb_reg, register writeback
//
//              Phase 2 Baseline: No forwarding unit or hazard detection unit.
//              Hazard safety achieved via NOP insertion in software.
// ============================================================================

`timescale 1ns / 1ps

module cpu_core #(
    parameter [31:0] RESET_VECTOR = 32'h0000_0000
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    // Instruction Memory Fetch Interface
    output logic        imem_req_o,
    output logic [31:0] imem_addr_o,
    input  logic [31:0] imem_rdata_i,
    input  logic        imem_ready_i,
    input  logic        imem_error_i,

    // Data Memory Bus Master Interface
    output logic        dmem_req_o,
    output logic [31:0] dmem_addr_o,
    output logic        dmem_we_o,
    output logic [31:0] dmem_wdata_o,
    output logic [3:0]  dmem_be_o,
    input  logic        dmem_ready_i,
    input  logic [31:0] dmem_rdata_i,
    input  logic        dmem_error_i
);

    // ========================================================================
    // Pipeline Control & Stall/Flush Signals
    // ========================================================================
    logic stall_pipeline;
    logic redirect_valid;
    logic [31:0] redirect_pc;
    logic flush_if_id;
    logic flush_id_ex;

    // ========================================================================
    // Stage 1: Instruction Fetch (IF)
    // ========================================================================
    logic [31:0] if_pc;
    logic [31:0] if_pc_plus4;

    pc_unit #(
        .RESET_VECTOR(RESET_VECTOR)
    ) u_pc_unit (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .stall_i      (stall_pipeline),
        .redirect_i   (redirect_valid),
        .redirect_pc_i(redirect_pc),
        .pc_o         (if_pc),
        .pc_plus4_o   (if_pc_plus4),
        .imem_req_o   (imem_req_o),
        .imem_addr_o  (imem_addr_o)
    );

    // IF/ID Pipeline Register Signals
    logic        id_valid;
    logic [31:0] id_pc;
    logic [31:0] id_pc_plus4;
    logic [31:0] id_instr;

    // Valid instruction fetch occurs when not in reset and imem is ready
    logic if_valid;
    assign if_valid = rst_ni && imem_ready_i;

    if_id_reg u_if_id_reg (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .stall_i   (stall_pipeline),
        .flush_i   (flush_if_id),
        .valid_i   (if_valid),
        .pc_i      (if_pc),
        .pc_plus4_i(if_pc_plus4),
        .instr_i   (imem_rdata_i),
        .valid_o   (id_valid),
        .pc_o      (id_pc),
        .pc_plus4_o(id_pc_plus4),
        .instr_o   (id_instr)
    );

    // ========================================================================
    // Stage 2: Instruction Decode (ID)
    // ========================================================================
    logic [6:0] id_opcode;
    logic [4:0] id_rd;
    logic [2:0] id_funct3;
    logic [4:0] id_rs1;
    logic [4:0] id_rs2;
    logic [6:0] id_funct7;
    logic       id_rs1_used;
    logic       id_rs2_used;
    logic       id_rd_used;
    logic       id_illegal_instr;

    instruction_decoder u_decoder (
        .instr_i        (id_instr),
        .opcode_o       (id_opcode),
        .rd_o           (id_rd),
        .funct3_o       (id_funct3),
        .rs1_o          (id_rs1),
        .rs2_o          (id_rs2),
        .funct7_o       (id_funct7),
        .rs1_used_o     (id_rs1_used),
        .rs2_used_o     (id_rs2_used),
        .rd_used_o      (id_rd_used),
        .illegal_instr_o(id_illegal_instr)
    );

    logic [2:0] id_imm_type;
    logic [3:0] id_alu_op;
    logic       id_alu_src_a;
    logic       id_alu_src_b;
    logic       id_mem_read;
    logic       id_mem_write;
    logic       id_reg_write;
    logic [1:0] id_wb_sel;
    logic       id_branch;
    logic       id_jump;
    logic       id_jalr;
    logic       id_sys_ecall;
    logic       id_sys_ebreak;
    logic       id_sys_fence;

    control_unit u_control_unit (
        .opcode_i       (id_opcode),
        .funct3_i       (id_funct3),
        .funct7_i       (id_funct7),
        .illegal_instr_i(id_illegal_instr),
        .imm_type_o     (id_imm_type),
        .alu_op_o       (id_alu_op),
        .alu_src_a_o    (id_alu_src_a),
        .alu_src_b_o    (id_alu_src_b),
        .mem_read_o     (id_mem_read),
        .mem_write_o    (id_mem_write),
        .reg_write_o    (id_reg_write),
        .wb_sel_o       (id_wb_sel),
        .branch_o       (id_branch),
        .jump_o         (id_jump),
        .jalr_o         (id_jalr),
        .sys_ecall_o    (id_sys_ecall),
        .sys_ebreak_o   (id_sys_ebreak),
        .sys_fence_o    (id_sys_fence)
    );

    logic [31:0] id_imm;
    immediate_generator u_imm_gen (
        .instr_i   (id_instr),
        .imm_type_i(id_imm_type),
        .imm_o     (id_imm)
    );

    // Register file read & WB write
    logic [31:0] id_rs1_data;
    logic [31:0] id_rs2_data;

    // Writeback signals from MEM/WB stage
    logic        wb_valid;
    logic [4:0]  wb_rd_addr;
    logic        wb_reg_write;
    logic [31:0] wb_data;

    register_file u_register_file (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .rs1_addr_i(id_rs1),
        .rs2_addr_i(id_rs2),
        .we_i      (wb_valid && wb_reg_write),
        .rd_addr_i (wb_rd_addr),
        .rd_data_i (wb_data),
        .rs1_data_o(id_rs1_data),
        .rs2_data_o(id_rs2_data)
    );

    // ID/EX Pipeline Register Signals
    logic        ex_valid;
    logic [31:0] ex_pc;
    logic [31:0] ex_pc_plus4;
    logic [31:0] ex_rs1_data;
    logic [31:0] ex_rs2_data;
    logic [31:0] ex_imm;
    logic [4:0]  ex_rs1_addr;
    logic [4:0]  ex_rs2_addr;
    logic [4:0]  ex_rd_addr;
    logic [2:0]  ex_funct3;
    logic [3:0]  ex_alu_op;
    logic        ex_alu_src_a;
    logic        ex_alu_src_b;
    logic        ex_branch;
    logic        ex_jump;
    logic        ex_jalr;
    logic        ex_mem_read;
    logic        ex_mem_write;
    logic        ex_reg_write;
    logic [1:0]  ex_wb_sel;

    id_ex_reg u_id_ex_reg (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .stall_i    (stall_pipeline),
        .flush_i    (flush_id_ex),
        .valid_i    (id_valid),
        .pc_i       (id_pc),
        .pc_plus4_i (id_pc_plus4),
        .rs1_data_i (id_rs1_data),
        .rs2_data_i (id_rs2_data),
        .imm_i      (id_imm),
        .rs1_addr_i (id_rs1),
        .rs2_addr_i (id_rs2),
        .rd_addr_i  (id_rd),
        .funct3_i   (id_funct3),
        .alu_op_i   (id_alu_op),
        .alu_src_a_i(id_alu_src_a),
        .alu_src_b_i(id_alu_src_b),
        .branch_i   (id_branch),
        .jump_i     (id_jump),
        .jalr_i     (id_jalr),
        .mem_read_i (id_mem_read),
        .mem_write_i(id_mem_write),
        .reg_write_i(id_reg_write),
        .wb_sel_i   (id_wb_sel),

        .valid_o    (ex_valid),
        .pc_o       (ex_pc),
        .pc_plus4_o (ex_pc_plus4),
        .rs1_data_o (ex_rs1_data),
        .rs2_data_o (ex_rs2_data),
        .imm_o      (ex_imm),
        .rs1_addr_o (ex_rs1_addr),
        .rs2_addr_o (ex_rs2_addr),
        .rd_addr_o  (ex_rd_addr),
        .funct3_o   (ex_funct3),
        .alu_op_o   (ex_alu_op),
        .alu_src_a_o(ex_alu_src_a),
        .alu_src_b_o(ex_alu_src_b),
        .branch_o   (ex_branch),
        .jump_o     (ex_jump),
        .jalr_o     (ex_jalr),
        .mem_read_o (ex_mem_read),
        .mem_write_o(ex_mem_write),
        .reg_write_o(ex_reg_write),
        .wb_sel_o   (ex_wb_sel)
    );

    // ========================================================================
    // Stage 3: Execute (EX)
    // ========================================================================
    logic [31:0] alu_op_a;
    logic [31:0] alu_op_b;
    logic [31:0] ex_alu_result;
    logic        ex_branch_taken;

    // Operand muxing
    assign alu_op_a = (ex_alu_src_a) ? ex_pc : ex_rs1_data;
    assign alu_op_b = (ex_alu_src_b) ? ex_imm : ex_rs2_data;

    alu u_alu (
        .op_a_i        (alu_op_a),
        .op_b_i        (alu_op_b),
        .alu_op_i      (ex_alu_op),
        .funct3_i      (ex_funct3),
        .result_o      (ex_alu_result),
        .branch_taken_o(ex_branch_taken)
    );

    // Branch and Jump Target Calculation
    logic [31:0] branch_target;
    logic [31:0] jalr_target;

    assign branch_target = ex_pc + ex_imm;
    assign jalr_target   = (ex_rs1_data + ex_imm) & ~32'd1;

    always_comb begin
        if (ex_valid && ex_jump) begin
            redirect_valid = 1'b1;
            redirect_pc    = ex_jalr ? jalr_target : branch_target;
        end else if (ex_valid && ex_branch && ex_branch_taken) begin
            redirect_valid = 1'b1;
            redirect_pc    = branch_target;
        end else begin
            redirect_valid = 1'b0;
            redirect_pc    = 32'h0000_0000;
        end
    end

    // Flush signals generated on redirect
    assign flush_if_id = redirect_valid;
    assign flush_id_ex = redirect_valid;

    // EX/MEM Pipeline Register Signals
    logic        mem_valid;
    logic [31:0] mem_pc_plus4;
    logic [31:0] mem_alu_result;
    logic [31:0] mem_rs2_data;
    logic [4:0]  mem_rd_addr;
    logic [2:0]  mem_funct3;
    logic        mem_mem_read;
    logic        mem_mem_write;
    logic        mem_reg_write;
    logic [1:0]  mem_wb_sel;

    ex_mem_reg u_ex_mem_reg (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .stall_i     (stall_pipeline),
        .flush_i     (1'b0), // EX/MEM is not flushed on branch taken in EX
        .valid_i     (ex_valid),
        .pc_plus4_i  (ex_pc_plus4),
        .alu_result_i(ex_alu_result),
        .rs2_data_i  (ex_rs2_data),
        .rd_addr_i   (ex_rd_addr),
        .funct3_i    (ex_funct3),
        .mem_read_i  (ex_mem_read),
        .mem_write_i (ex_mem_write),
        .reg_write_i (ex_reg_write),
        .wb_sel_i    (ex_wb_sel),

        .valid_o     (mem_valid),
        .pc_plus4_o  (mem_pc_plus4),
        .alu_result_o(mem_alu_result),
        .rs2_data_o  (mem_rs2_data),
        .rd_addr_o   (mem_rd_addr),
        .funct3_o    (mem_funct3),
        .mem_read_o  (mem_mem_read),
        .mem_write_o (mem_mem_write),
        .reg_write_o (mem_reg_write),
        .wb_sel_o    (mem_wb_sel)
    );

    // ========================================================================
    // Stage 4: Memory Access (MEM)
    // ========================================================================
    logic [31:0] mem_load_data;
    logic        lsu_busy;
    logic        lsu_error;

    load_store_unit u_lsu (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .valid_i     (mem_valid),
        .mem_read_i  (mem_mem_read),
        .mem_write_i (mem_mem_write),
        .funct3_i    (mem_funct3),
        .addr_i      (mem_alu_result),
        .wdata_i     (mem_rs2_data),
        .load_data_o (mem_load_data),
        .busy_o      (lsu_busy),
        .error_o     (lsu_error),

        .dmem_req_o  (dmem_req_o),
        .dmem_addr_o (dmem_addr_o),
        .dmem_we_o   (dmem_we_o),
        .dmem_wdata_o(dmem_wdata_o),
        .dmem_be_o   (dmem_be_o),
        .dmem_ready_i(dmem_ready_i),
        .dmem_rdata_i(dmem_rdata_i),
        .dmem_error_i(dmem_error_i)
    );

    // Stall pipeline when LSU is waiting for memory response
    assign stall_pipeline = lsu_busy;

    // MEM/WB Pipeline Register
    mem_wb_reg u_mem_wb_reg (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .stall_i     (stall_pipeline),
        .flush_i     (1'b0),
        .valid_i     (mem_valid),
        .alu_result_i(mem_alu_result),
        .load_data_i (mem_load_data),
        .pc_plus4_i  (mem_pc_plus4),
        .rd_addr_i   (mem_rd_addr),
        .reg_write_i (mem_reg_write),
        .wb_sel_i    (mem_wb_sel),

        .valid_o     (wb_valid),
        .rd_addr_o   (wb_rd_addr),
        .reg_write_o (wb_reg_write),
        .wb_data_o   (wb_data)
    );

    // ========================================================================
    // Stage 5: Write Back (WB)
    // ========================================================================
    // Handled above: wb_data, wb_rd_addr, wb_valid && wb_reg_write connect to register_file.

endmodule
