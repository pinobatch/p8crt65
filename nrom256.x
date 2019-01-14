#
# Linker script for Concentration Room (lite version)
# Copyright 2010 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#
MEMORY {
  ZP:       start = $10, size = $f0, type = rw;
  # use first $10 zeropage locations as locals
  HEADER:   start = 0, size = $0010, type = ro, file = %O, fill=yes, fillval=$00;
  RAM:      start = $0300, size = $0500, type = rw, define=yes;

  ROM0:     start = $8000, size = $8000, type = ro, file = %O, fill=yes, fillval=$FF;
  CHRROM:   start = $0000, size = $2000, type = ro, file = %O, fill=yes, fillval=$FF;
}

SEGMENTS {
  INESHDR:    load = HEADER, type = ro, align = $10;
  ZEROPAGE:   load = ZP, type = zp;
  BSS:        load = RAM, type = bss, define = yes, align = $100;
  LIBDATA:    load = ROM0, type = ro, align = $10, optional=1;
  PENTLYCODE: load = ROM0, type = ro, optional=1;
  PENTLYDATA: load = ROM0, type = ro, optional=1;
  CODE:       load = ROM0, type = ro, align = $100;
  RODATA:     load = ROM0, type = ro, align = $10;
  DATA:       load = ROM0, run=RAM, type = ro, align = $10, define=yes;
  STARTUP:    load = ROM0, type = ro, optional=1;
  ONCE:       load = ROM0, type = ro, optional=1;
  VECTORS:    load = ROM0, type = ro, start = $FFFA;
  CHR:        load = CHRROM, type = ro, align = $10;
}

FILES {
  %O: format = bin;
}

FEATURES {
    CONDES:    segment = STARTUP,
               type    = constructor,
               label   = __CONSTRUCTOR_TABLE__,
               count   = __CONSTRUCTOR_COUNT__;
    CONDES:    segment = STARTUP,
               type    = destructor,
               label   = __DESTRUCTOR_TABLE__,
               count   = __DESTRUCTOR_COUNT__;
}
