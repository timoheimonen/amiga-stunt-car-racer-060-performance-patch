; Per-frame link service in the race loop.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Game-loop adapter. The IRQ owns bytes and the 50 ms deadline;
; one game context owns framing, event state and whole 50 Hz pose snapshots.
SCR20_RACE_SEQUENCE equ $4600
SCR20_RACE_START_RECEIPT equ $4604
SCR20_RACE_TIME equ $4608
SCR20_RACE_ERROR equ $460c
SCR20_RACE_PHASE equ $4610
SCR20_RACE_PEER_READY equ $4612
SCR20_RACE_START_QUEUED equ $4614
SCR20_RACE_START_SEEN equ $4616
SCR20_RACE_START_AT equ $4618
SCR20_RACE_GATE_LEFT equ $461c
SCR20_RACE_END_REASON equ $461e ; 1 finish, 2 wreck, 3 leave, 4 link fault
SCR20_RACE_LOCAL_LAP equ $4624
SCR20_RACE_PEER_LAP equ $4625
SCR20_RACE_LAP_EVENTS equ $4626
SCR20_RACE_EVENT equ $4630

; $5d47e is the first call of the regular race frame. It is not reached by
; the local crane restart until the game rejoins the same frame loop.
; Finish, wreck and leave end the race through the game's own loop; only
; a link fault closes the link here (scr20-race-end.s owns the race end).
scr20_race_frame_begin:
        move.w sr,-(sp)
        movem.l d0-d7/a0-a6,-(sp)
        lea module_start(pc),a5
        tst.w SCR20_OWNER(a5)
        beq.s .legacy
        tst.w SCR20_RACE_ERROR(a5)
        bne.s .failed
        tst.w SCR20_RACE_PHASE(a5)
        bne.s .running
        bsr.w scr20_race_start_gate
        tst.l d0
        beq.s .failed
.running:
        bsr.w scr20_race_service
        tst.l d0
        beq.s .failed
        bsr.w scr20_race_dispatch
        tst.l d0
        beq.s .failed
        bsr.w scr20_race_local
        tst.l d0
        beq.s .failed
        tst.w SCR20_RACE_ERROR(a5)
        bne.s .failed
.legacy:
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        jmp $18271a.l
.failed:
        move.w #4,SCR20_RACE_END_REASON(a5)
        bsr.w scr20_race_close
        bsr.w scr20_race_screen_off
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        addq.l #8,sp           ; displaced JSR and enclosing $5d326 call
        clr.b $57c3c
        jmp $5cf40.l

; The original end of race first runs $5d674..$5d692 before its result
; and record work: cockpit sprite DMA off in the copper DMACON shadow
; ($8020 at $5d470 turned it on), fade to the end colour, clear the frame
; state byte and stop audio DMA/IRQs. Skipping it left the wheel sprites
; over the title menu. Registers are the caller's scratch.
scr20_race_screen_off:
        move.w #$20,$69ede
        move.w $23c32,d0
        jsr $6444e.l
        clr.b $5d724
        jsr $f3f0.l
        rts

; Before the first game frame, exchange numbered Ready and Start events.
; The UART IRQ continues at 20 Hz while this one-time gate waits. Join opens
; 75 ms after retaining Start; Host opens on its acknowledged Start. Measure
; the actual two-sided entry difference against a 40 ms initial bound.
scr20_race_start_gate:
        bsr.w scr20_clock_poll
        move.l d0,SCR20_RACE_TIME(a5)
        move.l d0,RX_LAST_TIME(a5)
        move.l d0,TX_CLOCK(a5)
        moveq #1,d0
        lea $4620(a5),a1
        bsr.w scr20_tx_enqueue
        tst.l d0
        beq.w .fail
        move.w #5000,SCR20_RACE_GATE_LEFT(a5)
.poll:
        bsr.w scr20_race_service
        tst.l d0
        beq.w .fail
        bsr.w scr20_race_publish
        tst.l d0
        beq.w .fail
.event:
        lea SCR20_RACE_EVENT(a5),a1
        bsr.w scr20_rx_take
        tst.l d0
        beq.s .decision
        cmpi.b #1,SCR20_RACE_EVENT+1(a5)
        bne.s .start_event
        move.w #1,SCR20_RACE_PEER_READY(a5)
        bra.s .event
.start_event:
        cmpi.b #2,SCR20_RACE_EVENT+1(a5)
        bne.w .fail
        cmpi.b #$40,SCR20_HANDOFF_ROLE(a5)
        bne.w .fail
        tst.w SCR20_RACE_PEER_READY(a5)
        beq.w .fail
        move.w #1,SCR20_RACE_START_SEEN(a5)
        move.l SCR20_RACE_TIME(a5),d0
        addi.l #75,d0
        move.l d0,SCR20_RACE_START_AT(a5)
        bra.s .event
.decision:
        tst.w SCR20_RACE_PEER_READY(a5)
        beq.s .wait
        tst.w TX_COUNT(a5)
        bne.s .wait
        cmpi.b #$80,SCR20_HANDOFF_ROLE(a5)
        bne.s .join_decision
        tst.w SCR20_RACE_START_QUEUED(a5)
        bne.s .host_open
        moveq #2,d0
        lea $4620(a5),a1
        bsr.w scr20_tx_enqueue
        tst.l d0
        beq.w .fail
        move.w #1,SCR20_RACE_START_QUEUED(a5)
        bra.s .wait
.host_open:
        move.l SCR20_RACE_TIME(a5),SCR20_RACE_START_AT(a5)
        bra.s .open
.join_decision:
        tst.w SCR20_RACE_START_SEEN(a5)
        beq.s .wait
        move.l SCR20_RACE_TIME(a5),d0
        cmp.l SCR20_RACE_START_AT(a5),d0
        blo.s .wait
.open:
        move.w #1,SCR20_RACE_PHASE(a5)
        move.l SCR20_RACE_TIME(a5),RACE_GATE_AT(a5)
        move.b $1bb20,SCR20_RACE_LOCAL_LAP(a5)
        moveq #1,d0
        rts
.wait:  jsr $57134.l
        subq.w #1,SCR20_RACE_GATE_LEFT(a5)
        bne.w .poll
.fail:  move.w #1,SCR20_RACE_ERROR(a5)
        moveq #0,d0
        rts

; Poll TOD, account for the actual TX start, then consume all received bytes.
; D0=1 for a live link, zero for a bounded fault. No game state writes.
scr20_race_service:
        bsr.w scr20_clock_poll
        move.l d0,SCR20_RACE_TIME(a5)
        move.l d0,d3
        bsr.w scr20_link_service
        tst.l d0
        beq.s .failed
        move.l SCR20_STARTS(a5),d0
        cmp.l SCR20_RACE_START_RECEIPT(a5),d0
        beq.s .bytes
        move.l d0,SCR20_RACE_START_RECEIPT(a5)
        bsr.w scr20_view_sent
        lea active(a5),a1
        move.l sent_at(a5),d3
        bsr.w scr20_tx_started
.bytes:
        moveq #0,d0
        move.b SCR20_RX_READ(a5),d0
        cmp.b SCR20_RX_WRITE(a5),d0
        beq.s .done
        lea SCR20_RING(a5),a1
        move.b (a1,d0.w),d0
        addq.b #1,SCR20_RX_READ(a5)
        lea $4200(a5),a0
        bsr.w scr25_push
        tst.l d0
        beq.s .bytes
        lea $4222(a5),a1      ; parser's checked complete frame
        move.l SCR20_RACE_TIME(a5),d3
        bsr.w scr20_link_receive
        bra.s .bytes
.done:
        tst.w SCR20_UART_FAULT(a5)
        bne.s .failed
        tst.w RX_FAILED(a5)
        bne.s .failed
        tst.w SCR20_CLOCK_BAD(a5)
        bne.s .failed
        moveq #1,d0
        rts
.failed:
        move.w #1,SCR20_RACE_ERROR(a5)
        moveq #0,d0
        rts

; Both $64ea0 and $64f54 are old blocking send/receive calls. The new
; adapter publishes the last complete remote sample, then forms one local
; sample after the current 50 Hz physics step. Return with the call site's
; original registers/CCR. Solo still uses the original routine.
scr20_race_draw:
        move.w sr,-(sp)
        movem.l d0-d7/a0-a6,-(sp)
        lea module_start(pc),a5
        tst.w SCR20_OWNER(a5)
        beq.s .legacy
        bsr.w scr20_race_keys
        bsr.w scr20_race_service
        tst.l d0
        beq.s .new_return
        bsr.w scr20_race_remote
        bsr.w scr20_race_publish
        tst.l d0
        bne.s .new_return
        move.w #1,SCR20_RACE_ERROR(a5)
.new_return:
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        rts
.legacy:
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        jmp $571ce.l

; The bypassed legacy sender $571ce also samples the local P and Esc keys
; ($572c2/$57304). Keep that exact rule: once set to a role, a flag stays
; until the game clears it; otherwise it is the role while the key is down.
; $612be clobbers D1/A0 and returns Z for a pressed key.
scr20_race_keys:
        move.b #$19,d1
        lea $1bba5,a1
        bsr.s .sample
        move.b #$45,d1
        lea $1bb64,a1
