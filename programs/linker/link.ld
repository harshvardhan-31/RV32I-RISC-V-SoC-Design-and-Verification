/* =============================================================================
 * File: link.ld
 * Project: RV32I RISC-V SoC (Phase 4 — Memory Subsystem and Peripheral Integration)
 * Description: Ratified Linker Script for RV32I SoC with 64 KiB Instruction RAM
 *              and 64 KiB Data RAM.
 * ============================================================================= */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY {
  IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
  DMEM (rw)  : ORIGIN = 0x10000000, LENGTH = 64K
}

/* MMIO Peripheral Base Addresses */
__uart_base  = 0x20000000;
__spi_base   = 0x20001000;
__timer_base = 0x20002000;
__intc_base  = 0x20003000;

SECTIONS {
  .text : {
    . = ALIGN(4);
    *(.text.start)
    *(.text*)
    *(.gnu.linkonce.t.*)
    . = ALIGN(4);
    _etext = .;
  } > IMEM

  .rodata : {
    . = ALIGN(4);
    _srodata = .;
    *(.rodata*)
    *(.gnu.linkonce.r.*)
    . = ALIGN(4);
    _erodata = .;
  } > DMEM

  .data : {
    . = ALIGN(4);
    _sdata = .;
    *(.data*)
    *(.gnu.linkonce.d.*)
    . = ALIGN(4);
    _edata = .;
  } > DMEM

  .bss : {
    . = ALIGN(4);
    _sbss = .;
    *(.bss*)
    *(COMMON)
    . = ALIGN(4);
    _ebss = .;
  } > DMEM

  /* Stack placed at top of Data RAM (grows downwards) */
  _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
}
