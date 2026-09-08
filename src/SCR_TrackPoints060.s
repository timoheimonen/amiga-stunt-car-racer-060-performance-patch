; Transform track points in batches while preserving coefficient reads, byte index wrap and CCR.
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
        move.w (0,a5,d1.w),d5
        move.w (0,a4,d1.w),d4
        move.w $22(a3),d0
        muls.w d5,d0
        asl.l #1,d0
        swap d0
        move.w $20(a3),d3
        muls.w d4,d3
        asl.l #1,d3
        swap d3
        add.w d3,d0
        asr.w #2,d0
        addi.w #128,d0
        move.w d0,(0,a5,d1.w)
        move.w $22(a3),d0
        muls.w d4,d0
        asl.l #1,d0
        swap d0
        move.w $20(a3),d3
        muls.w d5,d3
        asl.l #1,d3
        swap d3
        sub.w d3,d0
        asr.w #2,d0
        addi.w #64,d0
        move.w d0,(0,a4,d1.w)
 .next:
        addq.b #2,d1
        cmp.b $1bb59.l,d1
        beq.s .done
        tst.w (0,a6,d1.w)
        bmi.s .next
        bra.s .point
.done:
        jmp $654b4.l
track_points060_end:
