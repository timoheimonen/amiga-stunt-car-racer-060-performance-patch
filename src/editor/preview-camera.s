; Position the camera for straight and turning section previews.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Oblique append preview: preceding-piece anchor, outside a turn, full context.
; Fit height/FOV within 256 units; retreat to keep downward pitch <= 45 degrees.
; Manual V, ordinary endpoint view and route/undo state remain independent.
preview_camera_prepare:
        clr.w overview_first-module_start(a5)
        clr.w preview_camera_active-module_start(a5)
        move.l #2560,camera_back-module_start(a5)
        move.l #2048,camera_elevation-module_start(a5)
        move.l #4096,camera_twice_elevation-module_start(a5)
        move.l #1536,camera_near-module_start(a5)
        move.l #572,camera_focal_x-module_start(a5)
        move.l #256,camera_focal_y-module_start(a5)
        tst.w overview_active-module_start(a5)
        bne overview_fit
        tst.w block_render_active-module_start(a5)
        beq .done
        cmpi.w #1,block_render_mode-module_start(a5)
        bne .done
        move.w block_insert(pc),d0
        cmp.w camera_endpoint(pc),d0
        bne .done
        subq.w #1,d0
        bmi .done
        move.w d0,overview_first-module_start(a5)
        move.w #1,preview_camera_active-module_start(a5)
        move.w editor_track+28(pc),preview_fit_end-module_start(a5)
        clr.l preview_side_min-module_start(a5)
        clr.l preview_side_max-module_start(a5)
        bsr preview_camera_bounds
        ; Large runs use a readable local join view, not a whole-run fit.
        lea preview_bounds(pc),a0
        move.l 4(a0),d0
        sub.l (a0),d0
        cmpi.l #8192,d0
        bgt.s .local_fit
        move.l 12(a0),d0
        sub.l 8(a0),d0
        cmpi.l #4096,d0
        bgt.s .local_fit
        move.l 20(a0),d0
        sub.l 16(a0),d0
        cmpi.l #8192,d0
        ble.s .fit_bounds_ready
.local_fit:
        move.w overview_first(pc),d0
        addq.w #2,d0
        cmp.w preview_fit_end(pc),d0
        bhs.s .fit_bounds_ready
        move.w d0,preview_fit_end-module_start(a5)
        ; Keep turn-side evidence from the complete candidate.
        bsr preview_camera_bounds
.fit_bounds_ready:
        lea preview_bounds(pc),a0
        ; Bounds are X,Y,Z pairs. Center includes the bottom of the walls.
        move.l (a0)+,d0
        move.l (a0)+,d1
        add.l d1,d0
        asr.l #1,d0
        move.l d0,preview_target_x-module_start(a5)
        move.l (a0)+,d0
        move.l (a0)+,d1
        subi.l #128,d0
        add.l d1,d0
        asr.l #1,d0
        move.l d0,preview_target_y-module_start(a5)
        move.l (a0)+,d0
        move.l (a0)+,d1
        add.l d1,d0
        asr.l #1,d0
        move.l d0,preview_target_z-module_start(a5)
        lea preview_bounds(pc),a0
        move.l #2048,d2
        moveq #2,d3
.extent:
        move.l (a0)+,d0
        move.l (a0)+,d1
        sub.l d0,d1
        cmp.l d1,d2
        bge.s .extent_next
        move.l d1,d2
.extent_next:
        dbra d3,.extent
        move.l #2048,camera_elevation-module_start(a5)
        ; Anchor the view at the preceding primitive; turns move the anchor
        ; sideways to the outside. Fitting may retreat along the view axis.
        asr.l #1,d2
        cmpi.l #2048,d2
        bge.s .offset_size
        move.l #2048,d2
.offset_size:
        clr.w preview_turn-module_start(a5)
        move.l preview_side_min(pc),d0
        add.l preview_side_max(pc),d0
        cmpi.l #256,d0
        bgt.s .right_turn
        cmpi.l #-256,d0
        blt.s .left_turn
        moveq #0,d2
        bra.s .eye
