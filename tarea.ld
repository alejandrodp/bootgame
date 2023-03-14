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
    l1.o(.sprites)
    l2.o(.sprites)
    l3.o(.sprites)
    l4.o(.sprites)
    r1.o(.sprites)
    r2.o(.sprites)
    r3.o(.sprites)
    r4.o(.sprites)
  }
}
