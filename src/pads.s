;
; NES controller reading code (non-DPCM-safe version)
; Copyright 2010 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.
;
.export _read_pads, _autorepeat
.importzp _cur_keys, _new_keys, _das_keys, _das_timer
.importzp ptr1, ptr2

JOY1      = $4016
JOY2      = $4017

; time until autorepeat starts making keypresses
DAS_DELAY = 15
; time between autorepeat keypresses
DAS_SPEED = 3

.code
.proc _read_pads
thisRead = ptr1
lastFrameKeys = ptr2

  ; store the current keypress state to detect key-down later
  lda _cur_keys
  sta lastFrameKeys
  lda _cur_keys+1
  sta lastFrameKeys+1

  ; Read the joypads once.  We have no DPCM in the game and therefore
  ; no need to reread to detect bit deletions.
  jsr read_pads_once

  ldx #1
@fixupKeys:

  ; if the player's keys read out the same ways both times, update
  lda thisRead,x
  sta _cur_keys,x
@dontUpdateGlitch:
  
  lda lastFrameKeys,x   ; A = keys that were down last frame
  eor #$FF              ; A = keys that were up last frame
  and _cur_keys,x        ; A = keys down now and up last frame
  sta _new_keys,x
  dex
  bpl @fixupKeys
  rts

read_pads_once:
  lda #1
  sta thisRead+1
  sta JOY1
  lda #0
  sta JOY1
  loop:
    lda JOY1
    and #$03
    cmp #1
    rol thisRead+0
    lda JOY2
    and #$03
    cmp #1
    rol thisRead+1
    bcc loop
  rts
.endproc

;;
; Computes autorepeat (delayed-auto-shift) on the gamepad for one
; player, ORing result into the player's new_keys.
; @param A which player to calculate autorepeat for
.proc _autorepeat
  tax
  lda _cur_keys,x
  beq no_das
  lda _new_keys,x
  beq no_restart_das
  sta _das_keys,x
  lda #DAS_DELAY
  sta _das_timer,x
  bne no_das
no_restart_das:
  dec _das_timer,x
  bne no_das
  lda #DAS_SPEED
  sta _das_timer,x
  lda _das_keys,x
  and _cur_keys,x
  ora _new_keys,x
  sta _new_keys,x
no_das:
  rts
.endproc
