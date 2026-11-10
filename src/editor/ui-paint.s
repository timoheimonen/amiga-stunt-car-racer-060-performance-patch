; Paint the pages and buttons of the editor bar.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Track Editor bar: pages and buttons. ui_paint works out what every row of the
; table should look like and draws only the rows that changed. The row layout
; UI_ENTRY_*, the kinds UI_KIND_*, the flags UI_FLAG_* and their bits UI_BIT_*,
; UI_LIST_WIDTH and UI_BAR_TOP come from the builder.
UI_VIEW_LINES equ VIEW_BOTTOM-VIEW_TOP  ; the 3D view, from the top of the screen
UI_HIDDEN equ $ff
; A row state: word<<4 | green<<3 | button state.
UI_STATE_MASK equ 7
UI_BIT_GREEN equ 3
UI_STATE_GREEN equ 1<<UI_BIT_GREEN
; The list's Prev and Next as selections: values that are not slots.
UI_LIST_SLOT_PREVIOUS equ STORAGE_SLOTS
UI_LIST_SLOT_NEXT equ STORAGE_SLOTS+1

; The page the state shows now -> D0.
ui_page_now:
        move.w storage_modal(pc),d0
        beq.s .prompt
        cmpi.w #STORAGE_CUSTOM_LIST,d0
        beq.s .list
        cmpi.w #STORAGE_MODAL_NAME,d0
        blo.s .list
        beq.s .name
        move.w #UI_PAGE_REPLACE,d0
        rts
.name:  moveq #UI_PAGE_NAME,d0
        rts
.list:  moveq #UI_PAGE_LIST,d0
        rts
.prompt:
        move.w editing_prompt(pc),d0
        beq.s .mode
        cmpi.w #1,d0
        bne.s .guard
        moveq #UI_PAGE_NEW,d0
        rts
.guard: moveq #UI_PAGE_GUARD,d0
        rts
.mode:  tst.w place_active-module_start(a5)
        beq.s .building
        moveq #UI_PAGE_PLACE,d0
        rts
.building:
        tst.w building_mode-module_start(a5)
        beq.s .main
        move.w #UI_PAGE_CHOOSE|UI_PAGE_CHOOSE_NEW,d0
        cmpi.l #SCTR_BLOCKS_REVISION,editor_track+SCTR_REVISION-module_start(a5)
        bhs.s .done
        move.w #UI_PAGE_CHOOSE|UI_PAGE_CHOOSE_OLD,d0
        rts
.main:  moveq #UI_PAGE_BROWSE,d0
.done:  rts

ui_paint:
        movem.l d0-d7/a0-a4,-(sp)
        clr.b ui_yield_flag-module_start(a5)
        bsr ui_page_now
        cmp.w ui_page(pc),d0
        beq.s .page
        move.w d0,ui_page-module_start(a5)
        move.w #1,ui_moved-module_start(a5)
        move.l ui_ms(pc),d1
        addi.l #UI_PAGE_MS,d1
        move.l d1,ui_page_end-module_start(a5)
.page:  move.w ui_page(pc),d0
        andi.w #UI_PAGE_CHOOSE_NEW,d0
        beq.s .states
        bsr ui_choose_state
.states:
        lea ui_rows(pc),a3
        lea ui_plain(pc),a4
        moveq #0,d7
.state: cmpi.w #-1,(a3)
        beq.s .changed
        bsr ui_row_state
        cmp.b (a4),d0
        beq.s .same
        move.b d0,(a4)
        moveq #1,d7
.same:  addq.l #1,a4
        lea UI_ENTRY_BYTES(a3),a3
        bra.s .state
.changed:
        ; A row that changed may be the one the text of the pointer speaks of.
        tst.w d7
        beq.s .hover
        move.w #1,ui_moved-module_start(a5)
.hover: bsr.s ui_paint_rows
        movem.l (sp)+,d0-d7/a0-a4
        rts

