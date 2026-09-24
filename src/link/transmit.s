; Queue outgoing link frames and reliable events.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Bounded SCR outgoing transport, 68000, single main-loop owner, base a5.
; Requires receive.s. No IRQ may access these queues or metadata.
; All entries preserve registers except d0 (boolean); CCR undefined.
; Pointers are even, private, non-aliasing. Time is unsigned milliseconds
; within one session (no uint32 wrap); caller supplies a trustworthy clock.
; This module does not repair the CIA IRQ-counter clock.
TX_QUEUE        equ $4480
TX_STATE        equ $4540
TX_READ         equ TX_STATE       ; word index
TX_COUNT        equ TX_STATE+2     ; word count
TX_NEXT         equ TX_STATE+4     ; byte, initially 1
TX_SENT         equ TX_STATE+6     ; word: head actually started
TX_SENT_AT      equ TX_STATE+8     ; long first actual start, never retry time
TX_CLOCK        equ TX_STATE+12    ; long last service time
; RX_FAILED shared sticky error: 1/2 RX, 3 overflow, 4 RX timeout,
; 5 ACK timeout, 6 backward time. State tail +16..+31 reserved/zero.

; d0 = nonzero agreed generation, d3 = initial service milliseconds.
scr20_link_init:
        bsr.w scr20_rx_init
        tst.l d0
        beq.s .return
        movem.l d1/a0,-(sp)
        lea TX_QUEUE(a5),a0
        moveq #15,d1
.queue: clr.l (a0)+
        dbra d1,.queue
        lea TX_STATE(a5),a0
        moveq #7,d1
.state: clr.l (a0)+
        dbra d1,.state
        move.b #1,TX_NEXT(a5)
        move.l d3,TX_CLOCK(a5)
        movem.l (sp)+,d1/a0
.return:rts

; d3 = service time. Must precede receive/prepare and poll even when idle.
; Failure prohibits new events, preparation and consumption on both sides.
scr20_link_service:
        move.l d1,-(sp)
        moveq #0,d0
        tst.l RX_GENERATION(a5)
        beq.s .return
        cmp.l TX_CLOCK(a5),d3
        blo.s .backward
        move.l d3,TX_CLOCK(a5)
        tst.w RX_FAILED(a5)
        bne.s .return
        move.l d3,d1
        sub.l RX_LAST_TIME(a5),d1
        cmpi.l #2000,d1
        bhs.s .rx_timeout
        tst.w TX_SENT(a5)
        beq.s .ok
        move.l d3,d1
        sub.l TX_SENT_AT(a5),d1
        cmpi.l #2000,d1
        bhs.s .ack_timeout
.ok:    moveq #1,d0
        bra.s .return
.backward:
        tst.w RX_FAILED(a5)
        bne.s .return
        move.w #6,RX_FAILED(a5)
        bra.s .return
.rx_timeout:
        move.w #4,RX_FAILED(a5)
        bra.s .return
.ack_timeout:
        move.w #5,RX_FAILED(a5)
.return:
        move.l (sp)+,d1
        rts

; d0.b = kind 1..8, a1 = four data bytes. No event number consumed on error.
scr20_tx_enqueue:
        movem.l d1/a0,-(sp)
        move.b d0,d1
        moveq #0,d0
        tst.l RX_GENERATION(a5)
        beq.s .return
        tst.w RX_FAILED(a5)
        bne.s .return
        tst.b d1
        beq.s .return
        cmpi.b #8,d1
        bhi.s .return
        cmpi.w #8,TX_COUNT(a5)
        bne.s .append
        move.w #3,RX_FAILED(a5)
        bra.s .return
.append:
        move.w TX_READ(a5),d0
        add.w TX_COUNT(a5),d0
        andi.w #7,d0
        lsl.w #3,d0
        lea TX_QUEUE(a5),a0
        adda.w d0,a0
        move.b TX_NEXT(a5),(a0)
        move.b d1,1(a0)
        clr.w 2(a0)
        move.l (a1),4(a0)
        addq.b #1,TX_NEXT(a5)
        addq.w #1,TX_COUNT(a5)
        moveq #1,d0
.return:
        movem.l (sp)+,d1/a0
        rts

; a1 = prepared canonical 32-byte frame, d3 = current service time.
; Write only event/ACK fields; caller owns generation, sample, pose and CRC.
; Can repeat/replace preparation without starting the ACK timer.
scr20_tx_prepare:
        bsr.w scr20_link_service
        tst.l d0
        beq.s .return
        movem.l d1/a0,-(sp)
        clr.b 23(a1)
        clr.b 25(a1)
        clr.l 26(a1)
        move.b RX_EVENT(a5),24(a1)
        tst.w TX_COUNT(a5)
        beq.s .done
        move.w TX_READ(a5),d1
        lsl.w #3,d1
        lea TX_QUEUE(a5),a0
        adda.w d1,a0
        move.b (a0),23(a1)
        move.b 1(a0),25(a1)
        move.l 4(a0),26(a1)
.done:  movem.l (sp)+,d1/a0
.return:rts

; a1 = immutable actually started frame, d3 = its actual start time.
; Owner drains each receipt once BEFORE receive/ACK or reusing the active
; slot; never pass a mere prepared frame. It must also observe timeouts
; at the current service time before admitting a receipt. Start may be
; older than TX_CLOCK (IRQ receipt serviced later), never later than it.
; Full head identity guards a superseded prepared event. Retry preserves
; first sent_at. Receipt delivery/ordering is the UART adapter's contract.
scr20_tx_started:
        movem.l d1/a0,-(sp)
        moveq #0,d0
        tst.w RX_FAILED(a5)
        bne.s .return
        tst.w TX_COUNT(a5)
        beq.s .return
        tst.w TX_SENT(a5)
        bne.s .return
        cmp.l TX_CLOCK(a5),d3
        bhi.s .return
        move.l 2(a1),d1
        cmp.l RX_GENERATION(a5),d1
        bne.s .return
        move.w TX_READ(a5),d1
        lsl.w #3,d1
        lea TX_QUEUE(a5),a0
        adda.w d1,a0
        move.b 23(a1),d1
        cmp.b (a0),d1
        bne.s .return
        move.b 25(a1),d1
        cmp.b 1(a0),d1
        bne.s .return
        move.l 26(a1),d1
        cmp.l 4(a0),d1
        bne.s .return
        move.l d3,TX_SENT_AT(a5)
        move.w #1,TX_SENT(a5)
        moveq #1,d0
.return:
        movem.l (sp)+,d1/a0
        rts

; a1 = CRC-validated frame, d3 = current time. Invalid/stale packets
; cannot consume ACKs. RX backpressure still permits ACK of our own head.
scr20_link_receive:
        bsr.w scr20_link_service
        tst.l d0
        beq.s .return
        bsr.w scr20_rx_receive
        tst.l d0
        beq.s .return
        tst.w TX_SENT(a5)
        beq.s .return
        movem.l d1/a0,-(sp)
        move.w TX_READ(a5),d1
        lsl.w #3,d1
        lea TX_QUEUE(a5),a0
        adda.w d1,a0
        move.b 24(a1),d1
        cmp.b (a0),d1
        bne.s .done
        addq.w #1,TX_READ(a5)
        andi.w #7,TX_READ(a5)
        subq.w #1,TX_COUNT(a5)
        clr.w TX_SENT(a5)
        clr.l TX_SENT_AT(a5)
.done:  movem.l (sp)+,d1/a0
.return:rts
