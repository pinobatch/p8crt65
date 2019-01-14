#include "p8crt.h"

const unsigned char hello_stripe[] = {
  0x3F,0x00,0x03,0x0F,0x00,0x10,0x20,
  0x21,0x8A,0x0A,'H','e','l','l','o',' ','W','o','r','l','d',
  0x22,0xC1,0x1D,'P','i','n','o','\'','s',' ','f','i','r','s','t',' ','C',' ','p','r','o','g','r','a','m',' ','f','o','r',' ','N','E','S',
  0xFF
};

int main(void) {
  nstripe_append(hello_stripe);
  *(unsigned char *)0x4444 = 0;
  p8c_SCX = p8c_SCY = 0;
  p8c_PPUMASK = BG_ON;
  p8c_vbltasks = VBLTASK_VRAM;
  p8c_PPUCTRL = VBLANK_NMI;
  while (1) { p8c_vsync(); }
  return 0;
}
