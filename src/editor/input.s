; Queue keyboard and joystick transitions for the editor.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Ordered keyboard ISR and VBL joystick transitions. No model work in ISRs.
; Indices 0..95 are raw keys; 96 holds U/D/L/R/fire, active high.
EDITOR_INPUT_QUEUE equ $23000
EDITOR_INPUT_MASK equ $7fe
editor_input_keys equ $23800
editor_input_captured equ $23880
editor_input_suppressed equ $23900
editor_input_start:
        move.w sr,-(sp)
        ori.w #$0700,sr
        clr.w editor_input_head-module_start(a5)
        clr.w editor_input_tail-module_start(a5)
        clr.w editor_input_blocked-module_start(a5)
        clr.l editor_input_overflows-module_start(a5)
        lea editor_input_keys(a5),a0
        moveq #95,d0
.clear: clr.l (a0)+
        dbra d0,.clear
        move.w #1,editor_input_enabled-module_start(a5)
        move.w (sp)+,sr
        rts

; At original $f05e, the state table is updated and D0 is the raw index.
; Preserve registers, then execute the original keyboard handshake.
editor_keyboard:
        movem.l d0-d3/a0-a2/a5,-(sp)
        move.w sr,-(sp)
        ori.w #$0700,sr
        lea module_start(pc),a5
        tst.w editor_input_enabled-module_start(a5)
        beq.s .done
        cmpi.w #96,d0
        bhs.s .done
        lea $ead6.l,a0
        moveq #0,d1
        move.b (a0,d0.w),d1
        bsr editor_input_capture
.done:
        move.w (sp)+,sr
        movem.l (sp)+,d0-d3/a0-a2/a5
        jmp $f06a

editor_input_vbl:
        lea module_start(pc),a5
        tst.w editor_input_enabled-module_start(a5)
        beq.s .done
        bsr editor_read_joystick
        btst #7,$bfe001
        bne.s .fire
        bset #4,d0
.fire:
        move.w d0,d1
        moveq #96,d0
        move.w sr,-(sp)
        ori.w #$0700,sr
        bsr editor_input_capture
        move.w (sp)+,sr
.done: rts

; D0 index, D1 value. Interrupts masked for both producers and consumer.
editor_input_capture:
        lea editor_input_captured(a5),a0
        cmp.b (a0,d0.w),d1
        beq.s .done
        move.b d1,(a0,d0.w)
        tst.w editor_input_blocked-module_start(a5)
        bne.s .done
        move.w editor_input_head(pc),d2
        move.w d2,d3
        addq.w #2,d3
        andi.w #EDITOR_INPUT_MASK,d3
        cmp.w editor_input_tail(pc),d3
        beq.s .overflow
        lea EDITOR_INPUT_QUEUE(a5),a0
        move.b d0,(a0,d2.w)
        move.b d1,1(a0,d2.w)
        move.w d3,editor_input_head-module_start(a5)
.done: rts
.overflow:
        ; An exceptional burst drops pending commands and requires neutral
        ; controls before accepting actions again, rather than leaving a hold.
        move.w #1,editor_input_blocked-module_start(a5)
        addq.l #1,editor_input_overflows-module_start(a5)
        rts

editor_input_next:
        movem.l d0-d3/a0-a1,-(sp)
        move.w sr,-(sp)
        ori.w #$0700,sr
        tst.w editor_input_blocked-module_start(a5)
        bne.s .blocked
        move.w editor_input_tail(pc),d2
        cmp.w editor_input_head(pc),d2
        beq.s .done
        lea EDITOR_INPUT_QUEUE(a5),a0
        moveq #0,d0
        move.b (a0,d2.w),d0
        move.b 1(a0,d2.w),d1
        lea editor_input_suppressed(a5),a1
        and.b d1,(a1,d0.w)
        move.b (a1,d0.w),d3
        not.b d3
        and.b d3,d1
        lea editor_input_keys(a5),a1
        move.b d1,(a1,d0.w)
        addq.w #2,d2
        andi.w #EDITOR_INPUT_MASK,d2
        move.w d2,editor_input_tail-module_start(a5)
.done:
        move.w (sp)+,sr
        movem.l (sp)+,d0-d3/a0-a1
        rts
.blocked:
        move.w editor_input_head(pc),editor_input_tail-module_start(a5)
        lea editor_input_keys(a5),a0
        moveq #31,d0
.clear: clr.l (a0)+
        dbra d0,.clear
        lea editor_input_captured(a5),a0
        moveq #96,d0
.neutral:
        tst.b (a0)+
        bne.s .done
        dbra d0,.neutral
        lea editor_input_suppressed(a5),a0
        moveq #31,d0
.reset: clr.l (a0)+
        dbra d0,.reset
        clr.w editor_input_blocked-module_start(a5)
        bra.s .done

editor_sample_directions:
        moveq #0,d0
        move.b editor_input_keys+96(a5),d0
        andi.w #15,d0
        cmpi.b #$b3,editor_input_keys+$4c(a5)
        bne.s .down
        bset #0,d0
.down:  cmpi.b #$b3,editor_input_keys+$4d(a5)
        bne.s .left
        bset #1,d0
.left:  cmpi.b #$b3,editor_input_keys+$4f(a5)
        bne.s .right
        bset #2,d0
.right: cmpi.b #$b3,editor_input_keys+$4e(a5)
        bne.s .done
        bset #3,d0
.done:  rts

; Consume the current chord, without waiting through later ordered events.
; Suppress its held keys until their own release. Thus a held Fire plus a
; direction cannot confirm the next dialog, and overlapping typing survives.
editor_release:
        movem.l d0-d1/a0-a1,-(sp)
        lea editor_input_keys(a5),a0
        lea editor_input_suppressed(a5),a1
        moveq #96,d0
.keys:
        move.b (a0),d1
        or.b d1,(a1)+
        clr.b (a0)+
        dbra d0,.keys
        clr.w editor_directions-module_start(a5)
        clr.w building_fire-module_start(a5)
        clr.w building_arrow-module_start(a5)
        clr.w camera_buttons-module_start(a5)
        clr.w overview_key-module_start(a5)
        movem.l (sp)+,d0-d1/a0-a1
        rts

editor_input_enabled: dc.w 0
editor_input_head: dc.w 0
editor_input_tail: dc.w 0
editor_input_blocked: dc.w 0
editor_input_overflows: dc.l 0
