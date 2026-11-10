; Draw the editor ground grid and building-area boundary.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Ground grid and outline of the actual X/Z domain, 0..MAP_SIZE, Y=0.
; Paint before the road, without depth writes: road surfaces cover the guide.
; MAP_CELL subdivisions bound near-plane intersection products on 68060.
; The grid: MAP_CELLS-1 inner lines each way, of a segment per cell.
MAP_BORDER_SEGMENTS equ 4*MAP_CELLS
MAP_SEGMENTS equ 2*(MAP_CELLS-1)*MAP_CELLS+MAP_BORDER_SEGMENTS
editor_map_boundary:
        move.w #MAP_SEGMENTS-1,d7
        cmpi.w #FREE_WIRE_OUTLINE,free_wire-module_start(a5)
        bne.s .segment
        moveq #MAP_BORDER_SEGMENTS-1,d7
.segment:
        tst.b ui_yield_flag(pc)
        beq.s .segment_go
        bsr ui_yield
.segment_go:
        bsr map_boundary_segment
        movem.l d7/a4,-(sp)
        lea map_boundary_view(pc),a1
        moveq #0,d0
        moveq #0,d1
        move.w (a4),d0
        move.w 2(a4),d1
        bsr map_boundary_project
        moveq #0,d0
        moveq #0,d1
        move.w 4(a4),d0
        move.w 6(a4),d1
        bsr map_boundary_project
        tst.w overview_active-module_start(a5)
        bne.s .screen
        bsr map_boundary_near
        tst.w d0
        beq.s .next
.screen:
        lea map_boundary_view(pc),a0
        lea map_boundary_screen(pc),a1
        moveq #1,d7
.point:
        move.l (a0),d0
        move.l 8(a0),d1
        tst.w overview_active-module_start(a5)
        bne.s .store
        move.l 4(a0),d2
        muls.l #FREE_FOCAL,d0
        divs.l d2,d0
        addi.l #VIEW_CX,d0
        muls.l #FREE_FOCAL,d1
        divs.l d2,d1
        addi.l #VIEW_CY,d1
.store:
        move.l d0,(a1)+
        move.l d1,(a1)+
        adda.w #12,a0
        dbra d7,.point
        bsr map_boundary_clip
.next:
        movem.l (sp)+,d7/a4
        dbra d7,.segment
        rts

; D7 descending MAP_SEGMENTS-1..0. Grid first (color 3), then gold perimeter (15).
; A4 points at two adjacent world X/Z word pairs. No camera fit dependency.
map_boundary_segment:
        cmpi.w #MAP_BORDER_SEGMENTS,d7
        blo.s .border
        move.w #3,map_boundary_color-module_start(a5)
        move.w #MAP_SEGMENTS-1,d0
        sub.w d7,d0
        move.w d0,d1
        andi.w #MAP_CELLS-1,d1
        lsl.w #8,d1
        lsl.w #MAP_CELL_SHIFT-8,d1
        lsr.w #MAP_CELL_BITS,d0
        move.w d0,d2
        cmpi.w #MAP_CELLS-1,d0
        blo.s .coordinate
        subi.w #MAP_CELLS-1,d0
.coordinate:
        addq.w #1,d0
        lsl.w #8,d0
        lsl.w #MAP_CELL_SHIFT-8,d0
        lea map_boundary_world(pc),a4
        cmpi.w #MAP_CELLS-1,d2
        bhs.s .horizontal
        move.w d0,(a4)
        move.w d1,2(a4)
        move.w d0,4(a4)
        addi.w #MAP_CELL,d1
        move.w d1,6(a4)
        rts
.horizontal:
        move.w d1,(a4)
        move.w d0,2(a4)
        addi.w #MAP_CELL,d1
        move.w d1,4(a4)
        move.w d0,6(a4)
        rts
.border:
        move.w #15,map_boundary_color-module_start(a5)
        moveq #MAP_BORDER_SEGMENTS-1,d0
        sub.w d7,d0
        lsl.w #2,d0
        lea map_boundary_points(pc),a4
        adda.w d0,a4
        rts

; World X/Z in D0/D1 -> side/depth/vertical at A1 (or screen X/0/Y for V).
map_boundary_project:
        tst.w overview_active-module_start(a5)
        beq.s .perspective
        sub.l overview_min_x(pc),d0
        muls.l overview_scale(pc),d0
        asr.l #8,d0
        asr.l #8,d0
        add.l overview_left(pc),d0
        move.l d0,(a1)+
        clr.l (a1)+
        neg.l d1
        sub.l overview_min_v(pc),d1
        muls.l overview_scale(pc),d1
        asr.l #8,d1
        asr.l #8,d1
        add.l overview_top(pc),d1
        move.l d1,(a1)+
        rts
