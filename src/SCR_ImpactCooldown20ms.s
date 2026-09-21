; Preserve severe-impact cooldown timing during 50 Hz physics.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Replace [5dfe0,5e016), keeping the zero-counter and damage continuations.
; This function is called only by the gameplay loop after active frame_begin.
; Intermediate frames still process fresh impacts, but neither decrement the
; legacy counter nor repeat its special 69 -> 68 graphical transition.
impact_cooldown20:
        move.b $1bb73.l,d0
        beq.s $5e016
        tst.b legacy_due.l
        beq.s .event
        subq.b #1,$1bb73.l
        cmpi.b #$45,d0
        beq.s .first_tick
.event:
        move.b $1bb54.l,d0
        bne.s $5e05c
        rts
.first_tick:
        move.b $1c9cf.l,d2
        jsr $6091a.l
        bra.s $5e05c
        nop
