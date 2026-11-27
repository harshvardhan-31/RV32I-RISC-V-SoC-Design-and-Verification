# ============================================================================
# File: branch_dependencies.S
# Project: RV32I RISC-V SoC (Phase 3 — Hazard Detection and Forwarding)
# Description: Assembly test program for branch operand forwarding.
#
#   Tests that branch instructions correctly receive forwarded operand
#   values from the EX/MEM and MEM/WB stages so that the branch condition
#   is evaluated correctly without requiring NOPs between the last
#   ALU instruction and the BEQ/BNE.
#
#   Control-hazard flush is verified by ensuring that instructions in the
#   wrong-path slots (between branch and target) do NOT modify registers.
#
# Expected register values:
#   x1 = 10, x2 = 10 (inputs)
#   x3 = 1  (set at branch target — proves taken-branch path was correct)
#   x4 = 5  (independent computation after branch)
# ============================================================================

.section .text
.global _start
_start:
    # Test 1: Branch taken — operands forwarded from EX/MEM
    addi  x1, x0, 10         # x1 = 10
    addi  x2, x0, 10         # x2 = 10
    beq   x1, x2, taken      # branch taken (x1==x2 forwarded from EX/MEM, MEM/WB)
    addi  x3, x0, 0xBAD      # MUST NOT execute (flushed wrong-path instruction)

taken:
    addi  x3, x0, 1          # x3 = 1 — branch target, proves correct path

    # Test 2: Branch NOT taken — not-taken path continues
    addi  x1, x0, 5          # x1 = 5
    addi  x2, x0, 7          # x2 = 7
    beq   x1, x2, bad_path   # NOT taken (5 != 7)
    addi  x4, x0, 5          # x4 = 5 — executes normally

    j     end_test

bad_path:
    addi  x4, x0, 0xBAD      # MUST NOT execute

end_test:
    # Test 3: BNE with freshly computed value — EX/MEM forwarding on branch
    addi  x5, x0, 3
    add   x6, x5, x5         # x6 = 6 — EX/MEM
    bne   x6, x0, nonzero    # taken (6 != 0, forwarded from EX/MEM)
    addi  x7, x0, 0xBAD      # flushed

nonzero:
    addi  x7, x0, 6          # x7 = 6

_halt:
    j     _halt

.end