.perspective:
        sub.l camera_x(pc),d0
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
        move.l camera_y(pc),d1
        sub.l wire_y(pc),d1
        ; Split Q14 products keep high cameras over Y=0 inside 32-bit math.
        ; Ground can be much farther below the eye than any road.
        move.l d0,d5
        move.l d1,d6
        move.l view_pitch_cos(pc),d1
        bsr map_boundary_mul_q14
        move.l d0,d4
        move.l d6,d0
        move.l view_pitch_sin(pc),d1
        bsr map_boundary_mul_q14
        add.l d4,d0
        move.l d0,(a1)+
        move.l d6,d0
        move.l view_pitch_cos(pc),d1
        bsr map_boundary_mul_q14
        move.l d0,d4
        move.l d5,d0
        move.l view_pitch_sin(pc),d1
        bsr map_boundary_mul_q14
        sub.l d0,d4
        move.l d4,(a1)+
        rts

; Exact floor(D0*D1/16384), without overflowing the unsplit product.
; D1 Q14 coefficient, D2/D3 scratch. Negative inputs use arithmetic shift.
map_boundary_mul_q14:
        move.l d0,d2
        andi.l #16383,d2
        asr.l #7,d0
        asr.l #7,d0
        muls.l d1,d0
        muls.l d1,d2
        asr.l #7,d2
        asr.l #7,d2
        add.l d2,d0
        rts

; Clip one subdivided ground segment to depth>=512. D0=visible.
map_boundary_near:
        lea map_boundary_view(pc),a0
        lea 12(a0),a1
        move.l 4(a0),d0
        move.l 4(a1),d1
        cmpi.l #512,d0
        blt.s .a_out
        cmpi.l #512,d1
        bge.s .visible
        exg a0,a1
        bra.s .cross
.a_out:
        cmpi.l #512,d1
        blt.s .hidden
.cross:
        move.l #512,d5
        sub.l 4(a0),d5
        move.l 4(a1),d6
        sub.l 4(a0),d6
        move.l (a1),d0
        sub.l (a0),d0
        muls.l d5,d0
        divs.l d6,d0
        add.l d0,(a0)
        move.l 8(a1),d0
        sub.l 8(a0),d0
        muls.l d5,d0
        divs.l d6,d0
        add.l d0,8(a0)
        move.l #512,4(a0)
.visible:
        moveq #1,d0
        rts
.hidden:
        moveq #0,d0
        rts

; Cohen-Sutherland clipping to the road viewport, never the text rows.
map_boundary_clip:
        lea map_boundary_screen(pc),a0
        lea 8(a0),a1
        moveq #7,d7
.retry:
        move.l (a0),d0
        move.l 4(a0),d1
        bsr map_boundary_outcode
        move.l d2,d4
        move.l (a1),d0
        move.l 4(a1),d1
        bsr map_boundary_outcode
        move.l d2,d5
        or.l d4,d2
        beq map_boundary_draw
        and.l d4,d5
        bne.s .done
        tst.l d4
        bne.s .outside
        exg a0,a1
        bsr map_boundary_outcode
        move.l d2,d4
.outside:
        btst #2,d4
        bne.s .top
        btst #3,d4
        bne.s .bottom
        moveq #0,d3
        btst #0,d4
        bne.s .vertical
        move.l #SCREEN_WIDTH-1,d3
.vertical:
        move.l d3,d0
        sub.l (a0),d0
        move.l 4(a1),d1
        sub.l 4(a0),d1
        muls.l d1,d0
        move.l (a1),d1
        sub.l (a0),d1
        divs.l d1,d0
        add.l d0,4(a0)
        move.l d3,(a0)
        bra.s .next
.top:   moveq #VIEW_TOP,d3
        bra.s .horizontal
.bottom:
        move.l #VIEW_BOTTOM-1,d3
.horizontal:
        move.l d3,d0
        sub.l 4(a0),d0
        move.l (a1),d1
        sub.l (a0),d1
        muls.l d1,d0
        move.l 4(a1),d1
        sub.l 4(a0),d1
        divs.l d1,d0
        add.l d0,(a0)
        move.l d3,4(a0)
.next:  dbra d7,.retry
.done:  rts
map_boundary_outcode:
        moveq #0,d2
        tst.l d0
        bge.s .right
        bset #0,d2
