// ============================================================================
// File: tb_hazard_integration.sv
// Project: RV32I RISC-V SoC (Phase 3 — Hazard Detection and Forwarding)
// Description: System-level integration testbench verifying that the Phase 3
//              cpu_core correctly handles load-use stalls and RAW data hazards
//              through hardware forwarding — without any NOP padding.
//
//   Programs encoded directly as 32-bit words using RISC-V encoding.
//   Each test sequence is loaded into instruction_memory_model.
//   Register file final values are sampled from the DUT via hierarchical refs.
//
//   Test sequences:
//     SEQ-A  RAW ALU chain (ADD→SUB→AND): forwarded via EX/MEM and MEM/WB
//     SEQ-B  Load-use: LW followed immediately by ADD using loaded value
//     SEQ-C  Store data forwarding: ADD result stored without NOP
//     SEQ-D  Double-dependency chain: three consecutive RAW ALU instructions
//
//   Simulation results: Not run — simulator not installed in CI environment.
//   Run with: iverilog -g2012 -o sim_out/tb_hazard_integration.vvp \
//               rtl/core/*.sv testbench/models/*.sv \
//               testbench/system/tb_hazard_integration.sv && \
//             vvp sim_out/tb_hazard_integration.vvp
// ============================================================================

`timescale 1ns / 1ps

// RISC-V RV32I instruction encoding helpers
// R-type: funct7[31:25] rs2[24:20] rs1[19:15] funct3[14:12] rd[11:7] opcode[6:0]
// I-type: imm[31:20] rs1[19:15] funct3[14:12] rd[11:7] opcode[6:0]
// S-type: imm[31:25] rs2[24:20] rs1[19:15] funct3[14:12] imm[11:7] opcode[6:0]

`define OPCODE_ALU_R  7'b011_0011
`define OPCODE_ALU_I  7'b001_0011
`define OPCODE_LOAD   7'b000_0011
`define OPCODE_STORE  7'b010_0011
`define OPCODE_LUI    7'b011_0111
`define OPCODE_NOP    32'h0000_0013   // ADDI x0, x0, 0
`define OPCODE_END    32'hFFFF_FFFF   // Sentinel: end of program

// ADDI rd, rs1, imm12
`define ADDI(rd, rs1, imm12) \
    {12'(imm12), 5'(rs1), 3'b000, 5'(rd), `OPCODE_ALU_I}

// ADD rd, rs1, rs2
`define ADD(rd, rs1, rs2) \
    {7'b000_0000, 5'(rs2), 5'(rs1), 3'b000, 5'(rd), `OPCODE_ALU_R}

// SUB rd, rs1, rs2
`define SUB(rd, rs1, rs2) \
    {7'b010_0000, 5'(rs2), 5'(rs1), 3'b000, 5'(rd), `OPCODE_ALU_R}

// AND rd, rs1, rs2
`define AND(rd, rs1, rs2) \
    {7'b000_0000, 5'(rs2), 5'(rs1), 3'b111, 5'(rd), `OPCODE_ALU_R}

// LUI rd, imm20 (upper 20 bits)
`define LUI(rd, imm20) \
    {20'(imm20), 5'(rd), `OPCODE_LUI}

// LW rd, offset(rs1)
`define LW(rd, rs1, offset) \
    {12'(offset), 5'(rs1), 3'b010, 5'(rd), `OPCODE_LOAD}

// SW rs2, offset(rs1)
`define SW(rs2, rs1, offset) \
    {offset[11:5], 5'(rs2), 5'(rs1), 3'b010, offset[4:0], `OPCODE_STORE}

