SECTIONS
{
  . = 0x7c00;

  .image : AT(0x7c00)
  {
    *(.text.start)
    *(.text)
    *(.text*)
    *(.rodata)
    *(.rodata*)

    . = ALIGN(512) - 2;
    KEEP(*(.magic))
  }
}
