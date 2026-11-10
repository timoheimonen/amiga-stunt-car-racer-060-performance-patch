; Move the free editor camera.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Track Editor bar: the camera. It is an eye and two angles, and only the player
; moves it. A track opens on its start piece from the third person, the view of
; free_open_step, and nothing in the editor moves the camera after that.
; Angles are 512 steps a turn. Pitch 0 is level, a positive pitch looks down.
FREE_TURN_MASK equ 511
; A turn of FREE_TURN_MASK+1 steps: free_sin takes the sign from the half turn
; and the value from the quarter.
FREE_HALF_BIT equ 8
FREE_HALF equ 1<<FREE_HALF_BIT
FREE_QUARTER equ FREE_HALF/2
FREE_PITCH_MIN equ -28
FREE_PITCH_MAX equ 128
FREE_DRAG_COUNTS equ 16
FREE_GROUND_SHIFT equ 2         ; 4 units a millisecond
FREE_HEIGHT_SHIFT equ 1         ; 2 units a millisecond
FREE_STEP_MAX_MS equ 100
FREE_REST_MS equ 40
FREE_EYE_MIN equ -4096
FREE_EYE_MAX equ 36864
FREE_EYE_LOW equ 256
FREE_EYE_HIGH equ 24576
FREE_WIRE_EDGES equ 1
FREE_WIRE_GRID equ 2
FREE_WIRE_OUTLINE equ 3
FREE_FOCAL equ 256
FREE_OPEN_BACK equ 2560         ; eye behind the start piece
FREE_OPEN_HIGH equ 2048         ; and above it
FREE_OPEN_PITCH equ 38          ; atan(1/2)
FREE_PAGES equ UI_PAGE_BROWSE|UI_PAGE_CHOOSE

; Each pass, before the request of the pass: the right button and the held keys.
ui_camera_step:
        move.l ui_ms(pc),d4
        move.l d4,d5
        sub.l free_time(pc),d5
        move.l d4,free_time-module_start(a5)
        moveq #FREE_STEP_MAX_MS,d0
        cmp.l d0,d5
        bls.s .elapsed
        move.l d0,d5
.elapsed:
        move.w ui_sum_x(pc),d0
        move.w d0,d2
        sub.w free_last_x(pc),d2
        move.w d0,free_last_x-module_start(a5)
        move.w ui_sum_y(pc),d0
        move.w d0,d3
        sub.w free_last_y(pc),d3
        move.w d0,free_last_y-module_start(a5)
        tst.w ui_rmb_up-module_start(a5)
        beq.s .pressed
        bsr free_release
.pressed:
        bsr ui_page_now
        andi.w #FREE_PAGES,d0
        beq .still
        tst.w overview_active-module_start(a5)
        bne .still
        moveq #0,d6
        btst #1,ui_btn+1-module_start(a5)
        beq.s .keys
        tst.w free_drag-module_start(a5)
        bne.s .turn
        bsr free_drag_distance
        cmpi.w #FREE_DRAG_COUNTS,d0
        blo.s .keys
        move.w #1,free_drag-module_start(a5)
        move.w #UI_POINTER_DRAG,ui_pointer_want-module_start(a5)
        moveq #1,d6
.turn:  move.w d2,d0
        or.w d3,d0
        beq.s .keys
        moveq #1,d6
        add.w d2,free_yaw-module_start(a5)
        andi.w #FREE_TURN_MASK,free_yaw-module_start(a5)
        add.w free_pitch(pc),d3
        cmpi.w #FREE_PITCH_MIN,d3
        bge.s .above
        move.w #FREE_PITCH_MIN,d3
.above: cmpi.w #FREE_PITCH_MAX,d3
        ble.s .pitch
        move.w #FREE_PITCH_MAX,d3
.pitch: move.w d3,free_pitch-module_start(a5)
.keys:  moveq #RAW_D,d1
        moveq #RAW_A,d2
        bsr free_axis
        move.w d0,d7
        moveq #RAW_W,d1
        moveq #RAW_S,d2
        bsr free_axis
        move.w d0,d3
        moveq #RAW_Q,d1
        moveq #RAW_Z,d2
        bsr free_axis
        move.w d0,d2
        or.w d3,d0
        or.w d7,d0
        beq.s .pace
        bsr free_fly
        moveq #1,d6
.pace:  tst.w d6
        beq.s .rest
        move.w #FREE_WIRE_OUTLINE,free_wire-module_start(a5)
        move.l d4,d0
        addi.l #FREE_REST_MS,d0
        move.l d0,free_rest-module_start(a5)
        rts
.rest:  tst.w free_wire-module_start(a5)
        beq.s .done
        move.l d4,d0
        sub.l free_rest(pc),d0
        bmi.s .done
.still: clr.w free_wire-module_start(a5)
.done:  rts