module tb_hazard_integration;

    // ---- Clock and Reset ----
    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz

    // ---- Instruction Memory ----
    logic        imem_req;
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;
    logic        imem_ready;
    logic        imem_error;

    // ---- Data Memory ----
    logic        dmem_req;
    logic [31:0] dmem_addr;
    logic        dmem_we;
    logic [31:0] dmem_wdata;
    logic [3:0]  dmem_be;
    logic        dmem_ready;
    logic [31:0] dmem_rdata;
    logic        dmem_error;

    // ---- Instruction Memory Model ----
    instruction_memory_model u_imem (
        .clk_i      (clk),
        .rst_ni     (rst_n),
        .req_i      (imem_req),
        .addr_i     (imem_addr),
        .rdata_o    (imem_rdata),
        .ready_o    (imem_ready),
        .error_o    (imem_error)
    );

    // ---- Data Memory Bus Model ----
    data_memory_bus_model u_dmem (
        .clk_i      (clk),
        .rst_ni     (rst_n),
        .req_i      (dmem_req),
        .addr_i     (dmem_addr),
        .we_i       (dmem_we),
        .wdata_i    (dmem_wdata),
        .be_i       (dmem_be),
        .ready_o    (dmem_ready),
        .rdata_o    (dmem_rdata),
        .error_o    (dmem_error)
    );

    // ---- DUT ----
    cpu_core #(.RESET_VECTOR(32'h0)) u_cpu (
        .clk_i      (clk),
        .rst_ni     (rst_n),
        .imem_req_o (imem_req),
        .imem_addr_o(imem_addr),
        .imem_rdata_i(imem_rdata),
        .imem_ready_i(imem_ready),
        .imem_error_i(imem_error),
        .dmem_req_o (dmem_req),
        .dmem_addr_o(dmem_addr),
        .dmem_we_o  (dmem_we),
        .dmem_wdata_o(dmem_wdata),
        .dmem_be_o  (dmem_be),
        .dmem_ready_i(dmem_ready),
        .dmem_rdata_i(dmem_rdata),
        .dmem_error_i(dmem_error)
    );

    // ---- Helper: load instruction memory ----
    task automatic load_imem(input logic [31:0] prog []);
        int i;
        for (i = 0; i < prog.size(); i++) begin
            u_imem.mem[i] = prog[i];
        end
        // Fill rest with NOPs
        for (i = prog.size(); i < 256; i++) begin
            u_imem.mem[i] = `OPCODE_NOP;
        end
    endtask

    // ---- Helper: read register file value ----
    // Accesses register file through hierarchical reference
    function automatic logic [31:0] read_reg(input int rnum);
        return u_cpu.u_register_file.regs[rnum];
    endfunction

    // ---- Helper: apply reset ----
    task automatic apply_reset(input int cycles);
        rst_n = 1'b0;
        repeat(cycles) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
    endtask

    // ---- Helper: run N clock cycles ----
    task automatic run_cycles(input int n);
        repeat(n) @(posedge clk);
    endtask

    // ---- Waveform dump ----
    initial begin
        $dumpfile("sim_out/tb_hazard_integration.vcd");
        $dumpvars(0, tb_hazard_integration);
    end

    // ---- Test body ----
    logic [31:0] prog_a[];
    logic [31:0] prog_b[];
    logic [31:0] prog_c[];
    logic [31:0] prog_d[];
    logic [31:0] got;

    initial begin
        rst_n = 1'b0;

        // ================================================================
        // SEQ-A: RAW ALU chain — forwarding resolves without NOPs
        //   ADDI x1, x0, 5    # x1 = 5
        //   ADDI x2, x0, 3    # x2 = 3
        //   ADD  x3, x1, x2   # x3 = 8  — RAW on x1 (EX/MEM→EX) and x2
        //   SUB  x4, x3, x1   # x4 = 3  — RAW on x3 (EX/MEM→EX)
        //   AND  x5, x3, x4   # x5 = 0  — RAW on x3 (MEM/WB→EX), x4 (EX/MEM→EX)
        // ================================================================
        prog_a = new[8];
        prog_a[0] = `ADDI(1, 0, 5);
        prog_a[1] = `ADDI(2, 0, 3);
        prog_a[2] = `ADD (3, 1, 2);
        prog_a[3] = `SUB (4, 3, 1);
        prog_a[4] = `AND (5, 3, 4);
        prog_a[5] = `OPCODE_NOP;
        prog_a[6] = `OPCODE_NOP;
        prog_a[7] = `OPCODE_NOP;

        apply_reset(4);
        load_imem(prog_a);
        apply_reset(2);

        run_cycles(20);  // Allow pipeline to drain

        got = read_reg(1);
        if (got !== 32'd5)
            $fatal(1, "SEQ-A FAIL: x1 expected 5 got %0d", got);
        got = read_reg(2);
        if (got !== 32'd3)
            $fatal(1, "SEQ-A FAIL: x2 expected 3 got %0d", got);
        got = read_reg(3);
        if (got !== 32'd8)
            $fatal(1, "SEQ-A FAIL: x3 expected 8 got %0d", got);
        got = read_reg(4);
        if (got !== 32'd3)
            $fatal(1, "SEQ-A FAIL: x4 expected 3 got %0d", got);
        got = read_reg(5);
        if (got !== 32'd0)
            $fatal(1, "SEQ-A FAIL: x5 expected 0 got %0d", got);
        $display("PASS SEQ-A: RAW ALU chain forwarding");

        // ================================================================
        // SEQ-B: Load-use — exactly one stall bubble inserted automatically
        //   LUI  x1, 0x1000   # x1 = 0x1000_0000
        //   ADDI x2, x0, 42   # x2 = 42
        //   SW   x2, 0(x1)    # M[0x1000_0000] = 42
        //   LW   x3, 0(x1)    # x3 = 42  (load)
        //   ADD  x4, x3, x2   # x4 = 84  — load-use: hazard_unit inserts bubble
        // ================================================================
        prog_b = new[8];
        prog_b[0] = `LUI  (1, 20'h10000);
        prog_b[1] = `ADDI (2, 0, 42);
        prog_b[2] = `SW   (2, 1, 12'h0);
        prog_b[3] = `LW   (3, 1, 12'h0);
        prog_b[4] = `ADD  (4, 3, 2);
        prog_b[5] = `OPCODE_NOP;
        prog_b[6] = `OPCODE_NOP;
        prog_b[7] = `OPCODE_NOP;

        apply_reset(4);
        load_imem(prog_b);
        apply_reset(2);

        run_cycles(30);

        got = read_reg(3);
        if (got !== 32'd42)
            $fatal(1, "SEQ-B FAIL: x3 (loaded) expected 42 got %0d", got);
        got = read_reg(4);
        if (got !== 32'd84)
            $fatal(1, "SEQ-B FAIL: x4 expected 84 got %0d", got);
        $display("PASS SEQ-B: Load-use stall with MEM/WB forwarding");

        // ================================================================
        // SEQ-C: Store data forwarding — computed value stored immediately
        //   ADDI x1, x0, 7    # x1 = 7
        //   ADD  x2, x1, x1   # x2 = 14 — RAW on x1
        //   LUI  x3, 0x1000   # x3 = 0x1000_0000
        //   SW   x2, 4(x3)    # M[0x1000_0004] = 14 — store data fwd from EX/MEM
        //   LW   x4, 4(x3)    # x4 = 14 — verify
        // ================================================================
        prog_c = new[8];
        prog_c[0] = `ADDI (1, 0, 7);
        prog_c[1] = `ADD  (2, 1, 1);
        prog_c[2] = `LUI  (3, 20'h10000);
        prog_c[3] = `SW   (2, 3, 12'h4);
        prog_c[4] = `LW   (4, 3, 12'h4);
        prog_c[5] = `OPCODE_NOP;
        prog_c[6] = `OPCODE_NOP;
        prog_c[7] = `OPCODE_NOP;

        apply_reset(4);
        load_imem(prog_c);
        apply_reset(2);

        run_cycles(35);

        got = read_reg(4);
        if (got !== 32'd14)
            $fatal(1, "SEQ-C FAIL: x4 expected 14 got %0d", got);
        $display("PASS SEQ-C: Store data forwarding");

        // ================================================================
        // SEQ-D: Triple-dependency chain
        //   ADDI x1, x0, 1    # x1 = 1
        //   ADD  x2, x1, x1   # x2 = 2  — fwd x1 from EX/MEM
        //   ADD  x3, x2, x1   # x3 = 3  — fwd x2 from EX/MEM, x1 from MEM/WB
        //   ADD  x4, x3, x2   # x4 = 5  — fwd x3 from EX/MEM, x2 from MEM/WB
        // ================================================================
        prog_d = new[8];
        prog_d[0] = `ADDI (1, 0, 1);
        prog_d[1] = `ADD  (2, 1, 1);
        prog_d[2] = `ADD  (3, 2, 1);
        prog_d[3] = `ADD  (4, 3, 2);
        prog_d[4] = `OPCODE_NOP;
        prog_d[5] = `OPCODE_NOP;
        prog_d[6] = `OPCODE_NOP;
        prog_d[7] = `OPCODE_NOP;

        apply_reset(4);
        load_imem(prog_d);
        apply_reset(2);

        run_cycles(20);

        got = read_reg(2);
        if (got !== 32'd2)
            $fatal(1, "SEQ-D FAIL: x2 expected 2 got %0d", got);
        got = read_reg(3);
        if (got !== 32'd3)
            $fatal(1, "SEQ-D FAIL: x3 expected 3 got %0d", got);
        got = read_reg(4);
        if (got !== 32'd5)
            $fatal(1, "SEQ-D FAIL: x4 expected 5 got %0d", got);
        $display("PASS SEQ-D: Triple-dependency forwarding chain");

        $display("");
        $display("=========================================");
        $display("ALL HAZARD INTEGRATION TESTS PASSED");
        $display("=========================================");
        $finish;
    end

endmodule
