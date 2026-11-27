// ============================================================================
// File: cpu_core.sv
// Project: RV32I RISC-V SoC (Phase 3 — Hazard Detection and Forwarding)
// Description: Top-level CPU Core integrating the 5-stage RV32I pipeline with
//              full data forwarding and hazard detection:
//
//              Stages:
//                IF  — Instruction Fetch (pc_unit, instruction memory I/F)
//                ID  — Instruction Decode (if_id_reg, decoder, imm_gen,
//                                          control_unit, register_file)
//                EX  — Execute (id_ex_reg, forwarding muxes, ALU,
//                               branch/jump target, forwarding_unit)
//                MEM — Memory Access (ex_mem_reg, load_store_unit)
//                WB  — Write Back (mem_wb_reg, register file writeback)
//
//              Phase 3 additions over Phase 2:
//                - hazard_unit: load-use stall, control-hazard flush,
//                               LSU busy interaction
//                - forwarding_unit: EX/MEM→EX and MEM/WB→EX RAW forwarding
//                - Per-stage stall/flush signals replace single stall_pipeline
//                - Forwarding muxes for rs1, rs2 before ALU src mux
//                - JALR target uses forwarded rs1
//                - Store data (rs2) uses forwarded rs2 into EX/MEM register
//
// Architecture:  RV32I 32-bit in-order five-stage pipeline
// Reset vector:  0x0000_0000 (synchronous active-low reset rst_ni)
// Forwarding:    EX/MEM priority over MEM/WB; x0 never forwarded
// Load-use:      Exactly one bubble inserted; MEM/WB forwarding resolves it
// Branch hazard: Redirect in EX; flush IF/ID and ID/EX (2-cycle penalty)
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
    // Pipeline Stall / Flush Signals  (Phase 3 — per-stage)
    // ========================================================================
    // EX-stage redirect (branch taken / jump)
    logic        redirect_valid;
    logic [31:0] redirect_pc;

    // LSU busy: data memory not ready — entire pipeline frozen
    logic        lsu_busy;

    // Hazard unit outputs
    logic        hz_stall_if;    // hold PC
    logic        hz_stall_id;    // hold IF/ID register
    logic        hz_bubble_id_ex;// insert bubble into ID/EX (flush)
    logic        hz_flush_if_id; // flush IF/ID register (control hazard)

    // Per-stage stall composition
    // PC: stall when LSU busy (whole pipeline freeze) OR load-use
    logic        pc_stall;
    assign pc_stall = lsu_busy || hz_stall_if;

    // IF/ID: stall when LSU busy OR load-use
    logic        if_id_stall;
    assign if_id_stall = lsu_busy || hz_stall_id;

    // IF/ID flush: control hazard from hazard_unit (not asserted when lsu_busy)
    logic        if_id_flush;
    assign if_id_flush = hz_flush_if_id;

    // ID/EX stall: only when LSU busy (holds the load in EX during bus wait)
    // ID/EX flush/bubble: hazard_unit bubble_id_ex (load-use bubble OR redirect)
    logic        id_ex_stall;
    logic        id_ex_bubble;
    assign id_ex_stall  = lsu_busy;
    assign id_ex_bubble = hz_bubble_id_ex;

    // EX/MEM, MEM/WB: stall only when LSU busy; flush tied low (unchanged)
    logic        exmem_stall;
    assign exmem_stall = lsu_busy;

    logic        memwb_stall;
    assign memwb_stall = lsu_busy;

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
        .stall_i      (pc_stall),         // Phase 3: lsu_busy | hz_stall_if
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

    // A valid instruction fetch occurs when reset is deasserted and imem is ready
    logic if_valid;
    assign if_valid = rst_ni && imem_ready_i;

    if_id_reg u_if_id_reg (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .stall_i   (if_id_stall),    // Phase 3: lsu_busy | hz_stall_id
        .flush_i   (if_id_flush),    // Phase 3: hz_flush_if_id (control hazard)
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
    logic [6:0]  id_opcode;
    logic [4:0]  id_rd;
    logic [2:0]  id_funct3;
    logic [4:0]  id_rs1;
    logic [4:0]  id_rs2;
    logic [6:0]  id_funct7;
    logic [11:0] id_funct12;
    logic        id_rs1_used;
    logic        id_rs2_used;
    logic        id_rd_used;
    logic        id_illegal_instr;

    instruction_decoder u_decoder (
        .instr_i        (id_instr),
        .opcode_o       (id_opcode),
        .rd_o           (id_rd),
        .funct3_o       (id_funct3),
        .rs1_o          (id_rs1),
        .rs2_o          (id_rs2),
        .funct7_o       (id_funct7),
        .funct12_o      (id_funct12),
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
        .funct12_i      (id_funct12),
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

    // Register file — two read ports (combinational), one write port (synchronous)
    logic [31:0] id_rs1_data;
    logic [31:0] id_rs2_data;

    // Writeback signals driven from MEM/WB stage (declared further below,
    // forward-referenced here because SV allows wire/logic forward references)
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
    logic [31:0] ex_rs1_data;   // register-file value of rs1 (before forwarding)
    logic [31:0] ex_rs2_data;   // register-file value of rs2 (before forwarding)
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
        .stall_i    (id_ex_stall),   // Phase 3: lsu_busy only
        .flush_i    (id_ex_bubble),  // Phase 3: load-use bubble OR redirect flush
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

    // EX/MEM pipeline register outputs — declared here for use in hazard/fwd units
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

    // ---- Hazard Detection Unit ----
    hazard_unit u_hazard_unit (
        // IF/ID: the instruction about to enter EX
        .if_id_valid_i   (id_valid),
        .if_id_rs1_i     (id_rs1),
        .if_id_rs2_i     (id_rs2),
        .if_id_rs1_used_i(id_rs1_used),
        .if_id_rs2_used_i(id_rs2_used),
        // ID/EX: the load instruction currently in EX
        .id_ex_valid_i   (ex_valid),
        .id_ex_rd_i      (ex_rd_addr),
        .id_ex_mem_read_i(ex_mem_read),
        // EX redirect and LSU busy
        .redirect_valid_i(redirect_valid),
        .lsu_busy_i      (lsu_busy),
        // Outputs
        .stall_if_o      (hz_stall_if),
        .stall_id_o      (hz_stall_id),
        .bubble_id_ex_o  (hz_bubble_id_ex),
        .flush_if_id_o   (hz_flush_if_id)
    );

    // ---- Forwarding Unit ----
    logic [1:0] fwd_sel_a;  // rs1 forwarding select
    logic [1:0] fwd_sel_b;  // rs2 forwarding select

    forwarding_unit u_forwarding_unit (
        // EX stage source registers
        .ex_rs1_addr_i    (ex_rs1_addr),
        .ex_rs2_addr_i    (ex_rs2_addr),
        // EX/MEM potential producer
        .ex_mem_valid_i   (mem_valid),
        .ex_mem_rd_addr_i (mem_rd_addr),
        .ex_mem_reg_write_i(mem_reg_write),
        .ex_mem_mem_read_i (mem_mem_read),   // load result NOT fwd from EX/MEM
        // MEM/WB potential producer
        .mem_wb_valid_i   (wb_valid),
        .mem_wb_rd_addr_i (wb_rd_addr),
        .mem_wb_reg_write_i(wb_reg_write),
        // Outputs
        .fwd_sel_a_o      (fwd_sel_a),
        .fwd_sel_b_o      (fwd_sel_b)
    );

    // ---- Forwarding Muxes ----
    // Select the most recent producer value for each source register.
    // Encoding: 2'b00=RegFile  2'b10=EX/MEM  2'b01=MEM/WB
    logic [31:0] fwd_rs1_val;
    logic [31:0] fwd_rs2_val;

    always_comb begin
        // Operand A (rs1)
        case (fwd_sel_a)
            2'b10:   fwd_rs1_val = mem_alu_result; // from EX/MEM (ALU result)
            2'b01:   fwd_rs1_val = wb_data;         // from MEM/WB (ALU or load data)
            default: fwd_rs1_val = ex_rs1_data;     // from register file via ID/EX
        endcase
        // Operand B (rs2)
        case (fwd_sel_b)
            2'b10:   fwd_rs2_val = mem_alu_result;
            2'b01:   fwd_rs2_val = wb_data;
            default: fwd_rs2_val = ex_rs2_data;
        endcase
    end

    // ---- ALU Operand Muxes ----
    // alu_src_a: 0 = rs1 (forwarded)   1 = PC   (AUIPC)
    // alu_src_b: 0 = rs2 (forwarded)   1 = immediate
    logic [31:0] alu_op_a;
    logic [31:0] alu_op_b;
    assign alu_op_a = ex_alu_src_a ? ex_pc       : fwd_rs1_val;
    assign alu_op_b = ex_alu_src_b ? ex_imm      : fwd_rs2_val;

    logic [31:0] ex_alu_result;
    logic        ex_branch_taken;

    alu u_alu (
        .op_a_i        (alu_op_a),
        .op_b_i        (alu_op_b),
        .alu_op_i      (ex_alu_op),
        .funct3_i      (ex_funct3),
        .result_o      (ex_alu_result),
        .branch_taken_o(ex_branch_taken)
    );

    // ---- Branch and Jump Target Calculation ----
    // Branch target: PC-relative (PC + sign-extended B-immediate)
    // JAL   target: PC-relative (PC + sign-extended J-immediate)
    // JALR  target: register-relative — uses forwarded rs1 so dependent JRAs work
    logic [31:0] branch_target;
    logic [31:0] jalr_target;

    assign branch_target = ex_pc + ex_imm;
    assign jalr_target   = (fwd_rs1_val + ex_imm) & ~32'd1; // Phase 3: forwarded rs1

    // ---- Redirect / Flush Logic ----
    always_comb begin
        if (ex_valid && ex_jump) begin
            // Unconditional jump (JAL / JALR) always redirects
            redirect_valid = 1'b1;
            redirect_pc    = ex_jalr ? jalr_target : branch_target;
        end else if (ex_valid && ex_branch && ex_branch_taken) begin
            // Taken conditional branch redirects to branch target
            redirect_valid = 1'b1;
            redirect_pc    = branch_target;
        end else begin
            redirect_valid = 1'b0;
            redirect_pc    = 32'h0000_0000;
        end
    end

    // redirect feeds both pc_unit and hazard_unit.
    // hazard_unit generates flush_if_id_o and bubble_id_ex_o on redirect.

    // ---- EX/MEM Pipeline Register ----
    // Store data must use the forwarded rs2 value so that:
    //   ADD x2, ...       ; SW x2, 0(x1)
    // correctly stores the just-computed x2 without a NOP.
    ex_mem_reg u_ex_mem_reg (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .stall_i     (exmem_stall),   // Phase 3: lsu_busy
        .flush_i     (1'b0),          // EX/MEM not flushed: redirect already in EX
        .valid_i     (ex_valid),
        .pc_plus4_i  (ex_pc_plus4),
        .alu_result_i(ex_alu_result),
        .rs2_data_i  (fwd_rs2_val),   // Phase 3: forwarded rs2 (store data)
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

    // ---- MEM/WB Pipeline Register ----
    mem_wb_reg u_mem_wb_reg (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .stall_i     (memwb_stall),  // Phase 3: lsu_busy
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
    // wb_data, wb_rd_addr, (wb_valid && wb_reg_write) feed register_file above.
    // wb_data and wb_rd_addr also feed the MEM/WB→EX forwarding path.

endmodule
