; Race start: settings contract, session generation and link ownership.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Game race boundary for the 20 Hz link module.
; Both calls are within $5d326. A failed barrier or ownership change
; abandons that call and its direct caller before re-entering the game's
; existing title setup at $5cf40. No new link owner is active on failure.
SCR20_RACE_GENERATION equ $40ac
SCR20_RACE_CONTRACT equ $40b0

; Outside the per-race Fast state that acquire clears: survives the session.
; +0 last agreed generation, +4 completed link race handoffs.
        even
scr20_last_generation: dc.l 0,0

scr20_race_handoff:
        move.w sr,-(sp)
        movem.l d0-d7/a0-a6,-(sp)
        lea module_start(pc),a5
        bsr.w scr20_peer_handoff
        tst.l d0
        beq.s .abort
        bsr.w scr20_race_nonce
        tst.l d0
        beq.s .abort
        move.l d0,SCR20_RACE_GENERATION(a5)
        bsr.w scr20_race_contract
        tst.l d0
        beq.s .abort
        lea scr20_last_generation(pc),a0
        move.l SCR20_RACE_GENERATION(a5),(a0)
        addq.l #1,4(a0)
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        jmp $57134.l             ; displaced CIA-A wait (6 x 10 ms, see $5714c)
.abort:
        bsr.w scr20_resume_legacy
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        addq.l #8,sp             ; $5d342 and $5d326 return addresses
        clr.b $57c3c
        jmp $5cf40.l

scr20_race_acquire:
        move.w sr,-(sp)
        movem.l d0-d7/a0-a6,-(sp)
        lea module_start(pc),a5
        tst.b $57c3c
        beq.s .solo
        move.l SCR20_RACE_GENERATION(a5),d4
        tst.l d4
        beq.s .abort
        move.b SCR20_HANDOFF_ROLE(a5),d5
        bsr.w scr20_acquire
        tst.l d0
        beq.s .abort
        ; Acquire resets the transport tail, including its preflight role.
        move.b d5,SCR20_HANDOFF_ROLE(a5)
        move.l d4,d0
        move.l SCR20_CLOCK_MS(a5),d3
        bsr.w scr20_link_init
        tst.l d0
        beq.s .abort_owned
.solo:
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        jmp $1bace.l            ; first original post-reset call
.abort_owned:
        ; This can only fail if the agreed generation is zero, checked above.
        move.w #8,SCR20_UART_FAULT(a5)
.abort:
        bsr.w scr20_resume_legacy
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        addq.l #8,sp             ; $5d35e and $5d326 return addresses
        clr.b $57c3c
        jmp $5cf40.l

; A host-generated nonzero 32-bit generation travels as four odd-parity
; bytes after the proven legacy barrier. Join echoes each byte. The sender
; does not advance until its echo arrives, so either side can fail within
; the same 5-second CIA-A budget without entering the framed parser.
; A5=module base, D0=agreed generation or zero. All other registers saved.
scr20_race_nonce:
        movem.l d1-d7/a0,-(sp)
        moveq #0,d4
        cmpi.b #$80,SCR20_HANDOFF_ROLE(a5)
        bne.s .exchange
        move.l $5cf2c,d4
        moveq #0,d1
        move.b $bfe401,d1
        swap d1
        move.b $bfe501,d1
        eor.l d1,d4
        ; A deterministic boot and menu path can reproduce the same timer and
        ; counter state at every race entry. Mix the session's race count
        ; into the top byte, and never repeat the previous race's value:
        ; its late frames would otherwise stay acceptable.
        lea scr20_last_generation(pc),a0
        move.l 4(a0),d1
        ror.l #8,d1
        eor.l d1,d4
        ori.l #1,d4
        cmp.l (a0),d4
        bne.s .exchange
        addi.l #$9e3779b8,d4       ; even step keeps bit 0: never zero
.exchange:
        move.l d4,d7
        moveq #3,d5
.byte:
        cmpi.b #$80,SCR20_HANDOFF_ROLE(a5)
        bne.s .join
        move.l d4,d0
        lsr.l #8,d0
        lsr.l #8,d0
        lsr.l #8,d0
        move.b d0,d6
        bsr.w scr20_race_send
        tst.l d0
        beq.s .fail
        bsr.w scr20_race_recv
        tst.l d0
        beq.s .fail
        cmp.b d6,d1
        bne.s .fail
        lsl.l #8,d4
        bra.s .next
.join:
        bsr.w scr20_race_recv
        tst.l d0
        beq.s .fail
        lsl.l #8,d4
        move.b d1,d4
        move.b d1,d6
        bsr.w scr20_race_send
        tst.l d0
        beq.s .fail
.next: dbra d5,.byte
        cmpi.b #$80,SCR20_HANDOFF_ROLE(a5)
        bne.s .joined
        move.l d7,d4
.joined:
        tst.l d4
        beq.s .fail
        move.l d4,d0
        bra.s .return
.fail:  moveq #0,d0
.return:
        movem.l (sp)+,d1-d7/a0
        rts

