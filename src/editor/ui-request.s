; Turn clicks on the editor bar into editor actions.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Track Editor bar: what a click does. A row is a key for one pass or a call of
; the main loop. Nothing enters the capture queue, so a click cannot pass a key
; the keyboard queued, and the handlers stay the handlers of the keyboard.
UI_REQUEST_KEY equ 1
UI_REQUEST_CALL equ 2
UI_RAW_ESC equ $45
UI_RAW_SPACE equ $40
UI_RAW_RETURN equ $44
UI_FIRE_BIT equ 4
UI_LIST_FIRST_Y equ 4
UI_HOLD_DELAY equ 20
UI_HOLD_RATE equ 8

; After editor_input_next: one press or hold becomes one request.
ui_begin:
        bsr ui_camera_step
        bsr ui_hold_step
        tst.w ui_press_pending-module_start(a5)
        beq.s .request
        tst.w ui_request-module_start(a5)
        bne.s .request
        move.w editor_input_blocked(pc),d0
        or.w editor_input_holdoff(pc),d0
        bne.s .busy
        bsr ui_page_now
        cmp.w ui_press_page(pc),d0
        beq.s .hit
.busy:  clr.w ui_press_pending-module_start(a5)
        bsr ui_drop
        bra.s .request
.hit:   bsr ui_hit_begin
.request:
        move.w ui_request(pc),d0
        beq.s .done
        clr.w ui_request-module_start(a5)
        moveq #0,d1
        move.b d0,d1
        lsr.w #8,d0
        cmpi.w #UI_REQUEST_KEY,d0
        beq.s ui_key_press
        bra ui_call
.done:  rts

; D1 raw key: down for this pass, unless the keyboard or the stick holds it.
ui_key_press:
        lea editor_input_captured(a5),a0
        tst.b (a0,d1.w)
        bne.s .held
        cmpi.w #UI_RAW_SPACE,d1
        bne.s .free
        btst #UI_FIRE_BIT,editor_input_keys+96(a5)
        bne.s .held
.free:  lea editor_input_keys(a5),a0
        move.b (a0,d1.w),ui_key_old-module_start(a5)
        move.b #$b3,(a0,d1.w)
        move.w d1,ui_key-module_start(a5)
        rts
.held:  lea ui_text_held(pc),a0
        bra ui_refuse

; After the handlers. Nothing physical pressed it, so no release will come:
; end the suppression unless the key has really gone down meanwhile.
ui_end:
        move.w ui_key(pc),d1
        bmi.s .done
        move.w #-1,ui_key-module_start(a5)
        lea editor_input_keys(a5),a0
        move.b ui_key_old(pc),(a0,d1.w)
        lea editor_input_captured(a5),a0
        tst.b (a0,d1.w)
        bne.s .done
        lea editor_input_suppressed(a5),a0
        clr.b (a0,d1.w)
.done:  rts

; A press from a render or a scan was aimed at what the screen no longer shows.
ui_after_render:
        tst.w ui_press_pending-module_start(a5)
        beq.s .done
        clr.w ui_press_pending-module_start(a5)
        bsr ui_drop
.done:  rts

ui_drop:
        addq.l #1,ui_dropped-module_start(a5)
        lea ui_text_busy(pc),a0
        bra ui_refuse

; Latched press on the page the screen shows now -> a request or a refusal.
ui_hit_begin:
        clr.w ui_press_pending-module_start(a5)
        clr.l ui_hold_row-module_start(a5)
        clr.w ui_hold_repeat-module_start(a5)
        move.w ui_press_x(pc),d0
        move.w ui_press_y(pc),d1
        bsr ui_find_row
        bne.s .row
        tst.w place_active-module_start(a5)
        bne place_click
        lea ui_text_look(pc),a0
        bra ui_say
.row:   move.b (a2),d6
        move.b UI_ENTRY_FLAGS(a3),d5
        move.b d5,d0
        andi.b #UI_KIND_MASK,d0
        cmpi.b #UI_KIND_INFO,d0
        beq.s .text
        cmpi.b #UI_KIND_LIST,d0
        beq.s .guard
        move.b d6,d0
        andi.b #UI_STATE_MASK,d0
        cmpi.b #UI_DISABLED,d0
        bne.s .guard
        ; Test keeps its own reasons: the key says which one.
        cmpi.b #UI_PRED_TEST,UI_ENTRY_PRED(a3)
        bne.s .slot
        tst.w place_active-module_start(a5)
        beq.s .guard
        bra.s .text
.slot:
        ; A rejected section can be picked: its ghost shows what is wrong.
        cmpi.b #UI_PRED_SLOT,UI_ENTRY_PRED(a3)
        bne.s .text
        bsr ui_slot_candidate
        tst.w d0
        bpl.s .guard
.text:  move.b d6,d0
        bsr ui_row_text
        bra ui_refuse
.guard: move.l ui_ms(pc),d0
        sub.l ui_page_end(pc),d0
        bmi.s .wait
        btst #UI_BIT_PLACE_GUARD,d5
        beq.s .take
        move.l ui_ms(pc),d0
        sub.l ui_place_end(pc),d0
        bpl.s .take
.wait:  lea ui_text_wait(pc),a0
        bra ui_refuse
.take:  move.b d5,d0
        andi.b #UI_KIND_MASK,d0
        cmpi.b #UI_KIND_LIST,d0
        bne.s .request
        move.w ui_press_y(pc),d0
        bsr ui_list_slot
        move.w d0,storage_slot-module_start(a5)
.request:
        moveq #0,d0
        move.b UI_ENTRY_ACTION(a3),d0
        move.w #UI_REQUEST_KEY<<8,d1
        btst #6,d5
        beq.s .kind
        move.w #UI_REQUEST_CALL<<8,d1
.kind:  or.w d1,d0
        move.w d0,ui_request-module_start(a5)
        addq.l #1,ui_hits-module_start(a5)
        btst #UI_BIT_HOLD,d5
        beq.s .done
        move.l a3,ui_hold_row-module_start(a5)
        move.w d0,ui_hold_request-module_start(a5)
        move.w editor_ticks(pc),d0
        addi.w #UI_HOLD_DELAY,d0
        move.w d0,ui_hold_next-module_start(a5)
.done:  rts

; D0 screen y on the list -> D0 slot.
ui_list_slot:
        subq.w #UI_LIST_FIRST_Y,d0
        lsr.w #3,d0
        add.w storage_page(pc),d0
        rts

; A held row repeats at the rate of the arrow keys while the pointer stays on it.
ui_hold_step:
        move.l ui_hold_row(pc),d0
        beq.s .done
        btst #0,ui_btn+1-module_start(a5)
        beq.s .stop
        movea.l d0,a3
        move.w UI_ENTRY_PAGES(a3),d0
        and.w ui_page(pc),d0
        beq.s .stop
        move.w ui_ptr_x(pc),d0
        move.w ui_ptr_y(pc),d1
        bsr ui_row_hit
        beq.s .stop
        tst.w ui_request-module_start(a5)
        bne.s .done
        move.w editor_ticks(pc),d0
        sub.w ui_hold_next(pc),d0
        bmi.s .done
        move.w ui_hold_request(pc),ui_request-module_start(a5)
        move.w #1,ui_hold_repeat-module_start(a5)
        move.w editor_ticks(pc),d0
        addq.w #UI_HOLD_RATE,d0
        move.w d0,ui_hold_next-module_start(a5)
.done:  rts
.stop:  clr.l ui_hold_row-module_start(a5)
        rts

; A0 text, 0 keeps the line: the refused pointer and the reason. A held row that
; reached its end just stops.
ui_refuse:
        tst.w ui_hold_repeat-module_start(a5)
        bne.s .stop
        addq.l #1,ui_refused-module_start(a5)
        move.w #UI_POINTER_REFUSED,ui_pointer_want-module_start(a5)
        move.l ui_ms(pc),d0
        addi.l #UI_REFUSED_MS,d0
        move.l d0,ui_pointer_end-module_start(a5)
        move.l a0,d0
        beq.s .stop
        bsr ui_say
.stop:  clr.l ui_hold_row-module_start(a5)
        rts

ui_call:
        move.w d1,d0
        subq.w #1,d1
        add.w d1,d1
        move.w ui_calls(pc,d1.w),d1
        jmp ui_calls(pc,d1.w)
