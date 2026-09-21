; Construct selectable track sections from complete original track-piece runs.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Whole original runs. Authoritative track is never replaced by a preview.
; Two private Fast caches, outside the loaded module and screen backup.
BLOCK_CACHE_BYTES equ 128+64*EDITOR_GEOMETRY_STRIDE
BLOCK_ORIGINAL_CACHE equ $20000
BLOCK_PREVIEW_CACHE equ $3b000

block_save:
        lea editor_track(pc),a0
        lea block_original_track(pc),a1
        move.w #580,d0
        bsr storage_copy
        lea model_row_counts(pc),a0
        movea.l a5,a1
        adda.l #BLOCK_ORIGINAL_CACHE,a1
        move.w #BLOCK_CACHE_BYTES,d0
        bsr storage_copy
        lea practice_class(pc),a0
        move.w #1048,d0
        bra storage_copy
block_restore:
        move.w #1,model_valid-module_start(a5)
        lea block_original_track(pc),a0
        lea editor_track(pc),a1
        move.w #580,d0
        bsr storage_copy
        movea.l a5,a0
        adda.l #BLOCK_ORIGINAL_CACHE,a0
        lea model_row_counts(pc),a1
        move.w #BLOCK_CACHE_BYTES,d0
        bsr storage_copy
        lea practice_class(pc),a1
        move.w #1048,d0
        bra storage_copy

; D0 variant -> A4 descriptor; D0 destroyed.
block_descriptor:
        add.w d0,d0
        lea block_variants(pc),a4
        move.w (a4,d0.w),d0
        adda.w d0,a4
        rts

block_options:
        clr.w building_candidate_count-module_start(a5)
        clr.w building_choice-module_start(a5)
        clr.w block_preview_valid-module_start(a5)
        clr.w building_rows-module_start(a5)
        move.w #1,building_reason-module_start(a5)
        bsr editor_model_build
        tst.w d0
        beq .done
        bsr block_save
        move.w editor_track+28(pc),d0
        move.w d0,block_insert-module_start(a5)
        move.w d0,block_suffix-module_start(a5)
        cmpi.w #2,building_mode-module_start(a5)
        bne.s .append
        move.w building_selected(pc),d0
        beq .done
        bsr block_group_start
        move.w d0,building_selected-module_start(a5)
        move.w d0,block_insert-module_start(a5)
        moveq #1,d4
        bsr block_browse_step
        move.w d0,block_suffix-module_start(a5)
        bra.s .ready
.append:
        tst.w editor_track+30-module_start(a5)
        bne .done
.ready:
        move.w building_mode(pc),block_mode-module_start(a5)
        move.w building_selected(pc),block_selected-module_start(a5)
        ; Fresh group identifier above every existing identifier.
        lea editor_track+64(pc),a0
        move.w editor_track+28(pc),d1
        subq.w #1,d1
        moveq #0,d0
.max_id:
        cmp.l (a0),d0
        bhs.s .next_id
        move.l (a0),d0
.next_id:
        addq.l #8,a0
        dbra d1,.max_id
        andi.l #$ffffff00,d0
        addi.l #256,d0
        beq .done
        move.l d0,block_group-module_start(a5)
        cmpi.w #2,block_mode-module_start(a5)
        bne.s .group_ready
        move.w block_insert(pc),d0
        lsl.w #3,d0
        lea editor_track+64(pc),a0
        move.l (a0,d0.w),d0
        andi.l #$ffffff00,d0
        beq.s .group_ready
        move.l d0,block_group-module_start(a5)
.group_ready:
        clr.w block_scan-module_start(a5)
.scan:
        move.w block_scan(pc),d0
        bsr block_make
        tst.w d0
        bne.s .offer
        bsr block_restore
        bsr block_ghost
        tst.w d0
        beq.s .next
.offer:
        move.w building_candidate_count(pc),d0
        add.w d0,d0
        lea block_candidates(pc),a0
        move.w block_scan(pc),(a0,d0.w)
        addq.w #1,building_candidate_count-module_start(a5)
.next:
        bsr block_restore
        addq.w #1,block_scan-module_start(a5)
        cmpi.w #BLOCK_VARIANT_COUNT,block_scan-module_start(a5)
        blo .scan
        move.w block_mode(pc),building_mode-module_start(a5)
        move.w block_selected(pc),building_selected-module_start(a5)
        tst.w building_candidate_count-module_start(a5)
        beq .done
        clr.w building_reason-module_start(a5)
        bsr block_preview
