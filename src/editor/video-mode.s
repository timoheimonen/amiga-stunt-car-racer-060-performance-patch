; Measure whether the display runs PAL or NTSC.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Video standard of the running display, measured from the beam counter.
; The game never writes BEAMCON0, so the mode the machine booted in (or was
; switched to before the game) stays in force. The chip ID in VPOSR only
; gives the chip's default, so the frame length is measured instead:
; PAL fields end at line 311/312, NTSC fields at 261/262.
; Returns D0.L = 0 for PAL, 1 for NTSC; a stalled beam counter gives PAL.
; Preserves all other registers. 68000 code, callable with or without the OS.
VIDEO_NTSC_LAST_LINE equ 287
video_is_ntsc:
        movem.l d1-d6,-(sp)
        moveq #0,d2             ; highest line seen in measured fields
        moveq #3,d5             ; field starts: one to align, two measured
        move.l #4000000,d4      ; bounded sample count
        bsr.s .line
        move.w d1,d3
.sample:
        subq.l #1,d4
        beq.s .pal
        bsr.s .line
        cmp.w d3,d1
        bcc.s .same             ; not lower than before: same field
        subq.w #1,d5            ; the beam wrapped: a new field started
        beq.s .measured
        bra.s .next
.same:  cmpi.w #3,d5
        beq.s .next             ; still aligning to a field start
        cmp.w d2,d1
        bls.s .next
        move.w d1,d2
.next:  move.w d1,d3
        bra.s .sample
.measured:
        cmpi.w #VIDEO_NTSC_LAST_LINE,d2
        bhi.s .pal
        moveq #1,d0
        bra.s .done
.pal:   moveq #0,d0
.done:  movem.l (sp)+,d1-d6
        rts
; D1.W = 9-bit vertical beam position. VPOSR is read before and after
; VHPOSR; a V8 change between them (line 255/256 or the field wrap) retries.
.line:  move.w $dff004,d0
        move.w $dff006,d1
        move.w $dff004,d6
        eor.w d0,d6
        btst #0,d6
        bne.s .line
        lsr.w #8,d1
        andi.w #1,d0
        lsl.w #8,d0
        or.w d0,d1
        rts
