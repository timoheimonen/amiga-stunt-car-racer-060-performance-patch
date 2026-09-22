; Validate custom tracks for inclusion in Practise.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; shared validation: D0=1 Ready, 0 Draft/Closed/invalid.
; Only editor-owned Fast data is written. Every entry rechecks CRC/model.
validate_for_practice:
        bsr editor_model_build
        moveq #0,d0
        move.w practice_runtime_valid(pc),d0
        rts

; Called after model geometry validation, including load/save/edit/undo.
; Class 0 Draft, 1 Closed, 2 Ready. Reasons match host oracle.
practice_classify:
        movem.l d0-d7/a0-a4,-(sp)
        clr.w practice_class-module_start(a5)
        clr.w practice_runtime_valid-module_start(a5)
        move.w #1,practice_reason-module_start(a5)
        cmpi.l #2,editor_track+24-module_start(a5)
        blo .legacy
        tst.w editor_track+30-module_start(a5)
        beq .done
        move.w #1,practice_class-module_start(a5)
        move.w #2,practice_reason-module_start(a5)
        move.w editor_track+28(pc),d6
        cmpi.w #8,d6
        blo .done
        lea model_row_counts(pc),a0
        move.w d6,d0
        subq.w #1,d0
        moveq #0,d7
.segments:
        add.w (a0)+,d7
        subq.w #1,d7
        dbra d0,.segments
        cmpi.w #64,d7
        blo .done
        ; Original near/far side walls have a fixed bottom Y=512.
        ; A road below that plane produces inverted walls/stray edge lines.
        move.w #7,practice_reason-module_start(a5)
        lea model_geometry(pc),a0
        lea model_row_counts(pc),a1
        move.w d6,d0
        subq.w #1,d0
.clearance_piece:
        movea.l a0,a2
        move.w (a1)+,d1
        add.w d1,d1
        subq.w #1,d1
.clearance_vertex:
        cmpi.w #512,2(a2)
        bls .done
        addq.l #6,a2
        dbra d1,.clearance_vertex
        adda.w #EDITOR_GEOMETRY_STRIDE,a0
        dbra d0,.clearance_piece
        ; Reuse whole-footprint collision contract, preserving preview state.
        move.w building_mode(pc),-(sp)
        move.w building_selected(pc),-(sp)
        move.l building_probe(pc),-(sp)
        move.l building_probe+4(pc),-(sp)
        move.w #2,building_mode-module_start(a5)
        clr.w building_selected-module_start(a5)
.collision:
        movem.l d6-d7,-(sp)
        move.w building_selected(pc),d0
        lsl.w #3,d0
        lea editor_track+64(pc),a0
        adda.w d0,a0
        move.l (a0),building_probe-module_start(a5)
        move.l 4(a0),building_probe+4-module_start(a5)
        bsr building_collision
        movem.l (sp)+,d6-d7
        tst.w d0
        beq.s .collision_done
        addq.w #1,building_selected-module_start(a5)
        cmp.w building_selected(pc),d6
        bhi.s .collision
.collision_done:
        move.l (sp)+,building_probe+4-module_start(a5)
        move.l (sp)+,building_probe-module_start(a5)
        move.w (sp)+,building_selected-module_start(a5)
        move.w (sp)+,building_mode-module_start(a5)
        move.w #3,practice_reason-module_start(a5)
        tst.w d0
        beq .done
        ; Header: checker,count,start,finish,checkpoint,segments,startRow,finishRow.
        lea practice_runtime(pc),a1
        move.w #3,(a1)+
        move.w d6,(a1)+
        lea editor_track+64(pc),a0
        moveq #0,d4
.find_finish:
        move.l (a0),d0
        cmp.l editor_track+36(pc),d0
        beq.s .finish
        addq.w #1,d4
        addq.l #8,a0
        bra.s .find_finish
.finish:
        move.w d4,(a1)+
        move.w d4,(a1)+
        move.w d6,d0
        lsr.w #1,d0
        add.w d4,d0
        cmp.w d6,d0
        blo.s .checkpoint
        sub.w d6,d0
