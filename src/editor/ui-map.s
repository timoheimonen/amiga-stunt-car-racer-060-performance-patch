; Draw the track map on the editor bar.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Track Editor bar: the track from above, 3 pixels a cell, right of the texts.
; It shows what the view can not: the shape of the whole track.
MAP_X equ 271
MAP_TOP equ 1
MAP_LAST equ 47
MAP_ROW_BYTES equ 12
MAP_PLANE_STEP equ UI_BAR_BYTES/4
MAP_BACK_PLANES equ 5
MAP_ROAD equ 4
MAP_MARK equ 8
MAP_END equ 10
MAP_START equ 11

; D3 x, D4 y, D6 colour, A3 the bar.
map_plot:
        cmpi.w #MAP_LAST,d3
        bhi.s .out
        cmpi.w #MAP_LAST,d4
        bhi.s .out
        movem.l d0-d2/a0,-(sp)
        move.w d4,d0
        addq.w #MAP_TOP,d0
        mulu.w #40,d0
        move.w d3,d1
        addi.w #MAP_X,d1
        move.w d1,d2
        lsr.w #3,d2
        add.w d2,d0
        not.b d1
        lea (a3,d0.w),a0
        move.b d6,d0
        moveq #3,d2
.plane: lsr.b #1,d0
        bcs.s .set
        bclr d1,(a0)
        bra.s .next
.set:   bset d1,(a0)
.next:  adda.w #MAP_PLANE_STEP,a0
        dbra d2,.plane
        movem.l (sp)+,d0-d2/a0
.out:   rts

; A2 row, A4 what a rejected ghost adds to it -> D0 x, D1 y on the map.
map_centre:
        movem.l d2,-(sp)
        moveq #0,d0
        move.w (a2),d0
        moveq #0,d1
        move.w 6(a2),d1
        add.l d1,d0
        move.l (a4),d1
        add.l d1,d1
        add.l d1,d0
        move.l d0,d1
        add.l d1,d1
        add.l d1,d0
        moveq #12,d2
        asr.l d2,d0
        moveq #0,d1
        move.w 4(a2),d1
        moveq #0,d2
        move.w 10(a2),d2
        add.l d2,d1
        move.l 8(a4),d2
        add.l d2,d2
        add.l d2,d1
        move.l d1,d2
        add.l d2,d2
        add.l d2,d1
        moveq #12,d2
        asr.l d2,d1
        neg.w d1
        addi.w #MAP_LAST,d1
        movem.l (sp)+,d2
        rts

; A0 row counts, A1 geometry, D2 first piece, D5 end piece, D6 colour. Two rows of
; a section are at most a pixel apart, so the rows are the line.
map_rows:
        cmp.w d5,d2
        bhs.s .done
        move.w d2,d0
        add.w d0,d0
        move.w (a0,d0.w),d7
        move.w d2,d0
        mulu.w #EDITOR_GEOMETRY_STRIDE,d0
        lea (a1,d0.l),a2
        subq.w #1,d7
.row:   bsr map_centre
        move.w d0,d3
        move.w d1,d4
        bsr map_plot
        lea MAP_ROW_BYTES(a2),a2
        dbra d7,.row
        addq.w #1,d2
        tst.w block_render_offset_on-module_start(a5)
        beq.s map_rows
        lea MAP_ROW_BYTES(a4),a4
        bra.s map_rows
.done:  rts

; 3 x 3 marker at D0, D1 in colour D6.
map_blob:
        move.w d1,d4
        subq.w #1,d4
        moveq #2,d2
.y:     move.w d0,d3
        subq.w #1,d3
        moveq #2,d7
.x:     bsr map_plot
        addq.w #1,d3
        dbra d7,.x
        addq.w #1,d4
        dbra d2,.y
        rts

; The square of the map goes straight to the planes: through map_plot it cost
; more than all the rest.
map_clear:
        lea 33+MAP_TOP*40(a3),a0
        moveq #0,d2
.plane: moveq #MAP_LAST,d1
        movea.l a0,a1
        moveq #MAP_BACK_PLANES,d0
        btst d2,d0
        bne.s .set
