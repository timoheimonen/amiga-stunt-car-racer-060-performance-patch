; Fit the whole track and map into an orthographic overview.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Whole-track orthographic view. V toggles once per press; dialogs consume V.
editor_view_key:
        moveq #0,d0
        cmpi.b #$b3,editor_input_keys+$34(a5)       ; V raw $34
        bne.s .sample
        moveq #1,d0
.sample:
        move.w overview_key(pc),d1
        move.w d0,overview_key-module_start(a5)
        tst.w storage_modal-module_start(a5)
        bne.s .done
        tst.w editing_prompt-module_start(a5)
        bne.s .done
        tst.w d0
        beq.s .done
        tst.w d1
        bne.s .done
        eori.w #1,overview_active-module_start(a5)
.done:  rts

; Bounds include the displayed model (including translated rejected previews).
; Oblique projection: u=x, v=-z-2*y. Same elevated whole-track idea as load map.
overview_fit:
        ; Always include all four ground-plane map corners.
        clr.l overview_min_x-module_start(a5)
        move.l #-32768,overview_min_v-module_start(a5)
        move.l #32768,overview_max_x-module_start(a5)
        clr.l overview_max_v-module_start(a5)
        lea model_geometry(pc),a0
        lea model_row_counts(pc),a1
        move.w editor_track+28(pc),d6
        move.w overview_first(pc),d0
        sub.w d0,d6
        subq.w #1,d6
        move.w d0,render_piece-module_start(a5)
        add.w d0,d0
        adda.w d0,a1
        mulu.w #EDITOR_GEOMETRY_STRIDE/2,d0
        adda.w d0,a0
.piece:
        bsr block_render_offset
        movea.l a0,a2
        move.w (a1)+,d7
        add.w d7,d7
        subq.w #1,d7
.point:
        moveq #0,d0
        move.w (a2),d0
        add.l (a3),d0
        moveq #0,d1
        move.w 2(a2),d1
        add.l 4(a3),d1
        add.l d1,d1
        moveq #0,d2
        move.w 4(a2),d2
        add.l 8(a3),d2
        add.l d2,d1
        neg.l d1
        bsr overview_bound
        addi.l #256,d1         ; include bottom of 128-unit side walls
        bsr overview_bound
        addq.l #6,a2
        dbra d7,.point
        adda.w #EDITOR_GEOMETRY_STRIDE,a0
        addq.w #1,render_piece-module_start(a5)
        dbra d6,.piece
        move.l overview_max_x(pc),d0
        sub.l overview_min_x(pc),d0
        addq.l #1,d0
        move.l d0,overview_width-module_start(a5)
        move.l #288*65536,d2
        divu.l d0,d2
        move.l overview_max_v(pc),d1
        sub.l overview_min_v(pc),d1
        addq.l #1,d1
        move.l d1,overview_height-module_start(a5)
        move.l #128*65536,d3
        divu.l d1,d3
        cmp.l d3,d2
        bls.s .scale
        move.l d3,d2
.scale:
        move.l d2,overview_scale-module_start(a5)
        mulu.l d2,d0
        swap d0
        andi.l #$ffff,d0
        neg.l d0
        addi.l #320,d0
        lsr.l #1,d0
        move.l d0,overview_left-module_start(a5)
        mulu.l d2,d1
        swap d1
        andi.l #$ffff,d1
        neg.l d1
        addi.l #208,d1         ; centered inside y=40..168
        lsr.l #1,d1
        move.l d1,overview_top-module_start(a5)
        rts
overview_bound:
        cmp.l overview_min_x(pc),d0
        bge.s .maxx
        move.l d0,overview_min_x-module_start(a5)
.maxx:  cmp.l overview_max_x(pc),d0
        ble.s .minv
        move.l d0,overview_max_x-module_start(a5)
.minv:  cmp.l overview_min_v(pc),d1
        bge.s .maxv
        move.l d1,overview_min_v-module_start(a5)
.maxv:  cmp.l overview_max_v(pc),d1
        ble.s .done
        move.l d1,overview_max_v-module_start(a5)
.done:  rts

; polygon_world contains x,z,(camera_y-y); rasterizer keeps normal depth tests.
overview_polygon:
        lea polygon_world(pc),a0
        lea polygon_screen(pc),a1
        moveq #3,d7
.point:
        move.l (a0)+,d0
        sub.l overview_min_x(pc),d0
        muls.l overview_scale(pc),d0
        asr.l #8,d0
        asr.l #8,d0
        add.l overview_left(pc),d0
        move.l d0,(a1)+
        move.l (a0)+,d2
        move.l camera_y(pc),d3
        sub.l (a0)+,d3
        cmpi.w #3,d7
        beq.s .height
        tst.w d7
        beq.s .height
        moveq #0,d0
        move.w polygon_drop(pc),d0
        sub.l d0,d3
.height:
        move.l d3,d0
        add.l d0,d0
        add.l d2,d0
        neg.l d0
        sub.l overview_min_v(pc),d0
        muls.l overview_scale(pc),d0
        asr.l #8,d0
        asr.l #8,d0
        add.l overview_top(pc),d0
        move.l d0,(a1)+
        asr.l #2,d2
        asr.l #1,d3
        sub.l d2,d3
        addi.l #32768,d3
        move.l d3,(a1)+
        dbra d7,.point
        move.w #4,polygon_count-module_start(a5)
        bra polygon_raster

overview_active: dc.w 0
overview_key: dc.w 0
overview_min_x: dc.l 0
overview_max_x: dc.l 0
overview_min_v: dc.l 0
overview_max_v: dc.l 0
overview_width: dc.l 0
overview_height: dc.l 0
overview_scale: dc.l 0
overview_left: dc.l 0
overview_top: dc.l 0
