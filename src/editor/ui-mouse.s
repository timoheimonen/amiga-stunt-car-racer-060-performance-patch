; Handle the editor mouse pointer and left button.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Track Editor bar: the mouse. The VBL keeps the pointer and records one left
; press. The main loop acts on the press, so nothing here changes the track.
UI_POINTER_BYTES equ 72
UI_POINTER_ARROW equ 0
UI_POINTER_REFUSED equ 1
UI_POINTER_DRAG equ 2
UI_ORIGIN_PAL equ 60
UI_ORIGIN_NTSC equ 44
UI_MAX_X equ 319
UI_MAX_Y equ 199
UI_MS_PAL equ 20
UI_MS_NTSC equ 17
UI_REFUSED_MS equ 200
UI_PLACE_MS equ 200
UI_PAGE_MS equ 400

; A2 = Chip base. The images go to Chip with empty control words, so no sprite
; shows before the first movement.
ui_mouse_enter:
        lea UI_CHIP_SPRITE(a2),a0
        move.l a0,ui_spr-module_start(a5)
        move.l a0,ui_spr_base-module_start(a5)
        lea ui_pointer_images(pc),a1
        moveq #UI_POINTER_COUNT-1,d0
.image: clr.l (a0)+
        moveq #UI_POINTER_LINES-1,d1
.line:  move.l (a1)+,(a0)+
        dbra d1,.line
        clr.l (a0)+
        dbra d0,.image
        move.w #UI_ORIGIN_PAL,ui_origin-module_start(a5)
        move.w #UI_MS_PAL,ui_ms_step-module_start(a5)
        tst.b video_ntsc(pc)
        beq.s .pal
        move.w #UI_ORIGIN_NTSC,ui_origin-module_start(a5)
        move.w #UI_MS_NTSC,ui_ms_step-module_start(a5)
.pal:   clr.w ui_pointer_now-module_start(a5)
        clr.w ui_pointer_want-module_start(a5)
        clr.l ui_pointer_end-module_start(a5)
        move.w #1,ui_ptr_hidden-module_start(a5)
        clr.w ui_ptr_hide-module_start(a5)
        clr.w ui_press_pending-module_start(a5)
        clr.w ui_btn-module_start(a5)
        clr.w ui_rmb_up-module_start(a5)
        clr.w ui_view_told-module_start(a5)
        clr.w free_drag-module_start(a5)
        clr.w free_wire-module_start(a5)
        tst.b editor_active(pc)
        beq.s .potgo
        move.w #$ff00,$dff034
.potgo:
        move.w #2,ui_rmb_skip-module_start(a5)
        move.w #2,ui_baseline-module_start(a5)
        rts

; A5 = module_start. The vector saved all registers.
ui_mouse_vbl:
        moveq #0,d0
        move.w ui_ms_step(pc),d0
        add.l d0,ui_ms-module_start(a5)
        bsr ui_pointer_image
        move.w $dff00a,d0               ; JOY0DAT: Y high byte, X low byte
        move.w ui_joy0(pc),d1
        move.w d0,ui_joy0-module_start(a5)
        tst.w ui_baseline-module_start(a5)
        beq.s .delta
        subq.w #1,ui_baseline-module_start(a5)
        bra .buttons
.delta: move.w d0,d2
        sub.b d1,d2
        ext.w d2                        ; dx, -128..127
        lsr.w #8,d0
        lsr.w #8,d1
        sub.b d1,d0
        ext.w d0                        ; dy
        move.w d2,d1
        or.w d0,d1
        beq.s .still
        clr.w ui_ptr_hidden-module_start(a5)
        add.w d2,ui_sum_x-module_start(a5)
        add.w d0,ui_sum_y-module_start(a5)
        btst #1,ui_btn+1-module_start(a5)
        bne.s .stand
        move.w #1,ui_moved-module_start(a5)
        move.b #1,ui_yield_flag-module_start(a5)
        add.w ui_ptr_x(pc),d2
        bpl.s .x_low
        moveq #0,d2
.x_low: cmpi.w #UI_MAX_X,d2
        ble.s .x_high
        move.w #UI_MAX_X,d2
.x_high:
        move.w d2,ui_ptr_x-module_start(a5)
        add.w ui_ptr_y(pc),d0
        bpl.s .y_low
        moveq #0,d0
.y_low: cmpi.w #UI_MAX_Y,d0
        ble.s .y_high
        move.w #UI_MAX_Y,d0
.y_high:
        move.w d0,ui_ptr_y-module_start(a5)
.stand: bsr ui_pointer_place
        bra .buttons
.still: tst.w ui_ptr_hide-module_start(a5)
        beq .buttons
        clr.w ui_ptr_hide-module_start(a5)
        tst.w ui_ptr_hidden-module_start(a5)
        bne .buttons
        btst #1,ui_btn+1-module_start(a5)
        bne .buttons
        move.w #1,ui_ptr_hidden-module_start(a5)
        move.w #1,ui_moved-module_start(a5)
        movea.l ui_spr(pc),a0
        clr.l (a0)
