; Render editor track geometry with perspective and depth handling.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

editor_render_adapter:
        addq.l #1,render_count-module_start(a5)
        movea.l $6a58c,a0
        move.l a0,draw_surface-module_start(a5)
        ; A dialog covers the view, and storage_modal_text clears the surface.
        tst.w storage_modal-module_start(a5)
        bne .done
        move.w #SCREEN_PLANE_BYTES/4-1,d0
.clear:
        move.l #-1,(a0)
        clr.l SCREEN_PLANE_BYTES(a0)
        clr.l 2*SCREEN_PLANE_BYTES(a0)
        move.l #-1,3*SCREEN_PLANE_BYTES(a0)
        addq.l #4,a0
        dbra d0,.clear
        tst.w model_valid-module_start(a5)
        beq .done
        ; Per-pixel reciprocal-depth buffer lives in unused private Fast.
        tst.w free_wire-module_start(a5)
        bne.s .depth_ready
        lea DEPTH_BUFFER(a5),a0
        move.w #DEPTH_BUFFER_BYTES/4-1,d0 ; clear as longwords
.depth_clear:
        clr.l (a0)+
        dbra d0,.depth_clear
.depth_ready:
        tst.w overview_active-module_start(a5)
        bne.s .whole_map
        bsr free_camera_apply
        bra.s .view_ready
.whole_map:
        bsr overview_fit
.view_ready:
        cmpi.w #FREE_WIRE_EDGES,free_wire-module_start(a5)
        beq.s .no_grid
        bsr editor_map_boundary
.no_grid:
        tst.w place_active-module_start(a5)
        bne place_draw
        tst.w free_wire-module_start(a5)
        bne free_wire_draw
        clr.w render_layer-module_start(a5)
.layer:
        clr.w render_piece-module_start(a5)
.piece:
        tst.b ui_yield_flag(pc)
        beq.s .piece_go
        bsr ui_yield
.piece_go:
        move.w render_piece(pc),d0
        cmp.w editor_track+SCTR_COUNT(pc),d0
        bhs.s .preview
        cmpi.w #2,building_mode-module_start(a5)
        bne.s .confirmed
        tst.w building_candidate_count-module_start(a5)
        beq.s .confirmed
        cmp.w building_selected(pc),d0
        bne.s .confirmed
        lea building_geometry(pc),a0
        move.w building_rows(pc),d1
        bra.s .rows
.confirmed:
        move.w d0,d1
        add.w d1,d1
        lea model_row_counts(pc),a0
        move.w (a0,d1.w),d1
        mulu.w #EDITOR_GEOMETRY_STRIDE,d0
        lea model_geometry(pc),a0
        adda.w d0,a0
        bra.s .rows
.preview:
        bne .next_layer
        cmpi.w #1,building_mode-module_start(a5)
        bne .next_layer
        tst.w building_candidate_count-module_start(a5)
        beq .next_layer
        lea building_geometry(pc),a0
        move.w building_rows(pc),d1
.rows:
        bsr piece_visible
        bne.s .piece_on
        addq.w #1,render_piece-module_start(a5)
        bra .piece
.piece_on:
        move.l a0,render_rows-module_start(a5)
        subq.w #1,d1
        move.w d1,render_intervals-module_start(a5)
        clr.w segment_index-module_start(a5)
.segment:
        movea.l render_rows(pc),a0
        move.w segment_index(pc),d0
        mulu.w #12,d0
        adda.w d0,a0
        move.l a0,render_cross-module_start(a5)
        tst.w render_layer-module_start(a5)
        bne.s .top
        clr.w polygon_overlay-module_start(a5)
        ; Vertical perimeter walls (left/right; end caps are added below).
        moveq #0,d0
        moveq #0,d1
        move.w #128,polygon_drop-module_start(a5)
        move.w #7,polygon_color-module_start(a5)
        bsr render_band
        moveq #8,d0
        moveq #8,d1
        bsr render_band
        tst.w segment_index-module_start(a5)
        bne.s .end_cap
        movea.l render_cross(pc),a0
        bsr render_cap
