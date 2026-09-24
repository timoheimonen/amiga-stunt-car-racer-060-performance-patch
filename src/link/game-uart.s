; Serial port ownership and interrupt services for the game link code.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Game UART ownership and bounded interrupt services, 68000.
; Installed during main load before the existing instruction-cache flush.
; Owner 0 tail-calls the original routines with the original SR/registers.
; Owner 1 uses private Fast queues; outer game IRQs retain INTREQ and RTE.
; The playable race boundary acquires only after both peers have stopped
; legacy producers and the post-reset UART is locally drained.
;
; Public acquire/release: A5=module base; D0=1 success, 0 refused/busy.
; Preserve D1-D7/A0-A6 and caller IPL; CCR undefined. Never wait for UART.
; acquire additionally requires closed, locally drained, unviolated admission,
; loaded module, completed legacy role and
; empty legacy software/hardware TX. Caller guarantees post-OS PAL clock,
; no disk/video/CIA reset, no legacy producers and exclusive TOD ownership.
; release requires fully drained TX and leaves legacy admission closed.
; No partial frame is silently cut off. resume_legacy reopens explicitly.
SCR20_OWNER       equ $4094
SCR20_UART_FAULT  equ $4018
SCR20_TX_INDEX    equ $401c
SCR20_RX_HIGH     equ $401e
SCR20_RX_READ     equ $4020
SCR20_RX_WRITE    equ $4021
SCR20_TX_CLOCK_LAST equ $4004
SCR20_STARTS      equ $4008
SCR20_BUSY        equ $4010
SCR20_RING        equ $4100
SCR20_DRAIN_AFTER equ $4098
SCR20_QUIESCED    equ $40a0
SCR20_LEGACY_REJECTED equ $40a2
SCR20_LEGACY_DRAINED equ $40a4
SCR20_PEER_READY  equ $40a6
SCR20_HANDOFF_ROLE equ $40a8

; Close local legacy admission before negotiating the shared boundary.
; Existing bytes keep draining through the old TX dispatcher. Main-loop
; caller must stop its producers, then quiesce BOTH peers by protocol.
; A5=base, D0=boolean, others and SR control bits preserved.
scr20_quiesce:
        move.w sr,-(sp)
        ori.w #$0700,sr
        moveq #0,d0
        cmpi.l #2,module_state-module_start(a5)
        bne.s .return
        tst.w SCR20_OWNER(a5)
        bne.s .return
        move.w #1,SCR20_QUIESCED(a5)
        clr.w SCR20_LEGACY_DRAINED(a5)
        clr.w SCR20_PEER_READY(a5)
        moveq #1,d0
.return:
        move.w (sp)+,sr
        tst.l d0
        rts

; Explicit cancellation/re-entry into legacy mode, only after release.
; This does not establish a peer boundary or reset any hardware/queues.
scr20_resume_legacy:
        move.w sr,-(sp)
        ori.w #$0700,sr
        moveq #0,d0
        cmpi.l #2,module_state-module_start(a5)
        bne.s .return
        tst.w SCR20_OWNER(a5)
        bne.s .return
        clr.w SCR20_QUIESCED(a5)
        clr.w SCR20_LEGACY_REJECTED(a5)
        clr.w SCR20_LEGACY_DRAINED(a5)
        clr.w SCR20_PEER_READY(a5)
        moveq #1,d0
.return:
        move.w (sp)+,sr
        tst.l d0
        rts

; Guard the actual enqueue entry, including its full-ring retry branch.
; The displaced MOVEA does not affect CCR. Open mode exactly preserves
; the original entry ABI; closed mode preserves every register and SR.
; Rejection is sticky evidence of a producer violating the boundary.
scr20_legacy_enqueue:
        move.w sr,-(sp)
        move.l a5,-(sp)
        lea module_start(pc),a5
        tst.w SCR20_OWNER(a5)
        bne.s .owned
        tst.w SCR20_QUIESCED(a5)
        bne.s .reject
        move.l (sp)+,a5
        move.w (sp)+,sr
        movea.l #$ec56,a0
        jmp $f294.l
.owned:
        move.w #7,SCR20_UART_FAULT(a5)
.reject:
        move.w #1,SCR20_LEGACY_REJECTED(a5)
        clr.w SCR20_LEGACY_DRAINED(a5)
        move.l (sp)+,a5
        move.w (sp)+,sr
        rts

; Main-loop-only local drain. The game's $57134 is six 10 ms CIA-A timer B
; waits ($5714c, 7070 E-clock ticks each), about 60 ms per call;
; four consecutive idle waits cover the UART's final stop bit even though
; TSRE rises at its start. A busy/rejected queue resets the idle count.
; The 5000-wait limit assumes that the game's CIA-A wait itself completes.
; This says nothing about the peer: its last legacy byte may arrive later.
; A5=base, D0=boolean; preserve D1-D7/A0-A6 and caller IPL.
scr20_legacy_drain:
        move.w sr,-(sp)
        movem.l d1-d2,-(sp)
        moveq #0,d0
        cmpi.l #2,module_state-module_start(a5)
        bne.s .return
        tst.w SCR20_OWNER(a5)
        bne.s .return
        cmpi.w #1,SCR20_QUIESCED(a5)
        bne.s .return
        tst.w SCR20_LEGACY_REJECTED(a5)
        bne.s .return
        clr.w SCR20_LEGACY_DRAINED(a5)
        move.w #4999,d2
        moveq #0,d1
.poll:
        tst.w SCR20_LEGACY_REJECTED(a5)
        bne.s .return
        move.b $f256,d0
        cmp.b $f257,d0
        bne.s .busy
        tst.b $f258
        bne.s .busy
        tst.w $f25a
        bne.s .busy
        move.w $dff018,d0
        andi.w #$3000,d0
        cmpi.w #$3000,d0
        bne.s .busy
        addq.w #1,d1
        cmpi.w #5,d1
        beq.s .drained
        bra.s .wait
.busy:  moveq #0,d1
.wait:  jsr $57134.l
        dbra d2,.poll
        moveq #0,d0
        bra.s .return
.drained:
        move.w #1,SCR20_LEGACY_DRAINED(a5)
        moveq #1,d0
.return:
        movem.l (sp)+,d1-d2
        move.w (sp)+,sr
        tst.l d0
        rts

; Main-loop-only, bounded peer barrier after the legacy menu handshake.
; Both sides close admission and drain locally before any barrier byte.
; Host: A6 -> 5A, C3 -> 3C, D4. Join waits A6, sends 5A, waits C3,
; sends 3C, waits D4. A sender retries its current byte every 100 CIA-A
; waits; unknown/stale legacy bytes do not advance the exchange. Each phase
; has a 5000-wait bound. The final local UART drain precedes success.
; Caller must have stopped other legacy producers and must not run this in
; an interrupt. Success is an acquire precondition, not ownership itself.
; A5=base, D0=boolean; D1-D7/A0-A6 and caller IPL preserved.
scr20_peer_handoff:
        move.w sr,-(sp)
        movem.l d1-d7/a0-a6,-(sp)
        moveq #0,d0
        cmpi.l #2,module_state-module_start(a5)
        bne.w .return
        cmpi.b #$80,$57c5b
        bne.w .return
        move.b $57c3c,d1
        cmpi.b #$80,d1
        beq.s .role_ok
        cmpi.b #$40,d1
        bne.w .return
.role_ok:
        move.b d1,SCR20_HANDOFF_ROLE(a5)
        bsr.w scr20_quiesce
        tst.l d0
        beq.w .fail
        bsr.w scr20_legacy_drain
        tst.l d0
        beq.w .fail
        moveq #0,d4
        cmpi.b #$80,SCR20_HANDOFF_ROLE(a5)
        beq.s .host_begin
        moveq #0,d5
        move.w #$a6,d6
        bra.s .phase
.host_begin:
        move.w #$a6,d5
        moveq #$5a,d6
.phase:
        move.w #4999,d7
        moveq #0,d3
.poll:
        tst.w SCR20_LEGACY_REJECTED(a5)
        bne.w .fail
        tst.w SCR20_OWNER(a5)
        bne.w .fail
        tst.w d3
        bne.s .receive
        move.w #100,d3
        tst.b d5
        beq.s .receive
        move.b d5,d0
        bsr.w scr20_handoff_send
        tst.l d0
        beq.w .fail
