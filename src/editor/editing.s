; Manage track edits, deletion, undo and unsaved-change prompts.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Transactional model editing. Undo ring, content-based dirty state.
; No I/O or renderer pointers live in the snapshots. Geometry revision is
; monotonic, including undo; SCTR format revision remains unchanged.
; A slot holds the track and building_selected.w. The ring has
; 16 slots and keeps 17 states: the live one and undo plus redo levels, at most 16.
EDITING_RING equ $1d560
EDITING_SLOT equ 582
; D0 free-running index -> A0 slot.
editing_slot:
        andi.w #15,d0
        mulu.w #EDITING_SLOT,d0
        movea.l a5,a0
        adda.l #EDITING_RING,a0
        adda.l d0,a0
        rts

editing_backup:
        movem.l d0-d7/a0-a4,-(sp)
        move.w editing_head(pc),d0
        bsr editing_slot
        movea.l a0,a1
        lea editor_track(pc),a0
        move.w #580,d0
        bsr storage_copy
        move.w building_selected(pc),(a1)
        addq.w #1,editing_head-module_start(a5)
        cmpi.w #16,editing_undo_count-module_start(a5)
        bhs.s .full
        addq.w #1,editing_undo_count-module_start(a5)
.full:  clr.w editing_redo_count-module_start(a5)
        movem.l (sp)+,d0-d7/a0-a4
        rts

editing_mark_saved:
        movem.l d0/a0-a1,-(sp)
        lea editor_track(pc),a0
        lea editing_saved_track(pc),a1
        move.w #580,d0
        bsr storage_copy
        clr.w building_dirty-module_start(a5)
        move.w storage_slot(pc),storage_saved_slot-module_start(a5)
        movem.l (sp)+,d0/a0-a1
        rts
editing_dirty:
        movem.l d0/a0-a1,-(sp)
        move.w #1,building_dirty-module_start(a5)
        lea editor_track(pc),a0
        lea editing_saved_track(pc),a1
        move.w 6(a0),d0
        cmp.w 6(a1),d0
        bne.s .done
        subq.w #1,d0
.compare:
        cmpm.b (a0)+,(a1)+
        bne.s .done
        dbra d0,.compare
        clr.w building_dirty-module_start(a5)
.done:
        movem.l (sp)+,d0/a0-a1
        rts

; Check the outgoing join against the unchanged next piece or finish.
; The candidate geometry is regenerated to obtain its row count.
editing_next_join:
        cmpi.w #2,building_mode-module_start(a5)
        bne.s .good
        move.w building_selected(pc),d4
        addq.w #1,d4
        cmp.w editor_track+28(pc),d4
        blo.s .next
        tst.w editor_track+30-module_start(a5)
        beq.s .good
        clr.w d4
.next:
        lea building_probe(pc),a0
        lea building_geometry(pc),a1
        moveq #0,d7
        bsr building_base_height
        bsr editor_piece_geometry
        subq.w #1,d0
        mulu.w #12,d0
        lea building_geometry(pc),a0
        adda.w d0,a0
        mulu.w #EDITOR_GEOMETRY_STRIDE,d4
        lea model_geometry(pc),a1
        adda.w d4,a1
        bra editor_join
.good:
        moveq #1,d0
        rts

editing_replace:
        move.w building_selected(pc),d0
        lsl.w #3,d0
        lea editor_track+64(pc),a1
        adda.w d0,a1
        ; Choosing the identical piece is not a building change.
        move.l 4(a0),d0
        cmp.l 4(a1),d0
        beq.s .done
        move.l d0,4(a1)
        bra editing_changed
.done:
        rts

editing_changed:
        bsr editor_model_refresh
        addq.l #1,building_revision-module_start(a5)
        bsr editing_dirty
        clr.w storage_status-module_start(a5)
        bsr editor_model_view
        rts

; Exchange the live track and selection with ring slot D0.
editing_swap:
        bsr editing_slot
        lea editor_track(pc),a1
        move.w #144,d1
.long:  move.l (a0),d0
        move.l (a1),(a0)+
        move.l d0,(a1)+
        dbra d1,.long
        move.w building_selected(pc),d0
        move.w (a0),building_selected-module_start(a5)
        move.w d0,(a0)
        addq.l #1,building_revision-module_start(a5)
        clr.w storage_status-module_start(a5)
        bsr editing_dirty
        bra editor_model_view

editing_undo:
        tst.w editing_undo_count-module_start(a5)
        beq.s .done
        subq.w #1,editing_undo_count-module_start(a5)
        addq.w #1,editing_redo_count-module_start(a5)
        subq.w #1,editing_head-module_start(a5)
        move.w editing_head(pc),d0
        bra editing_swap
.done:  rts

editing_redo:
        tst.w editing_redo_count-module_start(a5)
        beq.s .done
        subq.w #1,editing_redo_count-module_start(a5)
        addq.w #1,editing_undo_count-module_start(a5)
        move.w editing_head(pc),d0
        addq.w #1,editing_head-module_start(a5)
        bra editing_swap
.done:  rts

; The piece a delete starts from -> D0. Mid-track that is the selected section,
; which takes the tail with it; on the start line or the Add slot the last
; section. An old track goes a piece at a time from its end.
editing_cut_start:
        cmpi.l #3,editor_track+24-module_start(a5)
        blo.s .last
        move.w building_selected(pc),d0
        beq.s .tail
        cmp.w editor_track+28(pc),d0
        blo block_group_start
.tail:  move.w editor_track+28(pc),d0
        subq.w #1,d0
        bra block_group_start
.last:  move.w editor_track+28(pc),d0
        subq.w #1,d0
        rts

editing_delete:
        move.l d4,-(sp)
        bsr.s .cut
        move.l (sp)+,d4
        rts
.cut:   cmpi.w #1,editor_track+28-module_start(a5)
        bls .done
        bsr editor_model_build
        tst.w d0
        beq .done
        bsr.s editing_cut_start
        move.w d0,d4
        beq .stays
        ; The piece of the start line stays, wherever it is.
        move.w d0,d1
        lsl.w #3,d1
        lea editor_track+64(pc),a0
        adda.w d1,a0
        move.w editor_track+28(pc),d1
        sub.w d0,d1
        subq.w #1,d1
        move.l editor_track+36(pc),d2
.finish:
        cmp.l (a0),d2
        beq .stays
        addq.l #8,a0
        dbra d1,.finish
        bsr editing_backup
        move.w d4,editor_track+28-module_start(a5)
        move.w d4,building_selected-module_start(a5)
        clr.w editor_track+30-module_start(a5)
        ; Remove stale bytes, including the old CRC; serialize canonically.
        lsl.w #3,d4
        addi.w #68,d4
        lea editor_track(pc),a0
        move.w 6(a0),d1
        move.w d4,6(a0)
        sub.w d4,d1
        lea -4(a0,d4.w),a0
        lsr.w #2,d1
.clear: clr.l (a0)+
        dbra d1,.clear
        bsr editing_changed
        cmpi.w #1,editor_track+28-module_start(a5)
        beq place_enter
        rts
.stays: lea ui_text_stays(pc),a0
        bra ui_refuse
.done:
        rts

; Extra keys consume a complete press; preview U only cancels preview.
editing_keys:
        cmpi.b #$b3,editor_input_keys+$16(a5)       ; raw U=$16
        beq.s .undo
        cmpi.b #$b3,editor_input_keys+$14(a5)       ; raw T=$14
        beq.s .test
        tst.w building_mode-module_start(a5)
        bne.s .none
        cmpi.b #$b3,editor_input_keys+$36(a5)       ; raw N=$36
        beq .new
        cmpi.b #$b3,editor_input_keys+$41(a5)       ; raw Backspace=$41
        beq.s .delete
        cmpi.b #$b3,editor_input_keys+$13(a5)       ; raw R=$13
        beq.s .redo
.none:
        moveq #0,d0
        rts
.undo:
        bsr editor_release
        tst.w building_mode-module_start(a5)
        beq.s .restore
        clr.w building_mode-module_start(a5)
        clr.w building_candidate_count-module_start(a5)
        bra.s .used
.restore:
        bsr editing_undo
        bra.s .used
.redo:
        bsr editor_release
        bsr editing_redo
        bra.s .used
.delete:
        bsr editor_release
        bsr editing_delete
        bra.s .used
.test:
        bsr editor_release
        tst.w building_mode-module_start(a5)
        bne.s .test_later
        move.w #1,test_request-module_start(a5)
        bra.s .used
.test_later:
        move.w #12,storage_status-module_start(a5)
        bra.s .used
.new:
        bsr editor_release
        move.w #1,editing_prompt-module_start(a5)
.used:
        moveq #1,d0
        rts

; Pending action: 1 New, 2 Load, 3 Exit, 4-6 a starter track. New confirmation
; precedes this.
editing_request:
        move.w d0,editing_action-module_start(a5)
        bsr editor_release
        tst.w building_dirty-module_start(a5)
        beq editing_execute
        move.w #2,editing_prompt-module_start(a5)
        rts
