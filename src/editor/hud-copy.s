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
HUD_CACHE equ $51000            ; Fast offset: 32-byte descriptors, then data
HUD_DATA equ HUD_CACHE+HUD_ITEMS*32
HUD_CACHE_END equ $5a000
HUD_PLANE equ 8000

; Descriptor: 0 source.l, 4 data.l, 8 width-1.w, 10 height-1.w,
; 12 pairs-1.w (-1: none), 14 lead word.b, 15 trail word.b,
; 16 source bytes.l (built height), 20 valid.b.
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
        movea.l a5,a3
        adda.l #HUD_CACHE,a3
        movea.l a5,a6
        adda.l #HUD_DATA,a6
        moveq #0,d7
.item:
        move.w d7,d0
        lsl.w #5,d0
        lea 0(a3,d0.w),a4
        moveq #7,d1
.clear: clr.l (a4)+
        dbra d1,.clear
        lea -32(a4),a4
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
        move.l d1,(a4)
        movea.l d1,a0
        lsl.w #2,d0
        movea.l #$6a16c,a1
        lea 4(a1,d0.w),a1
        move.w (a1),d2          ; width-1 in words
        cmpi.w #31,d2
        bhi .next
        move.w 2(a1),d3         ; height-1
        cmpi.w #199,d3
        bhi .next
        move.w d2,8(a4)
        move.w d3,10(a4)
        moveq #1,d4
        and.b 5(a1),d4          ; x word parity: odd x starts with one word
        move.b d4,14(a4)
        move.w d2,d5
        addq.w #1,d5
        sub.w d4,d5
        moveq #1,d6
        and.w d5,d6
        move.b d6,15(a4)
        lsr.w #1,d5
        subq.w #1,d5
        move.w d5,12(a4)
        move.w d2,d0
        addq.w #1,d0
        move.w d3,d1
        addq.w #1,d1
        mulu.w d1,d0            ; words
        move.l d0,d1
        mulu.w #10,d1
        move.l d1,16(a4)
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
        lea 10(a1),a1
        dbra d0,.check
        move.l a6,4(a4)
        movea.l a6,a2
        move.w d3,d6
.row:   tst.b 14(a4)
        beq.s .pairs
        bsr .word
.pairs: move.w 12(a4),d5
        bmi.s .trail
.pair:  move.w (a0),(a2)+       ; mask pair
        move.w 10(a0),(a2)+
        move.w 2(a0),(a2)+      ; plane 0 pair
        move.w 12(a0),(a2)+
        move.w 4(a0),(a2)+
        move.w 14(a0),(a2)+
        move.w 6(a0),(a2)+
        move.w 16(a0),(a2)+
        move.w 8(a0),(a2)+
        move.w 18(a0),(a2)+
        lea 20(a0),a0
        dbra d5,.pair
.trail: tst.b 15(a4)
        beq.s .rowdone
        bsr .word
.rowdone:
        dbra d6,.row
        movea.l a2,a6
        st 20(a4)
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
        lsl.w #5,d3
        adda.w d3,a3
        tst.b 20(a3)
        beq .fallback
        lsr.w #3,d3             ; item*4
        movea.l #$6a4ac,a4
        move.l 0(a4,d3.w),d5
        cmp.l (a3),d5
        bne .fallback
        lsl.w #2,d3
        movea.l #$6a16c,a4
        lea 4(a4,d3.w),a4
        move.w (a4),d1
        cmp.w 8(a3),d1
        bne .fallback
        move.w 2(a4),d4         ; $5e778 shortens the wheels per frame
        cmp.w 10(a3),d4
        bhi .fallback
        moveq #1,d5
        and.b 5(a4),d5
        cmp.b 14(a3),d5
        bne .parity
        moveq #0,d5
        move.b 5(a4),d5         ; x & $ff, words
        add.l d5,d5
        moveq #0,d3
        move.b 7(a4),d3         ; y & $ff
        mulu.w #40,d3
        movea.l $6a58c,a0
        adda.l d5,a0
        adda.l d3,a0
        movea.l 4(a3),a1
        moveq #-1,d2
        move.w d4,d7
.row:   movea.l a0,a2
        tst.b 14(a3)
        beq.s .pairs
        bsr hud_copy_word
.pairs: move.w 12(a3),d6
        bmi.s .trail
.pair:  move.l (a1)+,d5
        beq.s .opaque
        cmp.l d2,d5
        beq.s .clear
        move.l (a2),d0
        and.l d5,d0
        or.l (a1)+,d0
        move.l d0,(a2)
        move.l HUD_PLANE(a2),d0
        and.l d5,d0
        or.l (a1)+,d0
        move.l d0,HUD_PLANE(a2)
        move.l 2*HUD_PLANE(a2),d0
        and.l d5,d0
        or.l (a1)+,d0
        move.l d0,2*HUD_PLANE(a2)
        move.l 3*HUD_PLANE(a2),d0
        and.l d5,d0
        or.l (a1)+,d0
        move.l d0,3*HUD_PLANE(a2)
        addq.l #4,a2
        dbra d6,.pair
        bra.s .trail
.opaque:
        move.l (a1)+,(a2)
        move.l (a1)+,HUD_PLANE(a2)
        move.l (a1)+,2*HUD_PLANE(a2)
        move.l (a1)+,3*HUD_PLANE(a2)
        addq.l #4,a2
        dbra d6,.pair
        bra.s .trail
.clear: lea 16(a1),a1
        addq.l #4,a2
        dbra d6,.pair
.trail: tst.b 15(a3)
        beq.s .rowdone
        bsr hud_copy_word
.rowdone:
        lea 40(a0),a0
        dbra d7,.row
        lea -40(a0),a2          ; last row, as the original leaves A2
        move.w d1,d3
        add.w d3,d3
        lea 3*HUD_PLANE(a2),a4
        moveq #0,d0
        move.w 0(a4,d3.w),d0    ; last plane 3 word of the image
        addq.w #1,d1
        addq.w #1,d4
        mulu.w d4,d1
        mulu.w #10,d1
        movea.l (a3),a1
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
        move.w HUD_PLANE(a2),d0
        and.w d5,d0
        or.w (a1)+,d0
        move.w d0,HUD_PLANE(a2)
        move.w 2*HUD_PLANE(a2),d0
        and.w d5,d0
        or.w (a1)+,d0
        move.w d0,2*HUD_PLANE(a2)
        move.w 3*HUD_PLANE(a2),d0
        and.w d5,d0
        or.w (a1)+,d0
        move.w d0,3*HUD_PLANE(a2)
        addq.l #2,a2
        rts
.opaque:
        move.w (a1)+,(a2)
        move.w (a1)+,HUD_PLANE(a2)
        move.w (a1)+,2*HUD_PLANE(a2)
        move.w (a1)+,3*HUD_PLANE(a2)
        addq.l #2,a2
        rts
.clear: addq.l #8,a1
        addq.l #2,a2
        rts