.checkpoint:
        move.w d0,(a1)+
        move.w d7,(a1)+
        move.w #4,(a1)+
        move.w #8,(a1)+
        lea editor_track+64(pc),a0
        lea model_geometry(pc),a2
        lea model_row_counts(pc),a3
        moveq #0,d4             ; colour phase
        subq.w #1,d6
.entry:
        move.l (a0),(a1)+
        move.b 7(a0),(a1)+
        bsr practice_piece_metadata
        move.b d1,(a1)+
        move.b d2,(a1)+
        move.b d4,d2
        lsl.b #7,d2
        or.b d2,d3
        move.b d3,(a1)+
        bsr practice_first_heights
        move.w 2(a2),d0
        sub.w d1,d0
        move.w d0,(a1)+
        move.w 8(a2),d0
        sub.w d2,d0
        move.w d0,(a1)+
        move.w (a3)+,d3
        subq.w #1,d3
        move.w d3,(a1)+
        bsr practice_crane_safe
        move.w d0,(a1)+
        add.w d3,d4
        andi.w #1,d4
        addq.l #8,a0
        adda.w #EDITOR_GEOMETRY_STRIDE,a2
        dbra d6,.entry
        ; Roundtrip: decode every private entry through catalog geometry and
        ; compare all XYZ words. Metadata bytes have no external input path.
        bsr practice_roundtrip
        move.w #5,practice_reason-module_start(a5)
        tst.w d0
        beq.s .done
        move.w #2,practice_class-module_start(a5)
        move.w #1,practice_runtime_valid-module_start(a5)
        clr.w practice_reason-module_start(a5)
        bra.s .done
.legacy:
        move.w #6,practice_reason-module_start(a5)
.done:
        movem.l (sp)+,d0-d7/a0-a4
        rts

practice_roundtrip:
        movem.l d1-d7/a0-a4,-(sp)
        lea practice_runtime(pc),a3
        cmpi.w #3,(a3)
        bne .bad
        move.w editor_track+28(pc),d0
        cmp.w 2(a3),d0
        bne .bad
        cmpi.w #8,d0
        blo .bad
        cmpi.w #64,d0
        bhi .bad
        move.w 4(a3),d1
        cmp.w d0,d1
        bhs .bad
        cmp.w 6(a3),d1
        bne .bad
        move.w d1,d2
        lsl.w #3,d2
        lea editor_track+64(pc),a0
        move.l (a0,d2.w),d2
        cmp.l editor_track+36(pc),d2
        bne .bad
        move.w d0,d2
        lsr.w #1,d2
        add.w d1,d2
        cmp.w d0,d2
        blo.s .half
        sub.w d0,d2
.half:
        cmp.w 8(a3),d2
        bne .bad
        cmpi.l #$00040008,12(a3)
        bne .bad
        moveq #0,d5             ; summed segments and colour phase
        lea practice_runtime+16(pc),a3
        lea model_geometry(pc),a4
        move.w editor_track+28(pc),d6
        subq.w #1,d6
.piece:
        move.l (a0),d0
        cmp.l (a3),d0
        bne .bad
        move.b 7(a0),d0
        cmp.b 4(a3),d0
        bne .bad
        bsr practice_piece_metadata
        cmp.b 5(a3),d1
        bne .bad
        cmp.b 6(a3),d2
        bne .bad
        move.w d5,d2
        andi.w #1,d2
        lsl.b #7,d2
        or.b d2,d3
        cmp.b 7(a3),d3
        bne .bad
        bsr practice_crane_safe
        cmp.w 14(a3),d0
        bne .bad
        bsr practice_first_heights
        move.w 2(a4),d0
        sub.w d1,d0
        cmp.w 8(a3),d0
        bne .bad
        move.w 8(a4),d0
        sub.w d2,d0
        cmp.w 10(a3),d0
        bne .bad
        moveq #0,d7
        move.w 8(a3),d7
        add.w d1,d7
        andi.l #$ffff,d7
        lea practice_geometry(pc),a1
        bsr editor_piece_geometry
        tst.w d0
        beq.s .bad
        move.w 12(a3),d1
        addq.w #1,d1
        cmp.w d1,d0
        bne.s .bad
        add.w 12(a3),d5
        mulu.w #6,d0
        subq.w #1,d0
        lea practice_geometry(pc),a1
        movea.l a4,a2
