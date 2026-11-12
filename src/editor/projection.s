; Race point projection with the camera fractions, the full height difference and rounding.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Race projection with the bits the game drops (drawing only).
;
; The game turns a point into two view angles: the horizontal one from its
; X/Z distance to the camera, the vertical one from the height difference
; and the horizontal distance. Before the angles are taken it drops
;   - the 12 low bits of the camera's X/Z position ($601f0: the point's
;     X/Z words are whole units),
;   - the two low bits of the height difference ($624d4; three at $65fbc
;     and $6604e, where the distance is in half units),
;   - the three low bits of each angle, by truncation ($624a8, $624fc).
; Here the same angles come from wide values: X/Z in 1/16 units with four
; bits of the camera fraction, the whole height difference, the distance in
; 1/16 units, and the angle rounded to its quarter pixel.
;
; Hooks:
;   $601f0 jsr -> proj_latch            the camera fraction of this frame
;   $6249c jmp -> proj_horizontal       near points, from $62454
;   $624c2 jmp -> proj_vertical         near points
;   $65f90 jmp -> proj_far_horizontal   far points, back to $65fa6
;   $65fb4 jmp -> proj_far_vertical     far points, back to $65fca
;   $66044 jmp -> proj_far_vertical2    far points, back to $66060
;
; Nothing the game keeps changes meaning: $1bbf6/$1bbf8, the camera bytes
; $1bb22..$1bb32 and the tables are only read, and $1bc36 still gets the
; whole-unit distance (half units on the far path). The wide distance is
; private and tagged with that word: a vertical step takes it only when
; $1bc36 still holds the tag, otherwise the word as before. The track
; preview ($1bb8f negative) runs the game's own code unchanged.
;
; Registers: D0/D3/D4/D5/D7 and A0 are scratch in the game's routines too;
; D2/D6/A1/A2 are saved. D1 is the point index. The last flags are those of
; the store, as in the game.

PROJ_HEADING equ $1bc2e         ; .w camera heading inside its quadrant
PROJ_PITCH equ $1bc42           ; .w camera pitch
PROJ_CAMERA_Y equ $1bbfa        ; .w camera height
PROJ_DISTANCE equ $1bc36        ; .w horizontal distance of the last point
PROJ_SPECIAL equ $1bb8f         ; .b negative: track preview
PROJ_HEIGHTS equ $1be70
PROJ_SCREEN_X equ $1bfb0
PROJ_SCREEN_Y equ $1c0f0
PROJ_CAMERA_X equ $1bccc        ; .l camera X in its sector frame, 4096 per unit
PROJ_CAMERA_Z equ $1bcd4
PROJ_FAR_X equ $65ec0           ; .w camera X offset of the far path, half units
PROJ_FAR_Z equ $65ec2
PROJ_ATAN_GAME equ $1cc46       ; the game's atan table, 2048 words
PROJ_DIST_GAME equ $1dc46       ; its distance table, 2048 words
PROJ_TABLE_WORDS equ 2048
; Copies of both tables in Fast memory (PROJ_ATAN_TABLE and PROJ_DIST_TABLE,
; build defines, Fast offsets): the atan one with its end value atan(1).
PROJ_DIST equ PROJ_DIST_TABLE-PROJ_ATAN_TABLE   ; from an atan entry to its distance entry
PROJ_DIST_END equ 27146         ; 65536*(sqrt(2)-1), the value after the table

proj_frac:      dc.w 0,0        ; camera X, Z: the top four dropped bits
proj_wide:      dc.l 0          ; distance, 16 times the word in $1bc36
proj_tag:       dc.w 0          ; that word
proj_tables:    dc.l 0          ; the atan copy

; $601f0: move.l $1bccc,d0. The fractions belong to the camera bytes the
; following code makes.
proj_latch:
        move.l a0,-(sp)
        lea proj_frac(pc),a0
        moveq #15,d0
        and.b PROJ_CAMERA_X+2,d0
        move.w d0,(a0)+
        moveq #15,d0
        and.b PROJ_CAMERA_Z+2,d0
        move.w d0,(a0)
        movea.l (sp)+,a0
        move.l PROJ_CAMERA_X,d0
        rts

; D0.w/D3.w: X/Z of the point in whole units.
proj_horizontal:
        movem.l d2/d6/a1-a2,-(sp)
        ext.l d0
        ext.l d3
        bsr proj_h_wide
        bsr proj_store_distance
        movem.l (sp)+,d2/d6/a1-a2
        rts

