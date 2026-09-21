; Draw the editor ground grid and building-area boundary.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Ground grid and outline of the actual X/Z domain, 0..32768, Y=0.
; Paint before the road, without depth writes: road surfaces cover the guide.
; 2048-unit subdivisions bound near-plane intersection products on 68060.
editor_map_boundary:
        move.w #543,d7       ; 30 inner lines * 16 segments + 64 border segments
.segment:
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
        muls.l camera_focal_x(pc),d0
        divs.l d2,d0
        addi.l #160,d0
        muls.l camera_focal_y(pc),d1
        divs.l d2,d1
        addi.l #100,d1
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

; D7 descending 543..0. Grid first (color 3), then gold perimeter (15).
; A4 points at two adjacent world X/Z word pairs. No camera fit dependency.
map_boundary_segment:
        cmpi.w #64,d7
        blo.s .border
        move.w #3,map_boundary_color-module_start(a5)
        move.w #543,d0
        sub.w d7,d0
        move.w d0,d1
        andi.w #15,d1
        lsl.w #8,d1
        lsl.w #3,d1
        lsr.w #4,d0
        move.w d0,d2
        cmpi.w #15,d0
        blo.s .coordinate
        subi.w #15,d0
.coordinate:
        addq.w #1,d0
        lsl.w #8,d0
        lsl.w #3,d0
        lea map_boundary_world(pc),a4
        cmpi.w #15,d2
        bhs.s .horizontal
        move.w d0,(a4)
        move.w d1,2(a4)
        move.w d0,4(a4)
        addi.w #2048,d1
        move.w d1,6(a4)
        rts
.horizontal:
        move.w d1,(a4)
        move.w d0,2(a4)
        addi.w #2048,d1
        move.w d1,4(a4)
        move.w d0,6(a4)
        rts
.border:
        move.w #15,map_boundary_color-module_start(a5)
        moveq #63,d0
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
        add.l camera_back(pc),d0
        move.l camera_y(pc),d1
        add.l camera_elevation(pc),d1
        tst.w preview_camera_active-module_start(a5)
        bne.s .preview
        move.l d0,d2
        add.l d2,d2
        add.l d1,d2
        move.l d2,(a1)+
        add.l d1,d1
        sub.l d0,d1
        move.l d1,(a1)+
        rts
.preview:
        ; Split Q14 products keep high cameras over Y=0 inside 32-bit math.
        ; Ground can be much farther below the eye than any fitted road.
        move.l d0,d5
        move.l d1,d6
        move.l preview_pitch_cos(pc),d1
        bsr map_boundary_mul_q14
        move.l d0,d4
        move.l d6,d0
        move.l preview_pitch_sin(pc),d1
        bsr map_boundary_mul_q14
        add.l d4,d0
        move.l d0,(a1)+
        move.l d6,d0
        move.l preview_pitch_cos(pc),d1
        bsr map_boundary_mul_q14
        move.l d0,d4
        move.l d5,d0
        move.l preview_pitch_sin(pc),d1
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
        move.l #319,d3
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
.top:   moveq #32,d3
        bra.s .horizontal
.bottom:
        move.l #175,d3
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
.right: cmpi.l #319,d0
        ble.s .top
        bset #1,d2
.top:   cmpi.l #32,d1
        bge.s .bottom
        bset #2,d2
.bottom:
        cmpi.l #175,d1
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
map_boundary_pixel:
        movem.l d0-d3/a0,-(sp)
        move.l d1,d2
        mulu.w #40,d2
        move.l d0,d3
        lsr.l #3,d3
        add.l d3,d2
        andi.w #7,d0
        moveq #7,d3
        sub.w d0,d3
        movea.l draw_surface(pc),a0
        adda.l d2,a0
        bset d3,(a0)
        bset d3,8000(a0)
        cmpi.w #15,map_boundary_color-module_start(a5)
        beq.s .border
        bclr d3,16000(a0)
        bclr d3,24000(a0)
        bra.s .done
.border:
        bset d3,16000(a0)
        bset d3,24000(a0)
.done:  movem.l (sp)+,d0-d3/a0
        rts

map_boundary_world: dcb.w 4,0
map_boundary_color: dc.w 0
map_boundary_view: dcb.l 6,0
map_boundary_screen: dcb.l 4,0
map_boundary_points:
        dc.w 0,0
        dc.w 2048,0
        dc.w 4096,0
        dc.w 6144,0
        dc.w 8192,0
        dc.w 10240,0
        dc.w 12288,0
        dc.w 14336,0
        dc.w 16384,0
        dc.w 18432,0
        dc.w 20480,0
        dc.w 22528,0
        dc.w 24576,0
        dc.w 26624,0
        dc.w 28672,0
        dc.w 30720,0
        dc.w 32768,0
        dc.w 32768,2048
        dc.w 32768,4096
        dc.w 32768,6144
        dc.w 32768,8192
        dc.w 32768,10240
        dc.w 32768,12288
        dc.w 32768,14336
        dc.w 32768,16384
        dc.w 32768,18432
        dc.w 32768,20480
        dc.w 32768,22528
        dc.w 32768,24576
        dc.w 32768,26624
        dc.w 32768,28672
        dc.w 32768,30720
        dc.w 32768,32768
        dc.w 30720,32768
        dc.w 28672,32768
        dc.w 26624,32768
        dc.w 24576,32768
        dc.w 22528,32768
        dc.w 20480,32768
        dc.w 18432,32768
        dc.w 16384,32768
        dc.w 14336,32768
        dc.w 12288,32768
        dc.w 10240,32768
        dc.w 8192,32768
        dc.w 6144,32768
        dc.w 4096,32768
        dc.w 2048,32768
        dc.w 0,32768
        dc.w 0,30720
        dc.w 0,28672
        dc.w 0,26624
        dc.w 0,24576
        dc.w 0,22528
        dc.w 0,20480
        dc.w 0,18432
        dc.w 0,16384
        dc.w 0,14336
        dc.w 0,12288
        dc.w 0,10240
        dc.w 0,8192
        dc.w 0,6144
        dc.w 0,4096
        dc.w 0,2048
        dc.w 0,0