.done:
        rts

; Build a candidate in borrowed model storage; callers restore or commit it.
; Model validation checks every height and both edges, then footprint collision
; checks every section, including sections inside the same proposed block.
block_make:
        move.w d0,block_variant-module_start(a5)
        bsr block_descriptor
        move.w (a4),d0
        move.w d0,block_count-module_start(a5)
        add.w block_insert(pc),d0
        add.w block_original_track+28(pc),d0
        sub.w block_suffix(pc),d0
        cmpi.w #64,d0
        bhi .bad
        move.w d0,editor_track+28-module_start(a5)
        lsl.w #3,d0
        addi.w #68,d0
        move.w d0,editor_track+6-module_start(a5)
        clr.w editor_track+30-module_start(a5)
        ; Align the entry to the actual predecessor's left endpoint.
        move.w block_insert(pc),d0
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
        moveq #0,d2
        move.w (a0),d2
        move.w 4(a4),d0
        ext.l d0
        sub.l d0,d2
        addi.l #1024,d2
        asr.l #8,d2
        asr.l #3,d2
        moveq #0,d3
        move.w 4(a0),d3
        move.w 6(a4),d0
        ext.l d0
        sub.l d0,d3
        addi.l #1024,d3
        asr.l #8,d3
        asr.l #3,d3
        move.w block_insert(pc),d0
        lsl.w #3,d0
        lea editor_track+64(pc),a1
        adda.w d0,a1
        move.l block_group(pc),d5
        move.w block_count(pc),d6
        subq.w #1,d6
        addq.l #8,a4
.piece:
        move.l d5,(a1)+
        addq.l #1,d5
        move.b (a4)+,(a1)+
        move.b (a4)+,(a1)+
        move.b (a4)+,(a1)+
        addq.l #1,a4
        move.w (a4)+,d0
        add.w d2,d0
        cmpi.w #15,d0
        bhi .bad
        move.w (a4)+,d1
        add.w d3,d1
        cmpi.w #15,d1
        bhi .bad
        lsl.w #4,d1
        or.w d1,d0
        move.b d0,(a1)+
        dbra d6,.piece
        move.w block_suffix(pc),d0
        lsl.w #3,d0
        lea block_original_track+64(pc),a0
        adda.w d0,a0
        move.w block_original_track+28(pc),d0
        sub.w block_suffix(pc),d0
        beq.s .built
        lsl.w #3,d0
        bsr storage_copy
.built:
        bsr editor_model_refresh
        tst.w d0
        beq .bad
        bsr block_height_valid
        tst.w d0
        beq .bad
        ; Replacement must not move the unchanged suffix vertically.
        move.w block_original_track+28(pc),d6
        sub.w block_suffix(pc),d6
        beq.s .suffix_done
        subq.w #1,d6
        movea.l a5,a4
        adda.l #BLOCK_ORIGINAL_CACHE,a4
        move.w block_suffix(pc),d0
        add.w d0,d0
        adda.w d0,a4
        move.w block_suffix(pc),d0
        mulu.w #EDITOR_GEOMETRY_STRIDE,d0
        movea.l a5,a2
        adda.l #BLOCK_ORIGINAL_CACHE+128,a2
        adda.w d0,a2
        move.w block_insert(pc),d0
        add.w block_count(pc),d0
        mulu.w #EDITOR_GEOMETRY_STRIDE,d0
        lea model_geometry(pc),a3
        adda.w d0,a3
.suffix_piece:
        movea.l a2,a0
        movea.l a3,a1
        move.w (a4)+,d0
        mulu.w #6,d0
        subq.w #1,d0
.suffix_point:
        cmpm.w (a0)+,(a1)+
        bne .bad
        dbra d0,.suffix_point
        adda.w #EDITOR_GEOMETRY_STRIDE,a2
        adda.w #EDITOR_GEOMETRY_STRIDE,a3
        dbra d6,.suffix_piece
.suffix_done:
        move.w #2,building_mode-module_start(a5)
        clr.w building_selected-module_start(a5)
