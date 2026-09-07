; 68000-compatible 20 ms player integration kernel. Installed by SCR_Boot.s at boot.
; Assemble with -m68000 -Fbin. Default address is an emulator test placement.
        ifnd LOAD_BASE
LOAD_BASE equ $181000
        endif
        org LOAD_BASE
        dc.l $50323031           ; P201
        dc.l linear20,angular20,pose20,spring20,reset20,scale20
        dc.l remainders,diagnostic,kernel_end

; SCALE channel: D0.w input, D0.l signed quotient output, D2.b becomes EE.
; D1 and other registers preserved. A wrapper's final ADD establishes its CCR.
SCALE macro
        move.l d1,-(sp)
        moveq #\1,d1
        bsr.w scale20
        move.l (sp)+,d1
        endm

linear20:
        move.w $1bcf6.l,d0
        SCALE 0
        add.w d0,$1bcea.l
        move.w $1bcf8.l,d0
        SCALE 2
        add.w d0,$1bcec.l
        move.w $1bcfa.l,d0
        SCALE 4
        add.w d0,$1bcee.l
        rts

angular20:
        move.w $1bcfc.l,d0
        SCALE 6
        add.w d0,$1bcf0.l
        move.w $1bcfe.l,d0
        SCALE 8
        add.w d0,$1bcf2.l
        move.w $1bd00.l,d0
        SCALE 10
        add.w d0,$1bcf4.l
        rts

pose20:
        move.w $1bcea.l,d0
        SCALE 12
        asl.l #6,d0
        add.l d0,$1bcd8.l
        move.w $1bcec.l,d0
        SCALE 14
        asl.l #7,d0
        add.l d0,$1bcdc.l
        move.w $1bcee.l,d0
        SCALE 16
        asl.l #6,d0
        add.l d0,$1bce0.l
        move.w $1bcdc.l,d0
        cmpi.w #1000,d0
        blt.s height_ok
        move.w #1000,$1bcdc.l
        clr.w remainders+14
height_ok:
        move.w $1bd3a.l,d0
        SCALE 18
        add.w d0,$1bce4.l
        move.w $1bd3c.l,d0
        SCALE 20
        add.w d0,$1bce6.l
        move.w $1bd3e.l,d0
        SCALE 22
        add.w d0,$1bce8.l
        move.w #0,d2
        tst.b $1bb75.l
        bpl.s limits_selected
        move.b $1bb9a.l,d0
        cmpi.b #$e0,d0
        bne.s limits_selected
        addq.b #2,d2
limits_selected:
        movea.l #$61ad4,a0
        move.w $1bce4.l,d3
        bmi.s pitch_negative
        move.w (0,a0,d2.w),d0
        cmp.w d3,d0
        bcc.s pitch_ok
        bra.s pitch_clamp
pitch_negative:
        move.w (4,a0,d2.w),d0
        cmp.w d3,d0
        bcs.s pitch_ok
pitch_clamp:
        move.w d0,$1bce4.l
        clr.w remainders+18
        move.w $1bcf0.l,d3
        eor.w d3,d0
        bmi.s pitch_ok
        move.w #0,$1bcf0.l
        clr.w remainders+6
pitch_ok:
        move.w $1bce8.l,d3
        bmi.s roll_negative
        move.w (0,a0,d2.w),d0
        cmp.w d3,d0
        bcc.s roll_ok
        bra.s roll_clamp
roll_negative:
        move.w (4,a0,d2.w),d0
        cmp.w d3,d0
        bcs.s roll_ok
roll_clamp:
        move.w d0,$1bce8.l
        clr.w remainders+22
        move.w $1bcf4.l,d3
        eor.w d3,d0
        bmi.s roll_ok
        move.w #0,$1bcf4.l
        clr.w remainders+10
roll_ok:
        bclr #7,$1bbab.l
        move.b $1bce4.l,d0
        bpl.s tilt_positive
        neg.b d0
tilt_positive:
        cmpi.b #15,d0
        blt.s tilt_done
        bset #7,$1bbab.l
tilt_done:
        move.w #0,d0
        sub.w $1bce4.l,d0
        move.w d0,$1bc42.l
        rts

; Only the three PLAYER callers are to be redirected here.
spring20:
        move.w #1656,d3
        muls.w d3,d0
        asr.l #8,d0
        move.l d1,-(sp)
        move.w d6,d1
        ext.l d1
        add.l d1,d0
        cmpi.l #32767,d0
        ble.s spring_lower
        move.l #32767,d0
spring_lower:
        cmpi.l #-32768,d0
        bge.s spring_done
        move.l #-32768,d0
spring_done:
        move.l (sp)+,d1
        tst.w d0             ; caller immediately branches on N (BMI)
        rts

; D1.w is byte offset 0,2,...22; only kernel callers may provide it.
; Remainders are unsigned words 0..1535. DIVS truncates toward zero, so correct
; a negative remainder to obtain floor division. Largest numerator magnitude
; is 7,798,784; quotient fits a signed word. No 68020+ division is used.
scale20:
        movem.l d3/a0,-(sp)
        move.w d2,d3
        andi.w #$ff00,d3
        bne.s invalid_coefficient
        lea remainders(pc),a0
        muls.w #238,d0
        moveq #0,d3
        move.w (0,a0,d1.w),d3
        add.l d3,d0
        divs.w #1536,d0
        move.l d0,d3
        swap d3
        tst.w d3
        bpl.s remainder_positive
        subq.w #1,d0
        addi.w #1536,d3
remainder_positive:
        move.w d3,(0,a0,d1.w)
        ext.l d0
        bra.s scale_done
invalid_coefficient:
        ; Preserve defined original arithmetic, but mark the test invalid.
        ; Never divide an unbounded live coefficient with overflowing DIVS.W.
        move.w #1,diagnostic
        move.b #$ee,d2
        muls.w d2,d0
        asr.l #8,d0
scale_done:
        move.b #$ee,d2
        movem.l (sp)+,d3/a0
        rts

reset20:
        movem.l d0/a0,-(sp)
        lea remainders(pc),a0
        moveq #11,d0
reset_loop:
        clr.w (a0)+
        dbra d0,reset_loop
        clr.w diagnostic
        movem.l (sp)+,d0/a0
        rts

        even
remainders: dcb.w 12,0
diagnostic: dc.w 0
kernel_end:
