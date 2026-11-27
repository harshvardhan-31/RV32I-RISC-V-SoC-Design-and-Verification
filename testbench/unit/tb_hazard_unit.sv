// ============================================================================
// File: tb_hazard_unit.sv
// Project: RV32I RISC-V SoC (Phase 3 — Hazard Detection and Forwarding)
// Description: Self-checking unit testbench for hazard_unit.sv
//
//   Test cases covered (HAZARD-01 through HAZARD-12):
//     HAZARD-01  Load-use hazard: id_ex has load, rd matches if_id rs1 → stall
//     HAZARD-02  Load-use hazard: rd matches if_id rs2 → stall
//     HAZARD-03  Load-use hazard: rd = x0 → NO stall (x0 never hazardous)
//     HAZARD-04  Load-use hazard: rs1 not used → NO stall (LUI false dep)
//     HAZARD-05  Load-use hazard: rs2 not used → NO stall
//     HAZARD-06  Load-use hazard: id_ex not valid → NO stall
//     HAZARD-07  Load-use hazard: id_ex not a load → NO stall
//     HAZARD-08  Control hazard: redirect_valid=1 → flush_if_id + bubble_id_ex
//     HAZARD-09  Control hazard: redirect_valid=0 → no flush
//     HAZARD-10  LSU busy: entire pipeline stall; no flush
//     HAZARD-11  LSU busy + load-use pending: lsu_busy takes priority, no bubble
//     HAZARD-12  LSU busy + redirect: lsu_busy takes priority, no flush
//
//   All checks use $fatal to terminate on first failure.
//   Simulation results marked "Not run" until executed with Icarus Verilog.
// ============================================================================

