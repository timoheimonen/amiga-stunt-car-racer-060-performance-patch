; Place the start line of a new track on the map.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Track Editor: a new track starts on the map. The start line takes a square and
; a heading, and the road must be able to come back to it. Nothing of the track
; moves before Place, so the page draws only the ghost of the start.
PLACE_MAP_X equ 96
PLACE_MAP_Y equ 8
PLACE_MAP_PIXELS equ 128
PLACE_LAST_CELL equ 15
PLACE_ON equ 1
PLACE_OFF equ 13
PLACE_LINES equ 7
PLACE_CELL equ 2048
RAW_T equ $14

; Keeps the track, reads where its start stands.
place_enter:
        move.w #1,place_active-module_start(a5)
        move.w #1,overview_active-module_start(a5)
        clr.w place_fire-module_start(a5)
        clr.w place_arrow-module_start(a5)
        moveq #0,d0
        move.b editor_track+71(pc),d0
        move.w d0,d1
        andi.w #PLACE_LAST_CELL,d0
        move.w d0,place_x-module_start(a5)
        lsr.w #4,d1
        move.w d1,place_z-module_start(a5)
        moveq #3,d0
        and.b editor_track+69(pc),d0
        move.w d0,place_rot-module_start(a5)
        rts

place_leave:
        tst.w place_active-module_start(a5)
        beq.s .done
        clr.w place_active-module_start(a5)
        clr.w overview_active-module_start(a5)
.done:  rts

; D0 1 and Z clear when a road can come back: 3-12 along the heading, any across.
place_valid:
        move.w place_z(pc),d0
        btst #0,place_rot+1-module_start(a5)
        beq.s .along
        move.w place_x(pc),d0
.along: subq.w #3,d0
        cmpi.w #9,d0
        bls.s .yes
        moveq #0,d0
        rts
.yes:   moveq #1,d0
        rts

; What L2 says of the place -> A0.
place_text:
        lea place_text_refused(pc),a0
        bsr.s place_valid
        beq.s .done
        lea place_text_hint(pc),a0
.done:  rts

; Writes the two bytes of the start, then the track is an ordinary one.
place_commit:
        bsr.s place_valid
        bne.s .fits
        lea place_text_refused(pc),a0
        bra ui_refuse
.fits:  move.b place_rot+1(pc),editor_track+69-module_start(a5)
        move.w place_z(pc),d0
        lsl.w #4,d0
        or.w place_x(pc),d0
        move.b d0,editor_track+71-module_start(a5)
        bsr place_leave
        move.w #1,free_open_due-module_start(a5)
        move.l ui_ms(pc),d0
        addi.l #UI_PLACE_MS,d0
        move.l d0,ui_place_end-module_start(a5)
        bra editing_changed

place_turn:
        addq.w #1,place_rot-module_start(a5)
        andi.w #3,place_rot-module_start(a5)
        rts

; A press on the view: a square of the map.
place_click:
        move.w ui_press_x(pc),d0
        subi.w #PLACE_MAP_X,d0
        cmpi.w #PLACE_MAP_PIXELS,d0
        bhs.s .off
        move.w ui_press_y(pc),d1
        subi.w #PLACE_MAP_Y,d1
        cmpi.w #PLACE_MAP_PIXELS,d1
        bhs.s .off
        lsr.w #3,d0
        move.w d0,place_x-module_start(a5)
        lsr.w #3,d1
        moveq #PLACE_LAST_CELL,d0
        sub.w d1,d0
        move.w d0,place_z-module_start(a5)
        rts
.off:   suba.l a0,a0
        bra ui_refuse

; The keys of the page. A stick moves the start, Fire held turns it with the
; sideways move, and a short Fire places it when it is let go.
place_keys:
        cmpi.b #$b3,editor_input_keys+$36(a5)       ; N
        beq.s .new
        cmpi.b #$b3,editor_input_keys+$45(a5)       ; Esc
        beq.s .exit
        cmpi.b #$b3,editor_input_keys+RAW_T(a5)
        beq.s .turn
        cmpi.b #$b3,editor_input_keys+UI_RAW_SPACE(a5)
        beq.s .space
        move.w editor_directions(pc),d4
        btst #UI_FIRE_BIT,editor_input_keys+96(a5)
        bne.s .fire
        tst.w place_fire-module_start(a5)
        beq .steer
        clr.w place_fire-module_start(a5)
        tst.w place_turned-module_start(a5)
        bne .steer
        bra place_commit
.new:   bsr editor_release
        move.w #1,editing_prompt-module_start(a5)
        rts
.exit:  moveq #3,d0
        bra editing_request
.turn:  bsr editor_release
        bra place_turn
.space: bsr editor_release
        bra place_commit
.fire:  tst.w place_fire-module_start(a5)
        bne.s .held
        move.w #1,place_fire-module_start(a5)
        clr.w place_turned-module_start(a5)
        move.w d4,place_arrow-module_start(a5)
        rts