; D0.w/D3.w: X/Z of the far point before the game halves them. The camera
; offset is in half units; its dropped bit is the low bit of the camera byte.
proj_far_horizontal:
        movem.l d2/d6/a1-a2,-(sp)
        ext.l d0
        ext.l d3
        move.w PROJ_FAR_X,d2
        ext.l d2
        add.l d2,d2
        add.l d2,d0
        moveq #1,d2
        and.b $1bb23,d2
        add.l d2,d0
        move.w PROJ_FAR_Z,d2
        ext.l d2
        add.l d2,d2
        add.l d2,d3
        moveq #1,d2
        and.b $1bb27,d2
        add.l d2,d3
        bsr proj_h_wide
        lsr.l #1,d0             ; the word of this path is in half units
        bsr proj_store_distance
        movem.l (sp)+,d2/d6/a1-a2
        jmp $65fa6

; D0.l/D3.l X/Z in whole units -> the horizontal angle stored, D0.l the
; distance in 1/16 units.
proj_h_wide:
        asl.l #4,d0
        asl.l #4,d3
        lea proj_frac(pc),a1
        moveq #0,d2
        move.w (a1)+,d2
        sub.l d2,d0
        move.w (a1),d2
        sub.l d2,d3
        bsr proj_angle
        sub.w PROJ_HEADING,d0
        asr.w #3,d0
        moveq #0,d2
        addx.w d2,d0            ; round to the nearest, no wrap: at most 4096
        movea.l #PROJ_SCREEN_X,a0
        move.w d0,(a0,d1.w)
        ; Distance: larger + smaller*(sqrt(1+r*r)-1)/r, interpolated.
        adda.l #PROJ_DIST,a1
        move.w (a1),d0
        move.w #PROJ_DIST_END,d2
        cmpi.w #$ffe0,d7        ; the last entry: no word follows it
        bhs.s .last
        move.w 2(a1),d2
.last:  sub.w d0,d2
        moveq #31,d6
        and.w d7,d6
        mulu.w d6,d2
        addi.w #16,d2
        lsr.w #5,d2
        add.w d2,d0
        mulu.w d3,d0
        addi.l #$8000,d0
        clr.w d0
        swap d0
        swap d7
        moveq #0,d2
        move.w d7,d2
        add.l d2,d0
        move.w a2,d6
        lsl.l d6,d0
        rts

; D0.l: 16 times the distance word. Keeps it, and stores the word.
proj_store_distance:
        lea proj_wide(pc),a1
        move.l d0,(a1)+
        addq.l #8,d0
        lsr.l #4,d0
        cmpi.l #$7fff,d0
        bls.s .fits
        move.w #$7fff,d0        ; the reader is signed
.fits:  move.w d0,(a1)
        move.w d0,PROJ_DISTANCE
        rts

; D0.l/D3.l signed -> D0.w = atan2(D0,D3), 65536 per circle. Both are
; shifted down until they fit 16 bits; A2 counts the shifts. Leaves D7 =
; larger magnitude<<16 | ratio, D3.w the smaller one, A1 the atan entry.
proj_angle:
        suba.l a2,a2
        move.l d0,d4
        bpl.s .x_positive
        neg.l d0
.x_positive:
        swap d4                 ; sign words
        move.l d3,d5
        bpl.s .z_positive
        neg.l d3
.z_positive:
        swap d5
        move.l d0,d2
        or.l d3,d2
        bra.s .fit
.shift: lsr.l #1,d2
        lsr.l #1,d0
        lsr.l #1,d3
        addq.w #1,a2
.fit:   cmpi.l #$ffff,d2
        bhi.s .shift
        cmp.w d0,d3
        beq.s .equal
        bhi.s .z_larger
        move.l d3,d7
        swap d7
        divu.w d0,d7            ; smaller<<16 / larger: below 65536
        swap d7
        move.w d0,d7
        swap d7
        bsr proj_atan
        eor.w d4,d5
        bmi.s .x_opposite
        neg.w d0
.x_opposite:
        tst.w d4
        bmi.s .x_negative
        addi.w #$4000,d0
        rts
.x_negative:
        subi.w #$4000,d0
        rts
.equal: move.w d0,d7
        swap d7
        move.w #$ffff,d7
        movea.l proj_tables(pc),a1
        lea (PROJ_TABLE_WORDS-1)*2(a1),a1
        move.w #$2000,d0
        bra.s .quadrant
.z_larger:
        move.l d0,d7
        swap d7
        divu.w d3,d7
        swap d7
        move.w d3,d7
        swap d7
        move.w d0,d3
        bsr proj_atan
.quadrant:
        eor.w d5,d4
        bpl.s .same_sign
        neg.w d0