; From the row states of the last paint: the row under the pointer lit, and what
; changed drawn. On a hover that is two rows at most.
ui_paint_rows:
        bsr ui_hover
        moveq #0,d7
        lea ui_rows(pc),a3
        lea ui_plain(pc),a0
        lea ui_wanted(pc),a4
        lea ui_drawn(pc),a2
.want:  cmpi.w #-1,(a3)
        beq.s .wanted
        move.b (a0)+,d0
        cmpa.l ui_hover_row(pc),a3
        bne.s .plain
        bsr ui_lit
.plain: move.b d0,(a4)+
        cmp.b (a2)+,d0
        beq.s .kept_row
        moveq #1,d7
.kept_row:
        lea UI_ENTRY_BYTES(a3),a3
        bra.s .want
.wanted:
        tst.w d7
        beq .done
        ; A row leaves before the rows that take its place arrive.
        lea ui_rows(pc),a3
        lea ui_wanted(pc),a4
        lea ui_drawn(pc),a2
.leave: cmpi.w #-1,(a3)
        beq.s .arrive_start
        move.b (a2),d0
        cmp.b (a4)+,d0
        beq.s .kept
        cmpi.b #UI_HIDDEN,d0
        beq.s .kept
        bsr ui_erase_row
        move.b #UI_HIDDEN,(a2)
.kept:  addq.l #1,a2
        lea UI_ENTRY_BYTES(a3),a3
        bra.s .leave
.arrive_start:
        lea ui_rows(pc),a3
        lea ui_wanted(pc),a4
        lea ui_drawn(pc),a2
.arrive:
        cmpi.w #-1,(a3)
        beq.s .done
        move.b (a4)+,d0
        cmp.b (a2),d0
        beq.s .next
        move.b d0,(a2)
        bsr ui_draw_row
.next:  addq.l #1,a2
        lea UI_ENTRY_BYTES(a3),a3
        bra.s .arrive
.done:  rts

; In a long render or scan the pointer keeps lighting its row. This acts on
; nothing: the states are those of the last paint, and a press waits for the
; main loop. A5 stays the module base through the three loops that call it.
ui_yield:
        movem.l d0-d7/a0-a6,-(sp)
        clr.b ui_yield_flag-module_start(a5)
        bsr ui_paint_rows
        tst.w ui_line_due-module_start(a5)
        beq.s .done
        bsr ui_l2_show
.done:  movem.l (sp)+,d0-d7/a0-a6
        rts

; D0 state of the row under the pointer -> its lit state.
ui_lit: move.b d0,d1
        andi.b #UI_STATE_MASK,d1
        cmpi.b #UI_NORMAL,d1
        beq.s .lit
        cmpi.b #UI_DEFAULT,d1
        bne.s .done
.lit:   addq.b #1,d0
.done:  rts

; The pointer moved or the page changed: the row under the pointer, its text
; and, over the list, the selection.
ui_hover:
        tst.w ui_moved-module_start(a5)
        beq .done
        clr.w ui_moved-module_start(a5)
        suba.l a3,a3
        suba.l a0,a0
        tst.w ui_ptr_hidden-module_start(a5)
        bne.s .found
        move.w ui_ptr_x(pc),d0
        move.w ui_ptr_y(pc),d1
        bsr ui_find_row
        bne.s .row
        suba.l a3,a3
        suba.l a0,a0
        bra.s .found
.row:   move.b (a2),d0
        bsr ui_row_text
.found: cmpa.l ui_hover_row(pc),a3
        beq.s .same
        ; The pointer went on: what was said of the last row is over.
        clr.l ui_said-module_start(a5)
.same:  move.l a3,ui_hover_row-module_start(a5)
        cmpa.l ui_hover_text(pc),a0
        beq.s .list
        move.l a0,ui_hover_text-module_start(a5)
        move.w #1,ui_line_due-module_start(a5)
.list:  move.l a3,d0
        bne.s .kind
        bsr.s ui_view_hint
        bra.s .off