.right_turn:
        move.w #1,preview_turn-module_start(a5)
        neg.l d2
        bra.s .eye
.left_turn:
        move.w #-1,preview_turn-module_start(a5)
.eye:
        move.w overview_first(pc),d0
        move.w d0,d1
        add.w d1,d1
        lea model_row_counts(pc),a0
        move.w (a0,d1.w),d1
        subq.w #1,d1
        mulu.w #12,d1
        mulu.w #EDITOR_GEOMETRY_STRIDE,d0
        lea model_geometry(pc),a0
        adda.w d0,a0
        lea (a0,d1.w),a1
        ; camera_x/y/z are not a contiguous vector: store explicitly.
        bsr preview_previous_center
        move.l d0,camera_x-module_start(a5)
        bsr preview_previous_center
        move.l d0,camera_y-module_start(a5)
        bsr preview_previous_center
        move.l d0,camera_z-module_start(a5)
        move.w camera_right_x(pc),d0
        ext.l d0
        muls.l d2,d0
        asr.l #7,d0
        asr.l #7,d0
        add.l d0,camera_x-module_start(a5)
        move.w camera_right_z(pc),d0
        ext.l d0
        muls.l d2,d0
        asr.l #7,d0
        asr.l #7,d0
        add.l d0,camera_z-module_start(a5)
        ; Look toward the candidate's center from this anchored eye.
        move.l preview_target_z(pc),d0
        sub.l camera_z(pc),d0
        move.l camera_x(pc),d1
        sub.l preview_target_x(pc),d1
        bsr preview_normalize
        move.w d0,camera_right_x-module_start(a5)
        move.w d1,camera_right_z-module_start(a5)
        move.l preview_target_z(pc),d2
        sub.l camera_z(pc),d2
        muls.l d0,d2
        move.l preview_target_x(pc),d3
        sub.l camera_x(pc),d3
        muls.l d1,d3
        sub.l d3,d2
        asr.l #7,d2
        asr.l #7,d2
        move.l d2,preview_target_distance-module_start(a5)
        clr.l camera_back-module_start(a5)
        move.w #1,preview_fit_pass-module_start(a5)
        move.l #1792,preview_fit_low-module_start(a5)
        clr.l preview_fit_high-module_start(a5)
.retry:
        move.l preview_target_distance(pc),d0
        move.l camera_y(pc),d1
        add.l camera_elevation(pc),d1
        sub.l preview_target_y(pc),d1
        ; Keep every append view oblique: never steeper than 45 degrees.
        ; Move backwards along the view axis when height needs more room.
        clr.l camera_back-module_start(a5)
        cmp.l d0,d1
        ble.s .pitch_ready
        move.l d1,d2
        sub.l d0,d2
        move.l d2,camera_back-module_start(a5)
        move.l d1,d0
.pitch_ready:
        bsr preview_normalize
        move.l d0,preview_pitch_cos-module_start(a5)
        move.l d1,preview_pitch_sin-module_start(a5)
        move.l #320,camera_focal_y-module_start(a5)
        bsr preview_camera_scan
        cmpi.l #192,camera_focal_y-module_start(a5)
        blo.s .too_close
        move.l camera_elevation(pc),d0
        move.l d0,preview_fit_high-module_start(a5)
        sub.l preview_fit_low(pc),d0
        cmpi.l #256,d0
        bls.s .focal
        bra.s .bisect
.too_close:
        move.l camera_elevation(pc),preview_fit_low-module_start(a5)
        tst.l preview_fit_high-module_start(a5)
        bne.s .bisect
        move.l camera_elevation(pc),d0
        add.l d0,d0
        bra.s .retry_height
.bisect:
        move.l preview_fit_low(pc),d0
        add.l preview_fit_high(pc),d0
        lsr.l #1,d0
.retry_height:
        move.l d0,camera_elevation-module_start(a5)
        bra .retry