.collision:
        move.w building_selected(pc),d0
        lsl.w #3,d0
        lea editor_track+64(pc),a0
        move.l (a0,d0.w),building_probe-module_start(a5)
        move.l 4(a0,d0.w),building_probe+4-module_start(a5)
        bsr building_collision
        tst.w d0
        beq .bad
        addq.w #1,building_selected-module_start(a5)
        move.w editor_track+28(pc),d0
        cmp.w building_selected(pc),d0
        bhi.s .collision
        moveq #1,d0
        rts
.bad:
        moveq #0,d0
        rts

block_preview:
        clr.w block_preview_valid-module_start(a5)
        clr.w block_preview_visible-module_start(a5)
        lea block_offsets(pc),a0
        move.w #191,d0
.clear_offsets:
        clr.l (a0)+
        dbra d0,.clear_offsets
        move.w building_choice(pc),d0
        add.w d0,d0
        lea block_candidates(pc),a0
        move.w (a0,d0.w),d0
        bsr block_make
        tst.w d0
        bne.s .valid
        bsr block_restore
        bsr block_ghost
        move.w d0,block_preview_visible-module_start(a5)
        bra.s .restore
.valid:
        lea editor_track(pc),a0
        lea block_preview_track(pc),a1
        move.w #580,d0
        bsr storage_copy
        lea model_row_counts(pc),a0
        movea.l a5,a1
        adda.l #BLOCK_PREVIEW_CACHE,a1
        move.w #BLOCK_CACHE_BYTES,d0
        bsr storage_copy
        move.w #1,block_preview_valid-module_start(a5)
        move.w #1,block_preview_visible-module_start(a5)
.restore:
        bsr block_restore
        move.w block_mode(pc),building_mode-module_start(a5)
        move.w block_selected(pc),building_selected-module_start(a5)
        rts

block_commit:
        move.w building_choice(pc),-(sp)
        bsr block_options
        move.w (sp)+,d0
        cmp.w building_candidate_count(pc),d0
        bhs .done
        move.w d0,building_choice-module_start(a5)
        bsr block_preview
        tst.w block_preview_valid-module_start(a5)
        beq .done
        ; Choosing the identical run preserves the previous undo snapshot.
        lea editor_track(pc),a0
        lea block_preview_track(pc),a1
        move.w 6(a0),d0
        cmp.w 6(a1),d0
        bne.s .changed
        lsr.w #2,d0
        subq.w #1,d0
.compare:
        cmpm.l (a0)+,(a1)+
        bne.s .changed
        dbra d0,.compare
        clr.w building_mode-module_start(a5)
        clr.w block_preview_valid-module_start(a5)
        rts
.changed:
        bsr editing_backup
        lea block_preview_track(pc),a0
        lea editor_track(pc),a1
        move.w #580,d0
        bsr storage_copy
        bsr preview_camera_follow
        move.w block_insert(pc),building_selected-module_start(a5)
        ; An open-track append leaves Space ready to add the next block.
        cmpi.w #1,building_mode-module_start(a5)
        bne.s .selected
        tst.w editor_track+30-module_start(a5)
        bne.s .selected
        move.w editor_track+28(pc),building_selected-module_start(a5)
.selected:
        clr.w building_mode-module_start(a5)
        clr.w block_preview_valid-module_start(a5)
        bra editing_changed
.done:
        rts

block_render_enter:
        clr.w block_render_active-module_start(a5)
        cmpi.l #3,editor_track+24-module_start(a5)
        blo .done
        tst.w building_mode-module_start(a5)
        beq .done
        tst.w building_candidate_count-module_start(a5)
        beq .done
        tst.w block_preview_visible-module_start(a5)
        beq .done
        move.w building_mode(pc),block_render_mode-module_start(a5)
        move.w building_selected(pc),block_render_selected-module_start(a5)
        lea block_preview_track(pc),a0
        lea editor_track(pc),a1
        move.w #580,d0
        bsr storage_copy
        movea.l a5,a0
        adda.l #BLOCK_PREVIEW_CACHE,a0
        lea model_row_counts(pc),a1
        move.w #BLOCK_CACHE_BYTES,d0
        bsr storage_copy
        move.w building_candidate_count(pc),block_render_count-module_start(a5)
        clr.w building_candidate_count-module_start(a5)
        clr.w building_mode-module_start(a5)
        move.w block_insert(pc),building_selected-module_start(a5)
        move.w #1,block_render_active-module_start(a5)
.done:
        rts
block_render_exit:
        tst.w block_render_active-module_start(a5)
        beq .done
        bsr block_restore
        move.w block_render_count(pc),building_candidate_count-module_start(a5)
        move.w block_render_mode(pc),building_mode-module_start(a5)
        move.w block_render_selected(pc),building_selected-module_start(a5)
        clr.w block_render_active-module_start(a5)
.done:
        rts

; D0 index -> start of its persisted group. IDs <256 remain single pieces.
block_group_start:
        tst.w d0
        beq .done
        move.w d0,d1
        lsl.w #3,d1
        lea editor_track+64(pc),a0
        adda.w d1,a0
        move.l (a0),d2
        cmpi.l #256,d2
        blo .done
        andi.l #$ffffff00,d2
.loop:
        move.l -8(a0),d1
        andi.l #$ffffff00,d1
        cmp.l d2,d1
        bne.s .done
        subq.l #8,a0
        subq.w #1,d0
        bne.s .loop
.done: rts

; D0 selection, D4 direction -> next/previous complete block or Add Piece.
block_browse_step:
        tst.w d4
        bmi.s .back
        cmp.w editor_track+28(pc),d0
        bhs.s .done
        move.w d0,d1
        lsl.w #3,d1
        lea editor_track+64(pc),a0
        adda.w d1,a0
        move.l (a0),d2
        cmpi.l #256,d2
        blo.s .single
        andi.l #$ffffff00,d2
.forward:
        addq.w #1,d0
        addq.l #8,a0
        cmp.w editor_track+28(pc),d0
        bhs.s .done
        move.l (a0),d1
        andi.l #$ffffff00,d1
        cmp.l d2,d1
        beq.s .forward
        rts
.single:
        addq.w #1,d0
.done: rts
.back:
        subq.w #1,d0
        bmi.s .done
        bra block_group_start

block_text:
        tst.w editing_prompt-module_start(a5)
        bne editing_prompt_text
        lea block_browse_text(pc),a0
        tst.w building_mode-module_start(a5)
        bne.s .choosing
        move.w building_selected(pc),d0
        cmp.w editor_track+28(pc),d0
        bne.s .draw
        lea block_add_text(pc),a0
        bra.s .draw
.choosing:
        lea block_rejected_text(pc),a0
        tst.w building_candidate_count-module_start(a5)
        beq.s .draw
        tst.w block_preview_valid-module_start(a5)
        beq.s .draw
        move.w building_choice(pc),d0
        add.w d0,d0
        lea block_candidates(pc),a0
        move.w (a0,d0.w),d0
        bsr block_descriptor
        movea.l a4,a0
        adda.w 2(a4),a0
.draw:
        movea.l draw_surface(pc),a1
        adda.w #7242,a1
        bra storage_text_line
block_rejected_text: dc.b 'NO FIT: RED BLOCK CANNOT BE ADDED',0
block_add_text: dc.b 'ADD BLOCK  FIRE/SPACE PREVIEW',0
block_browse_text: dc.b 'BLOCKS L/R  FIRE/SPACE SELECT',0
        even
block_preview_valid: dc.w 0
block_insert: dc.w 0
block_suffix: dc.w 0
block_count: dc.w 0
block_variant: dc.w 0
block_scan: dc.w 0
block_mode: dc.w 0
block_selected: dc.w 0
block_group: dc.l 0
block_render_count: dc.w 0
block_render_active: dc.w 0
block_render_mode: dc.w 0
block_render_selected: dc.w 0
block_candidates: dcb.w BLOCK_VARIANT_COUNT,0

; The model also accepts old Drafts down to zero. New building choices must
; keep every edge above the game's fixed side-wall bottom (Y=512).
; The model has already checked the upper bound, using longword arithmetic.
block_height_valid:
        movem.l d1-d3/a0-a2,-(sp)
        lea model_geometry(pc),a0
        lea model_row_counts(pc),a1
        move.w editor_track+28(pc),d1
        subq.w #1,d1
.piece:
        movea.l a0,a2
        move.w (a1)+,d2
        add.w d2,d2
        subq.w #1,d2
.point:
        cmpi.w #513,2(a2)
        blo.s .bad
        addq.l #6,a2
        dbra d2,.point
        adda.w #EDITOR_GEOMETRY_STRIDE,a0
        dbra d1,.piece
        moveq #1,d0
        bra.s .done
