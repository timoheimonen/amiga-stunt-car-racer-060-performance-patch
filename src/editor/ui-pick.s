; Choose track sections on the editor bar.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Track Editor bar: the Choose page picks a section by Turn, Slope and word.
; A cell of pal_cell is class<<6 | turn<<4 | slope<<2 | place.
UI_INFO_NO_ROUTE equ $f0
UI_CLICK_SLOPE equ 3
UI_CLICK_WORD equ 7
UI_CELL_AXES equ $fc
UI_CALL_SECTION equ 11
UI_CALL_WORD equ 18
UI_SLOTS equ 4
BLOCK_MAX_PIECES equ EDITOR_MAX_PIECES

; D3 cell, D4 mask of the cell, D5 mask of the place -> D0 best candidate, -1 for
; none. The lowest key wins: rank<<2 | place, rank 0 fits with a route, 1 fits, 2
; is rejected. The first of equal keys stays.
ui_best:
        movem.l d1-d2/d6-d7/a0-a2,-(sp)
        lea block_candidates(pc),a0
        lea block_info(pc),a1
        lea pal_cell(pc),a2
        moveq #-1,d0
        moveq #-1,d6
        moveq #0,d7
.loop:  cmp.w building_candidate_count(pc),d7
        bhs.s .done
        move.w (a0)+,d1
        lsr.w #2,d1
        move.b (a2,d1.w),d1
        move.b d1,d2
        and.b d4,d2
        cmp.b d3,d2
        bne.s .next
        and.w d5,d1
        move.b (a1,d7.w),d2
        cmpi.b #UI_INFO_NO_ROUTE,d2
        beq.s .no_route
        andi.b #7,d2
        beq.s .key
        moveq #8,d2
        bra.s .key
.no_route:
        moveq #4,d2
.key:   or.b d2,d1
        cmp.w d6,d1
        bhs.s .next
        move.w d1,d6
        move.w d7,d0
.next:  addq.w #1,d7
        bra.s .loop
.done:  movem.l (sp)+,d1-d2/d6-d7/a0-a2
        rts

; First listed section that fits with a route, then the first that fits.
ui_default_pick:
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        bsr.s ui_best
        move.w d0,building_choice-module_start(a5)
        rts

; D2.b cell with place 0. Z set when the table has a section there.
ui_filled:
        lea pal_cell(pc),a0
        moveq #BLOCK_VARIANT_COUNT/4-1,d0
.loop:  move.b (a0)+,d5
        andi.b #UI_CELL_AXES,d5
        cmp.b d2,d5
        dbeq d0,.loop
        rts

; D0 click: 0-2 Left Ahead Right, 3-6 Flat Up Down Jump, 7-10 a word.
; -> D0 the new choice, the same one when nothing changes.
ui_pick:
        movem.l d1-d5/a0-a1,-(sp)
        move.w d0,d2
        move.w building_choice(pc),d0
        add.w d0,d0
        lea block_candidates(pc),a0
        move.w (a0,d0.w),d0
        lsr.w #2,d0
        lea pal_cell(pc),a0
        move.b (a0,d0.w),d3
        moveq #UI_CELL_AXES-256,d4
        cmpi.w #UI_CLICK_WORD,d2
        bhs.s .word
        move.b d3,d1
        andi.b #$c0,d3
        cmpi.w #UI_CLICK_SLOPE,d2
        bhs.s .slope
        lsl.b #4,d2
        andi.b #$0c,d1
        lea ui_slopes(pc),a1
        bra.s .axis
.slope: subq.w #UI_CLICK_SLOPE,d2
        lsl.b #2,d2
        andi.b #$30,d1
        lea ui_turns(pc),a1
.axis:  or.b d2,d3
.try:   move.b d3,d2
        or.b d1,d2
        bsr.s ui_filled
        beq.s .hit
        move.b (a1)+,d1
        bpl.s .try
        bra.s .same
.hit:   move.b d2,d3
.pick:  moveq #3,d5
        bsr ui_best
        tst.w d0
        bpl.s .out
.same:  move.w building_choice(pc),d0
.out:   movem.l (sp)+,d1-d5/a0-a1
        rts
.word:  subq.w #UI_CLICK_WORD,d2
        andi.b #UI_CELL_AXES,d3
        or.b d2,d3
        moveq #-1,d4
        bra.s .pick
ui_turns: dc.b $10,$00,$20,-1
ui_slopes: dc.b $00,$04,$0c,$08,-1
        even

; A row of the Choose page, D0 its CALL index.
ui_call_section:
        subi.w #UI_CALL_SECTION,d0
        bsr ui_pick
        cmp.w building_choice(pc),d0
        beq.s .same
        move.w d0,building_choice-module_start(a5)
        move.w #1,building_preview_due-module_start(a5)
.same:  rts

; D0.b cell -> D0.b its Turn bit and its Slope bit.
ui_axis_bits:
        movem.l d1-d2,-(sp)
        move.b d0,d1
        lsr.b #2,d1
        andi.w #3,d1
        addq.w #3,d1
        lsr.b #4,d0
        andi.w #3,d0
        moveq #0,d2
        bset d0,d2
        bset d1,d2
        move.l d2,d0
        movem.l (sp)+,d1-d2
        rts

