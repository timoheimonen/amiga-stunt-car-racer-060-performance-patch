; Mark the finish row with a small arrow in the track preview.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Track preview finish marker: a small fixed-size white down arrow with a
; black outline above the middle of the finish row, drawn over the preview.
;
; $604b4 draws the preview; its JSR $602e4 at $60532 walks the piece grid.
; $602e4 calls $60324 for every grid cell; $60324 transforms the cell's
; piece with $6521c and fills its polygons at once. Once $60324 returns,
; the piece's projected points are in $1bfb0 (x) and $1c0f0 (y), indexed
; by byte offset (left/right road edge pairs per row), with -$8000 in the
; height table $1be70 for a skipped point; $1bb85 is the piece. $657b4
; marks the row at byte offset $1bb98*2 of piece $1ca1c as the finish row.
; Preview screen pixel = projected point + (32,15) into the draw surface
; ($6a58c), 4 planes of 40 x 200 bytes; the preview frame's inner picture
; is x 15..309, y 10..143. Palette 15 is white and 8 black during preview.
;
; Only the call at $60532 is hooked. The hook walks the grid itself with
; the same instructions as $602e4 and reads the finish row after each
; completed piece, never inside the transform. Its state lives on the
; stack; nothing is written into code.

PREVIEW_ARROW_LIFT equ 3        ; pixels between the tip and the finish row

; Hook $60532 (JSR $602e4): the grid walk of $602e4, then the arrow on top.
; Registers on return equal those after $602e4. The caller's next
; instruction sets the flags.
; Stack frame during the walk: 0(sp) x.w, 2(sp) y.w, 4(sp) valid.w.
preview_arrow_draw:
        clr.w -(sp)             ; valid
        clr.l -(sp)             ; x, y
        move.b #$10,d2          ; $602e4 from here to .walked
.row:
        move.b #8,d1
        move.b #0,$1bb93
.right:
        jsr $60324
        bsr.w preview_arrow_capture
        subq.b #1,d1
        bne.s .right
        move.b #$f8,d1
        move.b #$80,$1bb93
.left:
        jsr $60324
        bsr.w preview_arrow_capture
        addq.b #1,d1
        bmi.s .left
        beq.s .left
        subq.b #1,d2
        bpl.s .row
.walked:
        movem.l d0-d7/a0-a2,-(sp)
        tst.w 44+4(sp)
        beq.s .done
        move.w 44(sp),d6
        addi.w #32-6,d6         ; left column of the 13 pixel wide mask
        move.w 44+2(sp),d7
        addi.w #15-PREVIEW_ARROW_LIFT-7,d7 ; top row; tip is row 7
        movea.l $6a58c,a1
        lea preview_arrow_mask(pc),a0
        moveq #7,d5             ; rows 0..7
.mask_row:
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
        bsr.w preview_arrow_pixel
.next:
        add.w d3,d3
        add.w d4,d4
        addq.w #1,d2
        cmpi.w #13,d2
        blo.s .column
        addq.w #1,d7
        dbra d5,.mask_row
.done:
        movem.l (sp)+,d0-d7/a0-a2
        addq.l #6,sp
        rts

; After a completed $60324: remember the finish row's projected centre in
; the caller's frame (x, y, valid at 4, 6 and 8 above the return address).
; A cell without a piece leaves $1bb85 and the tables of the previous
; piece, so a repeat capture reads the same centre. All registers and the
; caller's following flag-setting instruction are unaffected.
preview_arrow_capture:
        movem.l d0-d2/a0-a1,-(sp)
        lea 20+4(sp),a1         ; x, y, valid
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
        move.w d0,(a1)
        lea $1c0f0,a0
        move.w (a0,d1.w),d0
        add.w (a0,d2.w),d0
        asr.w #1,d0
        move.w d0,2(a1)
        move.w #1,4(a1)
.done:
        movem.l (sp)+,d0-d2/a0-a1
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
