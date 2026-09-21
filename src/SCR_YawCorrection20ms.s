; Apply fractional yaw correction at the 20 ms physics interval.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Replace [611ce,6121c); the caller runs after active frame_begin.
; Signed fractional carry conserves six constant 20 ms corrections exactly.
; yaw_fraction20 uses the otherwise unused expected-word of op_damage's
; rate-only state record. opponent_reset clears it at race/respawn startup.
; D0 is restored before the original yaw-rate load; D2 is scratch and ends
; at zero as before. D1 and the stack are preserved. The original checksum
; and contact-dependent torque suppression remain, with folded constants.
yaw_correction20:
        move.l d0,-(sp)
        ext.l d0
        move.w yaw_fraction20.l,d2
        ext.l d2
        add.l d2,d0
        divs.w #6,d0
        swap d0
        move.w d0,yaw_fraction20.l
        swap d0
        add.w d0,$1bce6.l
        move.l (sp)+,d0
yaw_damping20:
        move.w $1bcf2.l,d0
        sub.w d0,d4
        sub.l d2,d2          ; zero D2 and X, as the old constant ADD.L did
        lea $64aec(pc),a0
        move.l #$9cedcd02,d3
        cmp.l (a0),d3
        bne.s .zero
        tst.b $1bb7e.l
        bne.s .store
.zero:
        clr.w d4
.store:
        move.w d4,$1bcfe.l
        rts