.end_cap:
        move.w segment_index(pc),d0
        addq.w #1,d0
        cmp.w render_intervals(pc),d0
        bne.s .walls_done
        movea.l render_cross(pc),a0
        adda.w #12,a0
        bsr render_cap
.walls_done:
        clr.w polygon_drop-module_start(a5)
        bra .next_segment
.top:
        clr.w polygon_overlay-module_start(a5)
        moveq #0,d0
        moveq #8,d1
        move.w #1,polygon_color-module_start(a5)
        btst #0,segment_index+1-module_start(a5)
        beq.s .edge
        move.w #13,polygon_color-module_start(a5)
.edge:
        bsr render_band
        move.w #1,polygon_overlay-module_start(a5)
        moveq #1,d0
        moveq #7,d1
        move.w #3,polygon_color-module_start(a5)
        move.w render_piece(pc),d2
        cmp.w building_selected(pc),d2
        beq.s .selected
        bsr block_highlight
        tst.w d2
        beq.s .surface
.selected:
        move.w #2,polygon_color-module_start(a5)
.surface:
        tst.w block_render_active-module_start(a5)
        beq.s .surface_draw
        tst.w block_preview_valid-module_start(a5)
        bne.s .surface_draw
        move.w render_piece(pc),d2
        sub.w block_insert(pc),d2
        blo.s .surface_draw
        cmp.w block_count(pc),d2
        bhs.s .surface_draw
        move.w #13,polygon_color-module_start(a5)
.surface_draw:
        bsr render_band
        ; Checker only on the permanent finish piece, interval four.
        cmpi.w #4,segment_index-module_start(a5)
        bne.s .next_segment
        move.w render_piece(pc),d0
        cmp.w editor_track+SCTR_COUNT(pc),d0
        bhs.s .next_segment
        lsl.w #PIECE_SHIFT,d0
        lea editor_track+SCTR_PIECES(pc),a0
        move.l (a0,d0.w),d0
        cmp.l editor_track+SCTR_FINISH(pc),d0
        bne.s .next_segment
        clr.w render_checker-module_start(a5)
.checker:
        move.w render_checker(pc),d0
        move.w d0,d1
        andi.w #1,d1
        move.w d1,polygon_color-module_start(a5)
        move.w d0,d1
        addq.w #1,d1
        bsr render_band
        addq.w #1,render_checker-module_start(a5)
        cmpi.w #8,render_checker-module_start(a5)
        blo.s .checker
.next_segment:
        addq.w #1,segment_index-module_start(a5)
        move.w segment_index(pc),d0
        cmp.w render_intervals(pc),d0
        blo .segment
        addq.w #1,render_piece-module_start(a5)
        bra .piece
.next_layer:
        addq.w #1,render_layer-module_start(a5)
        cmpi.w #2,render_layer-module_start(a5)
        blo .layer
.done:
        rts

; Band across a cross-row quad: fractional edges D0/D1 in eighths.
; Four world X/Z longword vertices, preserving exact template endpoints.
render_band:
        bsr block_render_offset
        move.w d0,band_left-module_start(a5)
        move.w d1,band_right-module_start(a5)
        lea polygon_world(pc),a1
        movea.l render_cross(pc),a0
        bsr .point
        move.w band_right(pc),d0
        bsr .point
        adda.w #12,a0
        move.w band_right(pc),d0
        bsr .point
        move.w band_left(pc),d0
        bsr .point
        bra polygon_clip
.point:
        moveq #0,d2
        move.w (a0),d2
        moveq #0,d3
        move.w 6(a0),d3
        sub.l d2,d3
        muls.w d0,d3
        asr.l #3,d3
        add.l d2,d3
        add.l (a3),d3
        move.l d3,(a1)+
        moveq #0,d2
        move.w 4(a0),d2
        moveq #0,d3
        move.w 10(a0),d3
        sub.l d2,d3
        muls.w d0,d3
        asr.l #3,d3
        add.l d2,d3
        add.l 8(a3),d3
        move.l d3,(a1)+
        moveq #0,d2
        move.w 2(a0),d2
        moveq #0,d3
        move.w 8(a0),d3
        sub.l d2,d3
        muls.w d0,d3
        asr.l #3,d3
        add.l d2,d3
        add.l 4(a3),d3
        neg.l d3
        add.l camera_y(pc),d3
        move.l d3,(a1)+
        rts