; D0 = the counts since the right button went down.
free_drag_distance:
        move.w ui_sum_x(pc),d0
        sub.w ui_rmb_sx(pc),d0
        bpl.s .y
        neg.w d0
.y:     move.w ui_sum_y(pc),d1
        sub.w ui_rmb_sy(pc),d1
        bpl.s .add
        neg.w d1
.add:   add.w d1,d0
        rts

; D1 raw key for +1, D2 raw key for -1. D0.w = the sum.
free_axis:
        moveq #0,d0
        lea editor_input_keys(a5),a0
        cmpi.b #KEY_DOWN,(a0,d1.w)
        bne.s .minus
        addq.w #1,d0
.minus: cmpi.b #KEY_DOWN,(a0,d2.w)
        bne.s .done
        subq.w #1,d0
.done:  rts

; D7 right, D3 ahead, D2 up, D5 milliseconds: the speed comes from time, not
; from the frames, so a long track moves as fast as a short one. Keeps D4, D5.
free_fly:
        move.w d2,-(sp)
        move.w free_yaw(pc),d0
        bsr free_sin
        move.l d0,d1
        move.w free_yaw(pc),d0
        addi.w #FREE_QUARTER,d0
        bsr free_sin
        ext.l d3
        ext.l d7
        muls.l d5,d3
        muls.l d5,d7
        lsl.l #FREE_GROUND_SHIFT,d3
        lsl.l #FREE_GROUND_SHIFT,d7
        ; X = ahead sin + right cos, Z = ahead cos - right sin.
        move.l d3,d2
        muls.l d1,d2
        muls.l d0,d3
        move.l d7,d6
        muls.l d0,d6
        muls.l d1,d7
        add.l d6,d2
        sub.l d7,d3
        asr.l #7,d2
        asr.l #7,d2
        asr.l #7,d3
        asr.l #7,d3
        move.l d3,d7
        move.l d2,d0
        lea free_x(pc),a1
        bsr.s free_limit_ground
        move.l d7,d0
        lea free_z(pc),a1
        bsr.s free_limit_ground
        move.w (sp)+,d0
        ext.l d0
        muls.l d5,d0
        lsl.l #FREE_HEIGHT_SHIFT,d0
        move.l #FREE_EYE_LOW,d1
        move.l #FREE_EYE_HIGH,d2
        lea free_y(pc),a1
        bra.s free_limit

free_limit_ground:
        move.l #FREE_EYE_MIN,d1
        move.l #FREE_EYE_MAX,d2
; D0 step of the long at A1, D1 and D2 its limits. An eye the opening view left
; outside them may only come back, so the first movement never jumps.
free_limit:
        move.l (a1),d3
        add.l d3,d0
        cmp.l d1,d0
        bge.s .high
        cmp.l d3,d0
        bge.s .store
        move.l d1,d0
        cmp.l d3,d0
        ble.s .store
        move.l d3,d0
        bra.s .store
.high:  cmp.l d2,d0
        ble.s .store
        cmp.l d3,d0
        ble.s .store
        move.l d2,d0
        cmp.l d3,d0
        bge.s .store
        move.l d3,d0
.store: move.l d0,(a1)
        rts

; The right button came up. A drag ends. A click closes what is open. D2-D7 are
; kept for the step.
free_release:
        clr.w ui_rmb_up-module_start(a5)
        tst.w free_drag-module_start(a5)
        beq.s .click
        clr.w free_drag-module_start(a5)
        clr.w ui_pointer_want-module_start(a5)
        rts
.click: bsr free_drag_distance
        cmpi.w #FREE_DRAG_COUNTS,d0
        bhs.s .done
        move.w ui_rmb_page(pc),d1
        bsr ui_press_live
        bne.s .done
        cmpi.w #UI_PAGE_PLACE,d0
        beq.s .turn
        andi.w #FREE_PAGES,d0
        beq.s .close
        tst.w overview_active-module_start(a5)
        beq.s .view
        move.w #UI_REQUEST_KEY<<8|RAW_V,ui_request-module_start(a5)
        rts
.view:  andi.w #UI_PAGE_CHOOSE,d0
        bne.s .close
        lea ui_text_look(pc),a0
        bra ui_say
.close: move.w #UI_REQUEST_KEY<<8|RAW_ESC,ui_request-module_start(a5)
.done:  rts
.turn:  move.w #UI_REQUEST_KEY<<8|RAW_T,ui_request-module_start(a5)
        rts

