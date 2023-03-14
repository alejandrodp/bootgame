SECTIONS
{
  . = 0x7e00;
  .text . : AT(0x07e00)
  {
    SHORT(0xbaad)
    *(.text)
    *(.text*)
    *(.rodata)
    *(.rodata*)

    . = 0x10000;
  }

  . = 0;
  .sprites.map1 . : AT(0x17e00)
  {
    map1.o(.sprites)
    . = ALIGN(65536);
  }

  . &= 0xffff;
  .sprites.map2 . : AT(0x27e00)
  {
    map2.o(.sprites)
    . = ALIGN(65536);
  }

  . &= 0xffff;
  .sprites.float . : AT(0x37e00)
  {
    font.o(.sprites)
    nave.o(.sprites)
  }
}
