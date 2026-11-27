// ============================================================================
// File: tb_hazard_integration.sv
// Project: RV32I RISC-V SoC (Phase 3 — Hazard Detection and Forwarding)
// Description: System-level integration testbench verifying that the Phase 3
//              cpu_core correctly handles load-use stalls, RAW data hazards,
//              data memory wait states, and branch redirects occurring while
//              an older memory transaction is outstanding.
//
//   Test sequences:
//     SEQ-A  RAW ALU chain (ADD→SUB→AND): forwarded via EX/MEM and MEM/WB
//     SEQ-B  Load-use: LW followed immediately by ADD using loaded value;
//            asserts cycle-level counter for exactly ONE bubble.
//     SEQ-C  Store data forwarding: ADD result stored without NOP
//     SEQ-D  Double-dependency chain: three consecutive RAW ALU instructions
//     SEQ-E  Multi-cycle data memory wait states (wait cycles >= 2)
//     SEQ-F  Branch redirect occurring while older memory transaction is outstanding
//
// ============================================================================

`timescale 1ns / 1ps

`define OPCODE_ALU_R  7'b011_0011
`define OPCODE_ALU_I  7'b001_0011
`define OPCODE_LOAD   7'b000_0011
`define OPCODE_STORE  7'b010_0011
`define OPCODE_LUI    7'b011_0111
`define OPCODE_BRANCH 7'b110_0011
`define OPCODE_JAL    7'b110_1111
`define OPCODE_NOP    32'h0000_0013

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

// BEQ rs1, rs2, offset
`define BEQ(rs1, rs2, offset) \
    {1'(offset[12]), 6'(offset[10:5]), 5'(rs2), 5'(rs1), 3'b000, \
     4'(offset[4:1]), 1'(offset[11]), `OPCODE_BRANCH}

// JAL rd, offset
`define JAL(rd, offset) \
    {1'(offset[20]), 10'(offset[10:1]), 1'(offset[11]), 8'(offset[19:12]), \
     5'(rd), `OPCODE_JAL}

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

    // ---- Cycle-level counters for load-use stalls and ID/EX bubble insertion ----
    int load_use_stall_count = 0;
    int id_ex_bubble_count   = 0;
    logic count_enable       = 0;

    always_ff @(posedge clk) begin
        if (rst_n && count_enable) begin
            if (u_cpu.u_hazard_unit.load_use_hazard && !u_cpu.lsu_busy) begin
                load_use_stall_count <= load_use_stall_count + 1;
            end
            if (u_cpu.hz_bubble_id_ex && u_cpu.u_hazard_unit.load_use_hazard && !u_cpu.lsu_busy) begin
                id_ex_bubble_count <= id_ex_bubble_count + 1;
            end
        end
    end

    // ---- Helper: load instruction memory ----
    task automatic load_imem(input logic [31:0] prog []);
        int i;
        for (i = 0; i < prog.size(); i++) begin
            u_imem.mem[i] = prog[i];
        end
        for (i = prog.size(); i < 256; i++) begin
            u_imem.mem[i] = `OPCODE_NOP;
        end
    endtask

    // ---- Helper: read register file value ----
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
    logic [31:0] prog[];
    logic [31:0] got;

    initial begin
        rst_n = 1'b0;
        u_dmem.wait_cycles_cfg = 0; // Default zero wait cycles

        // ================================================================
        // SEQ-A: RAW ALU chain — forwarding resolves without NOPs
        //   ADDI x1, x0, 5    # x1 = 5
        //   ADDI x2, x0, 3    # x2 = 3
        //   ADD  x3, x1, x2   # x3 = 8
        //   SUB  x4, x3, x1   # x4 = 3
        //   AND  x5, x3, x4   # x5 = 0
        // ================================================================
        prog = new[8];
        prog[0] = `ADDI(1, 0, 5);
        prog[1] = `ADDI(2, 0, 3);
        prog[2] = `ADD (3, 1, 2);
        prog[3] = `SUB (4, 3, 1);
        prog[4] = `AND (5, 3, 4);
        prog[5] = `OPCODE_NOP;
        prog[6] = `OPCODE_NOP;
        prog[7] = `OPCODE_NOP;

        apply_reset(4);
        load_imem(prog);
        apply_reset(2);
        run_cycles(20);

        got = read_reg(1);
        if (got !== 32'd5) $fatal(1, "SEQ-A FAIL: x1 expected 5 got %0d", got);
        got = read_reg(2);
        if (got !== 32'd3) $fatal(1, "SEQ-A FAIL: x2 expected 3 got %0d", got);
        got = read_reg(3);
        if (got !== 32'd8) $fatal(1, "SEQ-A FAIL: x3 expected 8 got %0d", got);
        got = read_reg(4);
        if (got !== 32'd3) $fatal(1, "SEQ-A FAIL: x4 expected 3 got %0d", got);
        got = read_reg(5);
        if (got !== 32'd0) $fatal(1, "SEQ-A FAIL: x5 expected 0 got %0d", got);
        $display("PASS SEQ-A: RAW ALU chain forwarding");

        // ================================================================
        // SEQ-B: Isolated Load-use with cycle-level counter assertion
        //   LUI  x1, 0x10000   # x1 = 0x1000_0000
        //   ADDI x2, x0, 42    # x2 = 42
        //   SW   x2, 0(x1)     # M[0x1000_0000] = 42
        //   LW   x3, 0(x1)     # x3 = 42 (load)
        //   ADD  x4, x3, x2    # x4 = 84 (isolated load-use dependency!)
        // ================================================================
        prog = new[8];
        prog[0] = `LUI  (1, 20'h10000);
        prog[1] = `ADDI (2, 0, 42);
        prog[2] = `SW   (2, 1, 12'h0);
        prog[3] = `LW   (3, 1, 12'h0);
        prog[4] = `ADD  (4, 3, 2);
        prog[5] = `OPCODE_NOP;
        prog[6] = `OPCODE_NOP;
        prog[7] = `OPCODE_NOP;

        apply_reset(4);
        load_imem(prog);
        apply_reset(2);

        // Reset counters and enable counting for isolated load-use
        load_use_stall_count = 0;
        id_ex_bubble_count   = 0;
        count_enable         = 1;

        run_cycles(30);

        count_enable = 0;

        got = read_reg(3);
        if (got !== 32'd42) $fatal(1, "SEQ-B FAIL: x3 (loaded) expected 42 got %0d", got);
        got = read_reg(4);
        if (got !== 32'd84) $fatal(1, "SEQ-B FAIL: x4 expected 84 got %0d", got);

        // Assert exactly 1 stall cycle and 1 bubble insertion
        if (load_use_stall_count !== 1) begin
            $fatal(1, "SEQ-B FAIL: Expected exactly 1 load-use stall cycle, got %0d", load_use_stall_count);
        end
        if (id_ex_bubble_count !== 1) begin
            $fatal(1, "SEQ-B FAIL: Expected exactly 1 ID/EX bubble insertion, got %0d", id_ex_bubble_count);
        end
        $display("PASS SEQ-B: Load-use verified with EXACTLY 1 stall cycle and 1 bubble insertion");

        // ================================================================
        // SEQ-C: Store data forwarding
        // ================================================================
        prog = new[8];
        prog[0] = `ADDI (1, 0, 7);
        prog[1] = `ADD  (2, 1, 1);
        prog[2] = `LUI  (3, 20'h10000);
        prog[3] = `SW   (2, 3, 12'h4);
        prog[4] = `LW   (4, 3, 12'h4);
        prog[5] = `OPCODE_NOP;
        prog[6] = `OPCODE_NOP;
        prog[7] = `OPCODE_NOP;

        apply_reset(4);
        load_imem(prog);
        apply_reset(2);
        run_cycles(35);

        got = read_reg(4);
        if (got !== 32'd14) $fatal(1, "SEQ-C FAIL: x4 expected 14 got %0d", got);
        $display("PASS SEQ-C: Store data forwarding");

        // ================================================================
        // SEQ-D: Triple-dependency chain
        // ================================================================
        prog = new[8];
        prog[0] = `ADDI (1, 0, 1);
        prog[1] = `ADD  (2, 1, 1);
        prog[2] = `ADD  (3, 2, 1);
        prog[3] = `ADD  (4, 3, 2);
        prog[4] = `OPCODE_NOP;
        prog[5] = `OPCODE_NOP;
        prog[6] = `OPCODE_NOP;
        prog[7] = `OPCODE_NOP;

        apply_reset(4);
        load_imem(prog);
        apply_reset(2);
        run_cycles(20);

        got = read_reg(2);
        if (got !== 32'd2) $fatal(1, "SEQ-D FAIL: x2 expected 2 got %0d", got);
        got = read_reg(3);
        if (got !== 32'd3) $fatal(1, "SEQ-D FAIL: x3 expected 3 got %0d", got);
        got = read_reg(4);
        if (got !== 32'd5) $fatal(1, "SEQ-D FAIL: x4 expected 5 got %0d", got);
        $display("PASS SEQ-D: Triple-dependency forwarding chain");

        // ================================================================
        // SEQ-E: Data memory model configured for TWO additional wait cycles
        //   Verifies pipeline holds during wait states and resumes properly.
        // ================================================================
        u_dmem.wait_cycles_cfg = 2; // 2 additional wait cycles per transaction

        prog = new[8];
        prog[0] = `LUI  (1, 20'h10000);
        prog[1] = `ADDI (2, 0, 123);
        prog[2] = `SW   (2, 1, 12'h8);    // SW with 2 wait cycles
        prog[3] = `LW   (3, 1, 12'h8);    // LW with 2 wait cycles
        prog[4] = `ADDI (4, 3, 1);        // ADDI depends on loaded value
        prog[5] = `OPCODE_NOP;
        prog[6] = `OPCODE_NOP;
        prog[7] = `OPCODE_NOP;

        apply_reset(4);
        load_imem(prog);
        apply_reset(2);
        run_cycles(45);

        got = read_reg(3);
        if (got !== 32'd123) $fatal(1, "SEQ-E FAIL: x3 expected 123 got %0d", got);
        got = read_reg(4);
        if (got !== 32'd124) $fatal(1, "SEQ-E FAIL: x4 expected 124 got %0d", got);
        $display("PASS SEQ-E: Multi-cycle data memory wait states (WAIT_CYCLES=2) executed correctly");

        // ================================================================
        // SEQ-F: Branch redirect occurring while older memory transaction is outstanding!
        //   Address  Instruction
        //   0        LUI  x1, 0x10000       # x1 = 0x1000_0000
        //   4        ADDI x2, x0, 77        # x2 = 77
        //   8        SW   x2, 0(x1)         # Store 77 to memory (wait cycles active)
        //   12       LW   x6, 0(x1)         # Load from memory -> takes 2 wait cycles in MEM!
        //   16       BEQ  x0, x0, 16        # In EX while LW is in MEM! Taken branch to PC=32!
        //   20       ADDI x7, x0, 0xBAD     # Wrong path — MUST BE FLUSHED!
        //   24       ADDI x7, x0, 0xBAD     # Wrong path — MUST BE FLUSHED!
        //   28       NOP
        //   32       ADDI x8, x0, 99        # Branch target reached! x8 = 99
        // ================================================================
        u_dmem.wait_cycles_cfg = 2; // Keep 2 wait cycles active

        prog = new[10];
        prog[0] = `LUI (1, 20'h10000);        // PC = 0
        prog[1] = `ADDI(2, 0, 77);            // PC = 4
        prog[2] = `SW  (2, 1, 12'h0);         // PC = 8: Store 77
        prog[3] = `LW  (6, 1, 12'h0);         // PC = 12: Load 77 (outstanding in MEM)
        prog[4] = `BEQ (0, 0, 21'sd16);       // PC = 16: Branch to 16+16=32 (in EX while LW in MEM)
        prog[5] = `ADDI(7, 0, 12'hBAD);       // PC = 20: Flushed wrong-path
        prog[6] = `ADDI(7, 0, 12'hBAD);       // PC = 24: Flushed wrong-path
        prog[7] = `OPCODE_NOP;                // PC = 28
        prog[8] = `ADDI(8, 0, 99);            // PC = 32: Branch target!
        prog[9] = `OPCODE_NOP;                // PC = 36

        apply_reset(4);
        load_imem(prog);
        apply_reset(2);
        run_cycles(50);

        got = read_reg(6);
        if (got !== 32'd77)
            $fatal(1, "SEQ-F FAIL: x6 (older memory load) expected 77 got %0d", got);
        got = read_reg(7);
        if (got !== 32'd0)
            $fatal(1, "SEQ-F FAIL: x7 expected 0 (wrong-path flushed) got 0x%08h", got);
        got = read_reg(8);
        if (got !== 32'd99)
            $fatal(1, "SEQ-F FAIL: x8 expected 99 (branch target executed) got %0d", got);
        $display("PASS SEQ-F: Branch redirect during outstanding memory transaction resolved with NO lost instructions or redirects");

        u_dmem.wait_cycles_cfg = 0; // Restore default

        $display("");
        $display("==================================================");
        $display("ALL 6 HAZARD INTEGRATION TESTS PASSED SUCCESSFULLY");
        $display("==================================================");
        $finish;
    end

endmodule
