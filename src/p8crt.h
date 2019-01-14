#ifndef P8CRT_H
#define P8CRT_H

/* NMI handler *****************************************************/

/**
 * Value to write to $2000 when reenabling rendering.  Bit 7 off
 * disables most NMI handler functionality.
 */
extern unsigned char p8c_PPUCTRL;
#pragma zpsym ("p8c_PPUCTRL")
#define NT_2000    0x00
#define NT_2400    0x01
#define NT_2800    0x02
#define NT_2C00    0x03
#define VRAM_DOWN  0x04
#define OBJ_0000   0x00
#define OBJ_1000   0x08
#define OBJ_8X16   0x20
#define BG_0000    0x00
#define BG_1000    0x10
#define VBLANK_NMI 0x80

/**
 * Value to write to $2001 when reenabling rendering.  Bits 4-3 off
 * turn rendering off, but NMI handler execution continues.
 */
extern unsigned char p8c_PPUMASK;
#pragma zpsym ("p8c_PPUMASK")
#define LIGHTGRAY 0x01
#define BG_OFF    0x00
#define BG_CLIP   0x08
#define BG_ON     0x0A
#define OBJ_OFF   0x00
#define OBJ_CLIP  0x10
#define OBJ_ON    0x14
#define TINT_R    0x20
#define TINT_G    0x40
#define TINT_B    0x80

/**
 * Scroll values to write to $2005 when reenabling rendering.
 */
extern unsigned char p8c_SCX, p8c_SCY;
#pragma zpsym ("p8c_SCX")
#pragma zpsym ("p8c_SCY")

/**
 * Tasks to perform in NMI handler
 * 0x80: Perform OAM DMA
 * 0x40: Perform Popslide copy
 * 0x20: Call p8c_above_sprite_0() then wait for sprite 0
 */
extern unsigned char p8c_vbltasks;
#pragma zpsym ("p8c_vbltasks")
#define VBLTASK_OAM     (1<<7)
#define VBLTASK_VRAM    (1<<6)
#define VBLTASK_SPRITE0 (1<<5)

/**
 * Number of times the NMI handler has run since p8c_init()
 */
extern unsigned char nmis;
#pragma zpsym ("nmis")

/**
 * Buffer to copy to OAM if task is set
 */
extern unsigned char OAM[256];

/**
 * Current index into OAM[].  Your code might initialize this to
 * 0 or 4 at the start of each frame.
 */
extern unsigned char oam_used;
#pragma zpsym ("oam_used")

/**
 * Sets up variables used by the NMI handler and Popslide buffer.
 */
void p8c_init(void);

/**
 * If sprite 0 waiting is enabled, the NMI handler calls this
 * after enabling rendering and before sprite 0 hit testing.
 */
void p8c_above_sprite_0(void);

/**
 * Waits for vertical blanking.  The NMI handler will have run.
 */
void p8c_vsync(void);

/* Popslide: a VRAM stuffer ****************************************/

/**
 * Queued VRAM update data
 */
extern unsigned char popslide_buf[192];

/**
 * Current index into popslide_buf[]
 */
extern unsigned char popslide_used;

/**
 * Queues a set of stripes.  See Popslide docs for buffer format.
 * @param src pointer to a $FF-terminated list of stripes
 */
void __fastcall__ nstripe_append(const void *src);

/**
 * Queues a copy to consecutive video memory locations.
 * @param vram_dst starting destination address in video memory,
 * usually 0x0000-0x2FFF or 0x3F00-0x3F1F)
 * @param src starting source address in CPU memory
 * @param count number of bytes to copy; if not 1 to 64, behavior is
 * undefined
 */
void __fastcall__ nstripe_memcpy(unsigned int vram_dst, const void *src, unsigned char count);

/**
 * Queues a copy to video memory locations 32 bytes apart.
 * @param vram_dst starting destination address in video memory,
 * usually 0x0000-0x2FFF or 0x3F00-0x3F1F)
 * @param src starting source address in CPU memory
 * @param count number of bytes to copy; if not 1 to 64, behavior is
 * undefined
 */
void __fastcall__ nstripe_memcpy_down(unsigned int vram_dst, const void *src, unsigned char count);

/**
 * Queues a fill to consecutive video memory locations.
 * @param vram_dst starting destination address in video memory,
 * usually 0x0000-0x2FFF or 0x3F00-0x3F1F)
 * @param ch value to write
 * @param count number of bytes to copy; if not 1 to 64, behavior is
 * undefined
 */
void __fastcall__ nstripe_memset(unsigned int vram_dst, unsigned char ch, unsigned char count);

/**
 * Queues a fill to video memory locations 32 bytes apart.
 * @param vram_dst starting destination address in video memory,
 * usually 0x0000-0x2FFF or 0x3F00-0x3F1F)
 * @param ch value to write
 * @param count number of bytes to copy; if not 1 to 64, behavior is
 * undefined
 */
void __fastcall__ nstripe_memset_down(unsigned int vram_dst, unsigned char ch, unsigned char count);

/**
 * Writes a NUL-terminated string to video memory, adding a value to
 * each ASCII character code.
 * @param vram_dst starting destination address in video memory
 * (usually 0x2000-0x2BD0)
 * @param src the string to write
 * @param addamount the value to add to each character code
 */
void __fastcall__ nstripe_strcpy_add(unsigned int vram_dst, const char *src, unsigned char addamount);

/**
 * Writes a NUL-terminated string to video memory as ASCII codes.
 * @param vram_dst starting destination address in video memory
 * (usually 0x2000-0x2BD0)
 * @param src the string to write
 */
void __cdecl__ nstripe_strcpy(unsigned int vram_dst, const char *src);

/* Other PPU operations ********************************************/

/**
 * Sets 1024 bytes of video memory to a given tile number as if it
 * were a nametable.  If rendering is on, behavior is undefined.
 * @param nametable high byte of starting VRAM address, usually
 * 0x20, 0x24, 0x28, or 0x2C; lower values affect CHR RAM
 * @param tilenum value to write to first 960 bytes
 * @param attrvalue value to write to last 64 bytes
 */
void __fastcall__ p8c_clear_nt(unsigned char nametable,
  unsigned char tilenum, unsigned char attrvalue);

/**
 * Makes sprites starting at a given OAM index (4, 8, 12, 16, ...)
 * invisible as of next OAM DMA.
 */
void __fastcall__ p8c_clear_oam(unsigned char startindex);

/* Input ***********************************************************/

/**
 * The buttons held on both controllers as of the most recent
 * p8c_read_pads() call.
 */
extern unsigned char cur_keys[2];
#pragma zpsym ("cur_keys")

/**
 * The buttons changing from unpressed to pressed held on both controllers as of the most recent
 * p8c_read_pads() call.
 */
extern unsigned char new_keys[2];
#pragma zpsym ("new_keys")

/**
 * Reads the controller, updating p8c_cur_keys and p8c_new_keys.
 */
void read_pads(void);

#define KEY_A      (1<<7)
#define KEY_B      (1<<6)
#define KEY_SELECT (1<<5)
#define KEY_START  (1<<4)
#define KEY_UP     (1<<3)
#define KEY_DOWN   (1<<2)
#define KEY_LEFT   (1<<1)
#define KEY_RIGHT  (1<<0)


#endif
