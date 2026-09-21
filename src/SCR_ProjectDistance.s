; Interpolate and round projection distances with saturation.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Projection-only hypotenuse. D4/D5 signed words, D7.w ratio from angle.
; D0.w = rounded distance saturated to 32767 (the consumer is signed).
; D4/D5 become unsigned sorted magnitudes, D7.w becomes table byte offset,
; A0 = original distance table, as in $64de8. D2/D3 and others preserved.
; D0 upper half and CCR are scratch; caller's MOVE.W sets result flags.
        machine 68060
render_distance_precise:
        movem.l d2-d3,-(sp)
        movea.l #$1dc46,a0
        tst.w d4
        bpl.s .positive_x
        neg.w d4
.positive_x:
        tst.w d5
        bpl.s .positive_z
        neg.w d5
.positive_z:
        cmp.w d4,d5
        bhs.s .sorted
        exg d4,d5
.sorted:
        move.w d7,d3
        andi.w #31,d3
        lsr.w #4,d7
        andi.w #$ffe,d7
        move.w (a0,d7.w),d0
        ; round(65536*(sqrt(2)-1)); do not read beyond sample 2047.
        move.w #27146,d2
        cmpi.w #$ffe,d7
        beq.s .endpoint
        move.w 2(a0,d7.w),d2
.endpoint:
        sub.w d0,d2
        mulu.w d3,d2
        addi.w #16,d2
        lsr.w #5,d2
        add.w d2,d0
        mulu.w d4,d0
        addi.l #$8000,d0
        swap d0
        add.w d5,d0
        cmpi.w #$7fff,d0
        bls.s .done
        move.w #$7fff,d0
.done:
        movem.l (sp)+,d2-d3
        rts
render_distance_precise_end:
