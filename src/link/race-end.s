; Race events, pause, race end and shared results over the link.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Race events, pause and the end-of-race return to the game's own result
; path for the 20 Hz link, 68000, module base a5.
;
; During the race the numbered reliable events carry what the legacy
; per-frame and control packets carried ($57440, $5773a):
;   3 Lap      data +0 local lap count (diagnostic)
;   4 End      data +0 flags (7 finished, 6 wrecked, 5 left),
;              +1 damage nibble ($1c9cf & 15), +2.w finish time /10 ms
;   5 Pause    6 Resume    7 Wreck    8 Leave
; The receiver applies them to the same game flags as the legacy receive:
; Wreck -> $1bbe2 = peer role, $1bb6f = $80; Leave -> $1bb64 = peer role;
; Pause -> $1bba5 = peer role. Lap crossings of the remote car are still
; detected by the game from its presented pose ($5dcc8, D1=1).
;
; When the race loop ends ($5d58a or $5d66e, both JSR $57964) both peers
; exchange acknowledged End events, the Host settles a close finish from
; both finish times, and the UART returns to the legacy owner. The game
; then runs its original result block transfer ($5867a, Host -> Join),
; points, result screens and the next race's link barrier ($5d342), which
; starts a new generation. Record policy: link races neither show the
; record screen nor persist records; each disk keeps its own records.
RACE_FLAGS       equ $4700   ; w: 1 wreck sent, 2 leave sent, 4 finished
RACE_GATE_AT     equ $4704   ; l: service ms at the race gate
RACE_FINISH_AT   equ $4708   ; l: local finish, ms after the gate
RACE_REMOTE_PAUSE equ $470c  ; w: pause requested by the peer
RACE_RESUME      equ $470e   ; w: resume seen inside the pause loop
RACE_PEER_END    equ $4710   ; w: peer End received
RACE_PEER_DATA   equ $4714   ; l: peer End data
RACE_END_STATE   equ $4718   ; w: 1 barrier, 2 legacy, 3 failed
RACE_LAST_PUBLISH equ $471c  ; l: keepalive publication time
RACE_PAUSES      equ $4720   ; w: pause loops entered
RACE_RESULT_FIX  equ $4722   ; w: Host changed the winner bit
RACE_IN_PAUSE    equ $4724   ; w: inside the pause loop
RACE_PEER_EVENTS equ $4726   ; w: applied peer race events
RACE_END_WAITS   equ $4728   ; l: barrier 10 ms waits used
RACE_WAIT_FROM   equ $472c   ; l: barrier or linger start (publish uses D3-D7)
RACE_SAVED       equ $4730   ; 30 bytes: Join's own records around $5867a
RACE_PAUSED_MS   equ $4750   ; l: time spent in the pause loop this race
RACE_END_LIMIT   equ 30000   ; service ms
RACE_LINGER_MS   equ 300

; Frame hook part: local events after the game's previous frame.
; D0=1, or 0 on a transport failure. Scratch D0-D2/A1.
scr20_race_local:
        move.b $1bb20,d1
        cmp.b SCR20_RACE_LOCAL_LAP(a5),d1
        beq.s .finish
        lea $4620(a5),a1
        move.b d1,(a1)
        clr.b 1(a1)
        clr.w 2(a1)
        moveq #3,d0
        bsr.w scr20_tx_enqueue
        tst.l d0
        beq.w .fail
        move.b d1,SCR20_RACE_LOCAL_LAP(a5)
.finish:
        btst #2,RACE_FLAGS+1(a5)
        bne.s .wreck
        move.b $1bb20,d1
        cmp.b $1bb99,d1
        blo.s .wreck
        ; Racing time: pause loops excluded, so the 10 ms End field (655 s)
        ; is not exhausted by a long pause.
        move.l SCR20_RACE_TIME(a5),d0
        sub.l RACE_GATE_AT(a5),d0
        sub.l RACE_PAUSED_MS(a5),d0
        move.l d0,RACE_FINISH_AT(a5)
        bset #2,RACE_FLAGS+1(a5)
.wreck: btst #0,RACE_FLAGS+1(a5)
        bne.s .leave
        move.b $1bbe2,d1
        cmp.b $57c3c,d1
        bne.s .leave
        moveq #7,d0
        bsr.s scr20_race_signal
        beq.s .fail
        bset #0,RACE_FLAGS+1(a5)
