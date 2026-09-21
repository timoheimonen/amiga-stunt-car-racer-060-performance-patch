; Transform track points while preserving the original point order.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Preserve coefficient reads, byte index wrap and the loop's final CCR.
; A3/A4/A5 are initialized only for the first non-skipped point.
        machine 68060
track_points060:
        move.b $1bbc5.l,d1
.search:
        tst.w (0,a6,d1.w)
        bpl.s .first
        addq.b #2,d1
        cmp.b $1bb59.l,d1
        bne.s .search
        jmp $654b4.l
.first:
        movea.l #$1c230,a3
        movea.l #$1c0f0,a4
        movea.l #$1bfb0,a5
.point:
        include "src/SCR_Point32.s"
 .next:
        addq.b #2,d1
        cmp.b $1bb59.l,d1
        beq.s .done
        tst.w (0,a6,d1.w)
        bmi.s .next
        bra.s .point
.done:
        jmp $654b4.l
        ; Preserve every subsequent runtime entry address.
        dcb.w (142-(*-track_points060))/2,$4e71
track_points060_end:
