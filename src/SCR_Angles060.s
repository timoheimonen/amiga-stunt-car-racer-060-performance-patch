; Build and use exact angle lookup tables for coefficient calculation.
; The last call at $61420 remains original and restores A0/D6/D7 side outputs.
; D4 is dead across these seven call sites and is overwritten by coefficient products.
        machine 68060
angles_init060:
        tst.l angles_ready060
        bne.s .done
        tst.l angles_alloc060
        beq.s .done
        movem.l d0-d7/a0-a6,-(sp)
        move.w sr,-(sp)
        movea.l angles_alloc060(pc),a1
        movea.l a1,a2
        adda.l #$20000,a2
        moveq #0,d1
.build:
        move.w d1,d0
        jsr $64d08.l
        move.w d0,(a1)+
        move.w d1,d0
        jsr $64d10.l
        move.w d0,(a2)+
        addq.w #1,d1
        bne.s .build
        move.l angles_alloc060(pc),angles_ready060
        move.w (sp)+,ccr
        movem.l (sp)+,d0-d7/a0-a6
.done:
        movea.l #$1c230,a5
        jmp $6136e.l
angle08_lookup060:
        move.l angles_ready060(pc),d4
        beq.s .fallback
        movea.l d4,a0
        moveq #0,d4
        move.w d0,d4
        move.w (a0,d4.l*2),d0
        rts
.fallback:
        jmp $64d08.l
angle10_lookup060:
        move.l angles_ready060(pc),d4
        beq.s .fallback
        movea.l d4,a0
        adda.l #$20000,a0
        moveq #0,d4
        move.w d0,d4
        move.w (a0,d4.l*2),d0
        rts
.fallback:
        jmp $64d10.l
angles_alloc060: dc.l 0
angles_ready060: dc.l 0