.kind:  move.b UI_ENTRY_FLAGS(a3),d0
        andi.b #UI_KIND_MASK,d0
        cmpi.b #UI_KIND_LIST,d0
        bne.s .off
        move.w ui_ptr_y(pc),d0
        cmp.w ui_list_y(pc),d0
        beq.s .done
        move.w d0,ui_list_y-module_start(a5)
        bsr ui_list_slot
        move.w d0,storage_slot-module_start(a5)
        bra.s .done
.off:   move.w #-1,ui_list_y-module_start(a5)
.done:  rts

; The first time the pointer goes over the view, L2 says how to look around.
; Only for a while: the pointer rests here, and L2 has its own work.
ui_view_hint:
        tst.w ui_view_told-module_start(a5)
        bne.s .done
        tst.w ui_ptr_hidden-module_start(a5)
        bne.s .done
        cmpi.w #UI_VIEW_LINES,ui_ptr_y-module_start(a5)
        bhs.s .done
        bsr ui_page_now
        andi.w #FREE_PAGES,d0
        beq.s .done
        move.w #1,ui_view_told-module_start(a5)
        lea ui_text_view(pc),a0
        bra ui_say
.done:  rts

; A3 row, D0 its state -> A0 what L2 says of it, 0 for nothing of its own.
ui_row_text:
        andi.b #UI_STATE_MASK,d0
        cmpi.b #UI_DISABLED,d0
        bne.s .hint
        moveq #0,d0
        move.b UI_ENTRY_PRED(a3),d0
        cmpi.b #UI_PRED_SLOT,d0
        beq ui_slot_reason
        add.w d0,d0
        lea ui_reason_table(pc),a0
        move.w (a0,d0.w),d0
        bmi.s .hint
        beq.s .none
        adda.w d0,a0
        rts
.hint:  moveq #0,d0
        move.b UI_ENTRY_HINT(a3),d0
        add.w d0,d0
        lea ui_hint_table(pc),a0
        adda.w (a0,d0.w),a0
        tst.b (a0)
        bne.s .done
.none:  suba.l a0,a0
.done:  rts

; D0 x, D1 y -> A3 row and A2 its state, Z clear; Z set when no row is there.
; Reads what ui_paint worked out, so it needs nothing of the track.
ui_find_row:
        lea ui_rows(pc),a3
        lea ui_plain(pc),a2
.row:   move.w (a3),d2
        bmi.s .none
        bsr.s ui_row_hit
        beq.s .next
        move.w UI_ENTRY_PAGES(a3),d2
        and.w ui_page(pc),d2
        beq.s .next
        move.b UI_ENTRY_FLAGS(a3),d2
        andi.b #UI_KIND_MASK,d2
        cmpi.b #UI_KIND_LIST,d2
        beq.s .found
        cmpi.b #UI_HIDDEN,(a2)
        bne.s .found
        ; The status word is text, not a button, and speaks when it says Ready.
        cmpi.b #UI_PRED_WORD,UI_ENTRY_PRED(a3)
        bne.s .next
        cmpi.b #UI_KIND_INFO,d2
        bne.s .next
        cmpi.b #'R',ui_shown_word-module_start(a5)
        beq.s .found
.next:  addq.l #1,a2
        lea UI_ENTRY_BYTES(a3),a3
        bra.s .row
.found: moveq #1,d2
        rts
.none:  moveq #0,d2
        rts

; D0 x, D1 y, A3 row -> Z set when the point is outside. Keeps D0 and D1.
ui_row_hit:
        move.w (a3),d2
        cmp.w d2,d0
        blo.s .out
        moveq #0,d3
        move.b UI_ENTRY_W(a3),d3
        bne.s .width
        move.w #UI_LIST_WIDTH,d3
.width: add.w d3,d2
        cmp.w d2,d0
        bhs.s .out
        moveq #0,d2
        move.b UI_ENTRY_Y(a3),d2
        cmp.w d2,d1
        blo.s .out
        moveq #0,d3
        move.b UI_ENTRY_H(a3),d3
        add.w d3,d2
        cmp.w d2,d1
        bhs.s .out
        moveq #1,d2
        rts