; Closed end face at a piece cross section, top/bottom on both road edges.
render_cap:
        bsr block_render_offset
        lea polygon_world(pc),a1
        moveq #0,d0
        move.w (a0),d0
        moveq #0,d1
        move.w 4(a0),d1
        moveq #0,d2
        move.w 2(a0),d2
        add.l (a3),d0
        add.l 8(a3),d1
        add.l 4(a3),d2
        neg.l d2
        add.l camera_y(pc),d2
        move.l d0,(a1)+
        move.l d1,(a1)+
        move.l d2,(a1)+
        move.l d0,(a1)+
        move.l d1,(a1)+
        move.l d2,(a1)+
        moveq #0,d0
        move.w 6(a0),d0
        moveq #0,d1
        move.w 10(a0),d1
        moveq #0,d2
        move.w 8(a0),d2
        add.l (a3),d0
        add.l 8(a3),d1
        add.l 4(a3),d2
        neg.l d2
        add.l camera_y(pc),d2
        move.l d0,(a1)+
        move.l d1,(a1)+
        move.l d2,(a1)+
        move.l d0,(a1)+
        move.l d1,(a1)+
        move.l d2,(a1)+
        bra polygon_clip

; Near-plane Sutherland-Hodgman clipping at projected denominator 512.
; Side walls have repeated X/Z; represent their bottom by screen Y offset
; after projection (height 128). Clip interpolates their per-vertex drop too.
polygon_clip:
        tst.w overview_active-module_start(a5)
        bne overview_polygon
        lea polygon_world(pc),a0
        lea polygon_input(pc),a1
        moveq #3,d7
.copy:
        move.l (a0)+,d0
        sub.l camera_x(pc),d0
        move.l (a0)+,d1
        sub.l camera_z(pc),d1
        move.w camera_right_x(pc),d2
        ext.l d2
        move.w camera_right_z(pc),d3
        ext.l d3
        move.l d0,d4
        move.l d1,d5
        muls.l d2,d4
        muls.l d3,d5
        add.l d5,d4
        asr.l #7,d4
        asr.l #7,d4
        move.l d4,(a1)+
        muls.l d3,d0
        neg.l d0
        muls.l d2,d1
        add.l d1,d0
        asr.l #7,d0
        asr.l #7,d0
        move.l d0,(a1)+
        move.l (a0)+,(a1)+
        dbra d7,.copy
        ; band with equal fractions forms a wall: vertices 1 and 2 at bottom.
        moveq #0,d0
        move.w polygon_drop(pc),d0
        add.l d0,polygon_input+20-module_start(a5)
        add.l d0,polygon_input+32-module_start(a5)
        bra view_polygon
polygon_done:
        rts

; Signed floor division gives the SAME intersection for reversed edges.
; Truncation toward zero opens one-pixel cracks on shared polygon seams.
; D0 numerator/result, D1 divisor; D2/D3 scratch; divisor must be nonzero.
polygon_div_floor:
        move.l d0,d2
        divs.l d1,d0
        move.l d0,d3
        muls.l d1,d3
        cmp.l d2,d3
        beq.s .done
        eor.l d1,d2
        bpl.s .done
        subq.l #1,d0
.done:
        rts

; Convex projected polygon scan conversion, integer Y intersections.
; Full signed long arithmetic until clipped [0,320) spans; viewport excludes UI.
polygon_raster:
        tst.w polygon_overlay-module_start(a5)
        bne.s .parent_ready
        ; Overlays run on the top layer only. Clear the rows of the last parent.
        tst.w render_layer-module_start(a5)
        beq.s .parent_ready
        lea polygon_parent_rows(pc),a0
        move.w parent_top(pc),d0
        move.w parent_end(pc),d1
        sub.w d0,d1
        ble.s .parent_ready
        lsl.w #4,d0
        adda.w d0,a0
        subq.w #1,d1
