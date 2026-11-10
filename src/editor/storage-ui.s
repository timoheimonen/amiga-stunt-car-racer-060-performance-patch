; Handle track save and load menus, slot selection and names.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; The slot catalog: one 64-byte row per slot (storage_entry_fill) in Fast at
; STORAGE_CATALOG, read from the track files once a session. While WHDLoad
; runs the game only the editor changes them, and a Save updates its row, so
; later lists open from the catalog without file access.
storage_entry:
        move.w storage_slot(pc),d0
; D0 slot -> A3 its row; D0 changes.
storage_entry_of:
        andi.l #$ffff,d0
        lsl.l #CATALOG_ROW_SHIFT,d0
        lea STORAGE_CATALOG(a5),a3
        adda.l d0,a3
        rts

; A list shows a page of STORAGE_PAGE rows. A selection from STORAGE_SLOTS on is
; an action of the list, such as UI_LIST_SLOT_PREVIOUS.
STORAGE_PAGE_SHIFT equ 4
STORAGE_PAGE equ 1<<STORAGE_PAGE_SHIFT
; storage_modal: 0, or the dialog that is open. The lists come before the name.
STORAGE_MODAL_SAVE equ 1                ; the list, to save
STORAGE_MODAL_LOAD equ 2                ; the list, to load
STORAGE_MODAL_NAME equ 3                ; the name of a saved track
STORAGE_MODAL_REPLACE equ 4             ; an occupied slot, to confirm
STORAGE_CUSTOM_LIST equ 5               ; the Custom Tracks list

; The open list's rows -> D0: every slot, or in the Custom Tracks list the
; custom_count Ready tracks of custom_slots.
storage_rows:
        move.w #STORAGE_SLOTS,d0
        cmpi.w #STORAGE_CUSTOM_LIST,storage_modal-module_start(a5)
        bne.s .done
        move.w custom_count(pc),d0
.done:  rts
; D0 a row of the open list -> D0 its slot.
storage_row_slot:
        cmpi.w #STORAGE_CUSTOM_LIST,storage_modal-module_start(a5)
        bne.s .done
        move.l a0,-(sp)
        lea custom_slots(pc),a0
        add.w d0,d0
        move.w (a0,d0.w),d0
        movea.l (sp)+,a0
.done:  rts

storage_catalog_scan:
        clr.w editor_view_valid-module_start(a5)
        tst.w storage_catalog_valid-module_start(a5)
        bne .done
        move.w #EDITOR_INPUT_HOLDOFF,editor_input_holdoff-module_start(a5)
        bsr storage_backup
        move.w storage_slot(pc),-(sp)
        lea STORAGE_CATALOG(a5),a0
        move.w #STORAGE_SLOTS*CATALOG_ROW/4-1,d1
.wipe:  clr.l (a0)+
        dbra d1,.wipe
        bsr storage_listing
        clr.w storage_slot-module_start(a5)
.loop:
        bsr storage_entry
        move.w storage_slot(pc),d0
        tst.w CATALOG_LISTED(a3)
        beq.s .bundled
        bsr storage_slot_read
        bra.s .read
.bundled:
        bsr storage_bundled_read
.read:  bgt.s .file
        movea.l a3,a0
        moveq #CATALOG_ROW/4-1,d1
.clear: clr.l (a0)+
        dbra d1,.clear
        tst.l d0
        beq.s .next
        move.w #CLASS_UNUSABLE,CATALOG_CLASS(a3) ; too large to be a track file
        bra.s .next
.file:
        bsr storage_buffer
        movea.l a1,a4
        bsr storage_entry_fill
.next:
        addq.w #1,storage_slot-module_start(a5)
        cmpi.w #STORAGE_SLOTS,storage_slot-module_start(a5)
        blo.s .loop
        move.w (sp)+,storage_slot-module_start(a5)
        bsr storage_restore
        move.w #1,storage_catalog_valid-module_start(a5)
        bsr editor_model_view
.done:
        moveq #0,d0
        rts

; Modal: 1 save list, 2 load list, 3 name, 4 overwrite.
storage_open_save:
        tst.w editor_gap-module_start(a5)
        beq.s .save
        clr.w storage_continue-module_start(a5)
        lea ui_reason_gap(pc),a0
        bra ui_refuse
.save:  moveq #STORAGE_MODAL_SAVE,d6
        bra.s storage_open
storage_open_load:
        clr.w storage_continue-module_start(a5)
        moveq #STORAGE_MODAL_LOAD,d6
