; Link service clock from the CIA-B counter.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; PAL service clock from CIA-B's independent 24-bit HSync counter, 68000.
; A5 = module base. D0 = result ms; D1-D7/A0-A6 preserved, CCR undefined.
; One owner, level 6 (or masked). No other TOD reader/writer while active.
; Initialize after OS takeover; do not carry a link across CIA/video resets.
; 64 us/line = 8/125 ms, with retained fraction. Standard PAL only.
; Poll at least every 65535 lines (~4.194 s), and never across a full TOD
; period (~1074 s). Larger observed gaps/reset-like jumps fail closed.
SCR20_CLOCK_LAST equ $4080
SCR20_CLOCK_MS   equ $4084
SCR20_CLOCK_FRAC equ $4088
SCR20_CLOCK_BAD  equ $408a

; D0 = initial 24-bit counter (normally zero).
; Caller masks interrupts. Timer B configuration other than CRB7 survives.
scr20_clock_init:
        move.l d1,-(sp)
        andi.l #$ffffff,d0
        move.l d0,SCR20_CLOCK_LAST(a5)
        clr.l SCR20_CLOCK_MS(a5)
        clr.l SCR20_CLOCK_FRAC(a5)
        move.b #4,$bfdd00       ; disable TOD alarm, preserve timer IRQ masks
        bclr #7,$bfdf00         ; select TOD writes, retain keyboard timer
        move.l d0,d1
        swap d1
        move.b d1,$bfda00
        move.l d0,d1
        lsr.l #8,d1
        move.b d1,$bfd900
scr20_clock_start:
        move.b d0,$bfd800       ; low byte starts the hardware counter
        moveq #0,d0
        move.l (sp)+,d1
        rts

scr20_clock_poll:
        ; Main-loop and level-6 UART/Timer IRQ both poll this clock. Keep the
        ; CIA TOD latch and the shared fractional accumulator in one atomic
        ; region; an IRQ between the three TOD reads can fabricate a jump.
        move.w sr,-(sp)
        ori.w #$0700,sr
        moveq #0,d0
        move.b $bfda00,d0       ; latch all three bytes, counter keeps running
        lsl.l #8,d0
        move.b $bfd900,d0
        lsl.l #8,d0
        move.b $bfd800,d0       ; release latch
        bsr.w scr20_clock_advance
        move.w (sp)+,sr
        rts
; Separate arithmetic entry for the millisecond accumulation.
scr20_clock_advance:
        movem.l d1-d2,-(sp)
        tst.w SCR20_CLOCK_BAD(a5)
        bne.s .return
        andi.l #$ffffff,d0
        move.l d0,d2
        sub.l SCR20_CLOCK_LAST(a5),d0
        andi.l #$ffffff,d0
        cmpi.l #65535,d0
        bhi.s .failed
        lsl.l #3,d0
        moveq #0,d1
        move.w SCR20_CLOCK_FRAC(a5),d1
        add.l d1,d0
        divu.w #125,d0          ; quotient <= 4195: cannot overflow DIVU
        move.l d0,d1
        andi.l #$ffff,d0
        add.l SCR20_CLOCK_MS(a5),d0
        bcs.s .failed          ; uint32 ABI must not wrap within a session
        move.l d2,SCR20_CLOCK_LAST(a5)
        move.l d0,SCR20_CLOCK_MS(a5)
        swap d1
        move.w d1,SCR20_CLOCK_FRAC(a5)
        bra.s .return
.failed:
        move.w #1,SCR20_CLOCK_BAD(a5)
.return:
        move.l SCR20_CLOCK_MS(a5),d0
        movem.l (sp)+,d1-d2
scr20_clock_sampled:
        rts
