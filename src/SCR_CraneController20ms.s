; Complete guarded replacement of [5b4a8,5b506), 94 bytes.
; D0/D2/D3/D4 are scratch. Callers use only Z, then overwrite D0.
; D7 is now preserved. CMP operands reverse N/C, which no caller consumes.
; The target moves every 20 ms; direct roll feedback uses the old clock.
        org $5b4a8
crane_controller20:
        move.w #$101c,d4
        tst.b $1bbe1.l
        bpl.s .right
        neg.b d0
        move.w #$f0d2,d4
.right:
        asl.w #8,d0
        move.b #$ee,d2
        ; Original BEQ after nonzero MOVE #$ee was unreachable.
        muls.w d2,d0
        asr.l #8,d0
        move.w $1bc5c.l,d3
        asl.w #5,d3
        cmp.w $1bc00.l,d4
        beq.s .at_target
        jsr crane_target20
.at_target:
        move.w $1bc00.l,d0
        sub.w d3,d0
        tst.b active
        beq.s .feedback
        tst.b legacy_due
        beq.s .no_feedback
.feedback:
        move.w d0,$1bce8.l
.no_feedback:
        clr.w $1bd26.l
        cmp.w $1bc00.l,d4
        rts