storage_open:
        bsr ui_choose_end
        clr.w storage_status-module_start(a5)
        movem.l d6,-(sp)
        bsr storage_catalog_scan
        movem.l (sp)+,d6
        move.w d6,storage_modal-module_start(a5)
        move.w storage_active_slot(pc),d0
        bpl.s .select
        moveq #0,d0
        cmpi.w #STORAGE_MODAL_SAVE,d6
        bne.s .select
        bsr.s storage_first_empty
.select:
        move.w d0,storage_slot-module_start(a5)
        andi.w #-STORAGE_PAGE,d0
        move.w d0,storage_page-module_start(a5)
        clr.w storage_typed-module_start(a5)
.done:
        rts

; A track without a slot saves to the first free one, else to the first.
storage_first_empty:
        moveq #0,d0
        lea STORAGE_CATALOG(a5),a0
.free:  tst.w CATALOG_CLASS(a0)
        beq.s .found
        adda.w #CATALOG_ROW,a0
        addq.w #1,d0
        cmpi.w #STORAGE_SLOTS,d0
        blo.s .free
        moveq #0,d0
.found: rts

storage_modal_keys:
        cmpi.b #KEY_DOWN,editor_input_keys+$45(a5)
        beq .cancel
        cmpi.w #STORAGE_MODAL_NAME,storage_modal-module_start(a5)
        beq storage_name_keys
        cmpi.b #KEY_DOWN,editor_input_keys+$44(a5)
        beq .confirm
        cmpi.b #KEY_DOWN,editor_input_keys+$40(a5)       ; Space
        beq .confirm
        btst #EDITOR_INPUT_FIRE,editor_input_keys+EDITOR_INPUT_JOY(a5)
        bne .confirm
        cmpi.w #STORAGE_MODAL_REPLACE,storage_modal-module_start(a5)
        beq .done
        bsr storage_digit_keys
        bne .done
        move.w editor_directions(pc),d0
        moveq #-STORAGE_PAGE,d4
        btst #2,d0              ; left: the previous page
        bne storage_turn_page
        moveq #STORAGE_PAGE,d4
        btst #3,d0              ; right: the next page
        bne storage_turn_page
        moveq #-1,d4
        btst #0,d0              ; up
        bne.s .move
        moveq #1,d4
        btst #1,d0              ; down
        beq .done
.move:
        clr.w storage_typed-module_start(a5)
        ; Map global slot/action to the visible row (STORAGE_PAGE tracks + actions).
        move.w storage_slot(pc),d0
        cmpi.w #STORAGE_SLOTS,d0
        bhs.s .action_row
        sub.w storage_page(pc),d0
        bra.s .advance
.action_row:
        subi.w #STORAGE_SLOTS-STORAGE_PAGE,d0
.advance:
        add.w d4,d0
        moveq #18,d1
        tst.w d0
        bpl.s .upper
        move.w d1,d0
        subq.w #1,d0
.upper:
        cmp.w d1,d0
        blo.s .selected
        clr.w d0
.selected:
        cmpi.w #STORAGE_PAGE,d0
        bhs.s .action_slot
        ; Past the last row of a short list: Down goes on to Prev, Up to the last row.
        move.w d0,d1
        add.w storage_page(pc),d1
        move.w d0,-(sp)
        bsr storage_rows
        move.w d0,d2
        move.w (sp)+,d0
        cmp.w d2,d1
        blo.s .row
        moveq #STORAGE_PAGE,d0
        tst.w d4
        bpl.s .action_slot
        move.w d2,d0
        subq.w #1,d0
        sub.w storage_page(pc),d0
        bpl.s .row
        moveq #STORAGE_PAGE,d0
        bra.s .action_slot
.row:   add.w storage_page(pc),d0
        bra.s .store
.action_slot:
        addi.w #STORAGE_SLOTS-STORAGE_PAGE,d0
.store:
        move.w d0,storage_slot-module_start(a5)
        bra editor_release
.confirm:
        clr.w storage_typed-module_start(a5)
        cmpi.w #UI_LIST_SLOT_PREVIOUS,storage_slot-module_start(a5)
        beq .previous_page
        cmpi.w #UI_LIST_SLOT_NEXT,storage_slot-module_start(a5)
        beq .next_page
        bsr editor_release
        cmpi.w #STORAGE_CUSTOM_LIST,storage_modal-module_start(a5)
        beq storage_pick
        cmpi.w #STORAGE_MODAL_REPLACE,storage_modal-module_start(a5)
        beq storage_begin_name
        bsr storage_entry
        cmpi.w #CLASS_UNUSABLE,CATALOG_CLASS(a3)
        beq .invalid
        cmpi.w #STORAGE_MODAL_LOAD,storage_modal-module_start(a5)
        beq.s .load
        tst.l (a3)
        beq storage_begin_name
        ; Always confirm occupied slots: safe even for two distinct drafts
        ; whose imported legacy IDs happen to match.
        move.w #STORAGE_MODAL_REPLACE,storage_modal-module_start(a5)
        rts