.bad:
        moveq #0,d0
.done:
        movem.l (sp)+,d1-d3/a0-a2
        rts
block_original_track: dcb.b 580,0
block_preview_track: dcb.b 580,0


block_highlight:
        movem.l d0-d1/a0,-(sp)
        moveq #0,d2
        cmpi.l #3,editor_track+24-module_start(a5)
        blo.s .done
        move.w building_selected(pc),d0
        cmp.w editor_track+28(pc),d0
        bhs.s .done
        move.w render_piece(pc),d1
        cmp.w editor_track+28(pc),d1
        bhs.s .done
        lsl.w #3,d0
        lsl.w #3,d1
        lea editor_track+64(pc),a0
        move.l (a0,d0.w),d0
        andi.l #$ffffff00,d0
        beq.s .done
        move.l (a0,d1.w),d1
        andi.l #$ffffff00,d1
        cmp.l d0,d1
        seq d2
.done:
        movem.l (sp)+,d0-d1/a0
        rts

; Display-only rejected proposal. Generate each piece in a safe local frame,
; then apply LONG translations in the renderer. No wrapping/clamping of the
; real out-of-map coordinates, and no relaxation of the commit validator.
block_ghost:
        move.w block_variant(pc),d0
        bsr block_descriptor
        move.w (a4),d6
        move.w d6,block_count-module_start(a5)
        add.w block_insert(pc),d6
        add.w block_original_track+28(pc),d6
        sub.w block_suffix(pc),d6
        cmpi.w #64,d6
        bhi .bad
        lea block_original_track(pc),a0
        lea block_preview_track(pc),a1
        move.w #580,d0
        bsr storage_copy
        move.w d6,block_preview_track+28-module_start(a5)
        movea.l a5,a0
        adda.l #BLOCK_ORIGINAL_CACHE,a0
        movea.l a5,a1
        adda.l #BLOCK_PREVIEW_CACHE,a1
        move.w #BLOCK_CACHE_BYTES,d0
        bsr storage_copy
        ; Predecessor endpoint in the authoritative cache.
        move.w block_insert(pc),d0
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
        move.l a0,block_ghost_join-module_start(a5)
        moveq #0,d2
        move.w (a0),d2
        move.w 4(a4),d0
        ext.l d0
        sub.l d0,d2
        addi.l #1024,d2
        asr.l #8,d2
        asr.l #3,d2
        move.w d2,block_ghost_x-module_start(a5)
        moveq #0,d3
        move.w 4(a0),d3
        move.w 6(a4),d0
        ext.l d0
        sub.l d0,d3
        addi.l #1024,d3
        asr.l #8,d3
        asr.l #3,d3
        move.w d3,block_ghost_z-module_start(a5)
        moveq #0,d7
        move.w 2(a0),d7
        move.l d7,block_ghost_y-module_start(a5)
        addq.l #8,a4
        move.w block_insert(pc),block_ghost_index-module_start(a5)
        move.w block_count(pc),d6
        subq.w #1,d6
.piece:
        move.l block_group(pc),building_probe-module_start(a5)
        move.l (a4),building_probe+4-module_start(a5)
        move.b #$77,building_probe+7-module_start(a5)
        move.w block_ghost_index(pc),d0
        mulu.w #12,d0
        lea block_offsets(pc),a2
        adda.w d0,a2
        move.w 4(a4),d0
        add.w block_ghost_x(pc),d0
        subq.w #7,d0
        ext.l d0
        lsl.l #8,d0
        lsl.l #3,d0
        move.l d0,(a2)
        move.w 6(a4),d0
        add.w block_ghost_z(pc),d0
        subq.w #7,d0
        ext.l d0
        lsl.l #8,d0
        lsl.l #3,d0
        move.l d0,8(a2)
        move.l block_ghost_y(pc),d0
        subi.l #10000,d0
        move.l d0,4(a2)
        move.w block_ghost_index(pc),d0
        mulu.w #EDITOR_GEOMETRY_STRIDE,d0
        movea.l a5,a1
        adda.l #BLOCK_PREVIEW_CACHE+128,a1
        adda.w d0,a1
        move.l a1,block_ghost_rows-module_start(a5)
        lea building_probe(pc),a0
        move.l #10000,d7
        bsr editor_piece_geometry
        tst.w d0
        beq .bad
        move.w d0,d1
        subq.w #1,d1
        mulu.w #12,d1
        movea.l block_ghost_rows(pc),a0
        moveq #0,d7
        move.w 2(a0,d1.w),d7
        add.l 4(a2),d7
        move.l d7,block_ghost_y-module_start(a5)
        move.w block_ghost_index(pc),d1
        add.w d1,d1
        movea.l a5,a1
        adda.l #BLOCK_PREVIEW_CACHE,a1
        move.w d0,(a1,d1.w)
        ; Only offer the rotation whose ordered entrance joins both edges.
        move.w block_ghost_index(pc),d1
        cmp.w block_insert(pc),d1
        bne.s .metadata
        lea block_ghost_port(pc),a1
        moveq #1,d7
