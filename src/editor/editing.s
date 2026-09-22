; Manage track edits, deletion, undo and unsaved-change prompts.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; transactional model editing. One-level undo, content-based dirty state.
; No I/O or renderer pointers live in the snapshots. Geometry revision is
; monotonic, including undo; SCTR format revision remains unchanged.
editing_backup:
        movem.l d0-d7/a0-a4,-(sp)
        lea editor_track(pc),a0
        lea editing_undo_track(pc),a1
        move.w #580,d0
        bsr storage_copy
        move.w building_selected(pc),editing_undo_selected-module_start(a5)
        move.l camera_route(pc),editing_undo_camera-module_start(a5)
        move.w #1,editing_undo_valid-module_start(a5)
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

editing_undo:
        tst.w editing_undo_valid-module_start(a5)
        beq.s .done
        lea editing_undo_track(pc),a0
        lea editor_track(pc),a1
        move.w #580,d0
        bsr storage_copy
        move.w editing_undo_selected(pc),building_selected-module_start(a5)
        move.l editing_undo_camera(pc),camera_route-module_start(a5)
        clr.w editing_undo_valid-module_start(a5)
        addq.l #1,building_revision-module_start(a5)
        clr.w storage_status-module_start(a5)
        bsr editing_dirty
        bsr editor_model_view
.done:
        rts
editing_delete:
        cmpi.w #1,editor_track+28-module_start(a5)
        bls.s .done
        bsr editor_model_build
        tst.w d0
        beq.s .done
        move.w editor_track+28(pc),d0
        subq.w #1,d0
        lsl.w #3,d0
        lea editor_track+64(pc),a0
        adda.w d0,a0
        move.l (a0),d0
        cmp.l editor_track+36(pc),d0
        beq.s .done
        bsr editing_backup
        move.w editor_track+28(pc),d0
        subq.w #1,d0
        cmpi.l #3,editor_track+24-module_start(a5)
        blo.s .delete_count
        bsr block_group_start
.delete_count:
        move.w d0,editor_track+28-module_start(a5)
        lsl.w #3,d0
        addi.w #76,d0
        move.w d0,editor_track+6-module_start(a5)
        subq.w #8,editor_track+6-module_start(a5)
        clr.w editor_track+30-module_start(a5)
        move.w editor_track+28(pc),building_selected-module_start(a5)
        ; Remove stale bytes, including the old CRC; serialize canonically.
        move.w editor_track+6(pc),d0
        subq.w #4,d0
        lea editor_track(pc),a0
        adda.w d0,a0
        clr.l (a0)
        clr.l 4(a0)
        clr.l 8(a0)
        bra editing_changed
.done:
        rts

; Extra keys consume a complete press; preview U only cancels preview.
editing_keys:
        cmpi.b #$b3,editor_input_keys+$16(a5)       ; raw U=$16
        beq.s .undo
        tst.w building_mode-module_start(a5)
        bne.s .none
        cmpi.b #$b3,editor_input_keys+$36(a5)       ; raw N=$36
        beq.s .new
        cmpi.b #$b3,editor_input_keys+$41(a5)       ; raw Backspace=$41
        beq.s .delete
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
.delete:
        bsr editor_release
        bsr editing_delete
        bra.s .used
.new:
        bsr editor_release
        move.w #1,editing_prompt-module_start(a5)
.used:
        moveq #1,d0
        rts

; Pending action: 1 New, 2 Load, 3 Exit. New confirmation precedes this.
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
        move.w #-1,storage_active_slot-module_start(a5)
        lea editing_initial_track(pc),a0
        lea editor_track(pc),a1
        move.w #580,d0
        bsr storage_copy
        bsr editor_building_reset
        clr.w editing_undo_valid-module_start(a5)
        clr.l camera_route-module_start(a5)
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
        clr.w editing_undo_valid-module_start(a5)
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
        lea editing_confirm_text(pc),a0
        cmpi.w #1,editing_prompt-module_start(a5)
        beq.s .draw
        lea editing_guard_text(pc),a0
.draw:
        movea.l draw_surface(pc),a1
        adda.w #7242,a1
        bra storage_text_line
editing_confirm_text: dc.b 'NEW TRACK?  FIRE/SPACE YES  ESC CANCEL',0
editing_guard_text: dc.b 'S SAVE / D DISCARD / C CANCEL',0
        even
editing_prompt: dc.w 0
editing_action: dc.w 0
editing_undo_valid: dc.w 0
editing_undo_selected: dc.w 0
editing_undo_camera: dc.l 0
editing_undo_track: dcb.b 580,0
