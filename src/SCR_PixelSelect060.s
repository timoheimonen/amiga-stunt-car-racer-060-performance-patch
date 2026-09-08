; Select an immutable pixel drawing routine for the requested color.
        machine 68060
pixel_select060:
        move.w d0,-(sp)
        andi.w #15,d0
        move.l .pointers(pc,d0.w*4),pixel_odd_pointer060
        move.w (sp)+,d0
        lsr.b #4,d0
        bcs.s .set
        bclr #3,pixel_previous060
        rts
.set:   bset #3,pixel_previous060
        rts
.pointers:
        dc.l pixel_variants060+0*34
        dc.l pixel_variants060+1*34
        dc.l pixel_variants060+2*34
        dc.l pixel_variants060+3*34
        dc.l pixel_variants060+4*34
        dc.l pixel_variants060+5*34
        dc.l pixel_variants060+6*34
        dc.l pixel_variants060+7*34
        dc.l pixel_variants060+8*34
        dc.l pixel_variants060+9*34
        dc.l pixel_variants060+10*34
        dc.l pixel_variants060+11*34
        dc.l pixel_variants060+12*34
        dc.l pixel_variants060+13*34
        dc.l pixel_variants060+14*34
        dc.l pixel_variants060+15*34
        dcb.b $663b0-*,0
; Direct callers use this local entry, avoiding an extra trampoline per edge.
.word_edge:
        move.w d4,d2
        not.w d2
        jmp ([word_pointer060])
        dcb.b $663f2-*,0
