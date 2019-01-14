;
; cc65 bindings for Pin Eight interface
;

.include "popslide.inc"

OAM = $0200
PPUCTRL = $2000
PPUMASK = $2001
PPUSTATUS = $2002
OAMADDR = $2003
PPUSCROLL = $2005
OAM_DMA = $4014

P8C_USE_SPRITE_0 = 0

; cc65 calling convention summarized
;
; Like Forth, cc65 uses two stacks: the hardware stack for return
; addresses and a separate one for values.  The latter is a software
; defined full descending stack whose top is stored in zero page
; variable sp, contianing parameters and automatically allocated
; local variables.  A function call pushes parameters on the stack
; from left to right, without promoting char to int.  This means 3
; arguments of type char, int, char appear in sp[3], sp[1], and sp[0]
; respectively.  Adding __fastcall__ to a function's prototype puts
; the rightmost parameter in register pair XA instead of pushing it:
; bits 7-0 in A, bits 15-8 in X, and bits 31-16 of a long in sreg.
;
; The callee may overwrite up to 18 bytes of local variables in zero
; page: sreg (2 bytes), regsave (4 bytes), ptr1-ptr4 (2 bytes each),
; and tmp1-tmp4 (1 byte each).  The callee must pop all pushed
; parameters by adding their total size to sp.
;
; Sources:
; https://github.com/cc65/wiki/wiki/Parameter-passing-and-calling-conventions
; https://github.com/cc65/wiki/wiki/Parameter-and-return-stacks
.importzp sp  ; pointer to top of value stack
.importzp tmp1, tmp2, tmp3, tmp4  ; 1-byte temporaries
.importzp ptr1, ptr2, ptr3, ptr4, sreg  ; 2-byte temporaries
.importzp regsave  ; 4-byte temporary

.export _p8c_init, _p8c_clear_nt, _p8c_clear_oam, _p8c_vsync, p8c_nmi
.export OAM
.exportzp _p8c_PPUCTRL, _p8c_PPUMASK, _p8c_SCX, _p8c_SCY, _p8c_vbltasks
.exportzp _cur_keys, _new_keys, _das_keys, _das_timer
.import _p8c_above_sprite_0
.import ppu_clear_nt, ppu_clear_oam
.importzp cur_keys

.zeropage
_p8c_PPUCTRL: .res 1
_p8c_PPUMASK: .res 1
_p8c_SCX: .res 1
_p8c_SCY: .res 1
_p8c_vbltasks: .res 1
_nmis: .res 1
_cur_keys: .res 2
_new_keys: .res 2
_das_keys: .res 2
_das_timer: .res 2

.code

.proc _p8c_init
  lda #0
  sta PPUMASK
  sta _p8c_PPUCTRL
  sta _p8c_PPUMASK
  sta _p8c_SCX
  sta _p8c_SCY
  sta _p8c_vbltasks
  lda #$80
  sta PPUCTRL
  lda #$FF
  sta _cur_keys+0
  sta _cur_keys+1
  jmp popslide_init
.endproc

; void __fastcall__ p8c_clear_nt(unsigned char nametable,
;   unsigned char tilenum, unsigned char attrvalue);
.proc _p8c_clear_nt
  sta tmp1     ; attribute value
  lda #$80
  sta PPUCTRL  ; write +1, not +32
  ; Pop arguments into A and Y 
  ldy #1
  lda (sp),y   ; nametable address high
  tax
  dey
  lda (sp),y   ; tile number
  ldy tmp1
  jsr ppu_clear_nt
  lda #2
  jmp add_a_to_sp
.endproc

; void __fastcall__ p8c_clear_oam(unsigned char startindex);
_p8c_clear_oam = ppu_clear_oam+1

; void p8c_vsync(void);
.proc _p8c_vsync
  lda _nmis
  :
    cmp _nmis
    beq :-
  rts
.endproc

