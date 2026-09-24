; Present the remote car from interpolated 20 Hz link samples.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; 50 Hz presentation of the 20 Hz remote pose, 68000, module base a5.
; The sender marks each sample word 8 with its transition number (bits
; 15..12, a new crane lift) and its formation time (bits 11..0, service ms).
; The receiver keeps four decoded samples and plays them VIEW_DELAY ms
; behind the lowest observed arrival latency. Between two samples of the
; same transition it interpolates track progress (across one piece
; boundary), support heights, speed and lateral position. A new transition
; or an unmatched piece jump is shown as a cut: no motion between the two
; poses. There is no prediction; after the newest sample the pose holds
; until the link's 2-second receive timeout closes the race.
;
; Cleared with the rest of $4000..$5fff by acquire.
SCR20_VIEW       equ $4640
VIEW_CRANE       equ SCR20_VIEW+0    ; b local crane flag at last publish
VIEW_TRANSITION  equ SCR20_VIEW+1    ; b local transition number 0..15
VIEW_COUNT       equ SCR20_VIEW+2    ; w decoded samples 0..4
VIEW_SEQUENCE    equ SCR20_VIEW+4    ; w last decoded sample number
VIEW_BASE        equ SCR20_VIEW+8    ; l minimum arrival minus formation
VIEW_FRAMES      equ SCR20_VIEW+12   ; l presented frames
VIEW_HOLDS       equ SCR20_VIEW+16   ; w frames past the newest sample
VIEW_CUTS        equ SCR20_VIEW+18   ; w received transition changes
VIEW_JITTER      equ SCR20_VIEW+20   ; w max arrival latency above base
VIEW_LEAD_MIN    equ SCR20_VIEW+22   ; w min newest time minus playout
VIEW_LEAD_MAX    equ SCR20_VIEW+24   ; w max newest time minus playout
VIEW_STEP_MAX    equ SCR20_VIEW+26   ; w max |progress| between samples
VIEW_LATERAL_MAX equ SCR20_VIEW+28   ; w max |lateral| between samples
VIEW_SAMPLES     equ SCR20_VIEW+30   ; w decoded samples
VIEW_AGE_MAX     equ SCR20_VIEW+32   ; w max local formation-to-start ms
VIEW_AGE_SUM     equ SCR20_VIEW+34   ; l
VIEW_AGE_COUNT   equ SCR20_VIEW+38   ; w
VIEW_BREAKS      equ SCR20_VIEW+40   ; w same-transition piece jumps
VIEW_LOGS        equ SCR20_VIEW+42   ; w reserved
VIEW_CUT_FRAMES  equ SCR20_VIEW+44   ; w frames presented as a cut
VIEW_RESTARTS    equ SCR20_VIEW+46   ; w timing restarts after a receive gap
VIEW_OUT         equ SCR20_VIEW+48   ; 24-byte presented entry
VIEW_ARRIVAL     equ SCR20_VIEW+72   ; l local arrival of the last decoded sample
VIEW_GAP_MS      equ 2000
VIEW_HISTORY     equ SCR20_VIEW+80   ; four entries, newest first
VIEW_ENTRY       equ 24
VIEW_DELAY       equ 70
; Entry: +0.l formation ms, +4.b transition, +5.b piece, +6.w progress,
; +8/+10/+12.w support heights, +14.w speed, +16.w lateral (sender form).

; Sender: A1 = frame being prepared. D0/D1 scratch.
scr20_view_mark:
        tst.b $1bbdf
        sne d0
        tst.b d0
        beq.s .flag
        tst.b VIEW_CRANE(a5)
        bne.s .flag
        addq.b #1,VIEW_TRANSITION(a5)
        andi.b #$0f,VIEW_TRANSITION(a5)
.flag:  move.b d0,VIEW_CRANE(a5)
        moveq #0,d0
        move.b VIEW_TRANSITION(a5),d0
        ror.w #4,d0
        move.w SCR20_RACE_TIME+2(a5),d1
        andi.w #$0fff,d1
        or.w d1,d0
        move.w d0,8(a1)
        rts

; Sender diagnostic: formation-to-actual-start age of the started frame.
scr20_view_sent:
        movem.l d0,-(sp)
        move.l sent_at(a5),d0
        sub.l active_at(a5),d0
        bmi.s .return
        cmpi.l #$7fff,d0
        bls.s .word
        move.w #$7fff,d0