.out:   moveq #0,d2
        rts

; A3 row -> D0 button state or UI_HIDDEN.
ui_row_state:
        move.w UI_ENTRY_PAGES(a3),d0
        and.w ui_page(pc),d0
        beq.s .hidden
        move.b UI_ENTRY_FLAGS(a3),d0
        andi.b #UI_KIND_MASK,d0
        cmpi.b #UI_KIND_LIST,d0
        beq.s .hidden
        moveq #0,d0
        move.b UI_ENTRY_PRED(a3),d0
        add.w d0,d0
        lea ui_predicates(pc),a0
        adda.w (a0,d0.w),a0
        jmp (a0)
.hidden:
        move.w #UI_HIDDEN,d0
        rts

ui_pred_plain:
        moveq #UI_NORMAL,d0
        rts
ui_pred_default:
        moveq #UI_DEFAULT,d0
        rts
ui_pred_word:
        move.w #UI_HIDDEN,d0
        rts
; Finish: hidden on an older track, dimmed on a closed one.
ui_pred_finish:
        cmpi.l #SCTR_BLOCKS_REVISION,editor_track+SCTR_REVISION-module_start(a5)
        blo ui_pred_word
        tst.w editor_track+SCTR_CLOSED-module_start(a5)
        bne ui_dim
        bra ui_pred_plain
ui_pred_placed:
        tst.w place_active-module_start(a5)
        bne ui_dim
        bra ui_pred_plain
ui_pred_start:
        bsr place_valid
        beq ui_dim
        bra ui_pred_default
ui_pred_undo:
        tst.w place_active-module_start(a5)
        bne ui_dim
        tst.w editing_undo_count-module_start(a5)
        beq ui_dim
        move.w ui_page(pc),d0
        andi.w #UI_PAGE_CHOOSE,d0
        beq ui_pred_plain
        tst.w building_candidate_count-module_start(a5)
        beq ui_pred_default
        bra ui_pred_plain
ui_dim: moveq #UI_DISABLED,d0
        rts
ui_pred_redo:
        tst.w place_active-module_start(a5)
        bne ui_dim
        tst.w editing_redo_count-module_start(a5)
        beq ui_dim
        bra ui_pred_plain
ui_pred_delete:
        tst.w editor_gap-module_start(a5)
        bne ui_pred_word
        cmpi.w #1,editor_track+SCTR_COUNT-module_start(a5)
        bls ui_dim
        bsr ui_cut_here
        bne ui_pred_word
        bra ui_pred_plain
; Del with a gap open: it takes the section before the gap, from the Add slot or
; that section. Elsewhere on Browse it waits for the gap.
ui_pred_gap:
        tst.w editor_gap-module_start(a5)
        beq ui_pred_word
        cmpi.w #UI_PAGE_BROWSE,ui_page-module_start(a5)
        bne ui_pred_plain
        bsr editing_cut_start
        tst.w d0
        bmi ui_dim
        bra ui_pred_plain
ui_pred_cut:
        tst.w editor_gap-module_start(a5)
        bne ui_pred_word
        bsr ui_cut_here
        beq ui_pred_word
        move.w building_selected(pc),d0
        bsr block_group_start
        tst.w d0
        beq ui_dim
        bra ui_pred_plain
; Z clear with a section selected on Browse past the start that is not the last.
ui_cut_here:
        cmpi.w #UI_PAGE_BROWSE,ui_page-module_start(a5)
        bne.s .no
        cmpi.l #SCTR_BLOCKS_REVISION,editor_track+SCTR_REVISION-module_start(a5)
        blo.s .no
        move.w building_selected(pc),d0
        beq.s .no
        moveq #1,d4
        bsr block_browse_step
        cmp.w editor_track+SCTR_COUNT(pc),d0
        blo.s .yes
