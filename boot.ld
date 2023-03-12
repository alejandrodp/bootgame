SECTIONS
{
  . = 0x7c00;

  .mbr : AT(0x7c00)
  {
    *(.text.start)
    *(.text)
    *(.text*)
    *(.data:boot.o)
    *(.data*:boot.o)
    *(.rodata)
    *(.rodata*)

	. = ALIGN(512) - (512 - 446);
    KEEP(*(.mbr))
  }
}