.load:
        bsr editor_load
        cmpi.w #STORAGE_SAY_LOADED,storage_status-module_start(a5)
        bne.s .done
        clr.w storage_modal-module_start(a5)
        rts
.previous_page:
        moveq #-STORAGE_PAGE,d4
        bra.s storage_turn_page
.next_page:
        moveq #STORAGE_PAGE,d4
        bra.s storage_turn_page
.invalid:
        move.w #STORAGE_SAY_LOAD_FAILED,storage_status-module_start(a5)
.done:
        rts
.cancel:
        bsr editor_release
        cmpi.w #STORAGE_CUSTOM_LIST,storage_modal-module_start(a5)
        bne.s .close
        clr.w custom_picked-module_start(a5)
        move.w #1,building_exit-module_start(a5)
.close: clr.w storage_modal-module_start(a5)
        clr.w storage_continue-module_start(a5)
        ; Dirty-action prompt remains underneath a cancelled/failed Save.
        rts

; D4 -STORAGE_PAGE or STORAGE_PAGE: the previous or the next page, round. A
; selected row keeps its place on the page; a selected Prev or Next stays
; selected.
storage_turn_page:
        clr.w storage_typed-module_start(a5)
        bsr storage_rows
        move.w d0,d3
        move.w d0,d2
        subq.w #1,d2
        andi.w #-STORAGE_PAGE,d2          ; the last page
        move.w storage_page(pc),d0
        add.w d4,d0
        bpl.s .low
        move.w d2,d0
.low:   cmp.w d2,d0
        bls.s .page
        moveq #0,d0
.page:  move.w storage_slot(pc),d1
        cmpi.w #STORAGE_SLOTS,d1
        bhs.s .keep
        sub.w storage_page(pc),d1
        add.w d0,d1
        cmp.w d3,d1
        blo.s .slot
        move.w d3,d1
        subq.w #1,d1
.slot:  move.w d1,storage_slot-module_start(a5)
.keep:  move.w d0,storage_page-module_start(a5)
        bra editor_release

; Custom Tracks: the selected Ready track goes on to the game's mode menu.
storage_pick:
        bsr storage_rows
        cmp.w storage_slot(pc),d0
        bls.s .none
        move.w storage_slot(pc),custom_index-module_start(a5)
        move.w storage_slot(pc),d0
        bsr storage_row_slot
        addq.w #1,d0
        move.w d0,custom_picked-module_start(a5)
        clr.w storage_modal-module_start(a5)
        move.w #1,building_exit-module_start(a5)
.none:  rts

; D1 slot -> D1 the first row of the Custom Tracks list at or after it, or
; its last row.
storage_custom_row:
        movem.l d0/d2/a0,-(sp)
        lea custom_slots(pc),a0
        moveq #0,d2
.find:  cmp.w custom_count(pc),d2
        bhs.s .last
        cmp.w (a0)+,d1
        bls.s .found
        addq.w #1,d2
        bra.s .find
.last:  move.w custom_count(pc),d2
        subq.w #1,d2
.found: move.w d2,d1
        movem.l (sp)+,d0/d2/a0
        rts

; A digit key in a list types a slot number: up to three digits select that
; slot and its page, and a further digit or a number above the last slot
; starts a new one. D0 = 1 (flags set) if a digit was taken.
storage_digit_keys:
        movem.l d1-d2/a0-a1,-(sp)
        lea editor_input_keys(a5),a1
        moveq #1,d1
.key:   cmpi.b #KEY_DOWN,(a1,d1.w)
        beq.s .digit
        addq.w #1,d1
        cmpi.w #10,d1
        bls.s .key
        moveq #0,d0
        bra.s .done
.digit: lea storage_keymap(pc),a0
        moveq #0,d2
        move.b (a0,d1.w),d2
        subi.w #'0',d2
        move.w storage_typed(pc),d0
        moveq #0,d1
        tst.w d0
        beq.s .more
        move.w storage_typed_value(pc),d1
        cmpi.w #3,d0
        blo.s .more
        moveq #0,d0
        moveq #0,d1