.receive:
        jsr $5703a.l
        beq.s .wait
        jsr $f26a.l
        cmp.b d6,d0
        bne.s .wait
        cmpi.b #$80,SCR20_HANDOFF_ROLE(a5)
        beq.s .host_advance
        addq.w #1,d4
        cmpi.w #1,d4
        beq.s .join_reply
        cmpi.w #2,d4
        beq.s .join_ack
        bra.w .finish
.join_reply:
        moveq #$5a,d5
        move.w #$c3,d6
        bra.w .phase
.join_ack:
        moveq #$3c,d5
        move.w #$d4,d6
        bra.w .phase
.host_advance:
        addq.w #1,d4
        cmpi.w #1,d4
        beq.s .host_commit
        move.w #$d4,d0
        bsr.w scr20_handoff_send
        tst.l d0
        beq.w .fail
        bra.s .finish
.host_commit:
        move.w #$c3,d5
        moveq #$3c,d6
        bra.w .phase
.wait:
        jsr $57134.l
        subq.w #1,d3
        dbra d7,.poll
        bra.s .fail
.finish:
        ; TBE/TSRE alone do not cover the final stop bit. Four completed
        ; CIA-A waits also cover a byte just loaded into SERDAT.
        moveq #3,d7
.settle:
        jsr $57134.l
        dbra d7,.settle
        move.w $dff018,d0
        andi.w #$3000,d0
        cmpi.w #$3000,d0
        bne.s .fail
        tst.w SCR20_LEGACY_REJECTED(a5)
        bne.s .fail
        move.w #1,SCR20_LEGACY_DRAINED(a5)
        move.w #1,SCR20_PEER_READY(a5)
        moveq #1,d0
        bra.s .return
.fail:
        clr.w SCR20_PEER_READY(a5)
        clr.w SCR20_LEGACY_DRAINED(a5)
        moveq #0,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        move.w (sp)+,sr
        tst.l d0
        rts

; Directly send one odd-parity barrier byte while legacy admission is
; closed. The old TX queue must already be empty. D0=1 on success.
scr20_handoff_send:
        move.w $dff018,d2
        andi.w #$3000,d2
        cmpi.w #$3000,d2
        bne.s .busy
        bset #8,d0
        moveq #7,d2
.parity:
        ror.b #1,d0
        bcc.s .next
        bchg #8,d0
.next:  dbra d2,.parity
        bset #9,d0
        move.w d0,$dff030
        clr.w SCR20_LEGACY_DRAINED(a5)
        moveq #1,d0
        rts
.busy:  moveq #0,d0
        rts

scr20_acquire:
        move.w sr,-(sp)
        ori.w #$0700,sr
        movem.l d1/a0,-(sp)
        moveq #0,d0
        cmpi.l #2,module_state-module_start(a5)
        bne.w .return
        tst.w SCR20_OWNER(a5)
        bne.w .return
        cmpi.w #1,SCR20_QUIESCED(a5)
        bne.w .return
        cmpi.w #1,SCR20_LEGACY_DRAINED(a5)
        bne.w .return
        cmpi.w #1,SCR20_PEER_READY(a5)
        bne.w .return
        tst.w SCR20_LEGACY_REJECTED(a5)
        bne.w .return
        ; The race initializer consumes $57c5b after the peer barrier.
        ; PEER_READY is the durable proof, tied to the role used there.
        move.b SCR20_HANDOFF_ROLE(a5),d1
        cmp.b $57c3c,d1
        bne.w .return
        cmpi.b #$80,$57c3c
        beq.s .role_ok
        cmpi.b #$40,$57c3c
        bne.w .return
.role_ok:
        move.b $f256,d1
        cmp.b $f257,d1
        bne.w .return
        tst.b $f258
        bne.w .return
        tst.w $f25a
        bne.w .return
        move.w $dff018,d1
        andi.w #$3000,d1
        cmpi.w #$3000,d1
        bne.w .return
        ; All guards precede writes. UART baud/parity and keyboard timer
        ; remain configured by the game. Consume any old RX request once.
        move.w #$0801,$dff09a
        move.w $dff018,d1
        move.w #$0801,$dff09c
        clr.l $f254
        clr.b $57c3a
        clr.b $57c6e
        lea $4000(a5),a0
        move.w #$1fff/4,d1
