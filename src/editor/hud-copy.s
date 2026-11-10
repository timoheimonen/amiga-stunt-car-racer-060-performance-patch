; Draw HUD and cockpit images from a Fast RAM cache with the original result.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Masked HUD/cockpit image copy ($69f42) from a Fast cache.
; The original copies an image into the four draw planes word by word:
; for each plane dest = (dest AND mask) OR data, 13 Chip accesses per
; word with the interleaved image (mask, plane 0..3) in Chip at $6490.
; This copy produces the same planes: the images are converted once into
; row units of word pairs in Fast, the planes are updated as longs, fully
; transparent pairs (mask $ffffffff, data 0) are skipped and fully opaque
; pairs (mask 0) are written without reading the destination.
;
; Hooks (custom HOOKS, original bytes checked before install):
;   $1ba64 jsr $69cfc -> hud_build   original image build, then the cache
;   $69f42 move.l d5,-(sp) / move.w d1,-(sp) / movem.l a4-a6,-(sp)
;          -> hud_gate (JMP): calls of the HUD block on logic-only frame
;          steps are skipped, the rest go to hud_copy; anything not cached
;          runs the original.
; An image is cached only when every fully transparent mask word has zero
; plane data. A call is served from the cache only when the image pointer
; $6a4ac, the width and height and the x word parity in $6a16c still
; match the cached image and the height does not exceed it ($5e778 shortens
; the wheel images every frame; the original then draws their top rows).
; Positions are read at every call as before.
; Registers and CCR on return equal the original's: D0 = $0000 + last
; plane 3 word, D3 = $0000ffff, D4.w = $ffff, A0/A1/A2 as advanced by the
; original, D1/D5/A4-A6 preserved, CCR as after move.l (sp)+,d5.
HUD_ITEMS equ $34               ; image slots built by $69cfc (sprites excluded)
HUD_UNIT_BYTES equ 10           ; an image word: mask, planes 0..3
; The game's position entry of an image: $6a16c+HUD_POS+item*16.
HUD_POS equ 4
HUD_POS_WIDTH equ 0             ; .w width-1 in words
HUD_POS_HEIGHT equ 2            ; .w height-1
HUD_POS_X equ 5                 ; x & $ff, words
HUD_POS_Y equ 7                 ; y & $ff

; A descriptor of the cache, HUD_DESC_BYTES.
HUD_D_SOURCE equ 0              ; .l the image
HUD_D_DATA equ 4                ; .l its row units in the cache
HUD_D_WIDTH equ 8               ; .w width-1
HUD_D_HEIGHT equ 10             ; .w height-1
HUD_D_PAIRS equ 12              ; .w pairs-1 (-1: none)
HUD_D_LEAD equ 14               ; .b lead word
HUD_D_TRAIL equ 15              ; .b trail word
HUD_D_BYTES equ 16              ; .l source bytes (built height)
HUD_D_VALID equ 20              ; .b
HUD_DESC_SHIFT equ 5
HUD_DESC_BYTES equ 1<<HUD_DESC_SHIFT
; HUD_CACHE (a build define, Fast offset): the descriptors, then data,
; up to HUD_CACHE_END, where the editor stack follows.
HUD_DATA equ HUD_CACHE+HUD_ITEMS*HUD_DESC_BYTES

hud_fallbacks: dc.l 0           ; calls run by the original routine
hud_parity_fallbacks: dc.l 0    ; of which: x parity differs from the cache
hud_fallback_item: dc.b 0       ; image of the latest fallback
hud_ready: dc.b 0
        even

hud_build:
        jsr $69cfc.l
        move.w ccr,-(sp)
        movem.l d0-d7/a0-a6,-(sp)
        lea hud_ready(pc),a0
        clr.b (a0)
        lea module_start(pc),a5
        lea HUD_CACHE(a5),a3
        lea HUD_DATA(a5),a6
        moveq #0,d7
.item:
        move.w d7,d0
        lsl.w #HUD_DESC_SHIFT,d0
        lea 0(a3,d0.w),a4
        moveq #HUD_DESC_BYTES/4-1,d1
.clear: clr.l (a4)+
        dbra d1,.clear
        lea -HUD_DESC_BYTES(a4),a4
        cmpi.w #$25,d7          ; $25..$30 are sprite data ($69e30)
        blo.s .image
        cmpi.w #$30,d7
        bls .next
.image:
        move.w d7,d0
        lsl.w #2,d0
        movea.l #$6a4ac,a0
        move.l 0(a0,d0.w),d1
        beq .next
        move.l d1,HUD_D_SOURCE(a4)
        movea.l d1,a0
        lsl.w #2,d0
        movea.l #$6a16c,a1
        lea HUD_POS(a1,d0.w),a1
        move.w HUD_POS_WIDTH(a1),d2
        cmpi.w #31,d2
        bhi .next
        move.w HUD_POS_HEIGHT(a1),d3
        cmpi.w #SCREEN_ROWS-1,d3
        bhi .next
        move.w d2,HUD_D_WIDTH(a4)
        move.w d3,HUD_D_HEIGHT(a4)
        moveq #1,d4
        and.b HUD_POS_X(a1),d4  ; x word parity: odd x starts with one word
        move.b d4,HUD_D_LEAD(a4)
        move.w d2,d5
        addq.w #1,d5
        sub.w d4,d5
        moveq #1,d6
        and.w d5,d6
        move.b d6,HUD_D_TRAIL(a4)
        lsr.w #1,d5
        subq.w #1,d5
        move.w d5,HUD_D_PAIRS(a4)
        move.w d2,d0
        addq.w #1,d0
        move.w d3,d1
        addq.w #1,d1
        mulu.w d1,d0            ; words
        move.l d0,d1
        mulu.w #HUD_UNIT_BYTES,d1
        move.l d1,HUD_D_BYTES(a4)
        move.l a6,d4
        add.l d1,d4
        move.l a5,d6
        add.l #HUD_CACHE_END,d6
        cmp.l d6,d4
        bhi .next
        ; Skipping a transparent pair is exact only without plane data.
        movea.l a0,a1
        subq.w #1,d0
.check: cmpi.w #$ffff,(a1)
        bne.s .checked
        tst.l 2(a1)
        bne .next
        tst.l 6(a1)
        bne .next
.checked:
        lea HUD_UNIT_BYTES(a1),a1
        dbra d0,.check
        move.l a6,HUD_D_DATA(a4)
        movea.l a6,a2
        move.w d3,d6
.row:   tst.b HUD_D_LEAD(a4)
        beq.s .pairs
        bsr .word
.pairs: move.w HUD_D_PAIRS(a4),d5
        bmi.s .trail
.pair:  move.w (a0),(a2)+       ; mask pair
        move.w HUD_UNIT_BYTES(a0),(a2)+
        move.w 2(a0),(a2)+      ; plane 0 pair
        move.w HUD_UNIT_BYTES+2(a0),(a2)+
        move.w 4(a0),(a2)+
        move.w HUD_UNIT_BYTES+4(a0),(a2)+
        move.w 6(a0),(a2)+
        move.w HUD_UNIT_BYTES+6(a0),(a2)+
        move.w 8(a0),(a2)+
        move.w HUD_UNIT_BYTES+8(a0),(a2)+
        lea 2*HUD_UNIT_BYTES(a0),a0
        dbra d5,.pair
.trail: tst.b HUD_D_TRAIL(a4)
        beq.s .rowdone
        bsr .word
.rowdone:
        dbra d6,.row
        movea.l a2,a6
        st HUD_D_VALID(a4)
.next:  addq.w #1,d7
        cmpi.w #HUD_ITEMS,d7
        blo .item
        lea hud_ready(pc),a0
        st (a0)
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,ccr
        rts
.word:  move.l (a0)+,(a2)+
        move.l (a0)+,(a2)+
        move.w (a0)+,(a2)+
        rts

; Logic-only steps (auto_render_gate -> $650e2) run the HUD block
; $6510c..$651aa, whose images go to the hidden buffer. No swap follows a
; logic-only step, and the next drawn frame draws the same block again
; after its 3D view, before its swap, so these draws never reach the
; screen. They are skipped; the rest of the $650e2 path (wheel heights
; $5e778, turbo animation $1814d6, $5e508) still runs. Every other caller of
; $69f42 (damage holes, menus) and every drawn frame draws as before.
; On a skip D0 keeps its low word, D3 = $0000ffff and D4.w = $ffff as after
; the copy; the block reloads D0 before each call, $5e778 sets all it
; reads and $5e508 reads only D1, which the copy preserves.
HUD_GATE_FIRST equ $65112       ; return address of jsr $69f42 at $6510c
HUD_GATE_LAST equ $651b0        ; return address of jsr $69f42 at $651aa
hud_gate_skips: dc.l 0          ; skipped logic-step block calls

hud_gate:
        tst.b auto_nodraw(pc)
        beq hud_copy
        cmpi.l #HUD_GATE_FIRST,(sp)
        blo hud_copy
        cmpi.l #HUD_GATE_LAST,(sp)
        bhi hud_copy
        move.l a0,-(sp)
        lea hud_gate_skips(pc),a0
        addq.l #1,(a0)
        movea.l (sp)+,a0
        andi.l #$ffff,d0
        move.l #$ffff,d3
        move.w #-1,d4
        rts

hud_copy:
        movem.l d1-d2/d5-d7/a3-a6,-(sp)
        lea hud_ready(pc),a3
        tst.b (a3)
        beq .fallback
        moveq #0,d3
        move.b d0,d3
        cmpi.w #HUD_ITEMS,d3
        bhs .fallback
        lea module_start(pc),a3
        adda.l #HUD_CACHE,a3
        lsl.w #HUD_DESC_SHIFT,d3
        adda.w d3,a3
        tst.b HUD_D_VALID(a3)
        beq .fallback
        lsr.w #HUD_DESC_SHIFT-2,d3      ; item*4
        movea.l #$6a4ac,a4
        move.l 0(a4,d3.w),d5
        cmp.l HUD_D_SOURCE(a3),d5
        bne .fallback
        lsl.w #2,d3
        movea.l #$6a16c,a4
        lea HUD_POS(a4,d3.w),a4
        move.w HUD_POS_WIDTH(a4),d1
        cmp.w HUD_D_WIDTH(a3),d1
        bne .fallback
        move.w HUD_POS_HEIGHT(a4),d4    ; $5e778 shortens the wheels per frame
        cmp.w HUD_D_HEIGHT(a3),d4
        bhi .fallback
        moveq #1,d5
        and.b HUD_POS_X(a4),d5
        cmp.b HUD_D_LEAD(a3),d5
        bne .parity
        moveq #0,d5
        move.b HUD_POS_X(a4),d5
        add.l d5,d5
        moveq #0,d3
        move.b HUD_POS_Y(a4),d3
        mulu.w #SCREEN_ROW_BYTES,d3
        movea.l $6a58c,a0
        adda.l d5,a0
        adda.l d3,a0
        movea.l HUD_D_DATA(a3),a1
        moveq #-1,d2
        move.w d4,d7
.row:   movea.l a0,a2
        tst.b HUD_D_LEAD(a3)
        beq.s .pairs
        bsr hud_copy_word
.pairs: move.w HUD_D_PAIRS(a3),d6
        bmi.s .trail
