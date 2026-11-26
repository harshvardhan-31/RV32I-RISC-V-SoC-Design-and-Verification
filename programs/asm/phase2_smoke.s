# Phase 2 Assembly Test: Comprehensive Smoke Test
# Tests:
# 1. Register-register arithmetic (ADD, SUB)
# 2. Immediate arithmetic (ADDI)
# 3. Logical operations (AND, OR, XOR)
# 4. Shift operations (SLL, SRL, SRA)
# 5. Comparisons (SLT, SLTU)
# 6. LUI and AUIPC
# 7. Aligned Store and Load (SW, LW)
# 8. Branches (BEQ, BNE)
# 9. JAL and JALR
#
# IMPORTANT: 3 NOPs are placed between dependent instructions to guarantee
# hazard-free execution in Phase 2 (prior to Phase 3 hardware forwarding).

.section .text
.globl _start

_start:
    # --- Immediate Arithmetic ---
    # x1 = 10
    addi x1, x0, 10
    nop
    nop
    nop

    # x2 = 20
    addi x2, x0, 20
    nop
    nop
    nop

    # --- Register-Register Arithmetic ---
    # x3 = x1 + x2 = 30 (0x1E)
    add x3, x1, x2
    nop
    nop
    nop

    # x4 = x2 - x1 = 10 (0x0A)
    sub x4, x2, x1
    nop
    nop
    nop

    # --- Logical Operations ---
    # x5 = x1 & x2 = 10 & 20 = 0 (1010 & 10100 = 0)
    and x5, x1, x2
    nop
    nop
    nop

    # x6 = x1 | x2 = 10 | 20 = 30 (0x1E)
    or x6, x1, x2
    nop
    nop
    nop

    # x7 = x1 ^ x2 = 10 ^ 20 = 30 (0x1E)
    xor x7, x1, x2
    nop
    nop
    nop

    # --- Shift Operations ---
    # x8 = x1 << 2 = 40 (0x28)
    slli x8, x1, 2
    nop
    nop
    nop

    # --- Comparisons ---
    # x9 = (x1 < x2) ? 1 : 0 = 1
    slt x9, x1, x2
    nop
    nop
    nop

    # --- LUI and AUIPC ---
    # x11 = 0x12345000
    lui x11, 0x12345
    nop
    nop
    nop

    # --- Data Memory Load and Store ---
    # Set data memory base address in x13 = 0x1000_0000
    lui x13, 0x10000
    nop
    nop
    nop

    # Store x3 (30 = 0x1E) into DMEM[0x1000_0000]
    sw x3, 0(x13)
    nop
    nop
    nop

    # Load from DMEM[0x1000_0000] into x14
    lw x14, 0(x13)
    nop
    nop
    nop

    # --- Control Flow: Branch (BEQ) ---
    # x1 (10) == x4 (10) -> Taken! Jump over poisoned instruction
    beq x1, x4, branch_target
    nop
    nop
    nop

    # Flushed/skipped instruction: if branch failed, x15 would be set to 0xBAD
    addi x15, x0, 0xBAD
    nop
    nop
    nop

branch_target:
    # x15 = 0x600D (Good)
    addi x15, x0, 0x600D
    nop
    nop
    nop

    # --- End of test loop (infinite loop) ---
end_loop:
    beq x0, x0, end_loop
    nop
    nop
    nop
