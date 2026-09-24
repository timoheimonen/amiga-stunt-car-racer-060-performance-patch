; Linked races: cars pass through each other; clear car-to-car contact state.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Link-only ghost cars. Keep the interaction routine's distance/AI outputs.
; Clear only car/car transient state; shared road damage and sound stay intact.
link_contact_clear:
        clr.b $1bbc3.l
        clr.b $1bbeb.l
        clr.b $1bb46.l
        clr.w $1bd54.l
        clr.w $1bd56.l
        clr.w $1bd58.l
        clr.w op_state+48
        clr.w op_state+52
        clr.w op_state+56 ; +58 is the independent local yaw remainder
        rts

link_interaction:
        tst.b $57c3c.l
        beq.s .original
        bsr.s link_contact_clear
.original:
        move.b $1ca29.l,d1
        jmp $636c6.l

; The response can run before the next interaction update after a mode change.
link_contact_response:
        tst.b $57c3c.l
        beq.s .original
        bsr.s link_contact_clear
        rts
.original:
        tst.b $63ee0.l
        jmp $63e34.l