; A track was opened: at the end of the pass the camera goes to the third person
; view of the start piece. Before the view is compared, so it costs one render.
free_open_step:
        tst.w free_open_due-module_start(a5)
        beq .done
        tst.w model_valid-module_start(a5)
        beq .done
        clr.w free_open_due-module_start(a5)
        lea model_geometry(pc),a0       ; the first row of the start piece
        moveq #0,d4
        move.w (a0),d4
        moveq #0,d0
        move.w 6(a0),d0
        add.l d0,d4
        lsr.l #1,d4                     ; D4 middle of the road, X
        moveq #0,d5
        move.w 4(a0),d5
        moveq #0,d0
        move.w 10(a0),d0
        add.l d0,d5
        lsr.l #1,d5                     ; D5 and Z
        moveq #0,d0
        move.w 2(a0),d0
        moveq #0,d1
        move.w 8(a0),d1
        add.l d1,d0
        lsr.l #1,d0
        addi.l #FREE_OPEN_HIGH,d0
        move.l d0,free_y-module_start(a5)
        ; A row is 384 wide square to the map and 271 on a diagonal. The signs
        ; of its sides give the normalized Q14 right axis.
        move.w 6(a0),d1
        sub.w (a0),d1
        move.w 10(a0),d2
        sub.w 4(a0),d2
        move.w #16384,d3
        tst.w d1
        beq.s .axis
        tst.w d2
        beq.s .axis
        move.w #11585,d3
.axis:  bsr.s .signed
        exg d1,d2
        bsr.s .signed
        exg d1,d2                       ; D1 right X, D2 right Z, both Q14
        move.w d2,d0
        muls.w #FREE_OPEN_BACK,d0
        asr.l #7,d0
        asr.l #7,d0
        add.l d4,d0
        move.l d0,free_x-module_start(a5)
        move.w d1,d0
        muls.w #FREE_OPEN_BACK,d0
        asr.l #7,d0
        asr.l #7,d0
        neg.l d0
        add.l d5,d0
        move.l d0,free_z-module_start(a5)
        ext.l d1
        neg.w d2
        ext.l d2
        bsr free_angle
        move.w d0,free_yaw-module_start(a5)
        move.w #FREE_OPEN_PITCH,free_pitch-module_start(a5)
.done:  rts
; D1 -> D3 with the sign of D1, 0 for 0.
.signed:
        tst.w d1
        beq.s .out
        bmi.s .minus
        move.w d3,d1
        rts
.minus: move.w d3,d1
        neg.w d1
.out:   rts

; The view into the camera variables of the render.
free_camera_apply:
        move.l free_x(pc),camera_x-module_start(a5)
        move.l free_y(pc),camera_y-module_start(a5)
        move.l free_z(pc),camera_z-module_start(a5)
        move.w free_yaw(pc),d0
        bsr free_sin
        neg.w d0
        move.w d0,camera_right_z-module_start(a5)
        move.w free_yaw(pc),d0
        addi.w #FREE_QUARTER,d0
        bsr free_sin
        move.w d0,camera_right_x-module_start(a5)
        move.w free_pitch(pc),d0
        bsr free_sin
        move.l d0,view_pitch_sin-module_start(a5)
        move.w free_pitch(pc),d0
        addi.w #FREE_QUARTER,d0
        bsr free_sin
        move.l d0,view_pitch_cos-module_start(a5)
        rts

; D1 cosine part, D2 sine part. D0 = the angle that lies closest to them.
; Once a look, in a render, so a plain scan of the turn is enough.
free_angle:
        movem.l d3-d6,-(sp)
        moveq #0,d5
        bset #31,d5
        moveq #0,d6
        move.w #FREE_TURN_MASK,d3
.scan:  move.w d3,d0
        bsr free_sin
        muls.l d2,d0
        move.l d0,d4
        move.w d3,d0
        addi.w #FREE_QUARTER,d0
        bsr free_sin
        muls.l d1,d0
        add.l d4,d0
        cmp.l d5,d0
        ble.s .next
        move.l d0,d5
        move.w d3,d6
.next:  dbra d3,.scan
        move.w d6,d0
        movem.l (sp)+,d3-d6
        rts

; D0 angle -> D0.l sine, Q14. Uses A0.
free_sin:
        move.l d1,-(sp)
        move.w d0,d1
        andi.w #FREE_HALF-1,d1
        cmpi.w #FREE_QUARTER,d1
        bls.s .quarter
        subi.w #FREE_HALF,d1
        neg.w d1
.quarter:
        add.w d1,d1
        lea free_table(pc),a0
        move.w (a0,d1.w),d1
        ext.l d1
        btst #FREE_HALF_BIT,d0
        beq.s .plus
        neg.l d1
.plus:  move.l d1,d0
        move.l (sp)+,d1
        rts

; While the camera moves: the road edges of every piece and the map outline.
; The surface is cleared and the view set up. The ghost of an older track is
; not in the model, so it comes from its own rows.
free_wire_draw:
        move.w #15,map_boundary_color-module_start(a5)
        clr.w render_piece-module_start(a5)
.piece: move.w render_piece(pc),d0
        cmp.w editor_track+SCTR_COUNT(pc),d0
        bhs.s .ahead
        cmpi.w #2,building_mode-module_start(a5)
        bne.s .model
        tst.w building_candidate_count-module_start(a5)
        beq.s .model
        cmp.w building_selected(pc),d0
        bne.s .model
        lea building_geometry(pc),a0
        move.w building_rows(pc),d1
        bra.s .rows
.model: move.w d0,d1
        add.w d1,d1
        lea model_row_counts(pc),a0
        move.w (a0,d1.w),d1
        mulu.w #EDITOR_GEOMETRY_STRIDE,d0
        lea model_geometry(pc),a0
        adda.w d0,a0
.rows:  bsr free_wire_rows
        addq.w #1,render_piece-module_start(a5)
        bra.s .piece
.ahead: cmpi.w #1,building_mode-module_start(a5)
        bne.s .done
        tst.w building_candidate_count-module_start(a5)
        beq.s .done
        lea building_geometry(pc),a0
        move.w building_rows(pc),d1
        bsr free_wire_rows
.done:  clr.l wire_y-module_start(a5)
        rts

; A0 first row, D1 rows. Rows are two vertices of three words each.
free_wire_rows:
        subq.w #2,d1
        bmi.s .done
        move.w d1,wire_count-module_start(a5)
        move.l a0,wire_row-module_start(a5)
.row:   movea.l wire_row(pc),a0
        bsr free_wire_line
        movea.l wire_row(pc),a0
        addq.l #6,a0
        bsr free_wire_line
        addi.l #12,wire_row-module_start(a5)
        subq.w #1,wire_count-module_start(a5)
        bpl.s .row
.done:  rts

; A0 first vertex of a line. The second is the next row's same edge.
free_wire_line:
        move.l a0,wire_vertex-module_start(a5)
        lea map_boundary_view(pc),a1
        bsr free_wire_point
        movea.l wire_vertex(pc),a0
        adda.w #12,a0
        bsr free_wire_point
        bsr map_boundary_near
        tst.w d0
        beq.s .next
        lea map_boundary_view(pc),a0
        lea map_boundary_screen(pc),a1
        moveq #1,d7
.point: move.l (a0),d0
        move.l 8(a0),d1
        move.l 4(a0),d2
        muls.l #FREE_FOCAL,d0
        divs.l d2,d0
        addi.l #VIEW_CX,d0
        muls.l #FREE_FOCAL,d1
        divs.l d2,d1
        addi.l #VIEW_CY,d1
        move.l d0,(a1)+
        move.l d1,(a1)+
        adda.w #12,a0
        dbra d7,.point
        bsr map_boundary_clip
.next:  rts

free_wire_point:
        moveq #0,d0
        move.w (a0),d0
        moveq #0,d1
        move.w 4(a0),d1
        moveq #0,d2
        move.w 2(a0),d2
        move.l d2,wire_y-module_start(a5)
        bra map_boundary_project

; These six are view inputs: refresh.s compares them. free_wire comes first.
free_wire: dc.w 0
free_yaw: dc.w 0
free_pitch: dc.w 0
free_x: dc.l 0
free_y: dc.l 0
free_z: dc.l 0
free_open_due: dc.w 0
view_pitch_cos: dc.l 0
view_pitch_sin: dc.l 0
free_drag: dc.w 0
free_last_x: dc.w 0
free_last_y: dc.w 0
free_time: dc.l 0
free_rest: dc.l 0
wire_row: dc.l 0
wire_vertex: dc.l 0
wire_y: dc.l 0
wire_count: dc.w 0
free_table:
        dc.w 0,201,402,603,804,1005,1205,1406
        dc.w 1606,1806,2006,2205,2404,2603,2801,2999
        dc.w 3196,3393,3590,3786,3981,4176,4370,4563
        dc.w 4756,4948,5139,5330,5520,5708,5897,6084
        dc.w 6270,6455,6639,6823,7005,7186,7366,7545
        dc.w 7723,7900,8076,8250,8423,8595,8765,8935
        dc.w 9102,9269,9434,9598,9760,9921,10080,10238
        dc.w 10394,10549,10702,10853,11003,11151,11297,11442
        dc.w 11585,11727,11866,12004,12140,12274,12406,12537
        dc.w 12665,12792,12916,13039,13160,13279,13395,13510
        dc.w 13623,13733,13842,13949,14053,14155,14256,14354
        dc.w 14449,14543,14635,14724,14811,14896,14978,15059
        dc.w 15137,15213,15286,15357,15426,15493,15557,15619
        dc.w 15679,15736,15791,15843,15893,15941,15986,16029
        dc.w 16069,16107,16143,16176,16207,16235,16261,16284
        dc.w 16305,16324,16340,16353,16364,16373,16379,16383
        dc.w 16384
