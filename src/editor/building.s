; Browse, preview, append and replace track sections in the editor.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Browse=0, Append=1, Edit=2. Modal prompts are independent.
; Preview owns separate bytes/geometry; only commit changes SCTR.
editor_building_reset:
        clr.w building_mode-module_start(a5)
        clr.w building_selected-module_start(a5)
        cmpi.l #3,editor_track+24-module_start(a5)
        blo.s .selection_ready
        move.w editor_track+28(pc),building_selected-module_start(a5)
        tst.w editor_track+30-module_start(a5)
        beq.s .selection_ready
        clr.w building_selected-module_start(a5)
.selection_ready:
        clr.w building_candidate_count-module_start(a5)
        clr.w building_fire-module_start(a5)
        clr.w building_arrow-module_start(a5)
        clr.w building_exit-module_start(a5)
        rts

editor_building_keys:
        tst.w storage_modal-module_start(a5)
        bne .done
        clr.w building_exit-module_start(a5)
        tst.w editing_prompt-module_start(a5)
        bne editing_prompt_keys
        bsr editing_keys
        tst.w d0
        bne .done
        cmpi.b #$b3,editor_input_keys+$45(a5)
        bne.s .fire
        tst.w building_mode-module_start(a5)
        beq.s .exit
        clr.w building_mode-module_start(a5)
        clr.w building_candidate_count-module_start(a5)
        bsr editor_release
        rts
.exit:
        moveq #3,d0
        bra editing_request
.fire:
        moveq #0,d0
        cmpi.b #$b3,editor_input_keys+$40(a5)       ; Space raw $40
        beq.s .held
        btst #4,editor_input_keys+96(a5)        ; joystick port 2 fire
        beq.s .edge
.held:
        moveq #1,d0
.edge:
        move.w building_fire(pc),d1
        move.w d0,building_fire-module_start(a5)
        tst.w d0
        beq .arrows
        tst.w d1
        bne .arrows
        tst.w building_mode-module_start(a5)
        bne.s .confirm
        move.w building_selected(pc),d0
        cmp.w editor_track+28(pc),d0
        blo.s .inspect
        move.w #1,building_mode-module_start(a5)
        bsr building_options
        bra .arrows
.inspect:
        tst.w d0
        bne.s .replace
        ; The fixed finish is an append shortcut on an open track.
        tst.w editor_track+30-module_start(a5)
        bne .arrows
        move.w editor_track+28(pc),building_selected-module_start(a5)
        move.w #1,building_mode-module_start(a5)
        bsr building_options
        bra .arrows
.replace:
        move.w #2,building_mode-module_start(a5)
        bsr building_options
        bra .arrows
.confirm:
        tst.w building_candidate_count-module_start(a5)
        beq .arrows
        bsr building_commit
        cmpi.l #3,editor_track+24-module_start(a5)
        blo.s .inspect_done
        tst.w building_mode-module_start(a5)
        bne .arrows
.inspect_done:
        clr.w building_mode-module_start(a5)
        clr.w building_candidate_count-module_start(a5)
.arrows:
        moveq #0,d4
        btst #2,editor_directions+1-module_start(a5)
        beq.s .right
        moveq #-1,d4
.right:
        btst #3,editor_directions+1-module_start(a5)
        beq.s .repeat
        moveq #1,d4
.repeat:
        cmp.w building_arrow(pc),d4
        bne.s .new
        tst.w d4
        beq .done
        move.w editor_ticks(pc),d0
        sub.w building_repeat(pc),d0
        bmi .done
        cmpi.w #8,d0
        blo .done
        move.w editor_ticks(pc),building_repeat-module_start(a5)
        bra.s .move
.new:
        move.w d4,building_arrow-module_start(a5)
        move.w editor_ticks(pc),d0
        addi.w #12,d0          ; initial delay 20 VBL, then 8
        move.w d0,building_repeat-module_start(a5)
        tst.w d4
        beq .done
.move:
        tst.w building_mode-module_start(a5)
        bne.s .candidate
        move.w building_selected(pc),d0
        cmpi.l #3,editor_track+24-module_start(a5)
        blo.s .single_step
        bsr block_browse_step
        bra.s .stepped
.single_step:
        add.w d4,d0