.held:  cmp.w place_arrow(pc),d4
        beq .done
        move.w d4,place_arrow-module_start(a5)
        btst #3,d4
        bne.s .right
        btst #2,d4
        beq .done
        subq.w #2,place_rot-module_start(a5)
.right: move.w #1,place_turned-module_start(a5)
        bra place_turn
.steer: cmp.w place_arrow(pc),d4
        bne.s .fresh
        tst.w d4
        beq .done
        move.w editor_ticks(pc),d0
        sub.w place_repeat(pc),d0
        bmi.s .done
        cmpi.w #8,d0
        blo.s .done
        move.w editor_ticks(pc),place_repeat-module_start(a5)
        bra.s .move
.fresh: move.w d4,place_arrow-module_start(a5)
        move.w editor_ticks(pc),d0
        addi.w #12,d0
        move.w d0,place_repeat-module_start(a5)
        tst.w d4
        beq.s .done
.move:  move.w place_x(pc),d0
        move.w place_z(pc),d1
        btst #0,d4
        beq.s .down
        addq.w #1,d1
.down:  btst #1,d4
        beq.s .left
        subq.w #1,d1
.left:  btst #2,d4
        beq.s .across
        subq.w #1,d0
.across:
        btst #3,d4
        beq.s .clamp
        addq.w #1,d0
.clamp: cmpi.w #PLACE_LAST_CELL,d0
        bhi.s .z
        move.w d0,place_x-module_start(a5)
.z:     cmpi.w #PLACE_LAST_CELL,d1
        bhi.s .done
        move.w d1,place_z-module_start(a5)
.done:  rts

; In the render, after the grid: the square, its heading and the band.
place_draw:
        move.w #PLACE_OFF,map_boundary_color-module_start(a5)
        bsr place_valid
        beq.s .ghost
        move.w #PLACE_ON,map_boundary_color-module_start(a5)
.ghost: lea place_lines(pc),a4
        moveq #PLACE_LINES-1,d6
.line:  movem.w (a4)+,d0-d3
        bsr.s place_point
        exg d0,d2
        exg d1,d3
        bsr.s place_point
        exg d0,d2
        exg d1,d3
        bsr.s place_line
        dbra d6,.line
        move.w #PLACE_OFF,map_boundary_color-module_start(a5)
        move.l #3*PLACE_CELL,d4
        bsr.s place_band
        move.l #13*PLACE_CELL,d4
; D4 the limit along the heading: a line across the whole map.
place_band:
        btst #0,place_rot+1-module_start(a5)
        bne.s .x
        moveq #0,d0
        move.l d4,d1
        move.l #32768,d2
        move.l d4,d3
        bra.s place_line
.x:     move.l d4,d0
        moveq #0,d1
        move.l d4,d2
        move.l #32768,d3
        bra.s place_line

; D0, D1 in the square of the start -> on the map. Keeps D2, D3.
place_point:
        move.w place_rot(pc),d5
        beq.s .cell
        subq.w #1,d5
.rot:   exg d0,d1
        neg.l d1
        addi.l #PLACE_CELL,d1
        dbra d5,.rot
.cell:  move.w place_x(pc),d5
        mulu.w #PLACE_CELL,d5
        add.l d5,d0
        move.w place_z(pc),d5
        mulu.w #PLACE_CELL,d5
        add.l d5,d1
        rts

; D0, D1 to D2, D3 on the map.
place_line:
        movem.l d2-d3/d6/a4,-(sp)
        lea map_boundary_view(pc),a1
        bsr map_boundary_project
        move.l (sp),d0
        move.l 4(sp),d1
        bsr map_boundary_project
        lea map_boundary_view(pc),a0
        lea map_boundary_screen(pc),a1
        moveq #1,d7
.point: move.l (a0),(a1)+
        move.l 8(a0),(a1)+
        adda.w #12,a0
        dbra d7,.point
        bsr map_boundary_clip
        movem.l (sp)+,d2-d3/d6/a4
        rts

place_lines:
        dc.w 0,0,PLACE_CELL,0
        dc.w PLACE_CELL,0,PLACE_CELL,PLACE_CELL
        dc.w PLACE_CELL,PLACE_CELL,0,PLACE_CELL
        dc.w 0,PLACE_CELL,0,0
        dc.w 1024,1024,1024,6144
        dc.w 1024,6144,100,4800
        dc.w 1024,6144,1948,4800

place_text_name: dc.b 'Start line',0
place_text_hint: dc.b 'Click a square. Right click turns the start.',0
place_text_refused: dc.b 'Too close to the edge: no road back.',0
        even
; The view compares these four words: keep them together.
place_active: dc.w 0
place_x: dc.w 0
place_z: dc.w 0
place_rot: dc.w 0
place_fire: dc.w 0
place_turned: dc.w 0
place_arrow: dc.w 0
place_repeat: dc.w 0