.sample:
        cmpi.b #$40,(a1)
        beq.s .keep
        cmpi.b #$80,(a1)
        beq.s .keep
        moveq #0,d4
        jsr $612be.l
        bne.s .store
        move.b $57c3c,d4
.store: move.b d4,(a1)
.keep:  rts

; The old second half waits for its final packet. The CRC-checked remote
; pose is already applied at the draw boundary. Keep the legacy tail's
; link-race placement calls ($576ca..$576e6): without them the opponent's
; received pose never reaches the object and draw state, so the other car
; stays invisible. $636c0 carries the existing link-contact hook.
scr20_race_receive_tail:
        move.w sr,-(sp)
        move.l a5,-(sp)
        lea module_start(pc),a5
        tst.w SCR20_OWNER(a5)
        beq.s .legacy
        move.l (sp)+,a5
        move.w (sp)+,sr
        tst.b $1ca22
        bpl.s .solo
        jsr $641b6.l
        jsr $6076c.l
        jsr $636c0.l
        jsr $5a186.l
.solo:  rts
.legacy:
        move.l (sp)+,a5
        move.w (sp)+,sr
        jmp $57440.l

; The remote pose is decoded, buffered and presented by scr20-view.s.

; Use the game's same 13 presentation bytes, with the original height and
; mirror arithmetic. All local fields are read after the current physics
; step; commit makes the whole frame available to the 50 ms IRQ atomically.
scr20_race_publish:
        bsr.w scr20_begin
        move.w #$d391,(a1)
        move.l RX_GENERATION(a5),2(a1)
        move.w SCR20_RACE_SEQUENCE(a5),6(a1)
        bsr.w scr20_view_mark      ; transition and formation time
        move.b $1bb1c,10(a1)
        move.b $1bb0a,11(a1)
        move.b $1bb0b,12(a1)
        ; Same arithmetic as the legacy sender $571f4..$5725c.
        move.w $1bcec,d0
        asr.w #1,d0
        add.w $1bd38,d0
        asr.w #3,d0
        bpl.s .base
        clr.w d0
.base:  move.w d0,d1            ; common height base
        move.l $1bc94,d0
        asr.l #3,d0
        add.w d1,d0
        bpl.s .height1
        clr.w d0
.height1:
        move.l $1bc98,d3
        asr.l #3,d3
        add.w d1,d3
        bpl.s .height2
        clr.w d3
.height2:
        move.l $1bc9c,d4
        asr.l #3,d4
        add.w d1,d4
        bpl.s .height3
        clr.w d4
.height3:
        move.w d0,d7
        add.w d3,d7
        lsr.w #1,d7
        sub.w d0,d3
        asr.w #1,d3
        move.w d4,d5
        sub.w d3,d5
        move.w d4,d6
        add.w d3,d6
        move.w d5,d0
        lsr.w #8,d0
        move.b d0,13(a1)
        move.b d5,14(a1)
        move.w d6,d0
        lsr.w #8,d0
        move.b d0,15(a1)
        move.b d6,16(a1)
        move.w d7,d0
        lsr.w #8,d0
        move.b d0,17(a1)
        move.b d7,18(a1)
        move.b $1bd30,19(a1)
        move.b $1bd31,20(a1)
        move.w $1bc5e,d0
        tst.b $1bc32
        bpl.s .lateral
        neg.w d0
        addi.w #$180,d0
.lateral:
        move.w d0,d1
        lsr.w #8,d1
        move.b d1,21(a1)
        move.b d0,22(a1)
        move.l SCR20_RACE_TIME(a5),d3
        bsr.w scr20_tx_prepare
        tst.l d0
        beq.s .return
        moveq #30,d0
        bsr.w scr25_crc
        move.w d0,30(a1)
        bsr.w scr20_commit
        addq.w #1,SCR20_RACE_SEQUENCE(a5)
        moveq #1,d0
.return:rts

; A link failure closes admission immediately, drains any current frame for
; at most 100 $57134 waits (about 60 ms each), then returns to the game's title setup. This is
; outside the normal frame path. No old result/record routine is reached.
scr20_race_close:
        move.w sr,-(sp)
        ori.w #$0700,sr
        clr.w published(a5)
        move.w (sp)+,sr
        move.w #99,d6
.drain:
        bsr.w scr20_clock_poll
        bsr.w scr20_release
        tst.l d0
        bne.s .legacy
        jsr $57134.l
        dbra d6,.drain
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.b #8,$bfde00
        move.b #1,$bfdd00
        move.w #$0801,$dff09a
        move.w #$0801,$dff09c
        clr.w SCR20_OWNER(a5)
        move.w #$8801,$dff09a
        move.w (sp)+,sr
.legacy:
        bsr.w scr20_resume_legacy
        clr.b $57c5b
        rts
