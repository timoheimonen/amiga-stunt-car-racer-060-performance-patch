; Redraw the editor only when visible state changes.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Compare exact persistent view inputs, never renderer scratch or key history.
; This snapshot describes the published front surface. The back surface is
; rebuilt in full only when these inputs change; an idle loop never swaps it.
EDITOR_VIEW_SNAPSHOT equ $3f900
; Bytes before storage_status in the snapshot: the fields ahead of it below.
VIEW_SNAPSHOT_STATUS equ ((EDITOR_TRACK_BYTES+4)/2+6+3+1)*2
editor_view_changed:
        lea editor_view_fields(pc),a0
        lea EDITOR_VIEW_SNAPSHOT(a5),a1
        moveq #0,d0
        move.w editor_view_valid(pc),d3
.field:
        move.l (a0)+,d1
        move.w (a0)+,d2
        beq.s .done
        lea (a5,d1.l),a2
        subq.w #1,d2
.word:
        move.w (a2)+,d1
        cmp.w (a1),d1
        beq.s .same
        moveq #1,d0
.same:
        move.w d1,(a1)+
        dbra d2,.word
        bra.s .field
.done:
        tst.w d3
        bne.s .valid
        moveq #1,d0
.valid:
        move.w #1,editor_view_valid-module_start(a5)
        tst.w d0
        rts
editor_view_valid: dc.w 0
editor_poll_count: dc.l 0
editor_view_fields:
        ; The track, then editor_gap and editor_gap_height.
        dc.l editor_track
        dc.w (EDITOR_TRACK_BYTES+4)/2
        ; Catalog changes explicitly invalidate the view; it now spans 2 KiB.
        dc.l building_mode
        dc.w 6
        dc.l building_dirty
        dc.w 3
        dc.l overview_active
        dc.w 1
        dc.l storage_status
        dc.w 1
        dc.l storage_page
        dc.w 1
        dc.l storage_slot
        dc.w 18
        dc.l editing_prompt
        dc.w 1
        dc.l model_valid
        dc.w 1
        dc.l block_preview_valid
        dc.w 5
        dc.l block_preview_visible
        dc.w 1
        dc.l free_wire
        dc.w 9
        dc.l practice_class
        dc.w 2
        dc.l place_active
        dc.w 4
        dc.l 0
        dc.w 0
