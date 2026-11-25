/* TEMPLATE — follows PROPOSED memory map; update after sign-off. */
OUTPUT_ARCH("riscv")
ENTRY(_start)
MEMORY {
  IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K /* TBD */
  DMEM (rw)  : ORIGIN = 0x10000000, LENGTH = 64K /* TBD */
}
SECTIONS {
  .text : { *(.text.start) *(.text*) } > IMEM
  .rodata : { *(.rodata*) } > DMEM
  .data : { *(.data*) } > DMEM
  .bss : { *(.bss*) *(COMMON) } > DMEM
  _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
}