.focal:
        move.l camera_focal_y(pc),camera_focal_x-module_start(a5)
.done:  rts

preview_camera_bounds:
        lea preview_bounds(pc),a0
        moveq #2,d0
.init:  move.l #$7fffffff,(a0)+
        move.l #$80000000,(a0)+
        dbra d0,.init
        clr.w preview_fit_pass-module_start(a5)
        bra preview_camera_scan

; Visit fit vertices only; rendering still traverses the complete track.
preview_camera_scan:
        lea model_geometry(pc),a0
        lea model_row_counts(pc),a1
        move.w overview_first(pc),d0
        move.w d0,render_piece-module_start(a5)
        move.w preview_fit_end(pc),d6
        sub.w d0,d6
        subq.w #1,d6
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
        movem.l d6-d7/a0-a3,-(sp)
        moveq #0,d0
        move.w (a2)+,d0
        add.l (a3)+,d0
        moveq #0,d1
        move.w (a2)+,d1
        add.l (a3)+,d1
        moveq #0,d2
        move.w (a2)+,d2
        add.l (a3)+,d2
        tst.w preview_fit_pass-module_start(a5)
        bne.s .project
        move.w render_piece(pc),d3
        cmp.w block_insert(pc),d3
        blo.s .bounds
        movem.l d0-d2,-(sp)
        sub.l camera_x(pc),d0
        sub.l camera_z(pc),d2
        move.w camera_right_x(pc),d3
        ext.l d3
        muls.l d3,d0
        move.w camera_right_z(pc),d3
        ext.l d3
        muls.l d3,d2
        add.l d2,d0
        asr.l #7,d0
        asr.l #7,d0
        lea preview_side_min(pc),a0
        bsr preview_bound
        movem.l (sp)+,d0-d2
.bounds:
        lea preview_bounds(pc),a0
        bsr preview_bound
        move.l d1,d0
        bsr preview_bound
        move.l d2,d0
        bsr preview_bound
        bra.s .next
.project:
        sub.l camera_x(pc),d0
        sub.l camera_z(pc),d2
        move.w camera_right_x(pc),d3
        ext.l d3
        move.w camera_right_z(pc),d4
        ext.l d4
        move.l d0,d5
        move.l d2,d6
        muls.l d3,d5
        muls.l d4,d6
        add.l d6,d5
        asr.l #7,d5
        asr.l #7,d5        ; side coordinate
        muls.l d4,d0
        neg.l d0
        muls.l d3,d2
        add.l d0,d2
        asr.l #7,d2
        asr.l #7,d2
        add.l camera_back(pc),d2
        neg.l d1
        add.l camera_y(pc),d1
        bsr preview_focal_bound
        addi.l #128,d1     ; wall bottom must fit too
        bsr preview_focal_bound
.next:
        movem.l (sp)+,d6-d7/a0-a3
        addq.l #6,a2
        dbra d7,.point
        adda.w #EDITOR_GEOMETRY_STRIDE,a0
        addq.w #1,render_piece-module_start(a5)
        dbra d6,.piece
        rts
preview_bound:
        cmp.l (a0),d0
        bge.s .max
        move.l d0,(a0)
.max:   addq.l #4,a0
        cmp.l (a0),d0
        ble.s .done
        move.l d0,(a0)
.done:  addq.l #4,a0
        rts

; D5 side, D2 forward, D1 relative height. Preserve all three.
preview_focal_bound:
        movem.l d1-d2,-(sp)
        bsr preview_project
        cmpi.l #512,d2
        blt.s .near
        move.l d5,d4
        bpl.s .side
        neg.l d4
.side:  beq.s .vertical
        move.l d2,d0
        mulu.l #144,d0
        divu.l d4,d0
        bsr preview_focal_min
.vertical:
        move.l d1,d4
        bpl.s .height
        neg.l d4
.height:
        beq.s .done
        move.l d2,d0
        mulu.l #60,d0
        divu.l d4,d0
        bsr preview_focal_min
        bra.s .done
