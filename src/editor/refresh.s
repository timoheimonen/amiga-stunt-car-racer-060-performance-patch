; Redraw the editor only when visible state changes.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Compare exact persistent view inputs, never renderer scratch or key history.
; This snapshot describes the published front surface. The back surface is
; rebuilt in full only when these inputs change; an idle loop never swaps it.
EDITOR_VIEW_SNAPSHOT equ $3f900
editor_view_changed:
        lea editor_view_fields(pc),a0
        lea EDITOR_VIEW_SNAPSHOT(a5),a1
        moveq #0,d0
        move.w editor_view_valid(pc),d3
.field:
        moveq #0,d1
        move.w (a0)+,d1
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
        dc.w editor_track,290
        ; Catalog changes explicitly invalidate the view; it now spans 2 KiB.
        dc.w disk_state,(disk_state_end-disk_state)/2
        dc.w building_mode,6
        dc.w building_dirty,3
        dc.w camera_route,2
        dc.w overview_active,1
        dc.w storage_status,1
        dc.w storage_page,1
        dc.w storage_slot,18
        dc.w editing_prompt,1
        dc.w model_valid,1
        dc.w block_preview_valid,5
        dc.w block_preview_visible,1
        dc.w practice_class,2
        dc.w 0,0
