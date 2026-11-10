; Render depth-tested editor spans with planar writes.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Depth-tested runs use existing planar span writes, preserving overlay order
; for equal depth (edge paint, selection and finish checker).
; D0 x, D1 end, D2 y, D3 colour. One division per span: the reciprocal depth
; steps in whole units with a remainder, the same floor as dividing per pixel.
; The caller keeps span_left below span_right, so the divisor is positive.
depth_span:
        movem.l d0-d7/a0-a2,-(sp)
        move.w d3,depth_colour-module_start(a5)
        move.w d2,depth_y-module_start(a5)
        movea.l a5,a2
        adda.l #DEPTH_BUFFER,a2
        move.w d2,d6
        subi.w #VIEW_TOP,d6
        mulu.w #SCREEN_WIDTH*2,d6
        adda.l d6,a2
        moveq #0,d4
        move.w d0,d4
        move.w d4,d6
        add.w d6,d6
        adda.w d6,a2
        moveq #0,d5
        move.w d1,d5
        move.l span_right(pc),d7
        sub.l span_left(pc),d7
        move.l span_qright(pc),d2
        sub.l span_qleft(pc),d2
        move.l d4,d0
        sub.l span_left(pc),d0
        muls.l d2,d0
        divsl.l d7,d3:d0
        tst.l d3
        bpl.s .start_floor
        subq.l #1,d0
        add.l d7,d3
.start_floor:
        add.l span_qleft(pc),d0
        divsl.l d7,d1:d2
        tst.l d1
        bpl.s .step_floor
        subq.l #1,d2
        add.l d7,d1
.step_floor:
        moveq #-1,d6
.pixel:
        cmp.w (a2),d0
        blo.s .hidden
        move.w d0,(a2)+
        tst.w d6
        bpl.s .next
        move.w d4,d6
        bra.s .next
.hidden:
        addq.l #2,a2
        tst.w d6
        bmi.s .next
        bsr.s .flush
.next:
        add.l d2,d0
        add.l d1,d3
        cmp.l d7,d3
        blo.s .no_carry
        sub.l d7,d3
        addq.l #1,d0
.no_carry:
        addq.w #1,d4
        cmp.w d5,d4
        blo.s .pixel
        tst.w d6
        bmi.s .end
        bsr.s .flush
.end:
        movem.l (sp)+,d0-d7/a0-a2
        rts
; Draw the run from D6 up to D4.
.flush:
        movem.l d0-d3,-(sp)
        move.w d6,d0
        move.w d4,d1
        move.w depth_y(pc),d2
        move.w depth_colour(pc),d3
        bsr editor_span
        movem.l (sp)+,d0-d3
        moveq #-1,d6
        rts
depth_y: dc.w 0
depth_colour: dc.w 0