.leave: btst #1,RACE_FLAGS+1(a5)
        bne.s .ok
        move.b $1bb64,d1
        cmp.b $57c3c,d1
        bne.s .ok
        moveq #8,d0
        bsr.s scr20_race_signal
        beq.s .fail
        bset #1,RACE_FLAGS+1(a5)
.ok:    moveq #1,d0
        rts
.fail:  moveq #0,d0
        rts

; D0.b = kind with zero data. D0=boolean with CCR from TST.L.
scr20_race_signal:
        lea $4620(a5),a1
        clr.l (a1)
        bsr.w scr20_tx_enqueue
        tst.l d0
        rts

; Consume retained peer events. D0=1, 0 on an unknown kind. Race flags
; are applied only while the race loop runs (not in the end barrier).
; Scratch D0-D1/A1.
scr20_race_dispatch:
.next:  lea SCR20_RACE_EVENT(a5),a1
        bsr.w scr20_rx_take
        tst.l d0
        beq.w .ok
        move.b SCR20_RACE_EVENT+1(a5),d0
        cmpi.b #3,d0
        beq.w .lap
        cmpi.b #4,d0
        beq.w .end
        tst.w RACE_END_STATE(a5)
        bne.w .next                 ; race over: late pause/wreck/leave
        move.b $57c3c,d1
        eori.b #$c0,d1              ; peer role
        cmpi.b #5,d0
        beq.w .pause
        cmpi.b #6,d0
        beq.w .resume
        cmpi.b #7,d0
        beq.w .wreck
        cmpi.b #8,d0
        beq.w .leave
        cmpi.b #2,d0
        bls.w .next                 ; late Ready/Start duplicate class
        moveq #0,d0
        rts
.lap:   move.b SCR20_RACE_EVENT+4(a5),SCR20_RACE_PEER_LAP(a5)
        addq.w #1,SCR20_RACE_LAP_EVENTS(a5)
        bra.w .next
.end:   move.l SCR20_RACE_EVENT+4(a5),RACE_PEER_DATA(a5)
        move.w #1,RACE_PEER_END(a5)
        ; The peer's loop can end in the same frame as its leave key or
        ; wreck, before its frame hook sends Leave/Wreck: End carries them.
        tst.w RACE_END_STATE(a5)
        bne.w .next
        move.b $57c3c,d1
        eori.b #$c0,d1
        btst #5,RACE_PEER_DATA(a5)
        beq.s .end_wreck
        move.b d1,$1bb64
.end_wreck:
        btst #6,RACE_PEER_DATA(a5)
        beq.w .next
        move.b d1,$1bbe2
        move.b #$80,$1bb6f
        bra.w .next
.pause: tst.w RACE_IN_PAUSE(a5)
        bne.w .next
        move.b d1,$1bba5
        move.w #1,RACE_REMOTE_PAUSE(a5)
        addq.w #1,RACE_PEER_EVENTS(a5)
        bra.w .next
.resume:
        tst.w RACE_IN_PAUSE(a5)
        beq.w .next
        move.w #1,RACE_RESUME(a5)
        addq.w #1,RACE_PEER_EVENTS(a5)
        bra.w .next
.wreck: move.b d1,$1bbe2
        move.b #$80,$1bb6f
        addq.w #1,RACE_PEER_EVENTS(a5)
        bra.w .next
.leave: move.b d1,$1bb64
        addq.w #1,RACE_PEER_EVENTS(a5)
        bra.w .next
.ok:    moveq #1,d0
        rts

; Keep whole samples flowing while no game frame runs (pause, end barrier):
; republish the unchanged pose with a new sample number every 20 ms.
scr20_race_keepalive:
        move.l SCR20_RACE_TIME(a5),d0
        sub.l RACE_LAST_PUBLISH(a5),d0
        cmpi.l #20,d0
        blo.s .return
        move.l SCR20_RACE_TIME(a5),RACE_LAST_PUBLISH(a5)
        bsr.w scr20_race_publish
.return:rts

; $5da7e replaces the legacy link pause $57b86. A local P tells the peer;
; a peer pause arrives as $1bba5 = peer role and waits here without
; echoing. Either player resumes both with the game's resume key ($18,
; the same test as the solo loop $57bf6). The link stays serviced.
scr20_race_pause:
        move.w sr,-(sp)
        movem.l d0-d7/a0-a6,-(sp)
        lea module_start(pc),a5
        tst.w SCR20_OWNER(a5)
        beq.w .legacy
        tst.w RACE_REMOTE_PAUSE(a5)
        bne.s .enter
        moveq #5,d0
        bsr.w scr20_race_signal
        beq.w .fail