ui_calls:
        dc.w ui_call_place-ui_calls
        dc.w ui_call_undo-ui_calls
        dc.w ui_call_delete-ui_calls
        dc.w ui_call_free-ui_calls
        dc.w ui_call_starter_0-ui_calls
        dc.w ui_call_starter_1-ui_calls
        dc.w ui_call_starter_2-ui_calls
        dc.w ui_call_new-ui_calls
        dc.w ui_call_step_back-ui_calls
        dc.w ui_call_step_on-ui_calls
        dcb.w 11,ui_call_section-ui_calls
        dc.w ui_call_redo-ui_calls
        dc.w ui_call_slot_previous-ui_calls
        dc.w ui_call_slot_next-ui_calls
ui_call_free:
        rts

; Same order as the Fire confirm in editor_building_keys. A rejected ghost keeps
; Choose. The next section opens at once, so Primary stays under the pointer.
ui_call_place:
        tst.w building_candidate_count-module_start(a5)
        beq.s .done
        bsr building_commit
        cmpi.l #3,editor_track+24-module_start(a5)
        blo.s .placed
        tst.w building_mode-module_start(a5)
        bne.s .done
.placed:
        move.l ui_ms(pc),d0
        addi.l #UI_PLACE_MS,d0
        move.l d0,ui_place_end-module_start(a5)
        bsr.s ui_choose_end
        bra.s ui_continue
.done:  rts

ui_choose_end:
        clr.w building_mode-module_start(a5)
        clr.w building_candidate_count-module_start(a5)
        rts

; After a change on the Choose page: choose on while the tail is selected.
ui_continue:
        tst.w editor_track+30-module_start(a5)
        bne.s .done
        move.w building_selected(pc),d0
        cmp.w editor_track+28(pc),d0
        bne.s .done
        move.w #1,building_mode-module_start(a5)
        bsr building_options
.done:  rts

ui_call_undo:
        bsr.s ui_choose_end
        bsr editing_undo
        bra.s ui_continue

ui_call_redo:
        bsr.s ui_choose_end
        bsr editing_redo
        bra.s ui_continue

ui_call_delete:
        bsr.s ui_choose_end
        move.w editor_track+28(pc),building_selected-module_start(a5)
        bsr editing_delete
        bra.s ui_continue

ui_call_new:
        bsr.s ui_choose_end
        move.w #1,editing_prompt-module_start(a5)
        rts

ui_call_starter_0:
        moveq #4,d0
        bra editing_request
ui_call_starter_1:
        moveq #5,d0
        bra editing_request
ui_call_starter_2:
        moveq #6,d0
        bra editing_request

ui_call_slot_previous:
        moveq #UI_LIST_SLOT_PREVIOUS,d0
        bra.s ui_slot_confirm
ui_call_slot_next:
        moveq #UI_LIST_SLOT_NEXT,d0
ui_slot_confirm:
        move.w d0,storage_slot-module_start(a5)
        moveq #UI_RAW_RETURN,d1
        bra ui_key_press

ui_call_step_back:
        moveq #-1,d4
        bra.s ui_call_step
ui_call_step_on:
        moveq #1,d4
; The selection, on the page of the Prev and Next rows.
; A held Prev stops at the start, one click wraps like the Left key.
ui_call_step:
        move.w storage_modal(pc),d0
        or.w editing_prompt(pc),d0
        or.w building_mode(pc),d0
        bne.s .refused
        tst.w ui_hold_repeat-module_start(a5)
        beq.s .step
        tst.w d4
        bpl.s .step
        tst.w building_selected-module_start(a5)
        beq.s .refused
.step:  bsr building_step
        beq.s .refused
        rts
.refused:
        suba.l a0,a0
        bra ui_refuse

ui_text_look: dc.b 'Drag with the right button to look.',0
ui_text_view: dc.b 'Hold the right button to look. WASD moves.',0
ui_text_held: dc.b 'Let go of the key first.',0
ui_text_busy: dc.b 'Still drawing. Click again.',0
ui_text_wait: dc.b 'One moment.',0
ui_text_stays: dc.b 'The start section stays.',0
ui_text_gap: dc.b 'Fill the gap first.',0
        even
ui_hold_row: dc.l 0
ui_hits: dc.l 0
ui_refused: dc.l 0
ui_request: dc.w 0
ui_key: dc.w -1
ui_key_old: dc.w 0
ui_hold_request: dc.w 0
ui_hold_next: dc.w 0
ui_hold_repeat: dc.w 0
