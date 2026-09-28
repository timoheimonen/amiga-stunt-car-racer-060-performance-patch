; Show the building HUD: section rise, choice number, piece count, fit reason and closing guide.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Building HUD: block name with rise and choice number, piece count, exact
; rejection reason and a closing guide from the open end to the start line.
; hud_measure runs while a preview is installed, so a valid append preview
; is measured from its own open end. Text is drawn after the model restore.
HUD_LEVEL_SHIFT equ 8                  ; one displayed height level = 256
hud_measure:
        movem.l d0-d7/a0-a2,-(sp)
        clr.w hud_aid_valid-module_start(a5)
        move.w block_render_active(pc),hud_choosing-module_start(a5)
        move.w block_preview_valid(pc),hud_preview_valid-module_start(a5)
        move.w editor_track+30(pc),hud_closes-module_start(a5)
        tst.w model_valid-module_start(a5)
        beq .done
        cmpi.l #3,editor_track+24-module_start(a5)
        blo .done
        tst.w hud_choosing-module_start(a5)
        beq.s .measure
        tst.w hud_preview_valid-module_start(a5)
        beq .done
.measure:
        tst.w editor_track+30-module_start(a5)
        bne .done
        move.w editor_track+28(pc),d0
        beq .done
        subq.w #1,d0
        move.w d0,d1
        add.w d1,d1
        lea model_row_counts(pc),a0
        move.w (a0,d1.w),d1
        subq.w #1,d1
        mulu.w #12,d1
        mulu.w #EDITOR_GEOMETRY_STRIDE,d0
        add.w d1,d0
        lea model_geometry(pc),a0
        adda.w d0,a0                   ; open end: last exit row
        lea model_geometry(pc),a1      ; start line: first entrance row
        ; Direction indices of both right axes (45-degree steps, left +).
        move.w 6(a1),d1
        sub.w (a1),d1
        move.w 10(a1),d2
        sub.w 4(a1),d2
        bsr view_axis_index
        move.w d1,d7
        move.w 6(a0),d1
        sub.w (a0),d1
        move.w 10(a0),d2
        sub.w 4(a0),d2
        bsr view_axis_index
        sub.w d1,d7
        andi.w #7,d7
        move.w d7,hud_turn-module_start(a5)
        lsl.w #2,d1
        lea view_axes(pc),a2
        move.w (a2,d1.w),d6            ; right X
        ext.l d6
        move.w 2(a2,d1.w),d7           ; right Z
        ext.l d7
        ; Centre difference start - end, twice-sum form avoids a half unit.
        bsr hud_centre_delta           ; X
        move.l d0,d3
        bsr hud_centre_delta           ; Y
        move.l d0,d4
        bsr hud_centre_delta           ; Z
        move.l d0,d5
        ; side = D.right, ahead = D.forward with forward = (-right Z, right X)
        move.l d3,d0
        muls.l d6,d0
        move.l d5,d1
        muls.l d7,d1
        add.l d1,d0
        asr.l #7,d0
        asr.l #7,d0
        bsr hud_cells
        move.w d0,hud_side-module_start(a5)
        move.l d5,d0
        muls.l d6,d0
        move.l d3,d1
        muls.l d7,d1
        sub.l d1,d0
        asr.l #7,d0
        asr.l #7,d0
        bsr hud_cells
        move.w d0,hud_ahead-module_start(a5)
        move.l d4,d0
        bsr hud_levels
        move.w d0,hud_rise-module_start(a5)
        move.w #1,hud_aid_valid-module_start(a5)
.done:
        movem.l (sp)+,d0-d7/a0-a2
        rts

; A0 end row, A1 start row (both advance one axis word): D0 = start centre
; minus end centre on this axis, rounded down.
hud_centre_delta:
        moveq #0,d0
        move.w (a1),d0
        moveq #0,d1
        move.w 6(a1),d1
        add.l d1,d0
        moveq #0,d1
        move.w (a0),d1
        sub.l d1,d0
        move.w 6(a0),d1
        sub.l d1,d0
        asr.l #1,d0
        addq.l #2,a0
        addq.l #2,a1
        rts

; D0 world units -> nearest map cells (2048), and nearest levels (256).
hud_cells:
        addi.l #1024,d0
        asr.l #8,d0
        asr.l #3,d0
        rts
hud_levels:
        addi.l #128,d0
        asr.l #HUD_LEVEL_SHIFT,d0
        rts

; Row 181 while choosing: name, rise and choice number / choices.
hud_block_line:
        lea hud_line(pc),a1
        move.w building_choice(pc),d0
        add.w d0,d0
        lea block_candidates(pc),a0
        move.w (a0,d0.w),d0
        move.w d0,-(sp)
        bsr block_descriptor
        movea.l a4,a0
        adda.w 2(a4),a0
        bsr hud_put_text
        moveq #21,d1
        bsr hud_pad
        move.w (sp)+,d0
        lsr.w #2,d0
        lsl.w #2,d0
        lea block_heights(pc),a0
        moveq #0,d1
        move.w (a0,d0.w),d1
        ext.l d1
        move.l d1,d0
        bsr hud_levels
        bsr hud_put_rise
        moveq #31,d1
        bsr hud_pad
        move.w building_choice(pc),d0
        addq.w #1,d0
        bsr hud_put_decimal
        move.b #'/',(a1)+
        move.w building_candidate_count(pc),d0
        bsr hud_put_decimal
        clr.b (a1)
        lea hud_line(pc),a0
        rts

; Row 192 for whole-block tracks; otherwise the practice status.
hud_status_line:
        cmpi.l #3,editor_track+24-module_start(a5)
        blo .practice
        tst.w hud_choosing-module_start(a5)
        beq.s .browse
        tst.w hud_preview_valid-module_start(a5)
        bne.s .valid
        move.w block_fail(pc),d0
        add.w d0,d0
        lea hud_fail_texts(pc),a0
        move.w (a0,d0.w),d0
        adda.w d0,a0
        bra.s .draw
.valid:
        tst.w hud_closes-module_start(a5)
        beq.s .aid
        lea hud_closes_text(pc),a0
        bra.s .draw
.browse:
        tst.w editor_track+30-module_start(a5)
        bne.s .practice
        cmpi.w #1,practice_reason-module_start(a5)
        bne.s .practice
.aid:
        tst.w hud_aid_valid-module_start(a5)
        beq.s .practice
        bsr hud_build_aid
        movea.l draw_surface(pc),a1
        adda.w #7680,a1
        adda.w d1,a1
        bra storage_text_line
.practice:
        bsr practice_text
.draw:
        movea.l draw_surface(pc),a1
        adda.w #7682,a1
        bra storage_text_line

; "START n LEFT n FWD UP n FACE L90". A0 = text, D1 = column: the normal
; two-character margin shrinks when the text is longer than 38 characters.
hud_build_aid:
        lea hud_line(pc),a1
        lea hud_start_text(pc),a0
        bsr hud_put_text
        move.w hud_side(pc),d0
        beq.s .ahead
        lea hud_right_text(pc),a2
        bpl.s .side
        neg.w d0
        lea hud_left_text(pc),a2
.side:
        move.b #' ',(a1)+
        bsr hud_put_decimal
        movea.l a2,a0
        bsr hud_put_text
.ahead:
        move.w hud_ahead(pc),d0
        beq.s .rise
        lea hud_forward_text(pc),a2
        bpl.s .along
        neg.w d0
        lea hud_back_text(pc),a2
.along:
        move.b #' ',(a1)+
        bsr hud_put_decimal
        movea.l a2,a0
        bsr hud_put_text
.rise:
        move.w hud_rise(pc),d0
        ext.l d0
        bsr hud_put_rise
        move.w hud_turn(pc),d0
        beq.s .end
        lea hud_face_text(pc),a0
        bsr hud_put_text
        cmpi.w #4,d0
        bne.s .sided
        lea hud_reverse_text(pc),a0
        bsr hud_put_text
        bra.s .end
.sided:
        move.b #'L',(a1)+
        cmpi.w #4,d0
        blo.s .angle
        move.b #'R',-1(a1)
        neg.w d0
        addq.w #8,d0
.angle:
        mulu.w #45,d0
        bsr hud_put_decimal