.clear: andi.b #$fe,(a1)
        clr.l 1(a1)
        clr.b 5(a1)
        andi.b #1,6(a1)
        lea 40(a1),a1
        dbra d1,.clear
        bra.s .next
.set:   moveq #-1,d0
.fill:  ori.b #1,(a1)
        move.l d0,1(a1)
        move.b d0,5(a1)
        ori.b #$fe,6(a1)
        lea 40(a1),a1
        dbra d1,.fill
.next:  adda.w #MAP_PLANE_STEP,a0
        addq.w #1,d2
        cmpi.w #4,d2
        blo.s .plane
        rts

; Road, the selection or the ghost, the open end and the start.
map_draw:
        movem.l d0-d7/a0-a4,-(sp)
        movea.l ui_bar_target(pc),a3
        bsr map_clear
        clr.w block_render_offset_on-module_start(a5)
        tst.w place_active-module_start(a5)
        bne .done
        lea block_zero_offset(pc),a4
        moveq #MAP_ROAD,d6
        lea model_row_counts(pc),a0
        lea model_geometry(pc),a1
        moveq #0,d2
        move.w editor_track+28(pc),d5
        bsr map_rows
        tst.w building_mode-module_start(a5)
        bne.s .ghost
        ; The selected section, or nothing on the Add slot.
        move.w building_selected(pc),d0
        cmp.w editor_track+28(pc),d0
        bhs .marks
        bsr block_group_start
        move.w d0,d2
        moveq #1,d4
        bsr block_browse_step
        move.w d0,d5
        bra.s .marked
.ghost: cmpi.l #3,editor_track+24-module_start(a5)
        blo.s .marks
        tst.w block_preview_visible-module_start(a5)
        beq.s .marks
        movea.l a5,a0
        adda.l #BLOCK_PREVIEW_CACHE,a0
        lea 2*EDITOR_MAX_PIECES(a0),a1
        move.w block_insert(pc),d2
        move.w d2,d5
        add.w block_count(pc),d5
        tst.w block_preview_valid-module_start(a5)
        bne.s .marked_ghost
        move.w d2,d0
        mulu.w #MAP_ROW_BYTES,d0
        lea block_offsets(pc),a4
        adda.w d0,a4
        move.w #1,block_render_offset_on-module_start(a5)
.marked_ghost:
        moveq #MAP_MARK,d6
        bsr map_rows
        clr.w block_render_offset_on-module_start(a5)
        lea block_zero_offset(pc),a4
        bra.s .marks
.marked:
        moveq #MAP_MARK,d6
        lea model_row_counts(pc),a0
        lea model_geometry(pc),a1
        bsr map_rows
.marks: tst.w editor_track+30-module_start(a5)
        bne.s .start
        bsr model_tail_row
        movea.l a0,a2
        bsr map_centre
        moveq #MAP_END,d6
        bsr map_blob
        ; A gap has two ends: its far side is marked as well.
        move.w editor_gap(pc),d0
        beq.s .start
        mulu.w #EDITOR_GEOMETRY_STRIDE,d0
        lea model_geometry(pc),a2
        adda.l d0,a2
        bsr map_centre
        moveq #MAP_END,d6
        bsr map_blob
.start: lea model_geometry(pc),a2
        bsr map_centre
        moveq #MAP_START,d6
        bsr map_blob
.done:  movem.l (sp)+,d0-d7/a0-a4
        rts

; With the model of the track in place: the map when something on it changed.
ui_map_update:
        tst.w model_valid-module_start(a5)
        beq.s .done
        move.w building_selected(pc),d0
        swap d0
        move.w building_mode(pc),d0
        cmp.l ui_map_seen(pc),d0
        beq.s .same
        move.l d0,ui_map_seen-module_start(a5)
        bra.s .draw
.same:  tst.w ui_map_dirty-module_start(a5)
        beq.s .done
.draw:  clr.w ui_map_dirty-module_start(a5)
        bra map_draw
.done:  rts

ui_map_seen: dc.l 0
ui_map_dirty: dc.w 0
block_render_offset_on: dc.w 0