.parent_clear:
        clr.l (a0)+
        clr.l (a0)+
        clr.l (a0)+
        clr.l (a0)+
        dbra d1,.parent_clear
.parent_ready:
        lea polygon_screen(pc),a0
        move.w polygon_count(pc),d7
        subq.w #1,d7
        move.l #VIEW_BOTTOM,d4
        moveq #VIEW_TOP,d5
.bounds:
        move.l 4(a0),d0
        cmp.l d4,d0
        bge.s .max
        move.l d0,d4
.max:
        cmp.l d5,d0
        ble.s .bound_next
        move.l d0,d5
.bound_next:
        adda.w #12,a0
        dbra d7,.bounds
        cmpi.l #VIEW_TOP,d4
        bge.s .bottom
        moveq #VIEW_TOP,d4
.bottom:
        cmpi.l #VIEW_BOTTOM,d5
        ble.s .start
        move.l #VIEW_BOTTOM,d5
.start:
        move.w d5,polygon_bottom-module_start(a5)
        move.w d4,polygon_y-module_start(a5)
        tst.w polygon_overlay-module_start(a5)
        bne.s .range_done
        tst.w render_layer-module_start(a5)
        beq.s .range_done
        move.w d4,d0
        subi.w #VIEW_TOP,d0
        move.w d0,parent_top-module_start(a5)
        move.w d5,d0
        subi.w #VIEW_TOP,d0
        move.w d0,parent_end-module_start(a5)
.range_done:
.row:
        move.w polygon_y(pc),d4
        cmp.w polygon_bottom(pc),d4
        bge polygon_done
        ext.l d4
        move.l #2147483647,d5
        move.l #-2147483647,d6
        lea polygon_screen(pc),a1
        moveq #0,d0
        move.w polygon_count(pc),d0
        subq.w #1,d0
        move.w d0,d7
        mulu.w #12,d0
        lea (a1,d0.w),a0
.edge:
        move.l 4(a0),d0
        move.l 4(a1),d1
        cmp.l d1,d0
        beq.s .next
        cmp.l d0,d4
        blt.s .a_above
        cmp.l d1,d4
        bge.s .next
        bra.s .intersection
.a_above:
        cmp.l d1,d4
        blt.s .next
.intersection:
        sub.l d0,d1
        move.l d4,d2
        sub.l d0,d2
        move.l (a1),d0
        sub.l (a0),d0
        muls.l d2,d0
        bsr polygon_div_floor
        add.l (a0),d0
        cmp.l d5,d0
        bge.s .right
        move.l d0,d5
        bsr polygon_edge_depth
        move.l d0,span_qleft-module_start(a5)
        move.l d5,d0
.right:
        cmp.l d6,d0
        ble.s .next
        move.l d0,d6
        bsr polygon_edge_depth
        move.l d0,span_qright-module_start(a5)
.next:
        movea.l a1,a0
        adda.w #12,a1
        dbra d7,.edge
        move.l d5,span_left-module_start(a5)
        move.l d6,span_right-module_start(a5)
        ; All paint bands use the parent road face's depth plane. Projected
        ; integer band vertices must not introduce new rounding planes.
        move.w d4,d0
        subi.w #VIEW_TOP,d0
        lsl.w #4,d0
        lea polygon_parent_rows(pc),a0
        adda.w d0,a0
        tst.w polygon_overlay-module_start(a5)
        bne.s .parent_read
        tst.w render_layer-module_start(a5)
        beq.s .parent_done
        move.l span_left(pc),(a0)+
        move.l span_right(pc),(a0)+
        move.l span_qleft(pc),(a0)+
        move.l span_qright(pc),(a0)
        bra.s .parent_done
.parent_read:
        move.l (a0)+,span_left-module_start(a5)
        move.l (a0)+,span_right-module_start(a5)
        move.l (a0)+,span_qleft-module_start(a5)
        move.l (a0),span_qright-module_start(a5)
        move.l span_right(pc),d0
        cmp.l span_left(pc),d0
        ble .advance