.more:  mulu.w #10,d1
        add.w d2,d1
        cmpi.w #STORAGE_SLOTS,d1
        bls.s .fits
        moveq #0,d0
        move.w d2,d1
.fits:  addq.w #1,d0
        move.w d0,storage_typed-module_start(a5)
        move.w d1,storage_typed_value-module_start(a5)
        subq.w #1,d1
        bmi.s .taken            ; 0 or 00 so far
        cmpi.w #STORAGE_CUSTOM_LIST,storage_modal-module_start(a5)
        bne.s .slot
        bsr storage_custom_row
.slot:  move.w d1,storage_slot-module_start(a5)
        andi.w #-STORAGE_PAGE,d1
        move.w d1,storage_page-module_start(a5)
.taken: bsr editor_release
        moveq #1,d0
.done:  movem.l (sp)+,d1-d2/a0-a1
        tst.l d0
        rts

storage_begin_name:
        lea editor_track+SCTR_NAME(pc),a0
        lea storage_name(pc),a1
        moveq #SCTR_NAME_BYTES,d0
        bsr storage_copy
        lea storage_name(pc),a0
        moveq #0,d0
.length:
        tst.b (a0)+
        beq.s .ready
        addq.w #1,d0
        cmpi.w #SCTR_NAME_BYTES,d0
        blo.s .length
.ready:
        move.w d0,storage_name_length-module_start(a5)
        clr.w storage_name_default-module_start(a5)
        tst.w d0
        beq.s .default
        lea storage_name(pc),a0
        lea storage_untitled(pc),a1
.same:  cmpm.b (a0)+,(a1)+
        bne.s .named
        tst.b -1(a1)
        bne.s .same
.default:
        lea storage_name(pc),a1
        lea storage_track_text(pc),a0
        moveq #4,d0
.word:  move.b (a0)+,(a1)+
        dbra d0,.word
        move.w storage_slot(pc),d0
        bsr storage_number
        clr.b (a1)
        move.w #8,storage_name_length-module_start(a5)
        move.w #1,storage_name_default-module_start(a5)
.named:
        move.w #STORAGE_MODAL_NAME,storage_modal-module_start(a5)
        rts
storage_name_keys:
        cmpi.b #KEY_DOWN,editor_input_keys+$44(a5)       ; Return ends text entry; Space types a space
        beq storage_name_commit
        btst #EDITOR_INPUT_FIRE,editor_input_keys+EDITOR_INPUT_JOY(a5)
        bne storage_name_commit
        cmpi.b #KEY_DOWN,editor_input_keys+$41(a5)
        beq.s .backspace
        lea storage_keymap(pc),a0
        lea editor_input_keys(a5),a1
        moveq #0,d4
.search:
        cmpi.b #KEY_DOWN,(a1)+
        bne.s .next
        moveq #0,d5
        move.b (a0,d4.w),d5
        beq.s .next
        ; The first typed character replaces a default name.
        tst.w storage_name_default-module_start(a5)
        beq.s .typed
        clr.w storage_name_default-module_start(a5)
        clr.w storage_name_length-module_start(a5)
        lea storage_name(pc),a0
        moveq #SCTR_NAME_BYTES/4-1,d0
.wipe:  clr.l (a0)+
        dbra d0,.wipe
.typed:
        move.w storage_name_length(pc),d0
        cmpi.w #SCTR_NAME_BYTES,d0
        bhs editor_release
        lea storage_name(pc),a0
        move.b d5,(a0,d0.w)
        addq.w #1,storage_name_length-module_start(a5)
        bra editor_release
.next:
        addq.w #1,d4
        cmpi.w #65,d4
        blo.s .search
        rts
.backspace:
        clr.w storage_name_default-module_start(a5)
        move.w storage_name_length(pc),d0
        beq editor_release
        subq.w #1,d0
        move.w d0,storage_name_length-module_start(a5)
        lea storage_name(pc),a0
        clr.b (a0,d0.w)
        bra editor_release