.near:  clr.l camera_focal_y-module_start(a5)
.done:  movem.l (sp)+,d1-d2
        rts

; D2 forward, D1 relative height -> depth D2, vertical D1 (Q14 pitch).
; D0/D3/D4 scratch. D5 and loop registers survive.
preview_project:
        add.l camera_elevation(pc),d1
        move.l d2,d3
        move.l d1,d4
        muls.l preview_pitch_cos(pc),d3
        muls.l preview_pitch_sin(pc),d4
        add.l d4,d3
        muls.l preview_pitch_cos(pc),d1
        muls.l preview_pitch_sin(pc),d2
        sub.l d2,d1
        asr.l #7,d1
        asr.l #7,d1
        move.l d3,d2
        asr.l #7,d2
        asr.l #7,d2
        rts

; Advance across first/last row's X/Y/Z, average their four unsigned words.
preview_previous_center:
        moveq #0,d0
        move.w (a0),d0
        moveq #0,d1
        move.w 6(a0),d1
        add.l d1,d0
        move.w (a1),d1
        add.l d1,d0
        move.w 6(a1),d1
        add.l d1,d0
        lsr.l #2,d0
        addq.l #2,a0
        addq.l #2,a1
        rts

; Normalize signed D0/D1 to Q14 with a bounded integer square root.
; Four-unit quantization keeps squares and products inside signed 32 bits.
preview_normalize:
        movem.l d2-d6,-(sp)
        asr.l #2,d0
        asr.l #2,d1
        move.l d0,d2
        muls.l d2,d2
        move.l d1,d3
        muls.l d3,d3
        add.l d3,d2
        beq.s .zero
        moveq #0,d3
        move.l #$40000000,d4
.sqrt:
        move.l d3,d5
        add.l d4,d5
        cmp.l d5,d2
        blo.s .skip
        sub.l d5,d2
        lsr.l #1,d3
        add.l d4,d3
        bra.s .next
.skip:  lsr.l #1,d3
.next:  lsr.l #2,d4
        bne.s .sqrt
        asl.l #7,d0
        asl.l #7,d0
        asl.l #7,d1
        asl.l #7,d1
        divs.l d3,d0
        divs.l d3,d1
        bra.s .done
.zero:  move.l #16384,d0
        moveq #0,d1
.done:  movem.l (sp)+,d2-d6
        rts

preview_focal_min:
        cmp.l camera_focal_y(pc),d0
        bhs.s .done
        move.l d0,camera_focal_y-module_start(a5)
.done:  rts

; Follow a newly committed tail only when the user was inspecting its join.
; editing_backup ran first, so Undo restores the old route as well as geometry.
preview_camera_follow:
        cmpi.w #1,building_mode-module_start(a5)
        bne.s .done
        move.w block_insert(pc),d0
        cmp.w camera_endpoint(pc),d0
        bne.s .done
        moveq #0,d0
        move.w editor_track+28(pc),d0
        lsl.l #8,d0
        lsl.l #3,d0
        move.l d0,camera_route-module_start(a5)
.done:  rts

preview_camera_active: dc.w 0
preview_fit_pass: dc.w 0
overview_first: dc.w 0
camera_back: dc.l 2560
camera_elevation: dc.l 2048
camera_twice_elevation: dc.l 4096
camera_near: dc.l 1536
camera_focal_x: dc.l 572
camera_focal_y: dc.l 256
preview_bounds: dcb.l 6,0
preview_side_min: dc.l 0
preview_side_max: dc.l 0
preview_turn: dc.w 0
preview_target_x: dc.l 0
preview_target_y: dc.l 0
preview_target_z: dc.l 0
preview_target_distance: dc.l 0
preview_pitch_cos: dc.l 0
preview_pitch_sin: dc.l 0

preview_fit_low: dc.l 0
preview_fit_high: dc.l 0

preview_fit_end: dc.w 0
