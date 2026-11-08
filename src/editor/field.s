; Track the distance from the open track end to the start line or across a gap.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Track Editor: how many sections the open end is from the start line, or from
; the far side of a gap. The field has a level for every heading and cell, $ff
; where no route is. It hangs on that goal piece only, so a new section or a Del
; at the end leaves it as it is.
FIELD_OFFSET equ $1C960
FIELD_BYTES equ 2048
FIELD_NO_ROUTE equ 15

; With the model of the track built.
field_refresh:
        ; The goal piece's kind, rotation and cell fix its first row.
        move.w editor_gap(pc),d0
        lsl.w #3,d0
        lea editor_track+68(pc),a0
        move.l (a0,d0.w),d0
        cmp.l field_key(pc),d0
        beq field_done
        move.l d0,field_key-module_start(a5)
        movem.l d0-d7/a0-a2,-(sp)
        movea.l a5,a0
        adda.l #FIELD_OFFSET,a0
        movea.l a0,a1
        moveq #-1,d0
        move.w #FIELD_BYTES/4-1,d1
.fill:  move.l d0,(a1)+
        dbra d1,.fill
        lea model_geometry(pc),a1
        move.w editor_gap(pc),d0
        mulu.w #EDITOR_GEOMETRY_STRIDE,d0
        adda.l d0,a1
        ; A start line on the far edge of the map has no cell.
        move.w (a1),d0
        or.w 4(a1),d0
        bmi field_built
        bsr field_index
        clr.b (a0,d1.w)
        moveq #0,d7
.level: moveq #0,d6
        move.w #FIELD_BYTES-1,d3
.scan:  cmp.b (a0,d3.w),d7
        bne.s .scan_next
        move.w d3,d2
        lsr.w #8,d2
        moveq #FIELD_AXIS_EDGES-1,d5
        btst #0,d2
        beq.s .axis
        moveq #FIELD_DIAGONAL_EDGES-1,d5
.axis:  add.w d2,d2
        lea field_first(pc),a1
        move.w (a1,d2.w),d2
        lea field_edges(pc),a1
        adda.w d2,a1
.edge:  moveq #15,d0
        and.b d3,d0
        sub.b (a1),d0
        move.b 3(a1),d2
        move.b d2,d1
        lsr.b #4,d1
        cmp.b d1,d0
        blo.s .skip
        andi.b #15,d2
        cmp.b d2,d0
        bhi.s .skip
        move.b d3,d1
        lsr.b #4,d1
        sub.b 1(a1),d1
        move.b 4(a1),d2
        move.b d2,d4
        lsr.b #4,d4
        cmp.b d4,d1
        blo.s .skip
        andi.b #15,d2
        cmp.b d2,d1
        bhi.s .skip
        move.b 2(a1),d2
        lsl.w #8,d2
        lsl.b #4,d1
        or.b d0,d1
        move.b d1,d2
        tst.b (a0,d2.w)
        bpl.s .skip
        moveq #1,d6
        move.b d7,d1
        addq.b #1,d1
        move.b d1,(a0,d2.w)
.skip:  addq.l #5,a1
        dbra d5,.edge
.scan_next:
        dbra d3,.scan
        addq.b #1,d7
        tst.w d6
        bne .level
field_built:
        movem.l (sp)+,d0-d7/a0-a2
field_done:
        rts

; A1 row -> D1 index of its heading and cell.
field_index:
        move.w 6(a1),d1
        sub.w (a1),d1
        move.w 10(a1),d2
        sub.w 4(a1),d2
        bsr view_axis_index
        lsl.w #8,d1
        move.w 4(a1),d0
        lsr.w #7,d0
        andi.w #$f0,d0
        or.w d0,d1
        move.w (a1),d0
        moveq #11,d2
        lsr.w d2,d0
        or.w d0,d1
        rts

; With a candidate in the model: D0 sections from its open end to the goal,
; FIELD_NO_ROUTE when no route is.
field_end_level:
        bsr model_tail_row
        movea.l a0,a1
        move.w (a1),d0
        or.w 4(a1),d0
        bmi.s .none
        bsr field_index
        movea.l a5,a0
        adda.l #FIELD_OFFSET,a0
        moveq #0,d0
        move.b (a0,d1.w),d0
        cmpi.b #FIELD_NO_ROUTE,d0
        blo.s .ok
.none:  moveq #FIELD_NO_ROUTE,d0
.ok:    rts

; After block_make, D0 kept: what the bar says of the candidate, NNNN C RRR. N and
; C mean something only when a section is added to an open track. C is set when
; the section closes the track or fills the gap.
field_info:
        movem.l d0-d3/a0-a1,-(sp)
        move.w block_fail(pc),d3
        andi.w #7,d3
        tst.w d0
        beq.s .store
        cmpi.w #1,block_mode-module_start(a5)
        bne.s .store
        tst.w block_original_track+30-module_start(a5)
        bne.s .store
        tst.w editor_track+30-module_start(a5)
        bne.s .closes
        tst.w block_original_track+EDITOR_TRACK_BYTES-module_start(a5)
        beq.s .open
        tst.w editor_gap-module_start(a5)
        bne.s .open
.closes:
        bset #3,d3
        bra.s .store
.open:  bsr field_end_level
        lsl.w #4,d0
        or.w d0,d3
.store: move.w d3,field_value-module_start(a5)
        movem.l (sp)+,d0-d3/a0-a1
        rts

field_key: dc.l 0
field_value: dc.w 0
block_info: dcb.b BLOCK_VARIANT_COUNT/4+1,0
        even