.same_sign:
        tst.w d5
        bpl.s .done
        addi.w #$8000,d0
.done:  rts

; D7.w ratio -> D0.w = atan(ratio/65536), 8192 = 45 degrees; A1 the entry.
proj_atan:
        move.w d7,d0
        lsr.w #4,d0
        andi.w #$ffe,d0
        movea.l proj_tables(pc),a1
        adda.w d0,a1
        move.w (a1),d0
        move.w 2(a1),d2
        sub.w d0,d2
        moveq #31,d6
        and.w d7,d6
        mulu.w d6,d2
        addi.w #16,d2
        lsr.w #5,d2
        add.w d2,d0
        rts

proj_vertical:
        tst.b PROJ_SPECIAL
        bmi.s .special
        movem.l d2/d6/a1-a2,-(sp)
        movea.l #PROJ_HEIGHTS,a0
        move.w (a0,d1.w),d0
        sub.w PROJ_CAMERA_Y,d0
        neg.w d0
        moveq #2,d6             ; a unit is four height units
        bsr proj_v_wide
        movem.l (sp)+,d2/d6/a1-a2
        rts
.special:
        movea.l #PROJ_HEIGHTS,a0
        jmp $624c8

; D0.w: the height of the far point, already stored.
proj_far_vertical:
        movem.l d2/d6/a1-a2,-(sp)
        sub.w PROJ_CAMERA_Y,d0
        neg.w d0
        moveq #1,d6             ; a half unit is eight height units
        bsr proj_v_wide
        movem.l (sp)+,d2/d6/a1-a2
        jmp $65fca

; The same far point at the height $200, in the slot $78 further.
proj_far_vertical2:
        movem.l d2/d6/a1-a2,-(sp)
        move.w PROJ_CAMERA_Y,d0
        subi.w #$200,d0
        addi.b #$78,d1
        moveq #1,d6
        bsr proj_v_wide
        movem.l (sp)+,d2/d6/a1-a2
        jmp $66060

; D0.w height difference, D6 its shift to 1/16 of the distance word.
proj_v_wide:
        ext.l d0
        asl.l d6,d0
        move.w PROJ_DISTANCE,d3
        lea proj_wide(pc),a1
        cmp.w 4(a1),d3
        bne.s .word
        move.l (a1),d3
        bra.s .angle
.word:  ext.l d3                ; not from the last horizontal step
        asl.l #4,d3
.angle: bsr proj_angle
        sub.w PROJ_PITCH,d0
        asr.w #3,d0
        moveq #0,d2
        addx.w d2,d0
        movea.l #PROJ_SCREEN_Y,a0
        move.w d0,(a0,d1.w)
        rts

; Screen border clipping of an edge ($668a8): the crossing point is
; distance*other/this. The game divides first and multiplies by the
; truncated quotient; the patches multiply first and round. A site row:
; address, the word sum of the game's 18 words there, the offset of its new
; code in the templates (one per register set).
PROJ_CLIP_WORDS equ 18
proj_clip_sites:
        include "proj-clip.s"

proj_clip_verify:
        lea proj_clip_sites(pc),a4
.site:  move.l (a4)+,d0
        beq.s .good
        movea.l d0,a0
        moveq #0,d0
        moveq #PROJ_CLIP_WORDS-1,d6
.sum:   add.w (a0)+,d0
        dbra d6,.sum
        cmp.w (a4)+,d0
        addq.l #2,a4            ; an address register: the flags stay
        beq.s .site
        moveq #0,d0
        rts
.good:  moveq #1,d0
        rts

; A5 = module base. The table copies, then the clip patches.
proj_install:
        lea PROJ_ATAN_TABLE(a5),a1
        lea proj_tables(pc),a0
        move.l a1,(a0)
        lea PROJ_ATAN_GAME,a0
        move.w #PROJ_TABLE_WORDS-1,d6
.atan:  move.w (a0)+,(a1)+
        dbra d6,.atan
        move.w #$2000,(a1)
        lea PROJ_DIST_TABLE(a5),a1
        lea PROJ_DIST_GAME,a0
        move.w #PROJ_TABLE_WORDS-1,d6
.dist:  move.w (a0)+,(a1)+
        dbra d6,.dist
        lea proj_clip_sites(pc),a4
.site:  move.l (a4)+,d0
        beq.s .done
        movea.l d0,a0
        addq.l #2,a4
        lea proj_clip_templates(pc),a1
        adda.w (a4)+,a1
        moveq #PROJ_CLIP_WORDS-1,d6
.copy:  move.w (a1)+,(a0)+
        dbra d6,.copy
        bra.s .site
.done:  rts