.compare:
        cmpm.w (a1)+,(a2)+
        bne.s .bad
        dbra d0,.compare
        addq.l #8,a0
        adda.w #16,a3
        adda.w #EDITOR_GEOMETRY_STRIDE,a4
        dbra d6,.piece
        cmp.w practice_runtime+10(pc),d5
        bne.s .bad
        moveq #1,d0
        bra.s .done
.bad:
        moveq #0,d0
.done:
        movem.l (sp)+,d1-d7/a0-a4
        rts
 ; A0 piece -> D1 angle, D2 left profile, D3 right profile. Others preserved.
practice_piece_metadata:
        movem.l d0/a4,-(sp)
        bsr practice_catalog_entry
        moveq #0,d1
        move.b (a4),d1
        moveq #0,d2
        move.b 1(a4),d2
        moveq #0,d3
        move.b 2(a4),d3
        cmp.b d2,d3
        bne.s .angle
        ori.b #32,d1
.angle:
        move.b 5(a0),d0
        lsl.b #6,d0
        or.b d0,d1
        move.b 6(a0),d0
        lsl.b #4,d0
        or.b d0,d1
        movem.l (sp)+,d0/a4
        rts

; A0 piece -> original first profile samples D1/D2, independently.
practice_first_heights:
        movem.l d0/a4,-(sp)
        bsr practice_catalog_entry
        moveq #0,d1
        move.w 4(a4),d1
        moveq #0,d2
        move.w 6(a4),d2
        movem.l (sp)+,d0/a4
        rts
practice_crane_safe:
        movem.l d1/a4,-(sp)
        moveq #0,d1
        move.b 4(a0),d1
        subq.w #1,d1
        lea practice_safe_kinds(pc),a4
        moveq #0,d0
        move.b (a4,d1.w),d0
        movem.l (sp)+,d1/a4
        rts
practice_catalog_entry:
        moveq #0,d0
        move.b 4(a0),d0
        subq.w #1,d0
        cmpi.w #7,d0
        bhs.s .entry
        tst.b 6(a0)
        beq.s .entry
        addi.w #EDITOR_KIND_COUNT,d0
.entry:
        lsl.w #3,d0
        lea practice_catalog(pc),a4
        adda.w d0,a4
        rts
practice_class: dc.w 0
practice_reason: dc.w 1
practice_runtime_valid: dc.w 0
practice_runtime: dcb.b 1040,0
practice_geometry: dcb.b EDITOR_GEOMETRY_STRIDE,0

practice_text:
        move.w practice_reason(pc),d0
        add.w d0,d0
        lea practice_messages(pc),a0
        move.w (a0,d0.w),d0
        adda.w d0,a0
        rts
practice_messages:
        dc.w .ready-practice_messages,.draft-practice_messages,.short-practice_messages
        dc.w .overlap-practice_messages,.start-practice_messages,.runtime-practice_messages,.legacy-practice_messages,.clearance-practice_messages
.ready: dc.b 'READY',0
.draft: dc.b 'DRAFT: CLOSE BOTH ROAD EDGES',0
.short: dc.b 'CLOSED: ROAD TOO SHORT',0
.overlap: dc.b 'CLOSED: ROAD OVERLAP',0
.start: dc.b 'CLOSED: INVALID START AREA',0
.runtime: dc.b 'CLOSED: RUNTIME CHECK FAILED',0
.clearance: dc.b 'CLOSED: ROAD BELOW SIDE BASE',0
.legacy: dc.b 'DRAFT: LEGACY UNBANKED GEOMETRY',0
        even
