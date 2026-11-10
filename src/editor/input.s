; Queue keyboard and joystick transitions for the editor.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Ordered keyboard ISR and VBL joystick transitions. No model work in ISRs.
; The table layout is in input-equ.i.
EDITOR_INPUT_MASK equ $7fe
editor_input_keys equ EDITOR_INPUT_STATE
editor_input_captured equ editor_input_keys+EDITOR_INPUT_BANK
editor_input_suppressed equ editor_input_keys+2*EDITOR_INPUT_BANK
editor_input_start:
        move.w sr,-(sp)
        ori.w #$0700,sr
        clr.w editor_input_head-module_start(a5)
        clr.w editor_input_tail-module_start(a5)
        clr.w editor_input_blocked-module_start(a5)
        clr.w editor_input_holdoff-module_start(a5)
        clr.l editor_input_overflows-module_start(a5)
        lea editor_input_keys(a5),a0
        moveq #EDITOR_INPUT_STATE_BYTES/4-1,d0
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
        cmpi.w #RAW_KEYS,d0
        bhs.s .done
        lea $ead6.l,a0
        moveq #0,d1
        move.b (a0,d0.w),d1
        bsr editor_input_capture
.done:
        move.w (sp)+,sr
        movem.l (sp)+,d0-d3/a0-a2/a5
        jmp $f06a.l

editor_input_vbl:
        lea module_start(pc),a5
        tst.w editor_input_enabled-module_start(a5)
        beq.s .done
        bsr ui_mouse_vbl
        bsr editor_read_joystick
        btst #7,$bfe001
        bne.s .fire
        bset #EDITOR_INPUT_FIRE,d0
.fire:
        move.w d0,d1
        moveq #EDITOR_INPUT_JOY,d0
        move.w sr,-(sp)
        ori.w #$0700,sr
        bsr editor_input_capture
        move.w (sp)+,sr
.done: rts

; After a disk access, with interrupts masked. Under WHDLoad a file access
; may give the keyboard to the system; the slave then marks every key up in
; the game's table without a keyboard interrupt. Queue the transitions the
; captured state missed, so that a key released meanwhile ends its
; suppression and its next press counts. From floppy nothing differs.
editor_input_resync:
        movem.l d0-d3/a0,-(sp)
        tst.w editor_input_enabled-module_start(a5)
        beq.s .done
        ; JOY0DAT ran on: the next count is not a movement.
        move.w #1,ui_baseline-module_start(a5)
        moveq #RAW_KEYS-1,d0
.key:   lea $ead6.l,a0
        moveq #0,d1
        move.b (a0,d0.w),d1
        bsr.s editor_input_capture
        dbra d0,.key
.done:  movem.l (sp)+,d0-d3/a0
        rts

; D0 index, D1 value. Interrupts masked for both producers and consumer.
editor_input_capture:
        lea editor_input_captured(a5),a0
        cmp.b (a0,d0.w),d1
        beq.s .done
        move.b d1,(a0,d0.w)
        ; A key or the stick takes over from the mouse.
        tst.b d1
        beq.s .queue
        move.w #1,ui_ptr_hide-module_start(a5)
.queue: tst.w editor_input_blocked-module_start(a5)
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

EDITOR_INPUT_HOLDOFF equ 12
editor_input_next:
        movem.l d0-d3/a0-a1,-(sp)
        move.w sr,-(sp)
        ori.w #$0700,sr
        tst.w editor_input_blocked-module_start(a5)
        bne.s .blocked
        tst.w editor_input_holdoff-module_start(a5)
        bne .flush
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
        moveq #EDITOR_INPUT_BANK/4-1,d0
.clear: clr.l (a0)+
        dbra d0,.clear
        lea editor_input_captured(a5),a0
        moveq #EDITOR_INPUT_ENTRIES-1,d0
.neutral:
        tst.b (a0)+
        bne.s .done
        dbra d0,.neutral
        lea editor_input_suppressed(a5),a0
        moveq #EDITOR_INPUT_BANK/4-1,d0
.reset: clr.l (a0)+
        dbra d0,.reset
        clr.w editor_input_blocked-module_start(a5)
        bra.s .done
; A catalog scan just ended. The first poll comes after the list is published,
; and the flush repeats for EDITOR_INPUT_HOLDOFF polls, because the keyboard
; hands over its backlog only after the masked spans end. Dropped releases
; never reach the loop above, so suppressed must equal captured: OR would keep
; a key released during the scan suppressed and swallow its next press. A key
; still held stays suppressed until its own release.
.flush:
        subq.w #1,editor_input_holdoff-module_start(a5)
        move.w editor_input_head(pc),editor_input_tail-module_start(a5)
        lea editor_input_keys(a5),a0
        moveq #EDITOR_INPUT_ENTRIES-1,d0
