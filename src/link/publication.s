; Hand prepared link frames from the game loop to the serial interrupt.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Two prepared frames and a private active frame, 68000, module base a5.
; Main-loop is the sole producer. IRQ may consume only at level 6 or with
; level 6 masked. Initialize metadata to zero before enabling interrupts.
; Formation and actual-start times are service milliseconds from CIA-B TOD.
;
; begin: returns a1 = inactive 32-byte slot, preserves other registers.
; Never call begin again until commit; IRQ never changes published_slot.
scr20_begin:
        move.w published_slot(a5),producer_slot(a5)
        eori.w #32,producer_slot(a5)
        lea prepared(a5),a1
        adda.w producer_slot(a5),a1
        rts

; commit: a1 = completed frame from begin, d3 = sample formation time.
; CRC and any transition/event fields must already be complete.
; Preserves registers and original SR/CCR, including the caller's IPL.
; The aligned word publication is the last write inside the critical section.
scr20_commit:
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.l d3,prepared_at(a5)
        move.w producer_slot(a5),published_slot(a5)
        move.w #1,published(a5)
scr20_committed:
        move.w (sp)+,sr
        rts

; take: caller has checked valid, software TX empty and UART idle.
; Preserves all registers except CCR; invalidates only after the copy.
; sent_sequence + sent_at are the main-loop's actual-start receipt.
; Events must use this receipt, never preparation time, as sent_at.
scr20_take:
        movem.l d0/a0-a1,-(sp)
        lea prepared(a5),a0
        adda.w published_slot(a5),a0
        lea active(a5),a1
        moveq #7,d0
.copy:  move.l (a0)+,(a1)+
        dbra d0,.copy
        move.l prepared_at(a5),active_at(a5)
        move.w active+6(a5),sent_sequence(a5)
        move.l SCR20_CLOCK_MS(a5),sent_at(a5)
        clr.w published(a5)
        movem.l (sp)+,d0/a0-a1
        rts
