.include "nes2header.inc"
.export _exit
.import _main, ppu_clear_nt, _p8c_clear_oam, _p8c_init, p8c_nmi
.import copydata, initlib
.import __RAM_START__, __RAM_SIZE__
.importzp sp

; Force this to override cc65 startup code
.export   __STARTUP__ : absolute = 1

PPUCTRL = $2000
PPUMASK = $2001
PPUSTATUS = $2002
SNDCHN = $4015
P2 = $4017
_exit = start

.segment "INESHDR"
; NROM header
nes2mapper 0
nes2prg 32768
nes2chr 8192
nes2mirror 'V'
nes2tv 'N'
nes2end

.segment "STARTUP"
.proc start
  ; The very first thing to do when powering on is to put all sources
  ; of interrupts into a known state.
  sei             ; Disable interrupts
  ldx #$00
  stx PPUCTRL     ; Disable NMI and set VRAM increment to 32
  stx PPUMASK     ; Disable rendering
  stx $4010       ; Disable DMC IRQ
  dex             ; Subtracting 1 from $00 gives $FF, which is a
  txs             ; quick way to set the stack pointer to $01FF
  bit PPUSTATUS   ; Acknowledge stray vblank NMI across reset
  bit SNDCHN      ; Acknowledge DMC IRQ
  lda #$40
  sta P2          ; Disable APU Frame IRQ
  lda #$0F
  sta SNDCHN      ; Disable DMC playback, initialize other channels

vwait1:
  bit PPUSTATUS   ; It takes one full frame for the PPU to become
  bpl vwait1      ; stable.  Wait for the first frame's vblank.

  ; 29700 cycles to init the rest of the chipset...

  ; Unlike authentic MOS 6502, second-source Ricoh 6502 lacks
  ; working decimal mode.  Turn it off for full compatibility with
  ; debuggers and a small number famiclones that have decimal mode.
  cld

  ; Clear OAM and the zero page here.
  lda #0
  jsr _p8c_clear_oam  ; clear out OAM from A to end and set X to 0

  ; There are "holy wars" (perennial disagreements) on nesdev over
  ; whether it's appropriate to zero out RAM in the init code.  Some
  ; anti-zeroing people say it hides programming errors.  But the C
  ; language requires initializing all statically allocated variables
  ; to zero.
  txa
clear_zp:
  sta $00,x
  sta $0300,x
  sta $0400,x
  sta $0500,x
  sta $0600,x
  sta $0700,x
  inx
  bne clear_zp

  ; Set up cc65's value stack at end of RAM memory area
  lda #<(__RAM_START__+__RAM_SIZE__)
  sta sp
  lda #>(__RAM_START__+__RAM_SIZE__)
  sta sp+1

  ; Copy preinitialized data (DATA segment) from ROM to RAM
  jsr copydata

  ; Other things that can be done here (not shown):
  ; Set up PRG RAM
  ; Copy initial high scores, bankswitching trampolines, etc. to RAM
  ; Set up initial CHR banks
  ; Set up your sound engine

vwait2:
  bit PPUSTATUS  ; After the second vblank, we know the PPU has
  bpl vwait2     ; fully stabilized.
  ; After this point always wait for vblank using PPUSTATUS because
  ; of a race condition in the PPU.

  ; Clear nametable memory no matter whether mirroring is
  ; horizontal, vertical, or L-shaped
  lda #$00
  tay
  ldx #$20
  jsr ppu_clear_nt
  ldx #$2C
  jsr ppu_clear_nt

  jsr _p8c_init
  jmp _main
.endproc

irq_handler = start

.segment "VECTORS"
  .addr p8c_nmi, start, irq_handler
