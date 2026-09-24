; Receive, validate and retain incoming link frames.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Bounded SCR receive state, 68000, single main-loop owner, module base a5.
; No IRQ access, hardware I/O, allocation or game writes. CRC/framing is
; owned by scr25_push; receive accepts ONLY its complete validated frame.
; Caller enforces live-session timeout and monotonic time BEFORE receive.
; Outgoing queue/ACK consumption and clock policy are separate work.
;
; Every entry preserves all registers except d0 (boolean result); CCR undefined.
; All frame, output and module pointers must be even. No buffer aliasing.
; Wire generation/sample offsets are +2/+6.
RX_QUEUE        equ $44c0           ; eight 8-byte retained events
RX_STATE        equ $4500           ; 64 bytes; queue + state contiguous
RX_GENERATION   equ RX_STATE
RX_VALID        equ RX_STATE+4
RX_FAILED       equ RX_STATE+6      ; 1 changed duplicate, 2 sequence gap
RX_LAST_TIME    equ RX_STATE+8
RX_LATEST       equ RX_STATE+12     ; complete 32-byte frame
RX_EVENT        equ RX_STATE+44     ; number, kind, zero word, data long
RX_READ         equ RX_STATE+52     ; word slot 0..7
RX_COUNT        equ RX_STATE+54     ; word 0..8

; d0.l = externally agreed nonzero generation, d3.l = initial service time.
; Caller has stopped the old owner and discarded old serial/parser bytes.
; A zero generation is rejected without mutation.
scr20_rx_init:
        tst.l d0
        beq.s .return
        movem.l d1/a0,-(sp)
        lea RX_QUEUE(a5),a0
        moveq #31,d1
.clear: clr.l (a0)+
        dbra d1,.clear
        move.l d0,RX_GENERATION(a5)
        move.l d3,RX_LAST_TIME(a5)
        moveq #1,d0
        movem.l (sp)+,d1/a0
.return:rts

; a1 = CRC-validated 32-byte frame; d3.l = externally checked service time.
; Returns 1 for fresh accepted state (including inbox backpressure), else 0.
; RX_EVENT.number is the ACK to publish: retention, never application.
scr20_rx_receive:
        movem.l d1-d2/a0-a2,-(sp)
        moveq #0,d0
        tst.w RX_FAILED(a5)
        bne.w .return
        tst.l RX_GENERATION(a5)
        beq.w .return
; Canonical semantics checked before any state/ACK mutation.
        move.b 25(a1),d1
        cmpi.b #8,d1
        bhi.w .return
        tst.b d1
        bne.s .generation
        tst.b 23(a1)
        bne.w .return
        tst.l 26(a1)
        bne.w .return
.generation:
        move.l 2(a1),d2
        cmp.l RX_GENERATION(a5),d2
        bne.w .return
        tst.w RX_VALID(a5)
        beq.s .event
        move.w 6(a1),d2
        sub.w RX_LATEST+6(a5),d2
        tst.w d2
        ble.w .return               ; reject equal/old/half-range
.event:
        tst.b d1
        beq.w .accept
        move.b 23(a1),d2
        cmp.b RX_EVENT(a5),d2
        bne.s .new_event
        cmp.b RX_EVENT+1(a5),d1
        bne.s .changed
        move.l 26(a1),d2
        cmp.l RX_EVENT+4(a5),d2
        beq.s .accept               ; exact duplicate: no second enqueue
.changed:
        move.w #1,RX_FAILED(a5)
        bra.s .return
.new_event:
        move.b RX_EVENT(a5),d1
        addq.b #1,d1                ; event number wraps 255 -> 0
        cmp.b d1,d2
        beq.s .retain
        move.w #2,RX_FAILED(a5)
        bra.s .return
.retain:
        cmpi.w #8,RX_COUNT(a5)
        beq.s .accept              ; full inbox: old ACK, fresh pose allowed
        move.w RX_READ(a5),d1
        add.w RX_COUNT(a5),d1
        andi.w #7,d1
        lsl.w #3,d1
        lea RX_QUEUE(a5),a0
        adda.w d1,a0
        move.b 23(a1),(a0)
        move.b 25(a1),1(a0)
        clr.w 2(a0)
        move.l 26(a1),4(a0)
        move.l (a0),RX_EVENT(a5)
        move.l 4(a0),RX_EVENT+4(a5)
        addq.w #1,RX_COUNT(a5)
.accept:
        lea RX_LATEST(a5),a0
        movea.l a1,a2
        moveq #7,d1
.copy:  move.l (a2)+,(a0)+
        dbra d1,.copy
        move.l d3,RX_LAST_TIME(a5)
        move.w #1,RX_VALID(a5)
        moveq #1,d0
.return:
        movem.l (sp)+,d1-d2/a0-a2
        rts

; a1 = private 8-byte event output. Unchanged on failure/empty inbox.
; Retained events remain in memory after failure but cannot be applied.
scr20_rx_take:
        movem.l d1/a0,-(sp)
        moveq #0,d0
        tst.w RX_FAILED(a5)
        bne.s .return
        tst.w RX_COUNT(a5)
        beq.s .return
        move.w RX_READ(a5),d1
        lsl.w #3,d1
        lea RX_QUEUE(a5),a0
        adda.w d1,a0
        move.l (a0),(a1)
        move.l 4(a0),4(a1)
        addq.w #1,RX_READ(a5)
        andi.w #7,RX_READ(a5)
        subq.w #1,RX_COUNT(a5)
        moveq #1,d0
.return:
        movem.l (sp)+,d1/a0
        rts
