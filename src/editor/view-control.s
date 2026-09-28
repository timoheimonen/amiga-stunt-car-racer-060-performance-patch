; Turn the editor view in 45-degree steps and zoom it in five steps.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Manual view: Q/W orbit in 45-degree steps, A/Z zoom in five steps.
; Orbit is a temporary look-around: it resets when the inspected endpoint or
; the building mode changes. Zoom stays for the editor session. V overview,
; dialogs and name entry ignore these keys; letters remain name characters.
VIEW_ZOOM_DEFAULT equ 1
VIEW_ZOOM_MAX equ 4
view_keys:
        moveq #0,d0
        cmpi.b #$b3,editor_input_keys+$10(a5)      ; Q
        bne.s .w
        bset #0,d0
.w:     cmpi.b #$b3,editor_input_keys+$11(a5)      ; W
        bne.s .a
        bset #1,d0
.a:     cmpi.b #$b3,editor_input_keys+$20(a5)      ; A
        bne.s .z
        bset #2,d0
.z:     cmpi.b #$b3,editor_input_keys+$31(a5)      ; Z
        bne.s .sample
        bset #3,d0
.sample:
        move.w view_key_state(pc),d1
        move.w d0,view_key_state-module_start(a5)
        not.w d1
        and.w d1,d0
        tst.w storage_modal-module_start(a5)
        bne.s .done
        tst.w editing_prompt-module_start(a5)
        bne.s .done
        tst.w overview_active-module_start(a5)
        bne.s .done
        btst #0,d0
        beq.s .right
        subq.w #1,view_orbit-module_start(a5)
.right:
        btst #1,d0
        beq.s .orbit_ready
        addq.w #1,view_orbit-module_start(a5)
.orbit_ready:
        andi.w #7,view_orbit-module_start(a5)
        btst #2,d0
        beq.s .out
        tst.w view_zoom-module_start(a5)
        beq.s .out
        subq.w #1,view_zoom-module_start(a5)
.out:
        btst #3,d0
        beq.s .done
        cmpi.w #VIEW_ZOOM_MAX,view_zoom-module_start(a5)
        bhs.s .done
        addq.w #1,view_zoom-module_start(a5)
.done:  rts

; Orbit belongs to one endpoint and one building mode.
view_context_check:
        move.w building_mode(pc),d0
        lsl.w #8,d0
        or.w camera_endpoint(pc),d0
        cmp.w view_context(pc),d0
        beq.s .same
        move.w d0,view_context-module_start(a5)
        clr.w view_orbit-module_start(a5)
.same:  rts

view_reset:
        clr.w view_orbit-module_start(a5)
        move.w #VIEW_ZOOM_DEFAULT,view_zoom-module_start(a5)
        move.w #15,view_key_state-module_start(a5)
        move.w #-1,view_context-module_start(a5)
        rts

; Ordinary endpoint camera: orbit the heading around the endpoint anchor and
; scale eye distance and height. Near plane stays 512 below the elevation.
view_endpoint:
        move.w view_orbit(pc),d0
        beq.s .zoom
        move.w camera_right_x(pc),d1
        move.w camera_right_z(pc),d2
        bsr view_axis_index
        add.w view_orbit(pc),d1
        andi.w #7,d1
        lsl.w #2,d1
        lea view_axes(pc),a0
        move.w (a0,d1.w),camera_right_x-module_start(a5)
        move.w 2(a0,d1.w),camera_right_z-module_start(a5)
.zoom:
        cmpi.w #VIEW_ZOOM_DEFAULT,view_zoom-module_start(a5)
        beq.s .done
        bsr view_zoom_numerator
        move.l d1,d0
        mulu.w #640,d0
        move.l d0,camera_back-module_start(a5)
        move.l d1,d0
        mulu.w #512,d0
        move.l d0,camera_elevation-module_start(a5)
        add.l d0,d0
        move.l d0,camera_twice_elevation-module_start(a5)
        move.l camera_elevation(pc),d0
        subi.l #512,d0
        move.l d0,camera_near-module_start(a5)
.done:  rts

; D1 = zoom numerator over four (3,4,6,8,12). D0 preserved.
view_zoom_numerator:
        move.w view_zoom(pc),d1
        add.w d1,d1
        move.w view_zoom_table(pc,d1.w),d1
        ext.l d1
        rts
view_zoom_table: dc.w 3,4,6,8,12

; D1/D2 quantized axis X/Z signs -> D1 direction index 0..7 (45-degree
; steps, increasing to the left). D0 preserved.
view_axis_index:
        movem.l d0/d2,-(sp)
        moveq #1,d0
        tst.w d1
        beq.s .x_ready
        bmi.s .x_negative
        moveq #2,d0
        bra.s .x_ready
.x_negative:
        moveq #0,d0
.x_ready:
        mulu.w #3,d0
        tst.w d2
        beq.s .z_zero
        bmi.s .lookup
        addq.w #2,d0
        bra.s .lookup
.z_zero:
        addq.w #1,d0
.lookup:
        move.b view_sign_index(pc,d0.w),d1
        ext.w d1
        movem.l (sp)+,d0/d2
        rts
view_sign_index: dc.b 5,4,3,6,0,2,7,0,1
        even
view_axes:
        dc.w 16384,0,11585,11585,0,16384,-11585,11585
        dc.w -16384,0,-11585,-11585,0,-16384,11585,-11585

; Rotate XZ offset D1/D3 by D0*45 degrees (Q14 cosine table, floor shifts).
; D0/D2/D4/D5 scratch; results in D1/D3.
view_rotate:
        andi.w #7,d0
        move.w d0,d2
        add.w d2,d2
        move.w view_cos(pc,d2.w),d4
        ext.l d4
        subq.w #2,d0
        andi.w #7,d0
        add.w d0,d0
        move.w view_cos(pc,d0.w),d5
        ext.l d5
        move.l d1,d0
        muls.l d4,d0           ; x*c
        move.l d3,d2
        muls.l d5,d2           ; z*s
        sub.l d2,d0
        asr.l #7,d0
        asr.l #7,d0
        muls.l d5,d1           ; x*s
        muls.l d4,d3           ; z*c
        add.l d1,d3
        asr.l #7,d3
        asr.l #7,d3
        move.l d0,d1
        rts
view_cos: dc.w 16384,11585,0,-11585,-16384,-11585,0,11585

view_orbit: dc.w 0
view_zoom: dc.w VIEW_ZOOM_DEFAULT
view_key_state: dc.w 15
view_context: dc.w -1
camera_heading_x: dc.w 16384
camera_heading_z: dc.w 0
