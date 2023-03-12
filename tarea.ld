SECTIONS
{
  . = 0x7e00;

  .image :
  {
    *(.text)
    *(.text*)
    *(.rodata)
    *(.rodata*)
  }
}