.stepped:
        bmi.s .done
        move.w editor_track+28(pc),d1
        sub.w editor_track+30(pc),d1
        cmp.w d1,d0
        bhi.s .done
        move.w d0,building_selected-module_start(a5)
        bra.s .done
.candidate:
        move.w building_candidate_count(pc),d1
        beq.s .done
        move.w building_choice(pc),d0
        add.w d4,d0
        bpl.s .upper
        move.w d1,d0
        subq.w #1,d0
.upper:
        cmp.w d1,d0
        blo.s .choice
        clr.w d0
.choice:
        move.w d0,building_choice-module_start(a5)
        bsr building_preview
.done:
        rts

; A0 piece -> D0 surface variant (kind-1)*4+rotation. Preserves A0.
building_variant:
        moveq #0,d0
        move.b 4(a0),d0
        subq.w #1,d0
        lsl.w #2,d0
        moveq #0,d1
        move.b 5(a0),d1
        add.w d1,d0
        rts

building_options:
        cmpi.l #3,editor_track+24-module_start(a5)
        bhs block_options
        clr.w building_candidate_count-module_start(a5)
        clr.w building_choice-module_start(a5)
        move.w #1,building_reason-module_start(a5)
        cmpi.w #2,building_mode-module_start(a5)
        beq.s .edit_limit
        cmpi.w #64,editor_track+28-module_start(a5)
        bhs .done
        tst.w editor_track+30-module_start(a5)
        bne .done
        bra.s .validate
.edit_limit:
        tst.w building_selected-module_start(a5)
        beq .done             ; fixed finish anchor
.validate:
        bsr editor_model_build
        tst.w d0
        beq .done
        lea editor_track+64(pc),a0
        move.w editor_track+28(pc),d6
        moveq #0,d5
        move.w d6,d0
        subq.w #1,d0
.max_id:
        cmp.l (a0),d5
        bhs.s .id_next
        move.l (a0),d5
.id_next:
        addq.l #8,a0
        dbra d0,.max_id
        subq.l #8,a0
        cmpi.w #2,building_mode-module_start(a5)
        beq.s .edit_tail
        addq.l #1,d5
        beq .done
        bra.s .tail_ready
.edit_tail:
        move.w building_selected(pc),d0
        lsl.w #3,d0
        lea editor_track+64(pc),a0
        adda.w d0,a0
        move.l (a0),d5
        cmp.l editor_track+36(pc),d5
        beq .done
        subq.l #8,a0
.tail_ready:
        move.l a0,building_tail-module_start(a5)
        bsr building_variant
        add.w d0,d0
        moveq #0,d1
        move.b 6(a0),d1
        add.w d1,d0
        mulu.w #44,d0
        lea building_transitions(pc),a4
        adda.w d0,a4
        move.w (a4)+,d6
        subq.w #1,d6
        move.w #2,building_reason-module_start(a5)
.option:
        lea building_probe(pc),a0
        move.l d5,(a0)
        move.b (a4),4(a0)
        move.b 1(a4),5(a0)
        move.b 2(a4),6(a0)
        movea.l building_tail(pc),a1
        moveq #0,d0
        move.b 7(a1),d0
        move.w d0,d1
        andi.w #15,d0
        lsr.w #4,d1
        move.b 3(a4),d2
        ext.w d2
        add.w d2,d0
        move.b 4(a4),d2
        ext.w d2
        add.w d2,d1
        cmpi.w #15,d0
        bhi .next
        cmpi.w #15,d1
        bhi .next
        lsl.w #4,d1
        or.w d1,d0
        move.b d0,7(a0)
        lea building_geometry(pc),a1
        moveq #0,d7
        bsr building_base_height
        bsr editor_piece_geometry
        tst.w d0
        beq .next
        ; Actual ordered edge continuity, even though table is generated.
        movem.l d5-d6/a4,-(sp)
        move.w editor_track+28(pc),d0
        cmpi.w #2,building_mode-module_start(a5)
        bne.s .join_index
        move.w building_selected(pc),d0
