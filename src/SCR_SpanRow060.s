; Draw polygon rows with edge masks and a long-span interior path.
; Fixed original entry $66740 and continuation $667b0.
        ifnd WORD_EDGE060
WORD_EDGE060 equ $6646e
        endif
span_row060:
        move.w d4,d1
        andi.w #$f0,d1
        lsr.w #3,d1
        lea (a6,d1.w),a4
        move.w d4,d3
        move.w d5,d1
        lsr.w #4,d3
        lsr.w #4,d1
        sub.w d3,d1
        bne.s span_multiple060
        andi.w #15,d4
        asl.w #2,d4
        move.w (a5,d4.w),d4
        andi.w #15,d5
        asl.w #2,d5
        move.w 64(a5,d5.w),d5
        and.w d5,d4
        bsr.w WORD_EDGE060
        bra.s $667c4
span_multiple060:
        subq.b #1,d1
        andi.w #15,d4
        beq.s span_dispatch060
        asl.w #2,d4
        move.w (a5,d4.w),d4
        bsr.w WORD_EDGE060
        subq.w #1,d1
        bmi.s $667b0
span_dispatch060:
        cmpi.w #13,d1
        bcs.s span_short060
        jmp fill_spans060
span_short060:
        move.l d6,d2
        move.l d7,d3
        swap d2
        swap d3
span_word060:
        move.w d2,(a4)+
        move.w d6,$1f3e(a4)
        move.w d3,$3e7e(a4)
        move.w d7,$5dbe(a4)
        dbf d1,span_word060
span_end060:
