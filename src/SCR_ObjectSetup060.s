; Relocate $695a2..$69603 and fall through into the batched transform.
; Remove ASL.W #3,D0 using 68020+ scaled index EAs. No executed filler.
; Preserve original word arithmetic, byte counter, stack and buffer order.
        machine 68060
object_setup060:
        movea.l #$699b8,a0
        movea.l (0,a0,d0.w*8),a6
        movea.l (4,a0,d0.w*8),a2
        move.w (a6)+,d6
        subq.w #1,d6
        move.b d6,d1
        asl.b #1,d1
        movea.l #$1bfb0,a4
        movea.l #$1c0f0,a5
        move.w $6979a.l,d4
        move.w $6979c.l,d5
.vertex:
        move.w (a6)+,d0
        bpl.w .x_ready
        move.w (a2)+,d0
.x_ready:
        add.w d4,d0
        move.w d0,(a4)+
        move.w (a6)+,d0
        bpl.w .y_ready
        move.w (a2)+,d0
.y_ready:
        sub.w d5,d0
        neg.w d0
        move.w d0,(a5)+
        dbra d6,.vertex
        move.l a6,-(sp)
        movea.l #$1c230,a3
        movea.l #$1bfb0,a5
        movea.l #$1c0f0,a4
        ; Fall through to transform_points060; continue at $69610.
