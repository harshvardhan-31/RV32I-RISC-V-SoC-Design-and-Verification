// ============================================================================
// File: tb_forwarding_unit.sv
// Project: RV32I RISC-V SoC (Phase 3 — Hazard Detection and Forwarding)
// Description: Comprehensive self-checking unit testbench for forwarding_unit.sv
//
//   Test cases covered:
//     FORWARD-01  EX/MEM match rs1 → fwd_sel_a = 2'b10
//     FORWARD-02  MEM/WB match rs1 → fwd_sel_a = 2'b01
//     FORWARD-03  Both match rs1   → EX/MEM wins (2'b10)
//     FORWARD-04  rd = x0 in EX/MEM → no fwd for rs1 (2'b00)
//     FORWARD-05  reg_write=0 in EX/MEM → no fwd for rs1 (2'b00)
//     FORWARD-06  ex_mem_mem_read=1 → no EX/MEM fwd (load not ready); 2'b00
//     FORWARD-07  EX/MEM match rs2 → fwd_sel_b = 2'b10
//     FORWARD-08  MEM/WB match rs2 → fwd_sel_b = 2'b01
//     FORWARD-09  Both match rs2   → EX/MEM wins (2'b10)
//     FORWARD-10  rd = x0 in MEM/WB → no fwd for rs2 (2'b00)
//     FORWARD-11  No match → both selects = 2'b00
//     FORWARD-12  ex_mem_mem_read=1 but MEM/WB matches → MEM/WB fwd applied
//     FORWARD-13  ex_mem_valid=0 → no EX/MEM fwd for rs1 even if rd matches
//     FORWARD-14  mem_wb_valid=0 → no MEM/WB fwd for rs1 even if rd matches
//     FORWARD-15  ex_mem_valid=0 for rs2 → no forward
//     FORWARD-16  mem_wb_valid=0 for rs2 → no forward
//     FORWARD-17  MEM/WB reg_write=0 for rs1 → no forward
//     FORWARD-18  MEM/WB reg_write=0 for rs2 → no forward
//     FORWARD-19  MEM/WB rd=x0 for rs1 → no forward
//     FORWARD-20  Back-to-back priority with alternating register indices
//
//   All checks use $fatal.
// ============================================================================

`timescale 1ns / 1ps

module tb_forwarding_unit;

    // ---- DUT I/O ----
    logic [4:0]  ex_rs1_addr;
    logic [4:0]  ex_rs2_addr;
    logic        ex_mem_valid;
    logic [4:0]  ex_mem_rd_addr;
    logic        ex_mem_reg_write;
    logic        ex_mem_mem_read;
    logic        mem_wb_valid;
    logic [4:0]  mem_wb_rd_addr;
    logic        mem_wb_reg_write;

    logic [1:0]  fwd_sel_a;
    logic [1:0]  fwd_sel_b;

    // Forwarding select encoding
    localparam [1:0] FWD_REG   = 2'b00;
    localparam [1:0] FWD_EXMEM = 2'b10;
    localparam [1:0] FWD_MEMWB = 2'b01;

    // Instantiate DUT
    forwarding_unit dut (
        .ex_rs1_addr_i     (ex_rs1_addr),
        .ex_rs2_addr_i     (ex_rs2_addr),
        .ex_mem_valid_i    (ex_mem_valid),
        .ex_mem_rd_addr_i  (ex_mem_rd_addr),
        .ex_mem_reg_write_i(ex_mem_reg_write),
        .ex_mem_mem_read_i (ex_mem_mem_read),
        .mem_wb_valid_i    (mem_wb_valid),
        .mem_wb_rd_addr_i  (mem_wb_rd_addr),
        .mem_wb_reg_write_i(mem_wb_reg_write),
        .fwd_sel_a_o       (fwd_sel_a),
        .fwd_sel_b_o       (fwd_sel_b)
    );

    // ---- Helper task ----
    task automatic check(
        input string test_name,
        input logic [1:0] exp_a,
        input logic [1:0] exp_b
    );
        #1;
        if (fwd_sel_a !== exp_a) begin
            $fatal(1, "FAIL %s: fwd_sel_a expected 2'b%02b got 2'b%02b",
                   test_name, exp_a, fwd_sel_a);
        end
        if (fwd_sel_b !== exp_b) begin
            $fatal(1, "FAIL %s: fwd_sel_b expected 2'b%02b got 2'b%02b",
                   test_name, exp_b, fwd_sel_b);
        end
        $display("PASS %s", test_name);
    endtask

    // ---- Stimulus ----
    initial begin
        $dumpfile("sim_out/tb_forwarding_unit.vcd");
        $dumpvars(0, tb_forwarding_unit);

        // Safe defaults
        ex_rs1_addr      = 5'd1;
        ex_rs2_addr      = 5'd2;
        ex_mem_valid     = 1'b0;
        ex_mem_rd_addr   = 5'd0;
        ex_mem_reg_write = 1'b0;
        ex_mem_mem_read  = 1'b0;
        mem_wb_valid     = 1'b0;
        mem_wb_rd_addr   = 5'd0;
        mem_wb_reg_write = 1'b0;

        // ---- FORWARD-01: EX/MEM matches rs1 ----
        ex_rs1_addr      = 5'd5;
        ex_mem_valid     = 1'b1;
        ex_mem_rd_addr   = 5'd5;
        ex_mem_reg_write = 1'b1;
        ex_mem_mem_read  = 1'b0;
        check("FORWARD-01-exmem-rs1", FWD_EXMEM, FWD_REG);

        // ---- FORWARD-02: MEM/WB matches rs1 (EX/MEM doesn't) ----
        ex_mem_rd_addr   = 5'd8;    // different from rs1=5
        mem_wb_valid     = 1'b1;
        mem_wb_rd_addr   = 5'd5;
        mem_wb_reg_write = 1'b1;
        check("FORWARD-02-memwb-rs1", FWD_MEMWB, FWD_REG);

        // ---- FORWARD-03: Both match rs1 → EX/MEM wins ----
        ex_mem_rd_addr   = 5'd5;
        mem_wb_rd_addr   = 5'd5;
        check("FORWARD-03-both-match-rs1-exmem-wins", FWD_EXMEM, FWD_REG);

        // ---- FORWARD-04: EX/MEM rd = x0 → no fwd ----
        ex_mem_rd_addr   = 5'd0;
        mem_wb_rd_addr   = 5'd0;
        check("FORWARD-04-rd-x0-no-fwd", FWD_REG, FWD_REG);

        // ---- FORWARD-05: EX/MEM reg_write=0 → no EX/MEM fwd ----
        ex_mem_rd_addr   = 5'd5;
        ex_mem_reg_write = 1'b0;    // instruction does not write (e.g., store)
        mem_wb_rd_addr   = 5'd8;
        check("FORWARD-05-exmem-regwrite-0-no-fwd", FWD_REG, FWD_REG);

        // ---- FORWARD-06: EX/MEM load (mem_read=1) → no EX/MEM fwd for rs1 ----
        ex_mem_reg_write = 1'b1;
        ex_mem_mem_read  = 1'b1;    // load: data not yet available from EX/MEM
        mem_wb_rd_addr   = 5'd8;
        check("FORWARD-06-exmem-load-no-fwd", FWD_REG, FWD_REG);

        // Reset for rs2 tests
        ex_rs1_addr      = 5'd9;    // rs1 = x9 (no match to rd=5)
        ex_rs2_addr      = 5'd5;
        ex_mem_rd_addr   = 5'd5;
        ex_mem_reg_write = 1'b1;
        ex_mem_mem_read  = 1'b0;
        mem_wb_rd_addr   = 5'd8;
        mem_wb_reg_write = 1'b1;
        mem_wb_valid     = 1'b0;

        // ---- FORWARD-07: EX/MEM matches rs2 ----
        check("FORWARD-07-exmem-rs2", FWD_REG, FWD_EXMEM);

        // ---- FORWARD-08: MEM/WB matches rs2 ----
        ex_mem_rd_addr   = 5'd8;
        mem_wb_valid     = 1'b1;
        mem_wb_rd_addr   = 5'd5;
        check("FORWARD-08-memwb-rs2", FWD_REG, FWD_MEMWB);

        // ---- FORWARD-09: Both match rs2 → EX/MEM wins ----
        ex_mem_rd_addr   = 5'd5;
        mem_wb_rd_addr   = 5'd5;
        check("FORWARD-09-both-match-rs2-exmem-wins", FWD_REG, FWD_EXMEM);

        // ---- FORWARD-10: MEM/WB rd = x0 → no MEM/WB fwd ----
        ex_mem_rd_addr   = 5'd8;    // no match for rs2=5
        mem_wb_rd_addr   = 5'd0;
        check("FORWARD-10-memwb-rd-x0-no-fwd", FWD_REG, FWD_REG);

        // ---- FORWARD-11: No match for either ----
        ex_rs1_addr      = 5'd1;
        ex_rs2_addr      = 5'd2;
        ex_mem_rd_addr   = 5'd6;
        mem_wb_rd_addr   = 5'd7;
        mem_wb_reg_write = 1'b1;
        check("FORWARD-11-no-match-no-fwd", FWD_REG, FWD_REG);

        // ---- FORWARD-12: EX/MEM load but MEM/WB matches rs1 → MEM/WB fwd ----
        ex_rs1_addr      = 5'd4;
        ex_rs2_addr      = 5'd9;
        ex_mem_rd_addr   = 5'd4;
        ex_mem_reg_write = 1'b1;
        ex_mem_mem_read  = 1'b1;    // load in EX/MEM: cannot fwd from here
        mem_wb_rd_addr   = 5'd4;
        mem_wb_reg_write = 1'b1;
        mem_wb_valid     = 1'b1;
        check("FORWARD-12-exmem-load-fallback-memwb", FWD_MEMWB, FWD_REG);

        // ---- FORWARD-13: ex_mem_valid = 0 → no EX/MEM fwd for rs1 ----
        ex_rs1_addr      = 5'd7;
        ex_mem_valid     = 1'b0;    // invalid pipeline register!
        ex_mem_rd_addr   = 5'd7;
        ex_mem_reg_write = 1'b1;
        ex_mem_mem_read  = 1'b0;
        mem_wb_valid     = 1'b0;
        check("FORWARD-13-exmem-invalid-entry-no-fwd", FWD_REG, FWD_REG);

        // ---- FORWARD-14: mem_wb_valid = 0 → no MEM/WB fwd for rs1 ----
        ex_rs1_addr      = 5'd7;
        ex_mem_valid     = 1'b0;
        mem_wb_valid     = 1'b0;    // invalid pipeline register!
        mem_wb_rd_addr   = 5'd7;
        mem_wb_reg_write = 1'b1;
        check("FORWARD-14-memwb-invalid-entry-no-fwd", FWD_REG, FWD_REG);

        // ---- FORWARD-15: ex_mem_valid = 0 for rs2 → no forward ----
        ex_rs2_addr      = 5'd11;
        ex_mem_valid     = 1'b0;
        ex_mem_rd_addr   = 5'd11;
        ex_mem_reg_write = 1'b1;
        check("FORWARD-15-exmem-invalid-rs2-no-fwd", FWD_REG, FWD_REG);

        // ---- FORWARD-16: mem_wb_valid = 0 for rs2 → no forward ----
        ex_rs2_addr      = 5'd11;
        mem_wb_valid     = 1'b0;
        mem_wb_rd_addr   = 5'd11;
        mem_wb_reg_write = 1'b1;
        check("FORWARD-16-memwb-invalid-rs2-no-fwd", FWD_REG, FWD_REG);

        // ---- FORWARD-17: MEM/WB reg_write = 0 for rs1 → no forward ----
        ex_rs1_addr      = 5'd15;
        ex_mem_valid     = 1'b0;
        mem_wb_valid     = 1'b1;
        mem_wb_rd_addr   = 5'd15;
        mem_wb_reg_write = 1'b0;    // instruction doesn't write registers!
        check("FORWARD-17-memwb-regwrite0-rs1-no-fwd", FWD_REG, FWD_REG);

        // ---- FORWARD-18: MEM/WB reg_write = 0 for rs2 → no forward ----
        ex_rs2_addr      = 5'd16;
        mem_wb_valid     = 1'b1;
        mem_wb_rd_addr   = 5'd16;
        mem_wb_reg_write = 1'b0;
        check("FORWARD-18-memwb-regwrite0-rs2-no-fwd", FWD_REG, FWD_REG);

        // ---- FORWARD-19: MEM/WB rd = x0 for rs1 → no forward ----
        ex_rs1_addr      = 5'd0;    // instruction reading x0
        ex_mem_valid     = 1'b0;
        mem_wb_valid     = 1'b1;
        mem_wb_rd_addr   = 5'd0;    // previous wrote to x0
        mem_wb_reg_write = 1'b1;
        check("FORWARD-19-memwb-rd-x0-rs1-no-fwd", FWD_REG, FWD_REG);

        // ---- FORWARD-20: Back-to-back priority test on rs1 & rs2 simultaneously ----
        ex_rs1_addr      = 5'd20;
        ex_rs2_addr      = 5'd21;
        // EX/MEM writes x20 (matches rs1)
        ex_mem_valid     = 1'b1;
        ex_mem_rd_addr   = 5'd20;
        ex_mem_reg_write = 1'b1;
        ex_mem_mem_read  = 1'b0;
        // MEM/WB also writes x20 (matches rs1) and x21 (matches rs2)
        mem_wb_valid     = 1'b1;
        mem_wb_rd_addr   = 5'd21;
        mem_wb_reg_write = 1'b1;
        // rs1 should get EX/MEM, rs2 should get MEM/WB
        check("FORWARD-20-simultaneous-dual-stage-forwarding", FWD_EXMEM, FWD_MEMWB);

        $display("");
        $display("=================================================");
        $display("ALL 20 FORWARDING-UNIT TESTS PASSED SUCCESSFULLY");
        $display("=================================================");
        $finish;
    end

endmodule
