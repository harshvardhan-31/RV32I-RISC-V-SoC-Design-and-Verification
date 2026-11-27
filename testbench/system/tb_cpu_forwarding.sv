// ============================================================================
// File: tb_cpu_forwarding.sv
// Project: RV32I RISC-V SoC (Phase 3 — Hazard Detection and Forwarding)
// Description: System-level testbench focused on forwarding-path correctness
//              for all supported forwarding scenarios in the five-stage pipeline.
//
//   Test sequences:
//     FWD-SEQ-A  EX/MEM→EX forwarding on consecutive ALU instructions
//     FWD-SEQ-B  MEM/WB→EX forwarding (producer two stages back)
//     FWD-SEQ-C  Branch operand forwarding (BEQ with freshly computed operands)
//     FWD-SEQ-D  JALR base-register forwarding
//     FWD-SEQ-E  Store data forwarding (SW uses forwarded rs2)
//     FWD-SEQ-F  Load-use + MEM/WB forward (LW → stall → ADD uses load result)
//
//   Simulation results: Not run — simulator not installed.
//   Run with: scripts/run_phase3_sim.sh
// ============================================================================

`timescale 1ns / 1ps

`define OPCODE_ALU_R  7'b011_0011
`define OPCODE_ALU_I  7'b001_0011
`define OPCODE_LOAD   7'b000_0011
`define OPCODE_STORE  7'b010_0011
`define OPCODE_LUI    7'b011_0111
`define OPCODE_JAL    7'b110_1111
`define OPCODE_JALR   7'b110_0111
`define OPCODE_BRANCH 7'b110_0011

`define OPCODE_NOP    32'h0000_0013

// R-type instructions
`define ADD(rd, rs1, rs2)  {7'b000_0000, 5'(rs2), 5'(rs1), 3'b000, 5'(rd), `OPCODE_ALU_R}
`define SUB(rd, rs1, rs2)  {7'b010_0000, 5'(rs2), 5'(rs1), 3'b000, 5'(rd), `OPCODE_ALU_R}
`define OR(rd, rs1, rs2)   {7'b000_0000, 5'(rs2), 5'(rs1), 3'b110, 5'(rd), `OPCODE_ALU_R}

// I-type instructions
`define ADDI(rd, rs1, imm12) {12'(imm12), 5'(rs1), 3'b000, 5'(rd), `OPCODE_ALU_I}
`define LW(rd, rs1, offset)  {12'(offset), 5'(rs1), 3'b010, 5'(rd), `OPCODE_LOAD}
`define JALR(rd, rs1, imm12) {12'(imm12), 5'(rs1), 3'b000, 5'(rd), `OPCODE_JALR}

// U-type
`define LUI(rd, imm20)       {20'(imm20), 5'(rd), `OPCODE_LUI}

// S-type
`define SW(rs2, rs1, offset) {offset[11:5], 5'(rs2), 5'(rs1), 3'b010, offset[4:0], `OPCODE_STORE}

// B-type: BEQ rs1, rs2, offset  (offset is in bytes, LSB implicit 0)
// BEQ encoding: imm[12|10:5] rs2 rs1 000 imm[4:1|11] 1100011
`define BEQ(rs1, rs2, offset) \
    {1'(offset[12]), 6'(offset[10:5]), 5'(rs2), 5'(rs1), 3'b000, \
     4'(offset[4:1]), 1'(offset[11]), `OPCODE_BRANCH}

// JAL rd, offset (21-bit signed, LSB=0)
`define JAL(rd, offset) \
    {1'(offset[20]), 10'(offset[10:1]), 1'(offset[11]), 8'(offset[19:12]), \
     5'(rd), `OPCODE_JAL}