.buttons:
        moveq #0,d2
        btst #6,$bfe001
        bne.s .left_up
        moveq #1,d2
.left_up:
        move.w $dff016,d3               ; POTINP
        btst #10,d3
        bne.s .right_up
        tst.w ui_rmb_skip-module_start(a5)
        bne.s .right_up
        addq.w #2,d2
.right_up:
        tst.w ui_rmb_skip-module_start(a5)
        beq.s .edges
        subq.w #1,ui_rmb_skip-module_start(a5)
.edges: move.w ui_btn(pc),d3
        move.w d2,ui_btn-module_start(a5)
        eor.w d2,d3
        beq.s .done
        btst #0,d3
        beq.s .right
        btst #0,d2
        beq.s .right
        bsr ui_press_take
.right: btst #1,d3
        beq.s .done
        btst #1,d2
        bne.s .right_down
        move.w #1,ui_rmb_up-module_start(a5)
        bra.s .done
.right_down:
        move.w ui_sum_x(pc),ui_rmb_sx-module_start(a5)
        move.w ui_sum_y(pc),ui_rmb_sy-module_start(a5)
        move.w ui_page(pc),ui_rmb_page-module_start(a5)
.done:
ui_mouse_vbl_end:
        rts

; Control words of the shown image from ui_ptr_x and ui_ptr_y.
ui_pointer_place:
        move.w ui_ptr_y(pc),d0
        add.w ui_origin(pc),d0          ; V = origin + y
        move.w d0,d1
        addi.w #UI_POINTER_LINES,d1     ; stop line
        move.w ui_ptr_x(pc),d2
        addi.w #$80,d2                  ; H = $80 + x
        moveq #0,d3
        lsr.w #1,d2                     ; SH0 -> X
        roxl.w #1,d3                    ; bit 0
        lsl.w #8,d0                     ; SV0-7 high byte, SV8 -> X
        bcc.s .start
        ori.w #4,d3
.start: or.b d2,d0
        lsl.w #8,d1
        bcc.s .stop
        ori.w #2,d3
.stop:  or.w d3,d1
        movea.l ui_spr(pc),a0
        move.w d0,(a0)+
        move.w d1,(a0)
        rts

; The VBL alone writes the sprite, so the main loop only asks for an image. The
; refused mark ends by itself. Before D0 is read: all it may use is scratch.
ui_pointer_image:
        move.l ui_pointer_end(pc),d0
        beq.s .wanted
        sub.l ui_ms(pc),d0
        bpl.s .wanted
        clr.l ui_pointer_end-module_start(a5)
        clr.w ui_pointer_want-module_start(a5)
.wanted:
        move.w ui_pointer_want(pc),d0
        cmp.w ui_pointer_now(pc),d0
        beq.s .done
        move.w d0,ui_pointer_now-module_start(a5)
        mulu.w #UI_POINTER_BYTES,d0
        movea.l ui_spr(pc),a1
        move.l ui_spr_base(pc),d1
        add.l d0,d1
        movea.l d1,a0
        move.l (a1),(a0)
        move.l a0,ui_spr-module_start(a5)
        move.w d1,COPPER_SPRITES+4
        swap d1
        move.w d1,COPPER_SPRITES
.done:  rts

; A press while one waits is the second click of a render: it is dropped.
ui_press_take:
        addq.l #1,ui_press_count-module_start(a5)
        tst.w ui_press_pending-module_start(a5)
        beq.s .free
        addq.l #1,ui_dropped-module_start(a5)
        rts
.free:  move.w ui_ptr_x(pc),ui_press_x-module_start(a5)
        move.w ui_ptr_y(pc),ui_press_y-module_start(a5)
        move.w ui_page(pc),ui_press_page-module_start(a5)
        move.w #1,ui_press_pending-module_start(a5)
        rts


ui_press_count: dc.l 0
ui_dropped: dc.l 0
ui_spr: dc.l 0
ui_spr_base: dc.l 0
ui_ms: dc.l 0
ui_ms_step: dc.w 0
ui_pointer_end: dc.l 0
ui_page_end: dc.l 0
ui_place_end: dc.l 0
ui_pointer_now: dc.w 0
ui_pointer_want: dc.w 0
ui_moved: dc.w 0
ui_joy0: dc.w 0
ui_baseline: dc.w 0
ui_rmb_skip: dc.w 0
ui_btn: dc.w 0
ui_sum_x: dc.w 0
ui_sum_y: dc.w 0
ui_rmb_sx: dc.w 0
ui_rmb_sy: dc.w 0
ui_rmb_page: dc.w 0
ui_rmb_up: dc.w 0
ui_ptr_x: dc.w 160
ui_ptr_y: dc.w 100
ui_ptr_hidden: dc.w 1
ui_ptr_hide: dc.w 0
ui_origin: dc.w 0
ui_press_x: dc.w 0
ui_press_y: dc.w 0
ui_press_page: dc.w 0
ui_press_pending: dc.w 0
