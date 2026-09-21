; Preserve smoke and particle timing with 50 Hz drawing interpolation.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Original 120 ms particle simulation, with render-only 50 Hz interpolation.
; Entry replaces the two world effect calls. No change to 0x1bbac's clock.
effects_frame:
        movem.l d6-d7/a6,-(sp)
        clr.b effects_record
        tst.b active
        beq.w effects_original
        moveq #1,d6                 ; smoke
        moveq #30,d7                ; last word offset, 16 particles
        tst.b $1bb9c.l
        bpl.s effects_sparks
        tst.b $1bbdf.l
        bne.w effects_hide
        tst.b $57c3c.l
        beq.s effects_selected
        moveq #6,d7                 ; link view: four particles
        bra.s effects_selected
effects_sparks:
        moveq #2,d6
        moveq #62,d7
        move.b $1bbda.l,d0
        or.b $1bca2.l,d0
        beq.w effects_hide
        tst.b $1bd5c.l
        ble.w effects_hide
effects_selected:
        tst.b legacy_due
        bne.s effects_tick
        tst.b $1bb7e.l
        beq.w effects_clear
        cmp.b effects_mode(pc),d6
        bne.w effects_hide
        cmp.b effects_last(pc),d7
        bne.w effects_hide
        bsr.w effects_interpolate
        movea.l #$1c380,a4          ; original post-call base registers
        movea.l #$1c400,a5
        bra.s effects_return
effects_tick:
        move.b d6,effects_mode
        move.b d7,effects_last
        move.b #1,effects_record
        cmpi.b #1,d6
        bne.s effects_tick_sparks
        jsr $60c92.l
        bra.s effects_tick_done
effects_tick_sparks:
        jsr $60cf8.l
effects_tick_done:
        clr.b effects_record
effects_return:
        movem.l (sp)+,d6-d7/a6
        rts
effects_hide:
        clr.b effects_mode
        bra.s effects_return
effects_clear:
        clr.b effects_mode
        jsr $60cde.l               ; original 32-slot Y reset, no drawing
        bra.s effects_return
effects_original:
        clr.b effects_mode
        tst.b $1bbdf.l
        bne.s effects_original_sparks
        tst.b $1bb9c.l
        bpl.s effects_original_sparks
        jsr $60c92.l
effects_original_sparks:
        jsr $60cf8.l
        bra.s effects_return

; Hook both original draw calls: the final call for a respawned slot wins.
; Copies do not alter X; the original draw sets the returned condition codes.
effects_capture:
        tst.b effects_record
        beq.s effects_capture_draw
        movem.l d0/a0,-(sp)
        lea effects_anchor(pc),a0
        move.w (0,a4,d1.w),d0
        move.w d0,(0,a0,d1.w)
        move.w ($40,a4,d1.w),d0
        move.w d0,($40,a0,d1.w)
        movem.l (sp)+,d0/a0
effects_capture_draw:
        jmp $60e88.l

; Coordinates in Chip stay authoritative. Scratch receives only display data.
; Wrapped word differences preserve the original 16-bit motion at boundaries.
effects_interpolate:
        lea effects_anchor(pc),a0
        movea.l #$1c380,a1
        lea effects_display(pc),a2
        moveq #0,d6
        move.b phase(pc),d6
        moveq #63,d1
effects_lerp:
        move.w (a0)+,d0
        move.w (a1)+,d2
        sub.w d0,d2
        muls.w d6,d2
        divs.w #6,d2
        add.w d2,d0
        move.w d0,(a2)+
        dbra d1,effects_lerp
        lea effects_display(pc),a4
        movea.l #$1c400,a5
        moveq #0,d1
        move.b effects_last(pc),d1
        moveq #0,d2                ; original sprite consumers use D2.w
effects_draw:
        jsr $60e88.l               ; clipping may invalidate scratch only
        subq.b #2,d1
        bpl.s effects_draw
        rts

effects_state_start:
effects_mode: dc.b 0
effects_last: dc.b 0
effects_record: dc.b 0
        even
effects_anchor: dcb.w 64,0
effects_display: dcb.w 64,0
effects_state_end:
