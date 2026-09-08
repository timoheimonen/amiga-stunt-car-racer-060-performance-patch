; Select bitplane masks and the word drawing routine for a color.
        machine 68060
color_masks_entry060:
        moveq #0,d6
        move.b d0,d6
        andi.w #15,d6
        move.l (word_routines060,d6.w*4),word_pointer060
        move.l (color_masks060+4,d6.w*8),d7
        move.l (color_masks060,d6.w*8),d6
        lsr.b #4,d0
        bcc.s .done
        tst.w d7              ; original final NOT.W: NZVC=1000, X=1
.done:  rts
        dcb.b $67740-*,0
