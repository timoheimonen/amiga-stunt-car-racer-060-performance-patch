; Skip track pieces that lie wholly outside the editor view.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Skip a piece whose every vertex lies outside one side of the view.
; A0 rows, D1 row count, render_piece. Z=0 draws the piece, Z=1 skips it.
; Each vertex counts twice, on the road and 128 below it at the foot of its wall.
; The first layer decides, and the second reads the answer from piece_flags.
; D1 and A0 are preserved, D0 is not.
piece_visible:
        movem.l d0-d7/a0-a4,-(sp)
        lea piece_flags(pc),a4
        adda.w render_piece(pc),a4
        tst.w render_layer-module_start(a5)
        bne .cached
        tst.w overview_active-module_start(a5)
        bne .keep
        tst.w block_render_active-module_start(a5)
        beq.s .go
        tst.w block_preview_valid-module_start(a5)
        beq .keep
.go:
        move.w d1,d7
        add.w d7,d7
        subq.w #1,d7
        moveq #-1,d6             ; AND of outcodes
.vertex:
        moveq #0,d0
        move.w (a0)+,d0
        sub.l camera_x(pc),d0
        moveq #0,d1
        move.w (a0)+,d1
        moveq #0,d2
        move.w (a0)+,d2
        sub.l camera_z(pc),d2
        neg.l d1
        add.l camera_y(pc),d1    ; h: positive downward
        move.w camera_right_x(pc),d3
        ext.l d3
        move.w camera_right_z(pc),d4
        ext.l d4
        move.l d0,d5
        muls.l d3,d5
        move.l d2,a1
        muls.l d4,d2
        add.l d2,d5
        asr.l #7,d5
        asr.l #7,d5              ; side
        muls.l d4,d0
        neg.l d0
        move.l a1,d2
        muls.l d3,d2
        add.l d0,d2
        asr.l #7,d2
        asr.l #7,d2              ; forward
        bsr piece_outcode
        addi.l #128,d1
        bsr piece_outcode
        dbra d7,.vertex
        tst.w d6
        beq.s .keep
        move.b #1,(a4)
        movem.l (sp)+,d0-d7/a0-a4
        moveq #0,d0
        rts
.keep:  clr.b (a4)
        movem.l (sp)+,d0-d7/a0-a4
        moveq #1,d0
        rts
.cached:
        tst.b (a4)
        movem.l (sp)+,d0-d7/a0-a4
        seq d0
        ext.w d0
        tst.w d0
        rts

; D5 side, D2 forward, D1 h. AND the outcode into D6. Preserves D1/D2/D5/D7.
piece_outcode:
        movem.l d1-d2,-(sp)
        bsr view_project         ; D2 depth, D1 vertical
        move.l d1,d3
        move.l d2,d4
        moveq #0,d0
        ; Camera behind test, then the X and Y planes with two pixels of margin.
        cmpi.l #512,d4
        bge.s .front
        bset #0,d0
.front:
        move.l d5,d1
        muls.l #FREE_FOCAL,d1
        move.l d4,d2
        mulu.l #VIEW_CX+2,d2     ; D>=0 only, negatives fall to the behind code
        tst.l d4
        bpl.s .x
        moveq #0,d2
.x:     move.l d1,a2
        add.l d2,a2
        move.l a2,d1
        bpl.s .xr
        bset #1,d0
.xr:    move.l d5,d1
        muls.l #FREE_FOCAL,d1
        cmp.l d2,d1
        ble.s .y
        bset #2,d0
.y:     move.l d3,d1
        muls.l #FREE_FOCAL,d1
        move.l d4,d2
        tst.l d2
        bpl.s .y2
        moveq #0,d2
.y2:    mulu.l #VIEW_CY-VIEW_TOP+2,d2
        add.l d1,d2
        bpl.s .y3
        bset #3,d0
.y3:    move.l d4,d2
        tst.l d2
        bpl.s .y4
        moveq #0,d2
.y4:    mulu.l #VIEW_BOTTOM-VIEW_CY+2,d2
        cmp.l d2,d1
        ble.s .done
        bset #4,d0
.done:  and.w d0,d6
        movem.l (sp)+,d1-d2
        rts

; One flag per piece, and one for the ghost that follows a full track.
piece_flags: dcb.b EDITOR_MAX_PIECES+1,0
        even
