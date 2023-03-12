SECTIONS
{
  . = 0;
  .text . : AT(0x07e00)
  {
    *(.text)
    *(.text*)
    *(.rodata)
    *(.rodata*)

    . = ALIGN(65536);
  }

  . &= 0xffff;
  .map1 . : AT(0x17e00)
  {
	*(.sprites.map1)
    . = ALIGN(65536);
  }

  . &= 0xffff;
  .map2 . : AT(0x27e00)
  {
	*(.sprites.map2)
    . = ALIGN(65536);
  }
}