.join_index:
        subq.w #1,d0
        move.w d0,d1
        add.w d1,d1
        lea model_row_counts(pc),a0
        move.w (a0,d1.w),d1
        subq.w #1,d1
        mulu.w #12,d1
        mulu.w #EDITOR_GEOMETRY_STRIDE,d0
        add.w d1,d0
        lea model_geometry(pc),a0
        adda.w d0,a0
        lea building_geometry(pc),a1
        bsr editor_join
        tst.w d0
        beq.s .restore
        bsr editing_next_join
        tst.w d0
        beq.s .restore
        bsr building_collision
.restore:
        movem.l (sp)+,d5-d6/a4
        tst.w d0
        beq.s .next
        move.w building_candidate_count(pc),d0
        lsl.w #3,d0
        lea building_candidates(pc),a1
        adda.w d0,a1
        lea building_probe(pc),a0
        move.l (a0)+,(a1)+
        move.l (a0),(a1)
        addq.w #1,building_candidate_count-module_start(a5)
.next:
        addq.l #6,a4
        dbra d6,.option
        tst.w building_candidate_count-module_start(a5)
        beq.s .done
        clr.w building_reason-module_start(a5)
        bsr building_preview
.done:
        rts

; Generated exact whole-surface masks (convex quad SAT), 12x12 longwords.
; D0=1 if all existing surfaces are clear, else 0. No model writes.
building_collision:
        lea building_probe(pc),a0
        bsr building_variant
        bsr building_surface_variant
        move.w d0,d7
        moveq #0,d4
        move.b 7(a0),d4
        move.w d4,d5
        andi.w #15,d4
        lsr.w #4,d5
        lea editor_track+64(pc),a0
        move.w editor_track+28(pc),d6
        subq.w #1,d6
.piece:
        cmpi.w #2,building_mode-module_start(a5)
        bne.s .test_piece
        move.w editor_track+28(pc),d0
        subq.w #1,d0
        sub.w d6,d0
        cmp.w building_selected(pc),d0
        beq.s .next
.test_piece:
        moveq #0,d0
        move.b 7(a0),d0
        move.w d0,d1
        andi.w #15,d0
        lsr.w #4,d1
        neg.w d0
        neg.w d1
        add.w d4,d0
        add.w d5,d1
        addq.w #2,d0
        addq.w #2,d1
        cmpi.w #4,d0
        bhi.s .next
        cmpi.w #4,d1
        bhi.s .next
        mulu.w #5,d1
        add.w d0,d1
        move.w d1,d3
        bsr building_variant
        bsr building_surface_variant
        mulu.w #EDITOR_SURFACE_COUNT,d0
        add.w d7,d0
        lsl.w #2,d0
        lea building_collision_masks(pc),a1
        move.l (a1,d0.w),d0
        btst d3,d0
        bne.s .bad
.next:
        addq.l #8,a0
        dbra d6,.piece
        moveq #1,d0
        rts
.bad:
        moveq #0,d0
        rts

building_preview:
        cmpi.l #3,editor_track+24-module_start(a5)
        bhs block_preview
        move.w building_choice(pc),d0
        lsl.w #3,d0
        lea building_candidates(pc),a0
        adda.w d0,a0
        lea building_geometry(pc),a1
        moveq #0,d7
        bsr building_base_height
        bsr editor_piece_geometry
        move.w d0,building_rows-module_start(a5)
        rts

building_commit:
        cmpi.l #3,editor_track+24-module_start(a5)
        bhs block_commit
        ; Recompute admissibility at commit; never trust stale preview state.
        move.w building_choice(pc),-(sp)
        bsr building_options
        move.w (sp)+,d0
        cmp.w building_candidate_count(pc),d0
        bhs .done
        move.w d0,building_choice-module_start(a5)
        bsr building_preview
        cmpi.w #2,building_mode-module_start(a5)
        bne.s .backup
        move.w building_choice(pc),d0
        lsl.w #3,d0
        lea building_candidates(pc),a0
        adda.w d0,a0
        move.w building_selected(pc),d0
        lsl.w #3,d0
        lea editor_track+64(pc),a1
        adda.w d0,a1
        move.l 4(a0),d0
        cmp.l 4(a1),d0
        beq .done