.clear: clr.l (a0)+
        dbra d1,.clear
        move.w #32,SCR20_TX_INDEX(a5)
        moveq #0,d0
        bsr.w scr20_clock_init
        move.l SCR20_CLOCK_LAST(a5),SCR20_TX_CLOCK_LAST(a5)
        move.w #1,SCR20_OWNER(a5)
        move.w #1,SCR20_QUIESCED(a5)
        move.b #8,$bfde00
        move.b #$da,$bfd400
        move.b #$0d,$bfd500
        move.b #$81,$bfdd00
        move.w #$e800,$dff09a
        move.b #$11,$bfde00
        moveq #1,d0
.return:
        movem.l (sp)+,d1/a0
        move.w (sp)+,sr
        tst.l d0
        rts

scr20_release:
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.l d1,-(sp)
        moveq #0,d0
        cmpi.w #1,SCR20_OWNER(a5)
        bne.w .return
        tst.w published(a5)
        bne.w .return
        cmpi.w #32,SCR20_TX_INDEX(a5)
        bne.w .return
        move.w $dff018,d1
        andi.w #$3000,d1
        cmpi.w #$3000,d1
        bne.w .return
        ; TSRE rises at the start of the final stop bit on this UART.
        ; 32 * 11 * 373 color clocks = 37.017 ms. A 39 ms guard from
        ; the floored start timestamp includes the final stop bit and
        ; timestamp quantization. Before the first frame, it also drains
        ; any legacy stop bit present when ownership was acquired.
        move.l SCR20_CLOCK_MS(a5),d1
        sub.l sent_at(a5),d1
        cmpi.l #39,d1
        blo.w .return
        tst.w SCR20_CLOCK_BAD(a5)
        bne.w .return
        move.l SCR20_CLOCK_MS(a5),d1
        cmp.l SCR20_DRAIN_AFTER(a5),d1
        blo.w .return
        move.b #8,$bfde00
        move.b #1,$bfdd00
        move.w #$0801,$dff09a
        ; Dispatch the shared ICR before changing owner: pending keyboard
        ; B is serviced too. Publication is empty, so no new TX can start.
        bsr.w scr20_game_cia
        move.w $dff018,d1
        move.w #$0801,$dff09c
        clr.l $f254
        clr.w SCR20_OWNER(a5)
        move.w #$8801,$dff09a
        moveq #1,d0
.return:
        move.l (sp)+,d1
        move.w (sp)+,sr
        tst.l d0
        rts

scr20_game_tx:
        move.w sr,-(sp)
        movem.l d0-d3/a0-a1/a5,-(sp)
        lea module_start(pc),a5
        tst.w SCR20_OWNER(a5)
        beq.s .legacy
        ori.w #$0700,sr
        bsr.w scr20_send_byte
        movem.l (sp)+,d0-d3/a0-a1/a5
        move.w (sp)+,sr
        rts
.legacy:
        movem.l (sp)+,d0-d3/a0-a1/a5
        move.w (sp)+,sr
        jmp $f148.l

; Caller masks level 6, one character maximum. Odd parity as in $f148.
scr20_send_byte:
        cmpi.w #32,SCR20_TX_INDEX(a5)
        bhs.s .idle
        move.w $dff018,d0
        btst #13,d0
        beq.s .return
        move.w SCR20_TX_INDEX(a5),d1
        lea active(a5),a0
        moveq #0,d0
        move.b (a0,d1.w),d0
        bset #8,d0
        moveq #7,d2
.parity:
        ror.b #1,d0
        bcc.s .next
        bchg #8,d0
.next:  dbra d2,.parity
        bset #9,d0
        move.w d0,$dff030
        addq.w #1,SCR20_TX_INDEX(a5)
        cmpi.w #32,SCR20_TX_INDEX(a5)
        blo.s .return
        ; Read fresh TOD after the final SERDAT write. At most the prior
        ; character plus this character remain (2.314 ms). Four whole ms
        ; include timestamp quantization, even after a mid-frame TX stall.
        bsr.w scr20_clock_poll
        addq.l #4,d0
        bcs.s .clock_bad
        move.l d0,SCR20_DRAIN_AFTER(a5)
        bra.s .idle
.clock_bad:
        move.w #1,SCR20_CLOCK_BAD(a5)
        move.w #6,SCR20_UART_FAULT(a5)
.idle:  move.w #1,$dff09a
.return:rts

scr20_game_rx:
        move.w sr,-(sp)
        movem.l d0-d3/a0/a5,-(sp)
        lea module_start(pc),a5
        tst.w SCR20_OWNER(a5)
        beq.w .legacy
        move.w $dff018,d0
        btst #14,d0
        beq.s .return
        btst #15,d0
        bne.s .overrun
        btst #9,d0
        beq.s .bad_parity
        moveq #7,d2
.parity:
        ror.b #1,d0
        bcc.s .next
        bchg #8,d0
.next:  dbra d2,.parity
        btst #8,d0
        beq.s .bad_parity
        moveq #0,d1
        move.b SCR20_RX_WRITE(a5),d1
        move.w d1,d2
        addq.b #1,d2
        cmp.b SCR20_RX_READ(a5),d2
        beq.s .full
        lea SCR20_RING(a5),a0
        move.b d0,(a0,d1.w)
        move.b d2,SCR20_RX_WRITE(a5)
        sub.b SCR20_RX_READ(a5),d2
        andi.w #255,d2
        cmp.w SCR20_RX_HIGH(a5),d2
        bls.s .return
        move.w d2,SCR20_RX_HIGH(a5)
        bra.s .return
.overrun:
        move.w #1,SCR20_UART_FAULT(a5)
        bra.s .return
.bad_parity:
        move.w #2,SCR20_UART_FAULT(a5)
        bra.s .return
.full:  move.w #3,SCR20_UART_FAULT(a5)
.return:
        movem.l (sp)+,d0-d3/a0/a5
        move.w (sp)+,sr
        rts
.legacy:
        movem.l (sp)+,d0-d3/a0/a5
        move.w (sp)+,sr
        jmp $f1e0.l

scr20_game_cia:
        move.w sr,-(sp)
        movem.l d0-d3/a0-a1/a5,-(sp)
        lea module_start(pc),a5
        tst.w SCR20_OWNER(a5)
        beq.w .legacy
        moveq #0,d0
        move.b $bfdd00,d0
        btst #1,d0
        beq.s .timer_a
        bclr #6,$bfee01
        clr.b $f0a8
.timer_a:
        btst #0,d0
        beq.s .return
        bsr.w scr20_clock_poll
        tst.w SCR20_CLOCK_BAD(a5)
        beq.s .clock_ok
        move.w #6,SCR20_UART_FAULT(a5)
.clock_ok:
        tst.w SCR20_UART_FAULT(a5)
        bne.s .return
        ; Quantize 50 ms to 781 HSync ticks (49.984 ms). The TOD
        ; observation itself has one 64 us tick of uncertainty. Comparing
        ; floored milliseconds here can miss a wakeup and produce 55 ms.
        ; Keep the hardware-clock anchor, including its 24-bit wrap.
        move.l SCR20_CLOCK_LAST(a5),d0
        sub.l SCR20_TX_CLOCK_LAST(a5),d0
        andi.l #$ffffff,d0
        cmpi.l #781,d0
        blo.s .return
        tst.w published(a5)
        beq.s .return
        cmpi.w #32,SCR20_TX_INDEX(a5)
        bne.s .busy
        move.w $dff018,d1
        andi.w #$3000,d1
        cmpi.w #$3000,d1
        bne.s .busy
        bsr.w scr20_take
        move.l SCR20_CLOCK_LAST(a5),SCR20_TX_CLOCK_LAST(a5)
        clr.w SCR20_TX_INDEX(a5)
        addq.l #1,SCR20_STARTS(a5)
        move.w #$8001,$dff09a
        bsr.w scr20_send_byte
        bra.s .return
.busy:  addq.l #1,SCR20_BUSY(a5)
.return:
        movem.l (sp)+,d0-d3/a0-a1/a5
        move.w (sp)+,sr
        rts
.legacy:
        movem.l (sp)+,d0-d3/a0-a1/a5
        move.w (sp)+,sr
        jmp $f0aa.l