.no:    moveq #0,d0
        rts
.yes:   moveq #1,d0
        rts
ui_pred_test:
        cmpi.w #UI_PAGE_BROWSE,ui_page-module_start(a5)
        bne ui_dim
        cmpi.w #PRACTICE_READY,practice_class-module_start(a5)
        bne ui_dim
        bra ui_pred_default
ui_pred_direction:
        cmpi.w #UI_PAGE_BROWSE,ui_page-module_start(a5)
        bne ui_dim
ui_pred_add_slot:
        tst.w editor_track+SCTR_CLOSED-module_start(a5)
        bne ui_pred_word
        move.w building_selected(pc),d0
        cmp.w editor_track+SCTR_COUNT(pc),d0
        blo ui_pred_word
        bra ui_pred_plain
ui_pred_add:
        move.w building_selected(pc),d0
        cmp.w editor_track+SCTR_COUNT(pc),d0
        blo ui_pred_word
        tst.w editor_track+SCTR_CLOSED-module_start(a5)
        bne ui_dim
        bra ui_pred_default
ui_pred_edit:
        move.w building_selected(pc),d0
        cmp.w editor_track+SCTR_COUNT(pc),d0
        bhs ui_pred_word
        cmpi.w #PRACTICE_READY,practice_class-module_start(a5)
        beq ui_pred_plain
        bra ui_pred_default
ui_pred_place:
        tst.w building_candidate_count-module_start(a5)
        beq ui_dim
        cmpi.l #SCTR_BLOCKS_REVISION,editor_track+SCTR_REVISION-module_start(a5)
        blo ui_pred_default
        tst.w block_preview_valid-module_start(a5)
        beq ui_dim
        bra ui_pred_default
ui_pred_next:
        move.w building_selected(pc),d0
        moveq #1,d4
        cmpi.l #SCTR_BLOCKS_REVISION,editor_track+SCTR_REVISION-module_start(a5)
        blo.s .single
        bsr block_browse_ui
        bra.s .end
.single:
        addq.w #1,d0
.end:   move.w editor_track+SCTR_COUNT(pc),d1
        sub.w editor_track+SCTR_CLOSED(pc),d1
        cmp.w d1,d0
        bhi ui_dim
        cmp.w building_selected(pc),d0
        beq ui_dim
        bra ui_pred_plain
; The Turn and Slope rows: lit on the current cell, green with a closing section.
ui_pred_axis:
        moveq #0,d1
        move.b UI_ENTRY_ACTION(a3),d1
        subi.w #UI_CALL_SECTION,d1
        move.b ui_axis_fill(pc),d0
        btst d1,d0
        beq ui_dim
        moveq #UI_NORMAL,d0
        move.b ui_axis_green(pc),d2
        btst d1,d2
        beq.s .current
        moveq #UI_STATE_GREEN,d0
.current:
        move.b ui_axis_now(pc),d2
        btst d1,d2
        beq.s .done
        addq.b #UI_ACTIVE,d0
.done:  rts
ui_pred_slot:
        moveq #0,d1
        move.b UI_ENTRY_ACTION(a3),d1
        subi.w #UI_CALL_WORD,d1
        lea ui_slot_states(pc),a0
        move.b (a0,d1.w),d0
        rts
ui_pred_slot_previous:
        cmpi.w #UI_LIST_SLOT_PREVIOUS,storage_slot-module_start(a5)
        bne ui_pred_plain
        moveq #UI_ACTIVE,d0
        rts
ui_pred_slot_next:
        cmpi.w #UI_LIST_SLOT_NEXT,storage_slot-module_start(a5)
        bne ui_pred_plain
        moveq #UI_ACTIVE,d0
        rts

; A3 row -> D1 x, D2 bar y, D3 width, D6 height.
ui_row_rect:
        move.w (a3),d1
        moveq #0,d2
        move.b UI_ENTRY_Y(a3),d2
        subi.w #UI_BAR_TOP,d2
        moveq #0,d3
        move.b UI_ENTRY_W(a3),d3
        moveq #0,d6
        move.b UI_ENTRY_H(a3),d6
        rts