; D6=byte to send. One call is bounded to 5000 CIA-A waits.
scr20_race_send:
        move.l d7,-(sp)
        move.w #4999,d7
.poll: moveq #0,d0
        move.b d6,d0
        bsr.w scr20_handoff_send
        tst.l d0
        bne.s .return
        jsr $57134.l
        dbra d7,.poll
.return:move.l (sp)+,d7
        rts

; D0=1 success, D1.b=received byte. One call has the same bound.
scr20_race_recv:
        move.l d7,-(sp)
        move.w #4999,d7
.poll: jsr $5703a.l
        beq.s .wait
        jsr $f26a.l
        move.b d0,d1
        moveq #1,d0
        move.l (sp)+,d7
        rts
.wait: jsr $57134.l
        dbra d7,.poll
        moveq #0,d0
        move.l (sp)+,d7
        rts

; Compare the selected race and settings shared by the human peers before
; enabling the new UART owner. The local driver identifier is intentionally
; excluded. The fixed on-wire revision is already checked in the menu.
; Host sends each byte and Join echoes only an equal local value. An unequal
; byte is explicitly inverted, so both endpoints reject this race.
scr20_race_contract:
        movem.l d1-d7/a0,-(sp)
        move.b $1ca33,SCR20_RACE_CONTRACT(a5)   ; selected track
        move.b $1c9d0,SCR20_RACE_CONTRACT+1(a5) ; league
        move.b $1ca22,SCR20_RACE_CONTRACT+2(a5) ; race/practice mode
        move.b $1c9ce,SCR20_RACE_CONTRACT+3(a5) ; division
        move.b $18243a,SCR20_RACE_CONTRACT+4(a5) ; game speed
        move.b $18243b,SCR20_RACE_CONTRACT+5(a5)
        move.b $182445,SCR20_RACE_CONTRACT+6(a5) ; infinite boost
        move.b $182446,SCR20_RACE_CONTRACT+7(a5) ; disable damage
        ; $5eb79 is the local driver and $1ca29 the linked opponent, both
        ; 0..11 (runtime: Host 0b/0a, Join 0a/0b). Store Host's view on
        ; both peers so equal bytes mean complementary seats.
        move.b $5eb79,SCR20_RACE_CONTRACT+8(a5) ; Host driver
        move.b $1ca29,SCR20_RACE_CONTRACT+9(a5) ; Join driver
        cmpi.b #$80,SCR20_HANDOFF_ROLE(a5)
        beq.s .seats
        move.b $1ca29,SCR20_RACE_CONTRACT+8(a5)
        move.b $5eb79,SCR20_RACE_CONTRACT+9(a5)
.seats:
        move.b SCR20_RACE_CONTRACT+8(a5),d0
        cmp.b SCR20_RACE_CONTRACT+9(a5),d0
        beq.w .fail
        cmpi.b #11,d0
        bhi.w .fail
        cmpi.b #11,SCR20_RACE_CONTRACT+9(a5)
        bhi.w .fail
        moveq #0,d4
        moveq #9,d5
.byte:
        ; $f26a in scr20_race_recv loads the game's RX pointer into A0.
        ; Rebase for every byte rather than retaining A0 across that call.
        lea SCR20_RACE_CONTRACT(a5),a0
        move.b (a0,d4.w),d6
        cmpi.b #$80,SCR20_HANDOFF_ROLE(a5)
        bne.s .join
        bsr.w scr20_race_send
        tst.l d0
        beq.s .fail
        bsr.w scr20_race_recv
        tst.l d0
        beq.s .fail
        cmp.b d6,d1
        bne.s .fail
        bra.s .next
.join:
        bsr.w scr20_race_recv
        tst.l d0
        beq.s .fail
        cmp.b d6,d1
        beq.s .echo
        not.b d6
        bsr.w scr20_race_send
        bra.s .fail
.echo:
        bsr.w scr20_race_send
        tst.l d0
        beq.s .fail
.next: addq.w #1,d4
        dbra d5,.byte
        cmpi.b #$80,SCR20_HANDOFF_ROLE(a5)
        bne.s .join_commit
        moveq #$7e,d6
        bsr.w scr20_race_send
        tst.l d0
        beq.s .fail
        bra.s .settle
.join_commit:
        bsr.w scr20_race_recv
        tst.l d0
        beq.s .fail
        cmpi.b #$7e,d1
        bne.s .fail
.settle:
        moveq #3,d5
.wait:  jsr $57134.l
        dbra d5,.wait
        move.w $dff018,d0
        andi.w #$3000,d0
        cmpi.w #$3000,d0
        bne.s .fail
        ; Every nonce/contract byte cleared the local drained proof. Recheck
        ; the idle legacy queue and final stop bit before scr20_acquire.
        bsr.w scr20_legacy_drain
        tst.l d0
        beq.s .fail
        moveq #1,d0
        bra.s .return
.fail:  moveq #0,d0
.return:
        movem.l (sp)+,d1-d7/a0
        rts