.word:  cmp.w VIEW_AGE_MAX(a5),d0
        bls.s .sum
        move.w d0,VIEW_AGE_MAX(a5)
.sum:   ext.l d0
        add.l d0,VIEW_AGE_SUM(a5)
        addq.w #1,VIEW_AGE_COUNT(a5)
.return:movem.l (sp)+,d0
        rts

; Receiver, once per presented 50 Hz frame after link service.
; Registers are the draw hook's scratch.
scr20_race_remote:
        tst.w RX_VALID(a5)
        beq.w .return
        lea RX_LATEST(a5),a1
        move.w 6(a1),d0
        tst.w VIEW_COUNT(a5)
        beq.s .new
        cmp.w VIEW_SEQUENCE(a5),d0
        beq.s .present
.new:   move.w d0,VIEW_SEQUENCE(a5)
        ; The 12-bit formation time unwraps only across gaps below 4096 ms.
        ; No sample is decoded while no game frame runs (a long pause), so
        ; after a longer receive gap the timing and history start again.
        move.l RX_LAST_TIME(a5),d1
        sub.l VIEW_ARRIVAL(a5),d1
        move.l RX_LAST_TIME(a5),VIEW_ARRIVAL(a5)
        tst.w VIEW_COUNT(a5)
        beq.s .ingest
        cmpi.l #VIEW_GAP_MS,d1
        blo.s .ingest
        clr.w VIEW_COUNT(a5)
        addq.w #1,VIEW_RESTARTS(a5)
.ingest:
        bsr.w scr20_view_ingest
.present:
        move.l SCR20_RACE_TIME(a5),d6
        sub.l VIEW_BASE(a5),d6
        subi.l #VIEW_DELAY,d6          ; playout time, sender clock
        lea VIEW_HISTORY(a5),a3
        move.l (a3),d0
        sub.l d6,d0
        bsr.w scr20_view_lead
        addq.l #1,VIEW_FRAMES(a5)
        cmp.l (a3),d6
        blt.s .search
        beq.s .whole
        addq.w #1,VIEW_HOLDS(a5)
.whole: movea.l a3,a4
        bra.w scr20_view_apply
.search:
        move.w VIEW_COUNT(a5),d7
        subq.w #2,d7
        bmi.s .whole
.older: lea VIEW_ENTRY(a3),a2
        cmp.l (a2),d6
        bge.s .found
        movea.l a2,a3
        dbra d7,.older
        bra.s .whole                   ; before the oldest: show the oldest
.found: move.b 4(a2),d0
        cmp.b 4(a3),d0
        bne.w .cut
        bsr.w scr20_view_distance
        tst.w d1
        bne.w .cut
        move.l d0,d5
        bpl.s .range
        neg.l d5
.range: cmpi.l #$7fff,d5
        bhi.w .cut
        move.l d6,d1
        sub.l (a2),d1
        lsl.l #8,d1
        move.l (a3),d2
        sub.l (a2),d2
        ble.s .whole
        divu.w d2,d1                   ; 0..255, below 256 by the search
        andi.l #$ffff,d1
        muls.w d1,d0
        asr.l #8,d0
        move.w 6(a2),d2
        ext.l d2
        add.l d2,d0
        move.l d0,d4                   ; progress in the older piece
        moveq #0,d3
        move.b 5(a2),d3
        tst.l d4
        bpl.s .ahead
        move.b d3,d0
        bsr.w scr20_view_previous
        move.b d0,d3
        bsr.w scr20_view_length
        add.l d0,d4
        bra.s .placed
.ahead: move.b d3,d0
        bsr.w scr20_view_length
        cmp.l d0,d4
        blo.s .placed
        sub.l d0,d4
        move.b d3,d0
        bsr.w scr20_view_next
        move.b d0,d3
.placed:
        lea VIEW_OUT(a5),a4
        move.b d3,5(a4)
        move.w d4,6(a4)
        moveq #8,d5
.field: move.w (a3,d5.w),d0
        ext.l d0
        move.w (a2,d5.w),d2
        ext.l d2
        sub.l d2,d0
        asr.l #1,d0
        muls.w d1,d0
        asr.l #7,d0
        add.l d2,d0
        move.w d0,(a4,d5.w)
        addq.w #2,d5
        cmpi.w #18,d5
        blo.s .field
        bra.s scr20_view_apply
.cut:   addq.w #1,VIEW_CUT_FRAMES(a5)
        movea.l a2,a4
        bra.s scr20_view_apply
.return:rts

; A4 = entry. The same game fields and lateral scaling as the first
; playable phase's direct copy of the newest sample.
scr20_view_apply:
        move.b 5(a4),$1bb1d
        move.b 6(a4),$1bb0c
        move.b 7(a4),$1bb0d
        move.b 8(a4),$1bd66
        move.b 9(a4),$1bd67
        move.b 10(a4),$1bd68
        move.b 11(a4),$1bd69
        move.b 12(a4),$1bd6a
        move.b 13(a4),$1bd6b
        move.b 14(a4),$1bbee
        move.b 15(a4),$1bbef
        move.w 16(a4),d0
        move.w #$5555,d1
        muls.w d1,d0
        asl.l #1,d0
        swap d0
        move.w d0,$1bbec
        rts

; D0.l = newest formation time minus playout time.
scr20_view_lead:
        cmpi.l #$7fff,d0
        ble.s .low
        move.w #$7fff,d0
        bra.s .word
.low:   cmpi.l #-$8000,d0
        bge.s .word
        move.w #-$8000,d0
.word:  tst.l VIEW_FRAMES(a5)
        bne.s .compare
        move.w d0,VIEW_LEAD_MIN(a5)
        move.w d0,VIEW_LEAD_MAX(a5)
        rts
.compare:
        cmp.w VIEW_LEAD_MIN(a5),d0
        bge.s .max
        move.w d0,VIEW_LEAD_MIN(a5)
.max:   cmp.w VIEW_LEAD_MAX(a5),d0
        ble.s .return
        move.w d0,VIEW_LEAD_MAX(a5)
.return:rts

; A1 = accepted RX_LATEST. Shift the history and decode the new newest.
scr20_view_ingest:
        lea VIEW_HISTORY+3*VIEW_ENTRY(a5),a2
        lea VIEW_HISTORY+4*VIEW_ENTRY(a5),a3
        moveq #3*VIEW_ENTRY/4-1,d1
.shift: move.l -(a2),-(a3)
        dbra d1,.shift
        lea VIEW_HISTORY(a5),a3
        move.w 8(a1),d0
        move.w d0,d1
        andi.w #$0fff,d1
        rol.w #4,d0
        andi.w #$000f,d0
        move.b d0,4(a3)
        tst.w VIEW_COUNT(a5)
        bne.s .unwrap
        moveq #0,d2
        move.w d1,d2
        bra.s .timed
.unwrap:
        move.l VIEW_ENTRY(a3),d2
        move.w d1,d3
        sub.w d2,d3
        andi.l #$0fff,d3
        add.l d3,d2
.timed: move.l d2,(a3)
        move.b 10(a1),5(a3)
        lea 11(a1),a0
        lea 6(a3),a2
        moveq #11,d1
.bytes: move.b (a0)+,(a2)+
        dbra d1,.bytes
        ; Arrival latency in mixed clocks; its minimum anchors playout.
        move.l RX_LAST_TIME(a5),d0
        sub.l d2,d0
        tst.w VIEW_COUNT(a5)
        beq.s .base
        cmp.l VIEW_BASE(a5),d0
        bge.s .jitter
.base:  move.l d0,VIEW_BASE(a5)
.jitter:
        sub.l VIEW_BASE(a5),d0
        cmpi.l #$7fff,d0
        bls.s .jitter_word
        move.w #$7fff,d0
.jitter_word:
        cmp.w VIEW_JITTER(a5),d0
        bls.s .count
        move.w d0,VIEW_JITTER(a5)
.count: addq.w #1,VIEW_SAMPLES(a5)
        cmpi.w #4,VIEW_COUNT(a5)
        beq.s .steps
        addq.w #1,VIEW_COUNT(a5)
.steps: cmpi.w #2,VIEW_COUNT(a5)
        blo.s .return
        lea VIEW_HISTORY+VIEW_ENTRY(a5),a2
        move.b 4(a2),d0
        cmp.b 4(a3),d0
        beq.s .same
        addq.w #1,VIEW_CUTS(a5)
        moveq #1,d7
        bra.s .log