.port:
        moveq #0,d0
        move.w (a0)+,d0
        add.l (a2),d0
        move.w d0,(a1)+
        moveq #0,d0
        move.w (a0)+,d0
        add.l 4(a2),d0
        move.w d0,(a1)+
        moveq #0,d0
        move.w (a0)+,d0
        add.l 8(a2),d0
        move.w d0,(a1)+
        dbra d7,.port
        movea.l block_ghost_join(pc),a0
        lea block_ghost_port(pc),a1
        bsr editor_join
        tst.w d0
        beq .bad
.metadata:
        move.w block_ghost_index(pc),d0
        lsl.w #3,d0
        lea block_preview_track+64(pc),a1
        move.l block_group(pc),(a1,d0.w)
        move.l building_probe+4(pc),4(a1,d0.w)
        addq.l #8,a4
        addq.w #1,block_ghost_index-module_start(a5)
        dbra d6,.piece
        ; Preserve unchanged suffix geometry and metadata when replacing.
        move.w block_suffix(pc),d6
.suffix:
        cmp.w block_original_track+28(pc),d6
        bhs.s .good
        move.w d6,d0
        mulu.w #EDITOR_GEOMETRY_STRIDE,d0
        movea.l a5,a0
        adda.l #BLOCK_ORIGINAL_CACHE+128,a0
        adda.w d0,a0
        move.w block_ghost_index(pc),d0
        mulu.w #EDITOR_GEOMETRY_STRIDE,d0
        movea.l a5,a1
        adda.l #BLOCK_PREVIEW_CACHE+128,a1
        adda.w d0,a1
        move.w #EDITOR_GEOMETRY_STRIDE,d0
        bsr storage_copy
        move.w d6,d0
        add.w d0,d0
        movea.l a5,a0
        adda.l #BLOCK_ORIGINAL_CACHE,a0
        move.w (a0,d0.w),d1
        move.w block_ghost_index(pc),d0
        add.w d0,d0
        movea.l a5,a1
        adda.l #BLOCK_PREVIEW_CACHE,a1
        move.w d1,(a1,d0.w)
        move.w d6,d0
        lsl.w #3,d0
        lea block_original_track+64(pc),a0
        adda.w d0,a0
        move.w block_ghost_index(pc),d0
        lsl.w #3,d0
        lea block_preview_track+64(pc),a1
        adda.w d0,a1
        moveq #8,d0
        bsr storage_copy
        addq.w #1,d6
        addq.w #1,block_ghost_index-module_start(a5)
        bra .suffix
.good:
        moveq #1,d0
        rts
.bad:
        moveq #0,d0
        rts

block_preview_visible: dc.w 0
block_ghost_x: dc.w 0
block_ghost_z: dc.w 0
block_ghost_y: dc.l 0
block_ghost_join: dc.l 0
block_ghost_rows: dc.l 0
block_ghost_index: dc.w 0
block_ghost_port: dcb.w 6,0
block_offsets: dcb.l 64*3,0

; A longword XYZ translation is used only during a rejected preview render.
block_render_offset:
        movem.l d0/a0,-(sp)
        lea block_zero_offset(pc),a3
        tst.w block_render_active-module_start(a5)
        beq.s .done
        tst.w block_preview_valid-module_start(a5)
        bne.s .done
        move.w render_piece(pc),d0
        mulu.w #12,d0
        lea block_offsets(pc),a3
        adda.w d0,a3
.done:
        movem.l (sp)+,d0/a0
        rts
block_zero_offset: dc.l 0,0,0