.right: cmpi.l #SCREEN_WIDTH-1,d0
        ble.s .top
        bset #1,d2
.top:   cmpi.l #VIEW_TOP,d1
        bge.s .bottom
        bset #2,d2
.bottom:
        cmpi.l #VIEW_BOTTOM-1,d1
        ble.s .done
        bset #3,d2
.done:  rts

; Bounded integer Bresenham, one pixel wide. Roads paint over all guides.
map_boundary_draw:
        lea map_boundary_screen(pc),a0
        move.l (a0),d0
        move.l 4(a0),d1
        moveq #1,d2
        move.l 8(a0),d4
        sub.l d0,d4
        bge.s .dx
        neg.l d4
        moveq #-1,d2
.dx:
        moveq #1,d3
        move.l 12(a0),d5
        sub.l d1,d5
        bge.s .dy
        neg.l d5
        moveq #-1,d3
.dy:
        neg.l d5
        move.l d4,d6
        add.l d5,d6
.pixel:
        bsr map_boundary_pixel
        cmp.l 8(a0),d0
        bne.s .step
        cmp.l 12(a0),d1
        beq.s .done
.step:
        move.l d6,d7
        add.l d7,d7
        cmp.l d5,d7
        blt.s .y
        add.l d5,d6
        add.l d2,d0
.y:
        cmp.l d4,d7
        bgt.s .pixel
        add.l d4,d6
        add.l d3,d1
        bra.s .pixel
.done:  rts
; D0 x, D1 y. The grid comes first on the cleared surface, colour 9 with planes
; 0 and 3 set, and the border follows, so plane 0 stays set and plane 2 needs no
; clearing. A bit number on memory counts modulo 8, so NOT x gives 7-x%8.
; Uses A1-A3. D2 and D3 are preserved.
map_boundary_pixel:
        movea.l d2,a2
        movea.l d3,a3
        move.l d1,d2
        mulu.w #SCREEN_ROW_BYTES,d2
        move.l d0,d3
        lsr.l #3,d3
        add.l d3,d2
        movea.l draw_surface(pc),a1
        adda.l d2,a1
        move.l d0,d3
        not.l d3
        cmpi.w #PLACE_OFF,map_boundary_color-module_start(a5)
        beq.s .refused
        cmpi.w #PLACE_ON,map_boundary_color-module_start(a5)
        beq.s .ghost
        bset d3,SCREEN_PLANE_BYTES(a1)
        cmpi.w #15,map_boundary_color-module_start(a5)
        beq.s .border
        bclr d3,3*SCREEN_PLANE_BYTES(a1)
        move.l a2,d2
        move.l a3,d3
        rts
.border:
        bset d3,2*SCREEN_PLANE_BYTES(a1)
        bset d3,3*SCREEN_PLANE_BYTES(a1)
        move.l a2,d2
        move.l a3,d3
        rts
; Lines of the start page cross the grid, so these set every plane.
.refused:
        bclr d3,SCREEN_PLANE_BYTES(a1)
        bset d3,2*SCREEN_PLANE_BYTES(a1)
        bset d3,3*SCREEN_PLANE_BYTES(a1)
        move.l a2,d2
        move.l a3,d3
        rts
.ghost: bclr d3,SCREEN_PLANE_BYTES(a1)
        bclr d3,2*SCREEN_PLANE_BYTES(a1)
        bclr d3,3*SCREEN_PLANE_BYTES(a1)
        move.l a2,d2
        move.l a3,d3
        rts

map_boundary_world: dcb.w 4,0
map_boundary_color: dc.w 0
map_boundary_view: dcb.l 6,0
map_boundary_screen: dcb.l 4,0
; The perimeter from the origin round to it, a point per cell.
map_boundary_points:
MAP_POINT set 0
        rept MAP_CELLS
        dc.w MAP_POINT,0
MAP_POINT set MAP_POINT+MAP_CELL
        endr
MAP_POINT set 0
        rept MAP_CELLS
        dc.w MAP_SIZE,MAP_POINT
MAP_POINT set MAP_POINT+MAP_CELL
        endr
MAP_POINT set MAP_SIZE
        rept MAP_CELLS
        dc.w MAP_POINT,MAP_SIZE
MAP_POINT set MAP_POINT-MAP_CELL
        endr
MAP_POINT set MAP_SIZE
        rept MAP_CELLS
        dc.w 0,MAP_POINT
MAP_POINT set MAP_POINT-MAP_CELL
        endr
        dc.w 0,0