.same:  bsr.w scr20_view_distance
        tst.w d1
        beq.s .step
        addq.w #1,VIEW_BREAKS(a5)
        moveq #2,d7
        bra.s .log
.step:  moveq #0,d7
        tst.l d0
        bpl.s .step_abs
        neg.l d0
.step_abs:
        cmpi.l #$1000,d0
        bls.s .step_limit
        moveq #3,d7                     ; reason 3: over 16 segments
.step_limit:
        cmpi.l #$7fff,d0
        bls.s .step_word
        move.w #$7fff,d0
.step_word:
        cmp.w VIEW_STEP_MAX(a5),d0
        bls.s .lateral
        move.w d0,VIEW_STEP_MAX(a5)
.lateral:
        move.w 16(a3),d0
        sub.w 16(a2),d0
        bpl.s .lateral_abs
        neg.w d0
.lateral_abs:
        cmpi.w #$400,d0
        bls.s .lateral_limit
        moveq #4,d7                     ; reason 4: large lateral step
.lateral_limit:
        cmp.w VIEW_LATERAL_MAX(a5),d0
        bls.s .logged
        move.w d0,VIEW_LATERAL_MAX(a5)
.logged:
        tst.w d7
        bne.s .log
.return:rts
.log:
        rts

; A2 = older entry, A3 = newer entry. Progress words are signed.
; D0.l = signed track progress in the game's 1/256-segment unit, D1.w = 0 when the pieces are equal or one
; apart (either direction), else 1. D2-D5 scratch.
scr20_view_distance:
        moveq #0,d2
        move.b 5(a2),d2
        moveq #0,d3
        move.b 5(a3),d3
        move.w 6(a2),d4                ; signed: just past a boundary the
        ext.l d4                       ; game's progress can be a few units
        move.w 6(a3),d5                ; below zero (e.g. $fffb)
        ext.l d5
        cmp.b d2,d3
        bne.s .forward
        move.l d5,d0
        sub.l d4,d0
        moveq #0,d1
        rts
.forward:
        move.b d2,d0
        bsr.s scr20_view_next
        cmp.b d0,d3
        bne.s .backward
        move.b d2,d0
        bsr.s scr20_view_length
        sub.l d4,d0
        add.l d5,d0
        moveq #0,d1
        rts
.backward:
        move.b d3,d0
        bsr.s scr20_view_next
        cmp.b d0,d2
        bne.s .invalid
        move.b d3,d0
        bsr.s scr20_view_length
        sub.l d5,d0
        add.l d4,d0
        neg.l d0
        moveq #0,d1
        rts
.invalid:
        moveq #0,d0
        moveq #1,d1
        rts

; D0.b piece -> following / preceding piece on the loaded track ($1ca1a).
scr20_view_next:
        addq.b #1,d0
        cmp.b $1ca1a,d0
        blo.s .return
        moveq #0,d0
.return:rts

scr20_view_previous:
        tst.b d0
        bne.s .down
        move.b $1ca1a,d0
.down:  subq.b #1,d0
        rts

; D0.b piece -> D0.l piece length << 8, the progress word's range.
; Side-effect-free copy of the loader's lookup at $5fec0..$5ff5a:
; type = $1c5ec[piece] & 15, block = $1ef82 + (rol8($1ef82[2*type]) - $b100),
; count = block[block[0]], length = count/2 - 1 (the value put in $1bb6a).
scr20_view_length:
        movem.l d1/a0,-(sp)
        andi.w #$00ff,d0
        lea $1c5ec,a0
        move.b (a0,d0.w),d0
        andi.w #$000f,d0
        add.w d0,d0
        lea $1ef82,a0
        move.w (a0,d0.w),d0
        rol.w #8,d0
        subi.w #$b100,d0
        andi.l #$ffff,d0
        addi.l #$1ef82,d0
        movea.l d0,a0
        moveq #0,d1
        move.b (a0),d1
        moveq #0,d0
        move.b (a0,d1.w),d0
        lsr.b #1,d0
        subq.b #1,d0
        lsl.l #8,d0
        movem.l (sp)+,d1/a0
        rts