`timescale 1ns / 1ps

module tb_hazard_unit;

    // ---- DUT I/O ----
    logic        if_id_valid;
    logic [4:0]  if_id_rs1;
    logic [4:0]  if_id_rs2;
    logic        if_id_rs1_used;
    logic        if_id_rs2_used;
    logic        id_ex_valid;
    logic [4:0]  id_ex_rd;
    logic        id_ex_mem_read;
    logic        redirect_valid;
    logic        lsu_busy;

    logic        stall_if;
    logic        stall_id;
    logic        bubble_id_ex;
    logic        flush_if_id;

    // Instantiate DUT
    hazard_unit dut (
        .if_id_valid_i   (if_id_valid),
        .if_id_rs1_i     (if_id_rs1),
        .if_id_rs2_i     (if_id_rs2),
        .if_id_rs1_used_i(if_id_rs1_used),
        .if_id_rs2_used_i(if_id_rs2_used),
        .id_ex_valid_i   (id_ex_valid),
        .id_ex_rd_i      (id_ex_rd),
        .id_ex_mem_read_i(id_ex_mem_read),
        .redirect_valid_i(redirect_valid),
        .lsu_busy_i      (lsu_busy),
        .stall_if_o      (stall_if),
        .stall_id_o      (stall_id),
        .bubble_id_ex_o  (bubble_id_ex),
        .flush_if_id_o   (flush_if_id)
    );

    // ---- Helper task ----
    task automatic check_outputs(
        input string test_name,
        input logic  exp_stall_if,
        input logic  exp_stall_id,
        input logic  exp_bubble_id_ex,
        input logic  exp_flush_if_id
    );
        #1; // Allow combinational settle
        if (stall_if !== exp_stall_if) begin
            $fatal(1, "FAIL %s: stall_if expected %0b got %0b",
                   test_name, exp_stall_if, stall_if);
        end
        if (stall_id !== exp_stall_id) begin
            $fatal(1, "FAIL %s: stall_id expected %0b got %0b",
                   test_name, exp_stall_id, stall_id);
        end
        if (bubble_id_ex !== exp_bubble_id_ex) begin
            $fatal(1, "FAIL %s: bubble_id_ex expected %0b got %0b",
                   test_name, exp_bubble_id_ex, bubble_id_ex);
        end
        if (flush_if_id !== exp_flush_if_id) begin
            $fatal(1, "FAIL %s: flush_if_id expected %0b got %0b",
                   test_name, exp_flush_if_id, flush_if_id);
        end
        $display("PASS %s", test_name);
    endtask

    // ---- Stimulus ----
    initial begin
        $dumpfile("sim_out/tb_hazard_unit.vcd");
        $dumpvars(0, tb_hazard_unit);

        // Default safe state
        if_id_valid    = 1'b0;
        if_id_rs1      = 5'd0;
        if_id_rs2      = 5'd0;
        if_id_rs1_used = 1'b0;
        if_id_rs2_used = 1'b0;
        id_ex_valid    = 1'b0;
        id_ex_rd       = 5'd0;
        id_ex_mem_read = 1'b0;
        redirect_valid = 1'b0;
        lsu_busy       = 1'b0;

        // ---- HAZARD-01: load-use, rs1 match ----
        id_ex_valid    = 1'b1;
        id_ex_mem_read = 1'b1;
        id_ex_rd       = 5'd3;      // LW x3, ...
        if_id_valid    = 1'b1;
        if_id_rs1      = 5'd3;      // next instr uses x3 as rs1
        if_id_rs1_used = 1'b1;
        if_id_rs2      = 5'd0;
        if_id_rs2_used = 1'b0;
        check_outputs("HAZARD-01-load-use-rs1",
                      1'b1, 1'b1, 1'b1, 1'b0);

        // ---- HAZARD-02: load-use, rs2 match ----
        if_id_rs1      = 5'd1;
        if_id_rs1_used = 1'b0;
        if_id_rs2      = 5'd3;
        if_id_rs2_used = 1'b1;
        check_outputs("HAZARD-02-load-use-rs2",
                      1'b1, 1'b1, 1'b1, 1'b0);

        // ---- HAZARD-03: load-use but rd = x0 → NO stall ----
        id_ex_rd       = 5'd0;
        if_id_rs2      = 5'd0;      // matches x0 — but x0 never hazardous
        if_id_rs2_used = 1'b1;
        check_outputs("HAZARD-03-load-use-rd-x0-no-stall",
                      1'b0, 1'b0, 1'b0, 1'b0);

        // ---- HAZARD-04: LUI false dependency — rs1 not used ----
        id_ex_rd       = 5'd5;
        if_id_rs1      = 5'd5;
        if_id_rs1_used = 1'b0;      // LUI does not read rs1
        if_id_rs2      = 5'd0;
        if_id_rs2_used = 1'b0;
        check_outputs("HAZARD-04-lui-no-false-dep-rs1",
                      1'b0, 1'b0, 1'b0, 1'b0);

        // ---- HAZARD-05: rs2 not used → NO stall ----
        if_id_rs1_used = 1'b0;
        if_id_rs2      = 5'd5;
        if_id_rs2_used = 1'b0;
        check_outputs("HAZARD-05-rs2-not-used-no-stall",
                      1'b0, 1'b0, 1'b0, 1'b0);

        // ---- HAZARD-06: id_ex_valid = 0 → NO stall ----
        id_ex_valid    = 1'b0;
        if_id_rs1      = 5'd5;
        if_id_rs1_used = 1'b1;
        check_outputs("HAZARD-06-id-ex-invalid-no-stall",
                      1'b0, 1'b0, 1'b0, 1'b0);

        // ---- HAZARD-07: id_ex not a load → NO stall ----
        id_ex_valid    = 1'b1;
        id_ex_mem_read = 1'b0;      // ALU instruction, not a load
        check_outputs("HAZARD-07-not-a-load-no-stall",
                      1'b0, 1'b0, 1'b0, 1'b0);

        // ---- HAZARD-08: control hazard redirect ----
        id_ex_valid    = 1'b0;
        id_ex_mem_read = 1'b0;
        if_id_valid    = 1'b1;
        redirect_valid = 1'b1;
        check_outputs("HAZARD-08-redirect-flush",
                      1'b0, 1'b0, 1'b1, 1'b1);

        // ---- HAZARD-09: no redirect → no flush ----
        redirect_valid = 1'b0;
        check_outputs("HAZARD-09-no-redirect-no-flush",
                      1'b0, 1'b0, 1'b0, 1'b0);

        // ---- HAZARD-10: LSU busy only ----
        redirect_valid = 1'b0;
        lsu_busy       = 1'b1;
        check_outputs("HAZARD-10-lsu-busy-stall-all",
                      1'b1, 1'b1, 1'b0, 1'b0);

        // ---- HAZARD-11: LSU busy + load-use pending → lsu_busy priority ----
        id_ex_valid    = 1'b1;
        id_ex_mem_read = 1'b1;
        id_ex_rd       = 5'd7;
        if_id_rs1      = 5'd7;
        if_id_rs1_used = 1'b1;
        // lsu_busy=1 → stall only, no bubble (no load-use action under bus stall)
        check_outputs("HAZARD-11-lsu-busy-masks-load-use",
                      1'b1, 1'b1, 1'b0, 1'b0);

        // ---- HAZARD-12: LSU busy + redirect → lsu_busy priority; no flush ----
        redirect_valid = 1'b1;
        id_ex_valid    = 1'b0;
        id_ex_mem_read = 1'b0;
        check_outputs("HAZARD-12-lsu-busy-masks-redirect",
                      1'b1, 1'b1, 1'b0, 1'b0);

        $display("");
        $display("============================");
        $display("ALL HAZARD-UNIT TESTS PASSED");
        $display("============================");
        $finish;
    end

endmodule