; The default frame stands one pixel outside the button. A key underline sits
; below the glyphs, which on a low button (Finish) is the row under it.
ui_erase_row:
        bsr ui_row_rect
        btst #UI_BIT_FRAMED,UI_ENTRY_FLAGS(a3)
        beq.s .plain
        subq.w #1,d1
        subq.w #1,d2
        addq.w #2,d3
        addq.w #2,d6
        bra.s .erase
.plain: lea ui_labels(pc),a0
        adda.w UI_ENTRY_LABEL(a3),a0
.mark:  move.b (a0)+,d0
        beq.s .erase
        cmpi.b #$ff,d0
        beq.s .erase
        cmpi.b #UI_KEY_MARK,d0
        bne.s .mark
        move.w d6,d0
        subq.w #UI_GLYPH_ROWS,d0
        asr.w #1,d0
        addi.w #UI_GLYPH_ROWS+2,d0
        cmp.w d6,d0
        bls.s .erase
        move.w d0,d6
.erase: lea ui_commands(pc),a0
        move.w #UI_RECT,(a0)+
        move.w d1,(a0)+
        move.w d2,(a0)+
        move.w d3,(a0)+
        move.w d6,(a0)+
        move.w #UI_PANEL,(a0)+
        bra ui_run_commands

; A3 row, D0 state.
ui_draw_row:
        cmpi.b #UI_HIDDEN,d0
        beq.s .done
        move.w d0,d4
        move.w d0,d5
        bsr ui_row_rect
        lea ui_commands(pc),a0
        move.w #UI_BUTTON_AT,(a0)+
        move.w d1,(a0)+
        move.w d2,(a0)+
        move.w d3,(a0)+
        move.w d6,(a0)+
        andi.w #UI_STATE_MASK,d5
        move.w d5,(a0)+
        lea ui_labels(pc),a1
        adda.w UI_ENTRY_LABEL(a3),a1
        cmpi.b #UI_PRED_SLOT,UI_ENTRY_PRED(a3)
        bne.s .label
        move.w d4,d0
        lsr.b #4,d0
        andi.w #15,d0
        lea pal_word_at(pc),a1
        move.b (a1,d0.w),d0
        andi.w #255,d0
        lea pal_words(pc),a1
        adda.w d0,a1
.label: move.l a1,(a0)+
        move.w #UI_END,(a0)
        lea ui_commands(pc),a0
        lea ui_bar_target(pc),a1
        btst #UI_BIT_RED,UI_ENTRY_FLAGS(a3)
        beq.s .green
        lea ui_bar_target_red(pc),a1
.green: btst #UI_BIT_GREEN,d4
        beq.s .draw
        lea ui_bar_target_green(pc),a1
.draw:  moveq #0,d1
        bsr ui_service
.done:  rts

; After the bar is cleared no row is on it.
ui_paint_reset:
        lea ui_drawn(pc),a0
        lea ui_plain(pc),a1
        move.w #UI_ROW_COUNT-1,d0
.row:   move.b #UI_HIDDEN,(a0)+
        move.b #UI_HIDDEN,(a1)+
        dbra d0,.row
        clr.l ui_hover_row-module_start(a5)
        clr.l ui_hover_text-module_start(a5)
        move.w #-1,ui_list_y-module_start(a5)
        clr.w ui_page-module_start(a5)
        move.w #1,ui_map_dirty-module_start(a5)
        rts

ui_view_told: dc.w 0
ui_yield_flag: dc.b 0
        even
ui_hover_row: dc.l 0
ui_hover_text: dc.l 0
ui_list_y: dc.w -1
ui_page: dc.w 0
ui_plain: dcb.b UI_ROW_COUNT,0
ui_wanted: dcb.b UI_ROW_COUNT,0
ui_drawn: dcb.b UI_ROW_COUNT,0
        even