.backup:
        bsr editing_backup
        move.w building_choice(pc),d0
        lsl.w #3,d0
        lea building_candidates(pc),a0
        adda.w d0,a0
        cmpi.w #2,building_mode-module_start(a5)
        beq editing_replace
        move.w editor_track+28(pc),d0
        move.w d0,building_selected-module_start(a5)
        lsl.w #3,d0
        lea editor_track+64(pc),a1
        adda.w d0,a1
        move.l (a0)+,(a1)+
        move.l (a0),(a1)
        addq.w #1,editor_track+28-module_start(a5)
        addq.w #8,editor_track+6-module_start(a5)
        move.w building_rows(pc),d0
        subq.w #1,d0
        mulu.w #12,d0
        lea building_geometry(pc),a0
        adda.w d0,a0
        lea model_geometry(pc),a1
        bsr editor_join
        move.w d0,editor_track+30-module_start(a5)
        lea editor_track(pc),a0
        move.w 6(a0),d0
        subq.w #4,d0
        bsr storage_crc
        move.l d0,(a0)
        addq.l #1,building_revision-module_start(a5)
        bsr editing_dirty
        clr.w storage_status-module_start(a5)
        bsr editor_model_build
.done:
        rts

editor_building_text:
        cmpi.l #3,editor_track+24-module_start(a5)
        bhs block_text
        tst.w editing_prompt-module_start(a5)
        bne editing_prompt_text
        lea building_browse_text(pc),a0
        tst.w building_mode-module_start(a5)
        beq.s .browse
        lea building_edit_text(pc),a0
        cmpi.w #2,building_mode-module_start(a5)
        bne.s .append_text
        tst.w building_selected-module_start(a5)
        bne.s .draw
        lea building_finish_text(pc),a0
        bra.s .draw
.append_text:
        lea building_append_text(pc),a0
        tst.w building_candidate_count-module_start(a5)
        bne.s .draw
        lea building_blocked_text(pc),a0
        cmpi.w #1,building_reason-module_start(a5)
        bne.s .draw
        lea building_limit_text(pc),a0
        bra.s .draw
.browse:
        move.w building_selected(pc),d0
        cmp.w editor_track+28(pc),d0
        blo.s .draw
        lea building_add_text(pc),a0
.draw:
        movea.l draw_surface(pc),a1
        adda.w #7242,a1      ; row 181, 16px margin
        bra storage_text_line
building_browse_text: dc.b 'BROWSE  LEFT/RIGHT  FIRE/SPACE EDIT',0
building_add_text: dc.b 'ADD PIECE  FIRE/SPACE PREVIEW',0
building_append_text: dc.b 'APPEND L/R  FIRE/SPACE OK  ESC BACK',0
building_finish_text: dc.b 'FINISH FIXED  ESC BACK',0
building_edit_text: dc.b 'EDIT L/R  FIRE/SPACE OK  ESC BACK',0
building_blocked_text: dc.b 'NO FIT: MAP EDGE OR ROAD OVERLAP',0
building_limit_text: dc.b 'NO FIT: CLOSED, FULL OR INVALID',0
        even
building_mode: dc.w 0
building_selected: dc.w 0
building_candidate_count: dc.w 0
building_choice: dc.w 0
building_reason: dc.w 0
building_rows: dc.w 0
building_fire: dc.w 0
building_arrow: dc.w 0
building_repeat: dc.w 0
building_exit: dc.w 0
building_dirty: dc.w 0
building_revision: dc.l 0
building_tail: dc.l 0
building_candidates: dcb.b 56,0
building_probe: dcb.b 8,0
building_geometry: dcb.b EDITOR_GEOMETRY_STRIDE,0

; Height is the fixed predecessor's actual exit, also for replacement preview.
building_base_height:
        movem.l d0-d1/a2,-(sp)
        move.w editor_track+28(pc),d0
        cmpi.w #2,building_mode-module_start(a5)
        bne.s .index
        move.w building_selected(pc),d0
.index:
        subq.w #1,d0
        move.w d0,d1
        add.w d1,d1
        lea model_row_counts(pc),a2
        move.w (a2,d1.w),d1
        subq.w #1,d1
        mulu.w #12,d1
        mulu.w #EDITOR_GEOMETRY_STRIDE,d0
        add.w d1,d0
        lea model_geometry(pc),a2
        moveq #0,d7
        move.w 2(a2,d0.w),d7
        movem.l (sp)+,d0-d1/a2
        rts
building_surface_variant:
        add.w d0,d0
        lea building_surface_map(pc),a1
        move.w (a1,d0.w),d0
        rts