storage_name_commit:
        bsr editor_release
        tst.w storage_name_length-module_start(a5)
        beq .done
        move.w #STORAGE_SAY_SAVE_FAILED,storage_status-module_start(a5)
        ; Save has its own scan backup. This separate snapshot preserves RAM
        ; bytes and dirty state if a renamed save cannot commit.
        lea editor_track(pc),a0
        lea storage_ui_backup(pc),a1
        move.w #EDITOR_TRACK_BYTES,d0
        bsr storage_copy
        lea storage_name(pc),a0
        lea editor_track+SCTR_NAME(pc),a1
        moveq #SCTR_NAME_BYTES,d0
        bsr storage_copy
        ; A track saved to another slot gets an identity of its own: SCIE,
        ; the slot, one more than the number of the SCIE track it replaces.
        move.w storage_slot(pc),d0
        cmp.w storage_active_slot(pc),d0
        beq.s .identity_done
        bsr storage_entry
        moveq #1,d0
        cmpi.l #ID_SCIE,CATALOG_IDENTITY(a3)
        bne.s .identity
        move.l CATALOG_IDENTITY+8(a3),d0
        addq.l #1,d0
        bne.s .identity
        moveq #1,d0
.identity:
        move.l #ID_SCIE,editor_track+SCTR_IDENTITY-module_start(a5)
        moveq #0,d1
        move.w storage_slot(pc),d1
        move.l d1,editor_track+SCTR_IDENTITY+4-module_start(a5)
        move.l d0,editor_track+SCTR_IDENTITY+8-module_start(a5)
        move.l #$56303901,editor_track+SCTR_IDENTITY+12-module_start(a5)
.identity_done:
        bsr editor_model_refresh
        bsr editor_save
        cmpi.w #STORAGE_SAY_SAVED,storage_status-module_start(a5)
        beq.s .success
.rollback:
        lea storage_ui_backup(pc),a0
        lea editor_track(pc),a1
        move.w #EDITOR_TRACK_BYTES,d0
        bsr storage_copy
        bsr editor_model_view
        rts
.success:
        clr.w storage_modal-module_start(a5)
        tst.w storage_continue-module_start(a5)
        beq.s .done
        clr.w storage_continue-module_start(a5)
        bra editing_execute
.done:
        rts

; Opaque modal screen, 16 rows at 8 pixels/row. 40 columns, ASCII 5x7.
storage_modal_text:
        tst.w storage_modal-module_start(a5)
        beq .done
        movea.l draw_surface(pc),a0
        move.w #7999,d0
.clear:
        clr.l (a0)+
        dbra d0,.clear
        bsr storage_page_text
        move.l d5,-(sp)
        move.w storage_slot(pc),-(sp)
        move.w storage_page(pc),storage_slot-module_start(a5)
.row:
        lea storage_line(pc),a0
        moveq #37,d0
.blank:
        move.b #32,(a0)+
        dbra d0,.blank
        clr.b (a0)
        bsr storage_rows
        cmp.w storage_slot(pc),d0
        bls .next_row           ; past the end of a short list
        move.w storage_slot(pc),d0
        bsr storage_row_slot
        move.w d0,d5
        bsr storage_entry_of
        lea storage_line(pc),a0
        move.w storage_slot(pc),d0
        cmp.w (sp),d0
        bne.s .number
        move.b #62,(a0)
.number:
        move.w d5,d0
        lea 1(a0),a1
        bsr storage_number
        lea storage_empty(pc),a2
        cmpi.w #CLASS_UNUSABLE,CATALOG_CLASS(a3)
        bne.s .available
        lea storage_damaged(pc),a2
        tst.w CATALOG_NEWER(a3)
        beq.s .available
        lea storage_newer(pc),a2
.available:
        tst.l CATALOG_KIND(a3)
        beq.s .label
        lea CATALOG_NAME(a3),a2
.label:
        lea 5(a0),a1
        moveq #SCTR_NAME_BYTES-1,d0
        ; storage_text_line shows legacy lower case with the uppercase font.
.name:
        move.b (a2)+,d1
        beq.s .state
        move.b d1,(a1)+
        dbra d0,.name
.state:
        cmpi.w #STORAGE_CUSTOM_LIST,storage_modal-module_start(a5)
        beq.s .draw             ; every row of Custom Tracks is Ready
        lea storage_draft(pc),a2
        cmpi.w #CLASS_READY,CATALOG_CLASS(a3)
        bne.s .invalid
        lea storage_ready(pc),a2
.invalid:
        cmpi.w #CLASS_UNUSABLE,CATALOG_CLASS(a3)
        bne.s .status
        lea storage_invalid(pc),a2
.status:
        tst.w CATALOG_CLASS(a3)
        beq.s .draw
        lea 30(a0),a1
.copy_state:
        move.b (a2)+,(a1)+
        bne.s .copy_state