.pair:  move.l (a1)+,d5
        beq.s .opaque
        cmp.l d2,d5
        beq.s .clear
        move.l (a2),d0
        and.l d5,d0
        or.l (a1)+,d0
        move.l d0,(a2)
        move.l SCREEN_PLANE_BYTES(a2),d0
        and.l d5,d0
        or.l (a1)+,d0
        move.l d0,SCREEN_PLANE_BYTES(a2)
        move.l 2*SCREEN_PLANE_BYTES(a2),d0
        and.l d5,d0
        or.l (a1)+,d0
        move.l d0,2*SCREEN_PLANE_BYTES(a2)
        move.l 3*SCREEN_PLANE_BYTES(a2),d0
        and.l d5,d0
        or.l (a1)+,d0
        move.l d0,3*SCREEN_PLANE_BYTES(a2)
        addq.l #4,a2
        dbra d6,.pair
        bra.s .trail
.opaque:
        move.l (a1)+,(a2)
        move.l (a1)+,SCREEN_PLANE_BYTES(a2)
        move.l (a1)+,2*SCREEN_PLANE_BYTES(a2)
        move.l (a1)+,3*SCREEN_PLANE_BYTES(a2)
        addq.l #4,a2
        dbra d6,.pair
        bra.s .trail
.clear: lea 16(a1),a1
        addq.l #4,a2
        dbra d6,.pair
.trail: tst.b HUD_D_TRAIL(a3)
        beq.s .rowdone
        bsr hud_copy_word
.rowdone:
        lea SCREEN_ROW_BYTES(a0),a0
        dbra d7,.row
        lea -SCREEN_ROW_BYTES(a0),a2       ; last row, as the original leaves A2
        move.w d1,d3
        add.w d3,d3
        lea 3*SCREEN_PLANE_BYTES(a2),a4
        moveq #0,d0
        move.w 0(a4,d3.w),d0    ; last plane 3 word of the image
        addq.w #1,d1
        addq.w #1,d4
        mulu.w d4,d1
        mulu.w #HUD_UNIT_BYTES,d1
        movea.l HUD_D_SOURCE(a3),a1
        adda.l d1,a1            ; source advanced over the drawn words
        move.l #$ffff,d3
        move.w #-1,d4
        movem.l (sp)+,d1-d2/d5-d7/a3-a6
        tst.l d5
        rts
.parity:                        ; $6092a moves the damage hole images
        lea hud_parity_fallbacks(pc),a3
        addq.l #1,(a3)
.fallback:
        lea hud_fallbacks(pc),a3
        addq.l #1,(a3)
        move.b d0,hud_fallback_item-hud_fallbacks(a3)
        movem.l (sp)+,d1-d2/d5-d7/a3-a6
        move.l d5,-(sp)
        move.w d1,-(sp)
        movem.l a4-a6,-(sp)
        jmp $69f4a.l

; One word unit: A1 cache, A2 destination; D5/D0 scratch.
hud_copy_word:
        move.w (a1)+,d5
        beq.s .opaque
        cmp.w d2,d5
        beq.s .clear
        move.w (a2),d0
        and.w d5,d0
        or.w (a1)+,d0
        move.w d0,(a2)
        move.w SCREEN_PLANE_BYTES(a2),d0
        and.w d5,d0
        or.w (a1)+,d0
        move.w d0,SCREEN_PLANE_BYTES(a2)
        move.w 2*SCREEN_PLANE_BYTES(a2),d0
        and.w d5,d0
        or.w (a1)+,d0
        move.w d0,2*SCREEN_PLANE_BYTES(a2)
        move.w 3*SCREEN_PLANE_BYTES(a2),d0
        and.w d5,d0
        or.w (a1)+,d0
        move.w d0,3*SCREEN_PLANE_BYTES(a2)
        addq.l #2,a2
        rts
.opaque:
        move.w (a1)+,(a2)
        move.w (a1)+,SCREEN_PLANE_BYTES(a2)
        move.w (a1)+,2*SCREEN_PLANE_BYTES(a2)
        move.w (a1)+,3*SCREEN_PLANE_BYTES(a2)
        addq.l #2,a2
        rts
.clear: addq.l #8,a1
        addq.l #2,a2
        rts
