; Fill long polygon row interiors with aligned 32-bit writes.
; D1.w=N-1; D6/D7 pack two plane words each (0 or $ffff).
; Leave one or two final words to the original loop at $6679e.
; Row SUB/SUBQ establishes X=0; positive count SUBQ below preserves that.
fill_spans060:
        movem.l d6/d7,-(sp)
        move.l a4,d2
        btst #1,d2
        beq.s fill_aligned060
        move.l d6,d2
        move.l d7,d3
        swap d2
        swap d3
        move.w d2,(a4)+
        move.w d6,$1f3e(a4)
        move.w d3,$3e7e(a4)
        move.w d7,$5dbe(a4)
        subq.w #1,d1
fill_aligned060:
        move.w d1,-(sp)
        lsr.w #1,d1
        subq.w #1,d1
        move.l d6,d2
        move.l d7,d3
        swap d2
        swap d3
        ext.l d2
        ext.l d3
        ext.l d6
        ext.l d7
fill_pairs060:
        move.l d2,(a4)+
        move.l d6,$1f3c(a4)
        move.l d3,$3e7c(a4)
        move.l d7,$5dbc(a4)
        dbf d1,fill_pairs060
        move.w (sp)+,d1
        andi.w #1,d1
        movem.l (sp)+,d6/d7
        move.l d6,d2
        move.l d7,d3
        swap d2
        swap d3
        jmp $6679e