; After the scan. ui_axis_fill: the table has that Turn or Slope for this tail.
; ui_axis_green: a closing candidate has it. Bits 0-2 Left Ahead Right, 3-6 Flat
; Up Down Jump.
ui_axes:
        movem.l d0-d5/a0-a2,-(sp)
        moveq #0,d3
        moveq #0,d4
        lea pal_cell(pc),a2
        tst.w building_candidate_count-module_start(a5)
        beq.s .store
        move.w block_candidates(pc),d0
        lsr.w #2,d0
        move.b (a2,d0.w),d2
        andi.b #$c0,d2
        moveq #BLOCK_VARIANT_COUNT/4-1,d1
.fill:  move.b (a2)+,d0
        move.b d0,d5
        andi.b #$c0,d5
        cmp.b d2,d5
        bne.s .fill_next
        bsr ui_axis_bits
        or.b d0,d3
.fill_next:
        dbra d1,.fill
        lea pal_cell(pc),a2
        lea block_candidates(pc),a0
        lea block_info(pc),a1
        move.w building_candidate_count(pc),d1
        subq.w #1,d1
.green: move.w (a0)+,d0
        btst #3,(a1)+
        beq.s .green_next
        lsr.w #2,d0
        move.b (a2,d0.w),d0
        bsr ui_axis_bits
        or.b d0,d4
.green_next:
        dbra d1,.green
.store: move.b d3,ui_axis_fill-module_start(a5)
        move.b d4,ui_axis_green-module_start(a5)
        movem.l (sp)+,d0-d5/a0-a2
        rts

; Each paint of the page: the axes of the choice and the four words of its cell.
ui_choose_state:
        clr.b ui_axis_now-module_start(a5)
        lea ui_slot_states(pc),a0
        move.l #$ffffffff,(a0)
        move.w building_candidate_count(pc),d7
        beq .done
        move.w building_choice(pc),d0
        add.w d0,d0
        lea block_candidates(pc),a0
        move.w (a0,d0.w),d0
        lsr.w #2,d0
        lea pal_cell(pc),a1
        move.b (a1,d0.w),d4
        move.b d4,d0
        bsr ui_axis_bits
        move.b d0,ui_axis_now-module_start(a5)
        andi.b #UI_CELL_AXES,d4
        moveq #0,d5
.slot:  move.b d4,d3
        or.b d5,d3
        lea pal_cell(pc),a1
        moveq #BLOCK_VARIANT_COUNT/4-1,d0
.find:  cmp.b (a1)+,d3
        dbeq d0,.find
        bne .next
        move.l a1,d1
        lea pal_cell+1(pc),a1
        sub.l a1,d1
        lea pal_word(pc),a1
        moveq #0,d3
        move.b (a1,d1.w),d3
        lsl.b #4,d3
        lea ui_slot_blocks(pc),a1
        move.b d1,(a1,d5.w)
        ; Where on the list, if at all.
        lea block_candidates(pc),a0
        moveq #0,d6
.list:  move.w (a0)+,d0
        lsr.w #2,d0
        cmp.w d1,d0
        beq.s .listed
        addq.w #1,d6
        cmp.w d7,d6
        blo.s .list
        moveq #-1,d6
        moveq #UI_DISABLED,d0
        bra.s .state
.listed:
        lea block_info(pc),a0
        move.b (a0,d6.w),d2
        moveq #UI_NORMAL,d0
        btst #3,d2
        beq.s .fits
        moveq #UI_STATE_GREEN,d0
.fits:  cmp.w building_choice(pc),d6
        bne.s .other
        addq.b #UI_ACTIVE,d0
        bra.s .state
.other: andi.b #7,d2
        beq.s .state
        moveq #UI_DISABLED,d0
.state: or.b d0,d3
        lea ui_slot_states(pc),a0
        move.b d3,(a0,d5.w)
        lea ui_slot_places(pc),a0
        move.b d6,(a0,d5.w)
.next:  addq.w #1,d5
        cmpi.w #UI_SLOTS,d5
        blo .slot
.done:  rts

; A3 a word row -> D0 its candidate, negative when it is not on the list.
ui_slot_candidate:
        moveq #0,d0
        move.b UI_ENTRY_ACTION(a3),d0
        subi.w #UI_CALL_WORD,d0
        lea ui_slot_places(pc),a0
        move.b (a0,d0.w),d0
        ext.w d0
        rts

; A3 a dimmed word row -> A0 why.
ui_slot_reason:
        movem.l d1/a4,-(sp)
        bsr.s ui_slot_candidate
        bmi.s .unlisted
        lea block_info(pc),a0
        moveq #7,d1
        and.b (a0,d0.w),d1
        bra.s .text
.unlisted:
        moveq #0,d0
        move.b UI_ENTRY_ACTION(a3),d0
        subi.w #UI_CALL_WORD,d0
        lea ui_slot_blocks(pc),a0
        moveq #0,d1
        move.b (a0,d0.w),d1
        move.w d1,d0
        lsl.w #2,d0
        bsr block_descriptor
        move.w (a4),d0
        add.w block_insert(pc),d0
        add.w block_original_track+28(pc),d0
        sub.w block_suffix(pc),d0
        moveq #0,d1
        cmpi.w #BLOCK_MAX_PIECES,d0
        bls.s .text
        moveq #1,d1
.text:  add.w d1,d1
        lea hud_fail_texts(pc),a0
        adda.w (a0,d1.w),a0
        movem.l (sp)+,d1/a4
        rts

ui_axis_fill: dc.b 0
ui_axis_green: dc.b 0
ui_axis_now: dc.b 0
        even
ui_slot_states: dcb.b UI_SLOTS,UI_HIDDEN
ui_slot_places: dcb.b UI_SLOTS,0
ui_slot_blocks: dcb.b UI_SLOTS,0
        even