;;
; General-purpose NMI handler for p865 programs
; @param p8c_PPUCTRL  value for $2000; if bit 7 clear, do nothing
; @param p8c_PPUMASK  value for $2001
; @param p8c_SCX      value for $2005 first write
; @param p8c_SCY      value for $2005 second write
; @param p8c_vbltasks list of things to do in vblank:
;   $80 for OAM DMA
;   $40 for popslide
;   $20 for sprite 0 wait
.proc p8c_nmi
  inc _nmis
  bit _p8c_PPUCTRL
  bpl trivial

  ; Don't push all regs because popslide never uses Y.  Only if an
  ; "above sprite 0" routine is called does Y need to be pushed.
  pha
  txa
  pha

  lda _p8c_vbltasks
  ldx #0
  stx PPUMASK
  stx _p8c_vbltasks
  asl a
  bcc no_oam
    stx OAMADDR
    ldx #>OAM
    stx OAM_DMA
  no_oam:
  asl a
  pha
  bcc no_popslide
    jsr popslide_terminate_blit
  no_popslide:

  lda _p8c_SCX
  sta PPUSCROLL
  lda _p8c_SCY
  sta PPUSCROLL
  lda _p8c_PPUCTRL
  sta PPUCTRL
  lda _p8c_PPUMASK
  sta PPUMASK

  pla
  asl a
.if ::P8C_USE_SPRITE_0
  bcc no_sprite0
    tya
    pha
    jsr _p8c_above_sprite_0
    pla
    tay
    s0_wait_for_0:
      bit PPUSTATUS
      bvs s0_wait_for_0
    lda #$C0
    s0_wait_for_1:
      bit PPUSTATUS
      beq s0_wait_for_1
  no_sprite0:
.endif

  ; again no need to pop Y
  pla
  tax
  pla
trivial:
  rti
.endproc

; Popslide frontend ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.proc _nstripe_memcpy_down
  ora #$80
  ; fall through
.endproc

;;
; @param A count (1-64), bit 7 set for vertical
; @param sp[0] source address
; @param sp[2] destination address
.proc _nstripe_memcpy

  ; Fill a packet header
  ldx popslide_used
  sec
  sbc #1
  sta popslide_buf+2,x

  ldy #3
  lda (sp),y
  sta popslide_buf+0,x  ; VRAM address is big endian!
  dey
  lda (sp),y
  sta popslide_buf+1,x

  ; Get the starting pointer
  dey
  lda (sp),y
  sta ptr1+1
  dey
  lda (sp),y
  sta ptr1+0

  ; Find the end of the copy buffer
  clc
  lda popslide_buf+2,x
  and #$3F
  tay  ; A = Y = length - 1
  adc popslide_used  ; A = length + data size - 1
  ; TODO: Potential problem here if buffer full
  adc #4  ; size of header + 1
  sta popslide_used
  tax
  dex
  
  copyloop:
    lda (ptr1),y
    sta popslide_buf,x
    dex
    dey
    bpl copyloop
  
  lda #4  ; Clean up stack
.endproc
.proc add_a_to_sp
  clc
  adc sp
  sta sp
  bcc :+
    inc sp+1
  :
  rts
.endproc

.proc _nstripe_memset_down
  ora #$80
  ; fall through
.endproc

;;
; @param A count (1-64), bit 7 set for vertical
; @param sp[0] byte value
; @param sp[1] destination address
.proc _nstripe_memset

  ; Construct the header
  clc
  adc #63
  ldx popslide_used
  sta popslide_buf+2,x  ; Run length
  ldy #2
  lda (sp),y
  sta popslide_buf+0,x  ; VRAM address high
  dey
  lda (sp),y
  sta popslide_buf+1,x  ; VRAM address low
  dey
  lda (sp),y
  sta popslide_buf+3,x  ; byte value

  ; Move the used pointer ahead by 4
  txa
  clc
  adc #4
  sta popslide_used

  lda #3  ; Clean up stack
  jmp add_a_to_sp
.endproc