module tb_cpu_forwarding;

    // ---- Clock and Reset ----
    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Memory interfaces ----
    logic        imem_req, imem_ready, imem_error;
    logic [31:0] imem_addr, imem_rdata;
    logic        dmem_req, dmem_we, dmem_ready, dmem_error;
    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    logic [3:0]  dmem_be;

    instruction_memory_model u_imem (
        .clk_i   (clk),   .rst_ni (rst_n),
        .req_i   (imem_req),    .addr_i  (imem_addr),
        .rdata_o (imem_rdata),  .ready_o (imem_ready), .error_o (imem_error)
    );

    data_memory_bus_model u_dmem (
        .clk_i   (clk),   .rst_ni  (rst_n),
        .req_i   (dmem_req),    .addr_i  (dmem_addr),  .we_i    (dmem_we),
        .wdata_i (dmem_wdata),  .be_i    (dmem_be),
        .ready_o (dmem_ready),  .rdata_o (dmem_rdata), .error_o (dmem_error)
    );

    cpu_core #(.RESET_VECTOR(32'h0)) u_cpu (
        .clk_i       (clk),   .rst_ni      (rst_n),
        .imem_req_o  (imem_req),   .imem_addr_o  (imem_addr),
        .imem_rdata_i(imem_rdata), .imem_ready_i (imem_ready),
        .imem_error_i(imem_error),
        .dmem_req_o  (dmem_req),   .dmem_addr_o  (dmem_addr),
        .dmem_we_o   (dmem_we),    .dmem_wdata_o (dmem_wdata),
        .dmem_be_o   (dmem_be),    .dmem_ready_i (dmem_ready),
        .dmem_rdata_i(dmem_rdata), .dmem_error_i (dmem_error)
    );

    function automatic logic [31:0] read_reg(input int rnum);
        return u_cpu.u_register_file.regs[rnum];
    endfunction

    task automatic load_imem(input logic [31:0] prog []);
        for (int i = 0; i < prog.size(); i++)
            u_imem.mem[i] = prog[i];
        for (int i = prog.size(); i < 256; i++)
            u_imem.mem[i] = `OPCODE_NOP;
    endtask

    task automatic apply_reset(input int n);
        rst_n = 0;
        repeat(n) @(posedge clk);
        @(negedge clk);
        rst_n = 1;
    endtask

    logic [31:0] prog[];
    logic [31:0] got;

    initial begin
        $dumpfile("sim_out/tb_cpu_forwarding.vcd");
        $dumpvars(0, tb_cpu_forwarding);
        rst_n = 0;

        // ================================================================
        // FWD-SEQ-A: EX/MEM→EX — back-to-back ALU with no NOPs
        //   ADDI x1, x0, 10     # x1 = 10
        //   ADD  x2, x1, x1     # x2 = 20  — EX/MEM fwd x1
        //   ADD  x3, x2, x1     # x3 = 30  — EX/MEM fwd x2, MEM/WB fwd x1
        // ================================================================
        prog = new[6];
        prog[0] = `ADDI(1, 0, 10);
        prog[1] = `ADD (2, 1, 1);
        prog[2] = `ADD (3, 2, 1);
        prog[3] = `OPCODE_NOP;
        prog[4] = `OPCODE_NOP;
        prog[5] = `OPCODE_NOP;

        apply_reset(4);
        load_imem(prog);
        apply_reset(2);
        repeat(18) @(posedge clk);

        got = read_reg(2);
        if (got !== 32'd20) $fatal(1, "FWD-SEQ-A FAIL: x2 exp 20 got %0d", got);
        got = read_reg(3);
        if (got !== 32'd30) $fatal(1, "FWD-SEQ-A FAIL: x3 exp 30 got %0d", got);
        $display("PASS FWD-SEQ-A: EX/MEM->EX and MEM/WB->EX forwarding");

        // ================================================================
        // FWD-SEQ-B: MEM/WB→EX — producer two instructions back
        //   ADDI x1, x0, 7     # x1 = 7
        //   ADDI x2, x0, 3     # x2 = 3  (independent)
        //   ADD  x3, x1, x2    # x3 = 10 — MEM/WB fwd x1; EX/MEM fwd x2
        // ================================================================
        prog = new[6];
        prog[0] = `ADDI(1, 0, 7);
        prog[1] = `ADDI(2, 0, 3);
        prog[2] = `ADD (3, 1, 2);
        prog[3] = `OPCODE_NOP;
        prog[4] = `OPCODE_NOP;
        prog[5] = `OPCODE_NOP;

        apply_reset(4);
        load_imem(prog);
        apply_reset(2);
        repeat(18) @(posedge clk);

        got = read_reg(3);
        if (got !== 32'd10) $fatal(1, "FWD-SEQ-B FAIL: x3 exp 10 got %0d", got);
        $display("PASS FWD-SEQ-B: MEM/WB->EX forwarding for 2-back producer");

        // ================================================================
        // FWD-SEQ-C: Branch operand forwarding
        //   ADDI x1, x0, 10    # x1 = 10
        //   ADDI x2, x0, 10    # x2 = 10
        //   BEQ  x1, x2, +8   # should TAKE branch (x1==x2 forwarded)
        //   ADDI x3, x0, 0xBAD # flushed — should NOT execute
        //   ADDI x3, x0, 1    # branch target — x3 = 1
        // ================================================================
        prog = new[8];
        prog[0] = `ADDI(1, 0, 10);
        prog[1] = `ADDI(2, 0, 10);
        // BEQ at addr 8 (instr index 2), offset +8 → target addr 16 (index 4)
        prog[2] = `BEQ (1, 2, 21'sd8);
        prog[3] = `ADDI(3, 0, 12'hBAD);  // Wrong path — should be flushed
        prog[4] = `ADDI(3, 0, 1);        // Branch target
        prog[5] = `OPCODE_NOP;
        prog[6] = `OPCODE_NOP;
        prog[7] = `OPCODE_NOP;

        apply_reset(4);
        load_imem(prog);
        apply_reset(2);
        repeat(22) @(posedge clk);

        got = read_reg(3);
        if (got !== 32'd1)
            $fatal(1, "FWD-SEQ-C FAIL: x3 exp 1 (branch taken) got 0x%08h", got);
        $display("PASS FWD-SEQ-C: Branch operand forwarding, correct path taken");

        // ================================================================
        // FWD-SEQ-D: JALR base-register forwarding
        //   ADDI x1, x0, 24   # x1 = 24 (JALR base = target addr)
        //   JAL  x2, +8       # jump over next instr; x2 = PC+4
        //   ADDI x3, x0, 0xBAD # flushed
        //   JALR x4, x1, 0    # jump to x1=24; x4=PC+4 — forwarded x1 from MEM/WB
        //   ... (at addr 24):
        //   ADDI x5, x0, 42   # x5 = 42 (JALR target, proves jump resolved)
        // ================================================================
        // Instruction addresses:
        //   0: ADDI x1,x0,24
        //   4: JAL x2, +8  → target=12
        //   8: ADDI x3,x0,0xBAD (flushed)
        //  12: JALR x4,x1,0 → target=24
        //  16-23: NOPs (flushed after JALR)
        //  24: ADDI x5,x0,42
        prog = new[8];
        prog[0] = `ADDI(1, 0, 24);
        prog[1] = `JAL (2, 21'sd8);
        prog[2] = `ADDI(3, 0, 12'hBAD);
        prog[3] = `JALR(4, 1, 12'sd0);
        prog[4] = `OPCODE_NOP;
        prog[5] = `OPCODE_NOP;
        prog[6] = `ADDI(5, 0, 42);
        prog[7] = `OPCODE_NOP;

        apply_reset(4);
        load_imem(prog);
        apply_reset(2);
        repeat(28) @(posedge clk);

        got = read_reg(3);
        if (got !== 32'd0)
            $fatal(1, "FWD-SEQ-D FAIL: x3 should be 0 (flushed) got 0x%08h", got);
        got = read_reg(5);
        if (got !== 32'd42)
            $fatal(1, "FWD-SEQ-D FAIL: x5 exp 42 (JALR target exec) got %0d", got);
        $display("PASS FWD-SEQ-D: JALR base-register forwarding");

        // ================================================================
        // FWD-SEQ-E: Store data forwarding
        //   ADDI x1, x0, 14   # x1 = 14
        //   LUI  x2, 0x1000   # x2 = 0x1000_0000
        //   SW   x1, 8(x2)    # M[0x1000_0008] = 14; rs2=x1 forwarded from MEM/WB
        //   LW   x3, 8(x2)    # x3 = 14 (verify store data)
        // ================================================================
        prog = new[7];
        prog[0] = `ADDI(1, 0, 14);
        prog[1] = `LUI (2, 20'h10000);
        prog[2] = `SW  (1, 2, 12'h8);
        prog[3] = `LW  (3, 2, 12'h8);
        prog[4] = `OPCODE_NOP;
        prog[5] = `OPCODE_NOP;
        prog[6] = `OPCODE_NOP;

        apply_reset(4);
        load_imem(prog);
        apply_reset(2);
        repeat(30) @(posedge clk);

        got = read_reg(3);
        if (got !== 32'd14)
            $fatal(1, "FWD-SEQ-E FAIL: x3 exp 14 got %0d", got);
        $display("PASS FWD-SEQ-E: Store data forwarding");

        // ================================================================
        // FWD-SEQ-F: Load-use hazard + MEM/WB forwarding of loaded value
        //   LUI  x1, 0x1000   # x1 = 0x1000_0000
        //   ADDI x2, x0, 99   # x2 = 99
        //   SW   x2, 0(x1)    # M[0x1000_0000] = 99
        //   LW   x3, 0(x1)    # x3 = 99  (load)
        //   ADD  x4, x3, x2   # x4 = 198 — load-use: stall, then MEM/WB fwd x3
        // ================================================================
        prog = new[8];
        prog[0] = `LUI (1, 20'h10000);
        prog[1] = `ADDI(2, 0, 99);
        prog[2] = `SW  (2, 1, 12'h0);
        prog[3] = `LW  (3, 1, 12'h0);
        prog[4] = `ADD (4, 3, 2);
        prog[5] = `OPCODE_NOP;
        prog[6] = `OPCODE_NOP;
        prog[7] = `OPCODE_NOP;

        apply_reset(4);
        load_imem(prog);
        apply_reset(2);
        repeat(35) @(posedge clk);

        got = read_reg(4);
        if (got !== 32'd198)
            $fatal(1, "FWD-SEQ-F FAIL: x4 exp 198 got %0d", got);
        $display("PASS FWD-SEQ-F: Load-use stall + MEM/WB forwarding");

        $display("");
        $display("===================================");
        $display("ALL CPU FORWARDING TESTS PASSED");
        $display("===================================");
        $finish;
    end

endmodule