editing_execute:
        clr.w editing_prompt-module_start(a5)
        move.w editing_action(pc),d0
        cmpi.w #3,d0
        beq.s .exit
        cmpi.w #2,d0
        beq storage_open_load
        bhi starter_load
        move.w #-1,storage_active_slot-module_start(a5)
        lea editing_initial_track(pc),a0
        lea editor_track(pc),a1
        move.w #580,d0
        bsr storage_copy
        bsr editor_building_reset
        clr.l editing_undo_count-module_start(a5)
        move.w #1,free_open_due-module_start(a5)
        addq.l #1,building_revision-module_start(a5)
        bsr editing_dirty
        clr.w storage_status-module_start(a5)
        bra editor_model_view
.exit:
        tst.w building_dirty-module_start(a5)
        beq.s .leave
        move.w storage_saved_slot(pc),storage_active_slot-module_start(a5)
        lea editing_saved_track(pc),a0
        lea editor_track(pc),a1
        move.w #580,d0
        bsr storage_copy
        clr.l editing_undo_count-module_start(a5)
        clr.w building_dirty-module_start(a5)
        addq.l #1,building_revision-module_start(a5)
        bsr editor_model_view
.leave:
        move.w #1,building_exit-module_start(a5)
        rts

editing_prompt_keys:
        cmpi.b #$b3,editor_input_keys+$45(a5)       ; Esc/Cancel, always safe
        beq .cancel
        cmpi.b #$b3,editor_input_keys+$33(a5)       ; C raw $33
        beq .cancel
        cmpi.w #1,editing_prompt-module_start(a5)
        bne.s .dirty
        cmpi.b #$b3,editor_input_keys+$40(a5)       ; Space
        beq.s .new
        btst #4,editor_input_keys+96(a5)
        bne.s .new
        moveq #4,d0
        cmpi.b #$b3,editor_input_keys+$35(a5)       ; B, Banked Loop
        beq editing_request
        moveq #5,d0
        cmpi.b #$b3,editor_input_keys+$25(a5)       ; H, Small Hills
        beq editing_request
        moveq #6,d0
        cmpi.b #$b3,editor_input_keys+$13(a5)       ; R, Ramp and Hills
        beq editing_request
        rts
.new:
        moveq #1,d0
        bra editing_request
.dirty:
        cmpi.b #$b3,editor_input_keys+$21(a5)       ; S = Save, successful readback required
        beq.s .save
        cmpi.b #$b3,editor_input_keys+$22(a5)       ; D = Discard
        beq.s .discard
        rts
.save:
        bsr editor_release
        move.w #1,storage_continue-module_start(a5)
        bra storage_open_save
.discard:
        bsr editor_release
        bra editing_execute
.cancel:
        bsr editor_release
        clr.w editing_prompt-module_start(a5)
.done:
        rts

editing_prompt_text:
        lea editing_new_title(pc),a0
        lea editing_confirm_text(pc),a1
        cmpi.w #1,editing_prompt-module_start(a5)
        beq.s .draw
        lea editing_guard_title(pc),a0
        lea editing_guard_text(pc),a1
.draw:  move.l a1,-(sp)
        bsr ui_name_put
        movea.l (sp)+,a0
        moveq #UI_SAY_PROMPT,d0
        bra ui_status_put
editing_new_title: dc.b 'New track',0
editing_guard_title: dc.b 'Unsaved changes',0
editing_confirm_text: dc.b 'Fire Empty, B Banked, H Hills, R Ramps, Esc.',0
editing_guard_text: dc.b 'S saves, D discards, C or Esc cancels.',0
        even
; editing_execute actions 4-6, as a load from memory: the track is clean and has
; no slot, so Exit does not ask and Save opens the list.
starter_load:
        subq.w #4,d0
        add.w d0,d0
        lea starter_table(pc),a0
        adda.w (a0,d0.w),a0
        move.w #-1,storage_active_slot-module_start(a5)
        lea editor_track(pc),a1
        move.w #144,d0
.clear: clr.l (a1)+
        dbra d0,.clear
        lea editor_track(pc),a1
        move.w 6(a0),d0
        bsr storage_copy
        bsr editor_building_reset
        clr.l editing_undo_count-module_start(a5)
        move.w #1,free_open_due-module_start(a5)
        bsr editing_mark_saved
        move.w #-1,storage_saved_slot-module_start(a5)
        addq.l #1,building_revision-module_start(a5)
        move.w #2,storage_status-module_start(a5)
        bra editor_model_view
        include "starter-data.s"
editing_prompt: dc.w 0
editing_action: dc.w 0
; Cleared together with clr.l.
editing_undo_count: dc.w 0
editing_redo_count: dc.w 0
editing_head: dc.w 0
