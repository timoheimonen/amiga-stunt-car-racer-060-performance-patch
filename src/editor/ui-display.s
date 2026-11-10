; Split the display between the 3D view and the editor bar.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Track Editor bar: the display split. The 3D view shows rows 32-175 (VIEW_TOP
; to VIEW_BOTTOM-1) of its surface at the top of the screen. Below it a copper
; tail shows the bar, a bitmap of its own in Chip. The original list runs to
; $e82e, where three moves jump to the tail: the copper reads them only at the
; top of a frame, so they change only after line 250 or, going back, after the
; top of the list.
COPPER_LIST equ $e74e
COPPER_LIST_BYTES equ 236
COPPER_SPRITES equ $e7f0
COPPER_JUMP equ $e82e
UI_CHIP_BAR equ $6000
UI_CHIP_TAIL equ $8400
UI_CHIP_SPRITE equ $8600
UI_BAR_BYTES equ 8800
UI_NULL_SPRITE equ $f4b4
UI_FIRST_SAFE_LINE equ 251
UI_LAST_RESTORE_LINE equ 240

; Beam line in D0.
ui_vpos:
        move.l $dff004,d0
        lsr.l #8,d0
        andi.w #$1ff,d0
        rts

ui_display_enter:
        movem.l d0-d3/a0-a2,-(sp)
        movea.l 28(a5),a2
        ; Panel colour: plane 0 set, the others clear.
        lea UI_CHIP_BAR(a2),a0
        move.l a0,ui_bar_target-module_start(a5)
        move.w #UI_BAR_BYTES/16-1,d0
.panel: move.l #-1,(a0)+
        dbra d0,.panel
        move.w #UI_BAR_BYTES/16*3-1,d0
.clear: clr.l (a0)+
        dbra d0,.clear
        lea ui_bar_roles(pc),a0
        move.l a0,ui_bar_target+8-module_start(a5)
        lea ui_bar_roles_red(pc),a0
        move.l a0,ui_bar_target_red+8-module_start(a5)
        move.l ui_bar_target(pc),ui_bar_target_red-module_start(a5)
        lea ui_bar_roles_green(pc),a0
        move.l a0,ui_bar_target_green+8-module_start(a5)
        move.l ui_bar_target(pc),ui_bar_target_green-module_start(a5)
        bsr ui_status_reset
        bsr ui_paint_reset
        bsr ui_mouse_enter
        lea UI_CHIP_SPRITE(a2),a0
        move.l a0,d0
        move.w d0,COPPER_SPRITES+4
        swap d0
        move.w d0,COPPER_SPRITES
        lea COPPER_SPRITES+8.l,a0
        moveq #6,d1
.null:  clr.w (a0)
        move.w #UI_NULL_SPRITE,4(a0)
        addq.l #8,a0
        dbra d1,.null
        ; Tail: display off for one line, the bar's pointers and colours, on.
        lea UI_CHIP_TAIL(a2),a1
        move.w #$cbe1,d1
        tst.b video_ntsc(pc)
        beq.s .pal
        move.w #$bbe1,d1
.pal:   move.w d1,(a1)+
        move.w #$fffe,(a1)+
        move.l #$01000200,(a1)+
        move.l #$01800000,(a1)+
        lea UI_CHIP_BAR(a2),a0
        move.l a0,d0
        moveq #3,d2
        move.w #$00e0,d3
.planes:
        swap d0
        move.w d3,(a1)+
        move.w d0,(a1)+
        swap d0
        addq.w #2,d3
        move.w d3,(a1)+
        move.w d0,(a1)+
        addq.w #2,d3
        addi.l #UI_BAR_BYTES/4,d0
        dbra d2,.planes
        lea ui_bar_palette+2(pc),a0
        moveq #14,d2
        move.w #$0182,d3
.colour:
        move.w d3,(a1)+
        move.w (a0)+,(a1)+
        addq.w #2,d3
        dbra d2,.colour
        addi.w #$0100,d1
        move.w d1,(a1)+
        move.w #$fffe,(a1)+
        move.l #$01004200,(a1)+
        move.l #$fa01ff00,(a1)+
        move.l #$009c8010,(a1)+
        move.l #$fffffffe,(a1)+
        move.w #0,$dff1fc
        move.w #$0c00,$dff106
        move.w #$0011,$dff10c
.wait:  bsr ui_vpos
        cmpi.w #UI_FIRST_SAFE_LINE,d0
        blo.s .wait
        move.w sr,-(sp)
        ori.w #$0700,sr
        bsr ui_vpos
        cmpi.w #UI_FIRST_SAFE_LINE,d0
        bhs.s .install
        move.w (sp)+,sr
        bra.s .wait
.install:
        move.w d0,ui_enter_vpos-module_start(a5)
        lea UI_CHIP_TAIL(a2),a0
        move.l a0,d0
        lea COPPER_JUMP.l,a1
        swap d0
        move.w #$0084,(a1)+
        move.w d0,(a1)+
        swap d0
        move.w #$0086,(a1)+
        move.w d0,(a1)+
        move.l #$008a0000,(a1)
        move.w (sp)+,sr
        move.w #$8020,$dff096
        movem.l (sp)+,d0-d3/a0-a2
        rts

; Puts the original 236 bytes back. The sprite registers would keep showing
; their last words, so they go to zero with the DMA off.
ui_display_exit:
        movem.l d0/a0-a1,-(sp)
.wait:  bsr ui_vpos
        cmpi.w #3,d0
        blo.s .wait
        cmpi.w #UI_LAST_RESTORE_LINE,d0
        bhi.s .wait
        move.w sr,-(sp)
        ori.w #$0700,sr
        bsr ui_vpos
        cmpi.w #3,d0
        blo.s .again
        cmpi.w #UI_LAST_RESTORE_LINE,d0
        bls.s .restore
.again: move.w (sp)+,sr
        bra.s .wait
.restore:
        move.w d0,ui_exit_vpos-module_start(a5)
        lea SAVED_COPPER_FULL(a5),a0
        lea COPPER_LIST.l,a1
        move.w #COPPER_LIST_BYTES,d0
        bsr storage_copy
        move.w #$0020,$dff096
        lea $dff140.l,a0
        moveq #15,d0
.sprites:
        clr.l (a0)+
        dbra d0,.sprites
        move.w (sp)+,sr
        movem.l (sp)+,d0/a0-a1
        rts

ui_bar_target: dc.l 0,UI_BAR_BYTES/4,0
ui_bar_target_red: dc.l 0,UI_BAR_BYTES/4,0
ui_bar_target_green: dc.l 0,UI_BAR_BYTES/4,0
ui_bar_roles: dc.b 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
; A red button: panel face and red ink.
ui_bar_roles_red: dc.b 0,1,1,3,4,5,10,7,8,9,10,11,12,13,14,15
ui_bar_roles_green: dc.b 0,1,2,3,4,5,11,7,11,9,10,11,12,13,14,15
ui_enter_vpos: dc.w 0
ui_exit_vpos: dc.w 0
ui_bar_palette:
        dc.w $000,$223,$345,$468,$9ab,$012,$dde,$889,$fc3,$36a,$e55,$5c6,$eb4,$000,$000,$fff