.draw:
        move.w storage_slot(pc),d4
        sub.w storage_page(pc),d4
        mulu.w #320,d4
        addi.w #1442,d4
        movea.l draw_surface(pc),a1
        adda.w d4,a1
        bsr storage_text_line
.next_row:
        addq.w #1,storage_slot-module_start(a5)
        move.w storage_slot(pc),d0
        sub.w storage_page(pc),d0
        cmpi.w #STORAGE_PAGE,d0
        blo .row
        move.w (sp)+,storage_slot-module_start(a5)
        move.l (sp)+,d5
        lea storage_list_help(pc),a0
        cmpi.w #STORAGE_CUSTOM_LIST,storage_modal-module_start(a5)
        bne.s .overwrite
        lea storage_custom_help(pc),a0
.overwrite:
        cmpi.w #STORAGE_MODAL_REPLACE,storage_modal-module_start(a5)
        bne.s .name_prompt
        lea storage_overwrite(pc),a0
.name_prompt:
        cmpi.w #STORAGE_MODAL_NAME,storage_modal-module_start(a5)
        bne.s .help
        lea storage_name_help(pc),a0
.help:
        moveq #UI_SAY_PROMPT,d0
        bsr ui_status_put
        cmpi.w #STORAGE_MODAL_NAME,storage_modal-module_start(a5)
        bne.s .done
        lea storage_name(pc),a0
        movea.l draw_surface(pc),a1
        adda.w #6722,a1
        bsr storage_text_line
.done:
        rts
; L1 in a list: "Save track, page 3/32".
storage_page_text:
        lea hud_line(pc),a1
        lea storage_save_title(pc),a0
        cmpi.w #STORAGE_MODAL_LOAD,storage_modal-module_start(a5)
        bne.s .custom
        lea storage_load_title(pc),a0
.custom:
        cmpi.w #STORAGE_CUSTOM_LIST,storage_modal-module_start(a5)
        bne.s .title
        lea storage_custom_title(pc),a0
.title: bsr text_append
        lea storage_page_label(pc),a0
        bsr text_append
        move.w storage_page(pc),d0
        lsr.w #STORAGE_PAGE_SHIFT,d0
        addq.w #1,d0
        bsr text_decimal
        move.b #'/',(a1)+
        bsr storage_rows
        addi.w #STORAGE_PAGE-1,d0
        lsr.w #STORAGE_PAGE_SHIFT,d0
        bne.s .pages
        moveq #1,d0
.pages: bsr text_decimal
        clr.b (a1)
        lea hud_line(pc),a0
        bra ui_name_put

; D0 slot -> its number, three digits, at A1, which advances.
storage_number:
        movem.l d0,-(sp)
        andi.l #$ffff,d0
        addq.l #1,d0
        divu.w #100,d0
        addi.b #'0',d0
        move.b d0,(a1)+
        clr.w d0
        swap d0
        divu.w #10,d0
        addi.b #'0',d0
        move.b d0,(a1)+
        swap d0
        addi.b #'0',d0
        move.b d0,(a1)+
        movem.l (sp)+,d0
        rts
storage_page_label: dc.b ', page ',0
storage_save_title: dc.b 'Save track',0
storage_load_title: dc.b 'Load track',0
storage_custom_title: dc.b 'Custom Tracks',0
storage_list_help: dc.b 'Up/Down, Left/Right page, number: slot.',0
storage_custom_help: dc.b 'Fire drives. Left/Right page, number: slot.',0
storage_overwrite: dc.b 'Replace this track? Fire or Space.',0
storage_name_help: dc.b 'Type a name. Return or Fire saves it.',0
storage_empty: dc.b 'EMPTY',0
storage_damaged: dc.b 'UNREADABLE',0
storage_newer: dc.b 'NEWER VERSION',0
storage_draft: dc.b 'DRAFT',0
storage_ready: dc.b 'READY',0
storage_invalid: dc.b 'INVALID',0
        even
storage_page: dc.w 0
storage_slot: dc.w 0
storage_active_slot: dc.w -1
storage_saved_slot: dc.w -1
storage_modal: dc.w 0
storage_catalog_valid: dc.w 0
storage_continue: dc.w 0
storage_name_length: dc.w 0
storage_name_default: dc.w 0
; Digits typed for a slot number in the list, and their value.
storage_typed: dc.w 0
storage_typed_value: dc.w 0
storage_name: dcb.b SCTR_NAME_BYTES,0
        dc.b 0,0
storage_line: dcb.b 40,0
storage_ui_backup: dcb.b EDITOR_TRACK_BYTES,0
        include "storage-keymap.s"