.end:
        clr.b (a1)
        lea hud_line(pc),a0
        clr.b 40(a0)
        moveq #2,d1
        move.l a1,d0
        sub.l a0,d0
        subi.l #38,d0
        ble.s .fits
        sub.l d0,d1
        bpl.s .fits
        moveq #0,d1
.fits:
        rts

; D0.l levels -> " UP n" / " DOWN n", nothing when level. A1 advances.
hud_put_rise:
        tst.l d0
        beq.s .done
        lea hud_up_text(pc),a0
        bpl.s .text
        neg.l d0
        lea hud_down_text(pc),a0
.text:
        move.w d0,-(sp)
        bsr hud_put_text
        move.w (sp)+,d0
        bsr hud_put_decimal
.done:  rts

; Top status row: "PIECES n/64" after a short storage message (A1 = end).
hud_piece_count:
        movea.l draw_surface(pc),a0
        adda.w #880+26,a0
        cmpa.l a0,a1
        bhi.s .done
        lea hud_line(pc),a1
        lea hud_pieces_text(pc),a0
        bsr hud_put_text
        move.w editor_track+28(pc),d0
        bsr hud_put_decimal
        lea hud_capacity_text(pc),a0
        bsr hud_put_text
        clr.b (a1)
        lea hud_line(pc),a0
        movea.l draw_surface(pc),a1
        adda.w #880+28,a1
        bra storage_text_line
.done:  rts

; Copy a zero-terminated string A0 to A1 without its terminator.
hud_put_text:
        move.b (a0)+,d1
        beq.s .done
        move.b d1,(a1)+
        bra.s hud_put_text
.done:  rts

; Pad A1 with spaces to D1 characters after hud_line.
hud_pad:
        movem.l d0/a0,-(sp)
        lea hud_line(pc),a0
        adda.w d1,a0
.pad:   cmpa.l a0,a1
        bhs.s .done
        move.b #' ',(a1)+
        bra.s .pad
.done:  movem.l (sp)+,d0/a0
        rts

; Unsigned decimal of D0.w to A1. D0/D1 destroyed.
hud_put_decimal:
        andi.l #$ffff,d0
        cmpi.w #10,d0
        blo.s .digit
        divu.w #10,d0
        move.l d0,-(sp)
        andi.l #$ffff,d0
        bsr hud_put_decimal
        move.l (sp)+,d0
        swap d0
.digit:
        addi.b #'0',d0
        move.b d0,(a1)+
        rts

hud_fail_texts:
        dc.w .red-hud_fail_texts,.limit-hud_fail_texts,.map-hud_fail_texts
        dc.w .height-hud_fail_texts,.low-hud_fail_texts,.next-hud_fail_texts
        dc.w .overlap-hud_fail_texts
.red: dc.b 'NO FIT: RED BLOCK CANNOT BE ADDED',0
.limit: dc.b 'NO FIT: 64 PIECE LIMIT',0
.map: dc.b 'NO FIT: MAP EDGE',0
.height: dc.b 'NO FIT: HEIGHT LIMIT',0
.low: dc.b 'NO FIT: ROAD BELOW SIDE BASE',0
.next: dc.b 'NO FIT: NEXT SECTION DIFFERS',0
.overlap: dc.b 'NO FIT: ROAD OVERLAP',0
hud_closes_text: dc.b 'THIS BLOCK CLOSES THE TRACK',0
hud_start_text: dc.b 'START',0
hud_left_text: dc.b ' LEFT',0
hud_right_text: dc.b ' RIGHT',0
hud_forward_text: dc.b ' FWD',0
hud_back_text: dc.b ' BACK',0
hud_up_text: dc.b ' UP ',0
hud_down_text: dc.b ' DOWN ',0
hud_face_text: dc.b ' FACE ',0
hud_reverse_text: dc.b '180',0
hud_pieces_text: dc.b 'PIECES ',0
hud_capacity_text: dc.b '/64',0
        even
hud_choosing: dc.w 0
hud_preview_valid: dc.w 0
hud_closes: dc.w 0
hud_aid_valid: dc.w 0
hud_side: dc.w 0
hud_ahead: dc.w 0
hud_rise: dc.w 0
hud_turn: dc.w 0
hud_line: dcb.b 48,0
