#include "p8crt.h"

const unsigned char base_stripe[] = {
  0x3F,0x00,0x03,0x0F,0x00,0x10,0x20,
  0x22,0xC1,0x1D,'P','i','n','o','\'','s',' ','f','i','r','s','t',' ','C',' ','p','r','o','g','r','a','m',' ','f','o','r',' ','N','E','S',
  0xFF
};

int main(void) {
  nstripe_append(base_stripe);
  nstripe_strcpy(0x210A, "Hello World");
  p8c_SCX = p8c_SCY = 0;
  p8c_PPUMASK = BG_ON;
  p8c_vbltasks = VBLTASK_VRAM;
  p8c_PPUCTRL = VBLANK_NMI;

  do {
    read_pads();
    p8c_vsync();
  } while (!(new_keys[0] & KEY_A));

  nstripe_strcpy(0x2149, "You pressed A!");
  nstripe_strcpy(0x2166, "Sorry pannenkoek2012");
  nstripe_strcpy_add(0x2202, "uppercase", -0x20);
  nstripe_strcpy_add(0x2215, "LOWERCASE", 0x20);
  p8c_vbltasks = VBLTASK_VRAM;

  while (1) { p8c_vsync(); }
  return 0;
}