.enter: clr.w RACE_RESUME(a5)
        move.w #1,RACE_IN_PAUSE(a5)
        move.l SCR20_RACE_TIME(a5),RACE_WAIT_FROM(a5)
        addq.w #1,RACE_PAUSES(a5)
.loop:  bsr.w scr20_race_service
        tst.l d0
        beq.s .fail
        bsr.w scr20_race_dispatch
        tst.l d0
        beq.s .fail
        bsr.w scr20_race_keepalive
        tst.w RACE_RESUME(a5)
        bne.s .done
        jsr $5f98a.l                 ; the pause loop's own key service
        lea module_start(pc),a5
        move.b #$18,d1
        jsr $612be.l
        bne.s .idle
        moveq #6,d0
        bsr.w scr20_race_signal
        beq.s .fail
        bra.s .done
.idle:  jsr $5714c.l                 ; one 10 ms CIA-A wait
        lea module_start(pc),a5
        bra.s .loop
.fail:  move.w #1,SCR20_RACE_ERROR(a5)
.done:  move.l SCR20_RACE_TIME(a5),d0
        sub.l RACE_WAIT_FROM(a5),d0
        add.l d0,RACE_PAUSED_MS(a5)
        clr.w RACE_IN_PAUSE(a5)
        clr.w RACE_REMOTE_PAUSE(a5)
        clr.b $1bba5
        clr.b $57c63
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        rts
.legacy:
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        jmp $57b86.l

; $5d58a and $5d66e: the race loop has ended. Barrier, then the original
; $57964 and the game's result path with the legacy UART owner.
scr20_race_end:
        move.w sr,-(sp)
        movem.l d0-d7/a0-a6,-(sp)
        lea module_start(pc),a5
        tst.w SCR20_OWNER(a5)
        beq.s .legacy
        bsr.w scr20_end_barrier
        tst.l d0
        beq.s .failed
.legacy:
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        jmp $57964.l
.failed:
        move.w #3,RACE_END_STATE(a5)
        move.w #4,SCR20_RACE_END_REASON(a5)
        bsr.w scr20_race_close
        bsr.w scr20_race_screen_off
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        addq.l #8,sp           ; displaced JSR and enclosing $5d326 call
        clr.b $57c3c
        jmp $5cf40.l

; D0=1 after both End events are exchanged and the UART is legacy again.
scr20_end_barrier:
        move.w #1,RACE_END_STATE(a5)
        bsr.w scr20_race_service
        tst.l d0
        beq.w .fail
        lea $4620(a5),a1
        moveq #0,d0
        btst #2,RACE_FLAGS+1(a5)
        beq.s .wrecked
        bset #7,d0
.wrecked:
        move.b $1bbe2,d1
        cmp.b $57c3c,d1
        bne.s .left
        bset #6,d0
.left:  move.b $1bb64,d1
        cmp.b $57c3c,d1
        bne.s .flags
        bset #5,d0
.flags: move.b d0,(a1)
        move.b $1c9cf,d0
        andi.b #$0f,d0
        move.b d0,1(a1)
        move.l RACE_FINISH_AT(a5),d0
        divu.w #10,d0
        bvc.s .time
        move.w #$ffff,d0
.time:  move.w d0,2(a1)
        moveq #4,d0
        bsr.w scr20_tx_enqueue
        tst.l d0
        beq.w .fail
        move.l SCR20_RACE_TIME(a5),RACE_WAIT_FROM(a5)
.wait:  bsr.w scr20_race_service
        tst.l d0
        beq.w .fail
        bsr.w scr20_race_dispatch
        tst.l d0
        beq.w .fail
        bsr.w scr20_race_keepalive
        tst.w TX_COUNT(a5)
        bne.s .idle
        tst.w RACE_PEER_END(a5)
        bne.s .agreed
.idle:  jsr $5714c.l                 ; one 10 ms CIA-A wait
        lea module_start(pc),a5
        addq.l #1,RACE_END_WAITS(a5)
        move.l SCR20_RACE_TIME(a5),d0
        sub.l RACE_WAIT_FROM(a5),d0
        cmpi.l #RACE_END_LIMIT,d0
        blo.s .wait
        bra.w .fail