.key:
        clr.b (a0)
        move.b EDITOR_INPUT_BANK(a0),2*EDITOR_INPUT_BANK(a0)
        addq.l #1,a0
        dbra d0,.key
        bra.s .done

; After a handler pass. Z clear: the next queued event gets its pass before this
; frame, so taps during a slow render do not wait for a frame each. An event
; that may change the track waits for a frame of its own, and acts on what the
; frame shows. Releases never stop the drain.
editor_input_more:
        tst.w editor_input_blocked-module_start(a5)
        bne.s .stop
        tst.w editor_input_holdoff-module_start(a5)
        bne.s .stop
        move.w building_mode(pc),d1
        cmp.w editor_pass_mode(pc),d1
        bne.s .stop
        move.w editor_input_tail(pc),d1
        cmp.w editor_input_head(pc),d1
        beq.s .stop
        lea EDITOR_INPUT_QUEUE(a5),a0
        move.b 1(a0,d1.w),d2
        beq.s .more
        move.b (a0,d1.w),d1
        cmpi.b #EDITOR_INPUT_JOY,d1
        bne.s .key
        btst #EDITOR_INPUT_FIRE,d2
        bne.s .stop
        bra.s .more
.key:   lea editor_commit_keys(pc),a0
.scan:  move.b (a0)+,d0
        beq.s .more
        cmp.b d0,d1
        bne.s .scan
.stop:  moveq #0,d0
        rts
.more:  moveq #1,d0
        rts
; Space, Backspace, Return, Esc, U, R, N, L, T, F1, and the held camera keys
; W, S, A, D, Q, Z: a tap must still be down when the pass reads it.
editor_commit_keys:
        dc.b RAW_SPACE,RAW_BS,RAW_RETURN,RAW_ESC,RAW_U,RAW_R,RAW_N,RAW_L,RAW_T,RAW_F1
        dc.b RAW_W,RAW_S,RAW_A,RAW_D,RAW_Q,RAW_Z,0
        even

editor_sample_directions:
        moveq #0,d0
        move.b editor_input_keys+EDITOR_INPUT_JOY(a5),d0
        andi.w #15,d0
        cmpi.b #KEY_DOWN,editor_input_keys+$4c(a5)
        bne.s .down
        bset #0,d0
.down:  cmpi.b #KEY_DOWN,editor_input_keys+$4d(a5)
        bne.s .left
        bset #1,d0
.left:  cmpi.b #KEY_DOWN,editor_input_keys+$4f(a5)
        bne.s .right
        bset #2,d0
.right: cmpi.b #KEY_DOWN,editor_input_keys+$4e(a5)
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
        moveq #EDITOR_INPUT_ENTRIES-1,d0
.keys:
        move.b (a0),d1
        or.b d1,(a1)+
        clr.b (a0)+
        dbra d0,.keys
        clr.w editor_directions-module_start(a5)
        clr.w building_fire-module_start(a5)
        clr.w building_arrow-module_start(a5)
        clr.w overview_key-module_start(a5)
        movem.l (sp)+,d0-d1/a0-a1
        rts

; D4 the arrow held now (0 none), A0 the pair {arrow, repeat time} it is
; compared with. D0 (flags set) = 1 when it steps now: a new arrow at once, a
; held one after EDITOR_REPEAT_DELAY ticks, then every EDITOR_REPEAT_RATE.
; The other registers are kept.
editor_arrow_repeat:
        cmp.w (a0),d4
        bne.s .new
        tst.w d4
        beq.s .no
        move.w editor_ticks(pc),d0
        sub.w 2(a0),d0
        bmi.s .no
        cmpi.w #EDITOR_REPEAT_RATE,d0
        blo.s .no
        move.w editor_ticks(pc),2(a0)
        moveq #1,d0
        rts
.new:   move.w d4,(a0)
        move.w editor_ticks(pc),d0
        addi.w #EDITOR_REPEAT_DELAY-EDITOR_REPEAT_RATE,d0
        move.w d0,2(a0)
        tst.w d4
        beq.s .no
        moveq #1,d0
        rts
.no:    moveq #0,d0
        rts

editor_input_enabled: dc.w 0
editor_input_head: dc.w 0
editor_input_tail: dc.w 0
editor_input_blocked: dc.w 0
editor_input_holdoff: dc.w 0
editor_pass_mode: dc.w 0
building_preview_due: dc.w 0
editor_input_overflows: dc.l 0
