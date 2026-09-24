; Mark the finish row with a small arrow in the track preview.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Track preview finish marker: a small fixed-size white down arrow with a
; black outline above the middle of the finish row, drawn over the preview.
;
; $604b4 draws the preview; its JSR $602e4 at $60532 walks the piece grid.
; $602e4 -> $60324 transforms each visible piece with JSR $6521c at $603d6
; (only caller path of $60324) and then fills its polygons at once. After
; $6521c the piece's projected points are in $1bfb0 (x) and $1c0f0 (y),
; indexed by byte offset D1 (left/right road edge pairs per row), with
; -$8000 in the height table $1be70 for a skipped point. $657b4 marks the
; row at byte offset $1bb98*2 of piece $1ca1c as the finish row.
; Preview screen pixel = projected point + (32,15) into the draw surface
; ($6a58c), 4 planes of 40 x 200 bytes; the preview frame's inner picture
; is x 15..309, y 10..143. Palette 15 is white and 8 black during preview.

PREVIEW_ARROW_LIFT equ 3        ; pixels between the tip and the finish row

; Hook $603d6 (JSR $6521c): remember the finish row's projected centre.
preview_arrow_piece:
        jsr $6521c
        movem.l d0-d2/a0,-(sp)
        tst.w preview_arrow_armed(pc)
        beq.s .done
        move.b $1bb85,d0
        cmp.b $1ca1c,d0
        bne.s .done
        moveq #0,d1
        move.b $1bb98,d1
        add.w d1,d1             ; left edge of the finish row
        moveq #0,d0
        move.b $1bbc5,d0
        cmp.w d0,d1
        blo.s .done
        move.b $1bb59,d0
        move.w d1,d2
        addq.w #2,d2            ; right edge
        cmp.w d0,d2
        bhs.s .done
        lea $1be70,a0
        tst.w (a0,d1.w)
        bmi.s .done
        tst.w (a0,d2.w)
        bmi.s .done
        lea $1bfb0,a0
        move.w (a0,d1.w),d0
        add.w (a0,d2.w),d0
        asr.w #1,d0
        lea preview_arrow_x(pc),a0
        move.w d0,(a0)
        lea $1c0f0,a0
        move.w (a0,d1.w),d0
        add.w (a0,d2.w),d0
        asr.w #1,d0
        lea preview_arrow_y(pc),a0
        move.w d0,(a0)
        lea preview_arrow_valid(pc),a0
        move.w #1,(a0)
.done:
        movem.l (sp)+,d0-d2/a0
        rts

; Hook $60532 (JSR $602e4): draw the grid, then the arrow on top.
; The caller's next instruction sets the flags; all registers returned by
; $602e4 are preserved.
preview_arrow_draw:
        move.l a0,-(sp)
        lea preview_arrow_armed(pc),a0
        move.w #1,(a0)
        clr.w preview_arrow_valid-preview_arrow_armed(a0)
        movea.l (sp)+,a0
        jsr $602e4
        movem.l d0-d7/a0-a2,-(sp)
        lea preview_arrow_armed(pc),a2
        clr.w (a2)
        tst.w preview_arrow_valid-preview_arrow_armed(a2)
        beq.s .done
        move.w preview_arrow_x-preview_arrow_armed(a2),d6
        addi.w #32-6,d6         ; left column of the 13 pixel wide mask
        move.w preview_arrow_y-preview_arrow_armed(a2),d7
        addi.w #15-PREVIEW_ARROW_LIFT-7,d7 ; top row; tip is row 7
        movea.l $6a58c,a1
        lea preview_arrow_mask(pc),a0
        moveq #7,d5             ; rows 0..7
.row:
        move.w (a0)+,d3         ; outline bits (bit 15 = column 0)
        move.w (a0)+,d4         ; white bits
        moveq #0,d2             ; column
.column:
        moveq #15,d0            ; white
        btst.l #15,d4
        bne.s .plot
        moveq #8,d0             ; black
        btst.l #15,d3
        beq.s .next
.plot:
        move.w d6,d1
        add.w d2,d1
        bsr.s preview_arrow_pixel
.next:
        add.w d3,d3
        add.w d4,d4
        addq.w #1,d2
        cmpi.w #13,d2
        blo.s .column
        addq.w #1,d7
        dbra d5,.row
.done:
        movem.l (sp)+,d0-d7/a0-a2
        rts

; D0 colour, D1 x, D7 y, A1 draw surface. Clipped to the preview picture.
; Scratch D0-D1.
preview_arrow_pixel:
        cmpi.w #15,d1
        blt.s .out
        cmpi.w #309,d1
        bgt.s .out
        cmpi.w #10,d7
        blt.s .out
        cmpi.w #143,d7
        bgt.s .out
        movem.l d2-d4/a1,-(sp)
        move.w d7,d2
        mulu.w #40,d2
        move.w d1,d3
        lsr.w #3,d3
        add.w d3,d2
        adda.l d2,a1
        not.w d1
        andi.w #7,d1            ; bit number within the byte
        moveq #3,d4
.plane:
        lsr.w #1,d0
        bcc.s .clear
        bset d1,(a1)
        bra.s .next_plane
.clear:
        bclr d1,(a1)
.next_plane:
        lea 8000(a1),a1
        dbra d4,.plane
        movem.l (sp)+,d2-d4/a1
.out:
        rts

; Rows of (outline, white) masks, column 0 in bit 15, 13 columns.
preview_arrow_mask:
        dc.w %1111111111111000,%0000000000000000
        dc.w %1000000000001000,%0111111111110000
        dc.w %0100000000010000,%0011111111100000
        dc.w %0010000000100000,%0001111111000000
        dc.w %0001000001000000,%0000111110000000
        dc.w %0000100010000000,%0000011100000000
        dc.w %0000010100000000,%0000001000000000
        dc.w %0000001000000000,%0000000000000000
preview_arrow_armed: dc.w 0
preview_arrow_valid: dc.w 0
preview_arrow_x: dc.w 0
preview_arrow_y: dc.w 0