.agreed:
        ; Deliver the ACK of the peer's End before leaving the new
        ; transport. Late faults here no longer matter: both Ends are held.
        move.l SCR20_RACE_TIME(a5),RACE_WAIT_FROM(a5)
.linger:
        bsr.w scr20_race_service
        bsr.w scr20_race_dispatch
        bsr.w scr20_race_keepalive
        jsr $5714c.l
        lea module_start(pc),a5
        move.l SCR20_RACE_TIME(a5),d0
        sub.l RACE_WAIT_FROM(a5),d0
        cmpi.l #RACE_LINGER_MS,d0
        blo.s .linger
        bsr.s scr20_race_settle
        move.b RACE_PEER_DATA+1(a5),$57c61
        bsr.w scr20_race_release
        move.w #2,RACE_END_STATE(a5)
        moveq #1,d0
        rts
.fail:  moveq #0,d0
        rts

; Host only: when both cars finished, the earlier finish time wins
; ($1bbb4 bit 7 = the opponent won). A tie goes to the Host. The Host's
; result block ($5867a) carries the decision to the Join.
scr20_race_settle:
        cmpi.b #$80,$57c3c
        bne.s .return
        btst #2,RACE_FLAGS+1(a5)
        beq.s .return
        tst.b RACE_PEER_DATA(a5)
        bpl.s .return
        move.l RACE_FINISH_AT(a5),d0
        divu.w #10,d0
        move.b $1bbb4,d1
        move.b d1,d2
        bclr #7,d1
        cmp.w RACE_PEER_DATA+2(a5),d0
        bls.s .store
        bset #7,d1
.store: move.b d1,$1bbb4
        cmp.b d1,d2
        beq.s .return
        addq.w #1,RACE_RESULT_FIX(a5)
.return:rts

; Retire the new owner (drain the current frame for at most 100 $57134
; waits of about 60 ms) and reopen legacy admission. Unlike a fault close, the link role
; $57c3c and the game's menu-link flag $57c5b stay for the result path.
scr20_race_release:
        move.w sr,-(sp)
        ori.w #$0700,sr
        clr.w published(a5)
        move.w (sp)+,sr
        move.w #99,d6
.drain: bsr.w scr20_clock_poll
        bsr.w scr20_release
        tst.l d0
        bne.s .legacy
        jsr $57134.l
        lea module_start(pc),a5
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
        rts

; $5d116 replaces JSR $5867a. Records stay per disk: nobody gets the
; record screen, and the Join keeps its own historical times 14/15 and
; names when it adopts the Host's result block.
scr20_race_results:
        move.w sr,-(sp)
        movem.l d0-d7/a0-a6,-(sp)
        lea module_start(pc),a5
        tst.b $57c3c
        beq.s .call
        clr.b $1bbb1
        cmpi.b #$40,$57c3c
        bne.s .call
        moveq #0,d2
        bsr.s scr20_record_copy
.call:  movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        jsr $5867a.l
        move.w sr,-(sp)
        movem.l d0-d7/a0-a6,-(sp)
        lea module_start(pc),a5
        cmpi.b #$40,$57c3c
        bne.s .return
        clr.b $1bbb1
        moveq #1,d2
        bsr.s scr20_record_copy
.return:
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        rts

; D2.w = 0 saves, 1 restores the 30 record bytes: indices 14/15 of the
; three time levels $1c908/$1c920/$1c938, then the names $5ec48/$5ec55.
scr20_record_copy:
        lea RACE_SAVED(a5),a1
        lea .levels(pc),a2
        moveq #2,d3
.level: movea.l (a2)+,a0
        moveq #1,d4
        bsr.s .bytes
        dbra d3,.level
        lea $5ec48,a0
        moveq #11,d4
        bsr.s .bytes
        lea $5ec55,a0
        moveq #11,d4
.bytes: tst.w d2
        bne.s .in
.out:   move.b (a0)+,(a1)+
        dbra d4,.out
        rts
.in:    move.b (a1)+,(a0)+
        dbra d4,.in
        rts
.levels:
        dc.l $1c908+14,$1c920+14,$1c938+14

; $5d12a replaces JSR $5f25a (D0=0 stores the race's record names/times
; in the persistent per-track tables). Skipped after a link race.
scr20_race_records:
        tst.b $57c3c
        bne.s .skip
        jmp $5f25a.l
.skip:  rts
