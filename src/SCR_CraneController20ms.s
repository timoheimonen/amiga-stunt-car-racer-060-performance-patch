; Guarded replacement of [5b4a8,5b506), 94 bytes, 68000 instructions.
; D0/D2/D3/D4 are scratch; D1/D7/A0 and the stack are preserved.
; Callers consume only final Z (exact target reached), then overwrite D0.
; Smooth the signed shortest roll error by 1/6 each 20 ms, preserving
; angular velocity and contact forces. DIVS truncation leaves <6 angle units.
; Inactive runtime retains the original direct roll assignment.
        org $5b4a8
crane_controller20:
        move.l a0,-(sp)
        lea $1bc00.l,a0
        move.w #$101c,d4
        tst.b -$1f(a0)
        bpl.s .right
        neg.b d0
        move.w #$f0d2,d4
.right:
        asl.w #8,d0
        move.b #$ee,d2
        muls.w d2,d0
        asr.l #8,d0
        move.w $5c(a0),d3
        asl.w #5,d3
        cmp.w (a0),d4
        beq.s .at_target
        jsr crane_target20
.at_target:
        move.w (a0),d0
        sub.w d3,d0
        tst.b active
        beq.s .original
        sub.w $e8(a0),d0
        ext.l d0
        divs.w #6,d0
        add.w d0,$e8(a0)
        bra.s .done
.original:
        move.w d0,$e8(a0)
.done:
        clr.w $126(a0)
        cmp.w (a0),d4
        movea.l (sp)+,a0
        rts
        nop