.parent_done:
        tst.l d5
        bpl.s .clip_right
        clr.l d5
.clip_right:
        cmpi.l #SCREEN_WIDTH,d6
        ble.s .span
        move.l #SCREEN_WIDTH,d6
.span:
        cmp.l d5,d6
        ble.s .advance
        move.w d5,d0
        move.w d6,d1
        move.w d4,d2
        move.w polygon_color(pc),d3
        bsr depth_span
.advance:
        addq.w #1,polygon_y-module_start(a5)
        bra .row

editor_span:
        movem.l d0-d7/a0-a2,-(sp)
        tst.w d0
        bpl.s .left
        clr.w d0
.left:
        cmpi.w #SCREEN_WIDTH,d1
        ble.s .right
        move.w #SCREEN_WIDTH,d1
.right:
        cmp.w d0,d1
        ble .done
        movea.l draw_surface(pc),a0
        mulu.w #SCREEN_ROW_BYTES,d2
        adda.l d2,a0
        move.w d0,d4
        lsr.w #3,d4
        adda.w d4,a0
        andi.w #7,d0
        subq.w #1,d1
        move.w d1,d5
        lsr.w #3,d5
        sub.w d4,d5
        andi.w #7,d1
        move.w #255,d4
        lsr.w d0,d4
        moveq #7,d7
        sub.w d1,d7
        move.w #255,d6
        lsl.w d7,d6          ; inclusive right mask
        moveq #3,d2
.plane:
        movea.l a0,a1
        move.b d4,d7
        tst.w d5
        bne.s .first_mask
        and.b d6,d7
.first_mask:
        lsr.w #1,d3
        bcs.s .set_first
        not.b d7
        and.b d7,(a1)+
        moveq #0,d1
        bra.s .middle
.set_first:
        or.b d7,(a1)+
        moveq #-1,d1
.middle:
        move.w d5,d7
        beq.s .next_plane
        subq.w #1,d7          ; bytes strictly between the two edge bytes
        beq.s .last
        ; Align before word/long stores (also valid for 68000).
        move.l a1,d0
        btst #0,d0
        beq.s .words
        move.b d1,(a1)+
        subq.w #1,d7
.words:
        cmpi.w #4,d7
        blt.s .tail
        move.l d1,(a1)+
        subq.w #4,d7
        bra.s .words
.tail:
        cmpi.w #2,d7
        blt.s .byte_tail
        move.w d1,(a1)+
        subq.w #2,d7
.byte_tail:
        tst.w d7
        beq.s .last
        move.b d1,(a1)+
.last:
        move.b d6,d7
        tst.b d1
        bne.s .set_last
        not.b d7
        and.b d7,(a1)
        bra.s .next_plane
.set_last:
        or.b d7,(a1)
.next_plane:
        adda.w #SCREEN_PLANE_BYTES,a0
        dbra d2,.plane
.done:
        movem.l (sp)+,d0-d7/a0-a2
        rts


camera_x: dc.l 5120
camera_z: dc.l 0
camera_right_x: dc.w 16384
camera_right_z: dc.w 0
segment_index: dc.w 0
draw_surface: dc.l 0
render_count: dc.l 0
render_layer: dc.w 0
render_piece: dc.w 0
render_intervals: dc.w 0
render_rows: dc.l 0
render_cross: dc.l 0
render_checker: dc.w 0
band_left: dc.w 0
band_right: dc.w 0
polygon_drop: dc.w 0
polygon_color: dc.w 0
polygon_count: dc.w 0
polygon_y: dc.w 0
polygon_bottom: dc.w 0
polygon_world: dcb.l 12,0
polygon_input: dcb.l 12,0
polygon_clipped: dcb.l 18,0
polygon_screen: dcb.l 18,0

camera_y: dc.l 0
span_qleft: dc.l 0
span_qright: dc.l 0
span_left: dc.l 0
span_right: dc.l 0

; Reciprocal depth is affine on every projected planar road quad.
polygon_edge_depth:
        move.l 4(a1),d1
        sub.l 4(a0),d1
        move.l d4,d2
        sub.l 4(a0),d2
        move.l 8(a1),d0
        sub.l 8(a0),d0
        muls.l d2,d0
        bsr polygon_div_floor
        add.l 8(a0),d0
        rts

        include "src/editor/depth-span.s"
parent_top: dc.w 0
parent_end: dc.w VIEW_BOTTOM-VIEW_TOP

polygon_overlay: dc.w 0
; Private Fast scratch, outside the module and preview cache.
polygon_parent_rows equ POLYGON_PARENT_ROWS

        include "src/editor/overview.s"

; The view looks down by its pitch. Near plane at depth 512.
view_polygon:
        ; Convert to camera space once, including the downward pitch.
        lea polygon_input(pc),a0
        moveq #3,d7
.transform:
        move.l 4(a0),d2
        move.l 8(a0),d1
        bsr view_project
        move.l d2,4(a0)
        move.l d1,8(a0)
        adda.w #12,a0
        dbra d7,.transform
        lea polygon_input+36(pc),a0
        lea polygon_input(pc),a1
        lea polygon_clipped(pc),a2
        clr.w polygon_count-module_start(a5)
        moveq #3,d7
.edge:
        move.l 4(a0),d5
        subi.l #512,d5
        move.l 4(a1),d6
        subi.l #512,d6
        move.l d5,d0
        eor.l d6,d0
        bpl.s .same
        sub.l d6,d5
        move.l d5,d6
        move.l 4(a0),d5
        subi.l #512,d5
        move.l (a1),d0
        sub.l (a0),d0
        muls.l d5,d0
        move.l d6,d1
        bsr polygon_div_floor
        add.l (a0),d0
        move.l d0,(a2)+
        move.l #512,(a2)+
        move.l 8(a1),d0
        sub.l 8(a0),d0
        muls.l d5,d0
        move.l d6,d1
        bsr polygon_div_floor
        add.l 8(a0),d0
        move.l d0,(a2)+
        addq.w #1,polygon_count-module_start(a5)
.same:
        cmpi.l #512,4(a1)
        blt.s .next
        move.l (a1),(a2)+
        move.l 4(a1),(a2)+
        move.l 8(a1),(a2)+
        addq.w #1,polygon_count-module_start(a5)
.next:
        movea.l a1,a0
        adda.w #12,a1
        dbra d7,.edge
        cmpi.w #3,polygon_count-module_start(a5)
        blo polygon_done
        lea polygon_clipped(pc),a0
        lea polygon_screen(pc),a1
        move.w polygon_count(pc),d7
        subq.w #1,d7
.point:
        move.l 4(a0),d2
        move.l 8(a0),d1
        move.l (a0),d0
        muls.l #FREE_FOCAL,d0
        divs.l d2,d0
        addi.l #VIEW_CX,d0
        move.l d0,(a1)+
        muls.l #FREE_FOCAL,d1
        divs.l d2,d1
        addi.l #VIEW_CY,d1
        move.l d1,(a1)+
        move.l #$1000000,d0
        divu.l d2,d0
        move.l d0,(a1)+
        adda.w #12,a0
        dbra d7,.point
        bra polygon_raster

; D2 forward, D1 height under the eye -> depth D2, vertical D1 (Q14 pitch).
; D0/D3/D4 scratch. D5 and loop registers survive.
view_project:
        move.l d2,d3
        move.l d1,d4
        muls.l view_pitch_cos(pc),d3
        muls.l view_pitch_sin(pc),d4
        add.l d4,d3
        muls.l view_pitch_cos(pc),d1
        muls.l view_pitch_sin(pc),d2
        sub.l d2,d1
        asr.l #7,d1
        asr.l #7,d1
        move.l d3,d2
        asr.l #7,d2
        asr.l #7,d2
        rts

        include "src/editor/map-boundary.s"
        include "src/editor/piece-visible.s"
