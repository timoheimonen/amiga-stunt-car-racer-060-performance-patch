; Show the building HUD: section rise, choice number, piece count, fit reason and closing guide.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Building HUD: block name with rise and choice number, piece count, exact
; rejection reason and a closing guide from the open end to the start line, or
; to the far side of a gap.
; hud_measure runs while a preview is installed, so a valid append preview
; is measured from its own open end. Text is drawn after the model restore.
hud_measure:
        movem.l d0-d7/a0-a2,-(sp)
        clr.w hud_aid_valid-module_start(a5)
        move.w block_render_active(pc),hud_choosing-module_start(a5)
        move.w block_preview_valid(pc),hud_preview_valid-module_start(a5)
        move.w editor_track+30(pc),hud_closes-module_start(a5)
        ; A preview that fills the gap closes what is open.
        tst.w block_render_active-module_start(a5)
        beq.s .fill_done
        tst.w block_preview_valid-module_start(a5)
        beq.s .fill_done
        tst.w block_original_track+EDITOR_TRACK_BYTES-module_start(a5)
        beq.s .fill_done
        tst.w editor_gap-module_start(a5)
        bne.s .fill_done
        move.w #1,hud_closes-module_start(a5)
.fill_done:
        move.w editor_track+28(pc),hud_count-module_start(a5)
        tst.w block_render_active-module_start(a5)
        beq.s .counted
        tst.w block_preview_valid-module_start(a5)
        bne.s .counted
        move.w block_original_track+28(pc),hud_count-module_start(a5)
.counted:
        tst.w model_valid-module_start(a5)
        beq .done
        cmpi.l #3,editor_track+24-module_start(a5)
        blo .done
        tst.w hud_choosing-module_start(a5)
        beq.s .measure
        tst.w hud_preview_valid-module_start(a5)
        beq .done
.measure:
        tst.w editor_track+30-module_start(a5)
        bne .done
        tst.w editor_track+28-module_start(a5)
        beq .done
        bsr model_tail_row             ; open end: last exit row
        ; The goal: the first entrance row of the start line or after the gap.
        move.w editor_gap(pc),d0
        mulu.w #EDITOR_GEOMETRY_STRIDE,d0
        lea model_geometry(pc),a1
        adda.l d0,a1
        ; Direction indices of both right axes (45-degree steps, left +).
        move.w 6(a1),d1
        sub.w (a1),d1
        move.w 10(a1),d2
        sub.w 4(a1),d2
        bsr view_axis_index
        move.w d1,d7
        move.w 6(a0),d1
        sub.w (a0),d1
        move.w 10(a0),d2
        sub.w 4(a0),d2
        bsr view_axis_index
        sub.w d1,d7
        andi.w #7,d7
        move.w d7,hud_turn-module_start(a5)
        lsl.w #2,d1
        lea view_axes(pc),a2
        move.w (a2,d1.w),d6            ; right X
        ext.l d6
        move.w 2(a2,d1.w),d7           ; right Z
        ext.l d7
        ; Centre difference start - end, twice-sum form avoids a half unit.
        bsr hud_centre_delta           ; X
        move.l d0,d3
        bsr hud_centre_delta           ; Y
        move.l d0,d4
        bsr hud_centre_delta           ; Z
        move.l d0,d5
        ; side = D.right, ahead = D.forward with forward = (-right Z, right X)
        move.l d3,d0
        muls.l d6,d0
        move.l d5,d1
        muls.l d7,d1
        add.l d1,d0
        asr.l #7,d0
        asr.l #7,d0
        bsr hud_cells
        move.w d0,hud_side-module_start(a5)
        move.l d5,d0
        muls.l d6,d0
        move.l d3,d1
        muls.l d7,d1
        sub.l d1,d0
        asr.l #7,d0
        asr.l #7,d0
        bsr hud_cells
        move.w d0,hud_ahead-module_start(a5)
        move.l d4,d0
        bsr hud_levels
        move.w d0,hud_rise-module_start(a5)
        move.w #1,hud_aid_valid-module_start(a5)
.done:
        movem.l (sp)+,d0-d7/a0-a2
        rts

; A0 end row, A1 start row (both advance one axis word): D0 = start centre
; minus end centre on this axis, rounded down.
hud_centre_delta:
        moveq #0,d0
        move.w (a1),d0
        moveq #0,d1
        move.w 6(a1),d1
        add.l d1,d0
        moveq #0,d1
        move.w (a0),d1
        sub.l d1,d0
        move.w 6(a0),d1
        sub.l d1,d0
        asr.l #1,d0
        addq.l #2,a0
        addq.l #2,a1
        rts

; D0 world units -> nearest map cells (2048), and eighths of a level (256),
; the 32-unit grid of the heights.
hud_cells:
        addi.l #1024,d0
        asr.l #8,d0
        asr.l #3,d0
        rts
hud_levels:
        addi.l #16,d0
        asr.l #5,d0
        rts

; L1 while choosing: name and rise.
hud_block_line:
        lea hud_line(pc),a1
        move.w building_choice(pc),d0
        add.w d0,d0
        lea block_candidates(pc),a0
        move.w (a0,d0.w),d0
        move.w d0,-(sp)
        bsr block_descriptor
        movea.l a4,a0
        adda.w 2(a4),a0
        bsr hud_put_text
        move.w (sp)+,d0
        lsr.w #2,d0
        lsl.w #2,d0
        lea block_heights(pc),a0
        moveq #0,d1
        move.w (a0,d0.w),d1
        ext.l d1
        move.l d1,d0
        bsr hud_levels
        bsr hud_put_rise
        clr.b (a1)
        lea hud_line(pc),a0
        rts

; L1 on a whole-block track: "Straight 4 of 6". D0 selected section start.
hud_section_line:
        move.w building_selected(pc),d0
        bsr block_group_start
        move.w d0,d6
        moveq #1,d4
        bsr block_browse_step
        move.w d0,d7
        sub.w d6,d7                     ; pieces of the section
        lea hud_start_line_text(pc),a0
        tst.w d6
        beq.s .named
        bsr hud_section_name
.named:
        lea hud_line(pc),a1
        bsr hud_put_text
        move.b #' ',(a1)+
        ; Sections before it, then all of them.
        moveq #0,d0
        moveq #0,d5
.count: cmp.w d6,d0
        bne.s .before
        move.w d5,d7
.before:
        cmp.w editor_track+28(pc),d0
        bhs.s .counted
        addq.w #1,d5
        moveq #1,d4
        bsr block_browse_step
        bra.s .count
.counted:
        move.w d7,d0
        addq.w #1,d0
        bsr hud_put_decimal
        lea hud_of_text(pc),a0
        bsr hud_put_text
        move.w d5,d0
        bsr hud_put_decimal
        clr.b (a1)
        lea hud_line(pc),a0
        rts

; Sections keep no block number, so the name comes from their piece types.
; D6 first piece, D7 pieces -> A0 name.
hud_section_name:
        moveq #0,d3
.variant:
        move.w d3,d0
        bsr block_descriptor
        cmp.w (a4),d7
        bne.s .next
        lea 8(a4),a2
        move.w d6,d0
        lsl.w #3,d0
        lea editor_track+68(pc),a0
        adda.w d0,a0
        move.w d7,d1
        subq.w #1,d1
.piece: moveq #2,d0
.byte:  cmpm.b (a0)+,(a2)+
        bne.s .next
        dbra d0,.byte
        addq.l #5,a0
        addq.l #5,a2
        dbra d1,.piece
        movea.l a4,a0
        adda.w 2(a4),a0
        rts
.next:  addq.w #1,d3
        cmpi.w #BLOCK_VARIANT_COUNT,d3
        blo.s .variant
        lea hud_section_text(pc),a0
        rts

UI_LEVEL_NONE equ 15

; L2 for whole-block tracks; otherwise the practice status.
hud_status_line:
        tst.w place_active-module_start(a5)
        bne .place
        tst.w overview_active-module_start(a5)
        bne .overview
        cmpi.l #3,editor_track+24-module_start(a5)
        blo .practice
        tst.w building_mode-module_start(a5)
        beq.s .chosen
        tst.w building_candidate_count-module_start(a5)
        bne.s .chosen
        lea hud_none_text(pc),a0
        bra .draw
.chosen:
        tst.w hud_choosing-module_start(a5)
        beq .browse
        tst.w hud_preview_valid-module_start(a5)
        bne.s .valid
        move.w block_fail(pc),d0
        add.w d0,d0
        lea hud_fail_texts(pc),a0
        move.w (a0,d0.w),d0
        adda.w d0,a0
        bra .draw
.valid:
        tst.w hud_closes-module_start(a5)
        beq.s .route
        lea hud_closes_text(pc),a0
        lea hud_fills_text(pc),a1
        bsr hud_goal_text
        bra .draw
.route: cmpi.w #1,block_mode-module_start(a5)
        bne.s .aid
        tst.w block_original_track+30-module_start(a5)
        bne.s .aid
        bsr hud_route_level
        cmpi.w #UI_LEVEL_NONE,d2
        bne.s .way
        lea hud_no_way_text(pc),a0
        lea hud_no_way_gap_text(pc),a1
        bsr hud_goal_text
        bra.s .draw
.way:   bsr hud_odd
        bne.s .odd
        tst.w d2
        bne.s .count
        lea hud_height_text(pc),a0
        lea hud_gap_height_text(pc),a1
        bsr hud_goal_text
        bra.s .draw
.count: bsr hud_route_text
        bra.s .draw
.browse:
        tst.w editor_track+30-module_start(a5)
        bne.s .practice
        cmpi.w #1,practice_reason-module_start(a5)
        bne.s .practice
.aid:
        bsr hud_odd
        beq.s .aid_only
.odd:   bsr hud_odd_text
        bra.s .draw
.aid_only:
        tst.w hud_aid_valid-module_start(a5)
        beq.s .practice
        bsr hud_build_aid
        bra.s .draw
.overview:
        lea hud_overview_text(pc),a0
        bra.s .draw
.place: bsr place_text
        bra.s .draw
.practice:
        bsr practice_text
        tst.w practice_reason-module_start(a5)
        bne.s .draw
        moveq #UI_SAY_HINT,d0
        bra ui_status_put
.draw:
        moveq #UI_SAY_REASON,d0
        bra ui_status_put

; Z clear when the open end has an odd rise: the height can never meet. A gap
; asks for the rise of the section that was there, so it is not odd.
hud_odd:
        tst.w editor_gap-module_start(a5)
        bne.s .gap
        tst.w hud_aid_valid-module_start(a5)
        beq.s .done
        btst #0,hud_rise+1-module_start(a5)
.done:  rts
.gap:   cmp.w d0,d0
        rts

; A0 text of the start line, A1 of the gap -> A0 the one for this track.
hud_goal_text:
        tst.w editor_gap-module_start(a5)
        beq.s .done
        movea.l a1,a0
.done:  rts

; D2 the level of the choice in the distance field.
hud_route_level:
        move.w building_choice(pc),d0
        lea block_info(pc),a0
        moveq #0,d2
        move.b (a0,d0.w),d2
        lsr.b #4,d2
        rts

; "At least 3 more sections to the start." D2 sections.
hud_route_text:
        lea hud_line(pc),a1
        lea hud_least_text(pc),a0
        bsr hud_put_text
        move.w d2,d0
        bsr hud_put_decimal
        lea hud_more_text(pc),a0
        bsr hud_put_text
        cmpi.w #1,d2
        beq.s .one
        move.b #'s',(a1)+
.one:   lea hud_to_start_text(pc),a0
        movea.l a1,a2
        lea hud_to_gap_text(pc),a1
        bsr hud_goal_text
        movea.l a2,a1
        bsr hud_put_text
        clr.b (a1)
        lea hud_line(pc),a0
        rts

; "Start 3 left 2 ahead +1 3/8 face L90". A0 = text.
hud_build_aid:
        lea hud_line(pc),a1
        lea hud_start_text(pc),a0
        movea.l a1,a2
        lea hud_gap_text(pc),a1
        bsr hud_goal_text
        movea.l a2,a1
        bsr hud_put_text
        move.w hud_side(pc),d0
        beq.s .ahead
        lea hud_right_text(pc),a2
        bpl.s .side
        neg.w d0
        lea hud_left_text(pc),a2
.side:
        move.b #' ',(a1)+
        bsr hud_put_decimal
        movea.l a2,a0
        bsr hud_put_text
.ahead:
        move.w hud_ahead(pc),d0
        beq.s .rise
        lea hud_forward_text(pc),a2
        bpl.s .along
        neg.w d0
        lea hud_back_text(pc),a2
.along:
        move.b #' ',(a1)+
        bsr hud_put_decimal
        movea.l a2,a0
        bsr hud_put_text
.rise:
        move.w hud_rise(pc),d0
        ext.l d0
        bsr hud_put_rise
        move.w hud_turn(pc),d0
        beq.s .end
        lea hud_face_text(pc),a0
        bsr hud_put_text
        cmpi.w #4,d0
        bne.s .sided
        lea hud_reverse_text(pc),a0
        bsr hud_put_text
        bra.s .end
.sided:
        move.b #'L',(a1)+
        cmpi.w #4,d0
        blo.s .angle
        move.b #'R',-1(a1)
        neg.w d0
        addq.w #8,d0
.angle:
        mulu.w #45,d0
        bsr hud_put_decimal
.end:
        clr.b (a1)
        lea hud_line(pc),a0
        rts

; D0.l eighths -> " +1 3/8" / " -5", nothing when level. A1 advances.
hud_put_rise:
        tst.l d0
        beq.s .done
        lea hud_up_text(pc),a0
        bpl.s .text
        neg.l d0
        lea hud_down_text(pc),a0
.text:
        move.w d0,-(sp)
        bsr hud_put_text
        move.w (sp),d0
        lsr.w #3,d0
        beq.s .eighths
        bsr hud_put_decimal
        move.b #' ',(a1)+
.eighths:
        move.w (sp)+,d0
        andi.w #7,d0
        bne.s .fraction
        subq.l #1,a1
        bra.s .done
.fraction:
        bsr hud_put_decimal
        move.b #'/',(a1)+
        move.b #'8',(a1)+
.done:  rts

; An odd 32-unit rise never meets the 64 unit grid of the blocks. Only a track
; built before both drops were put on the grid has one: Downhill large began
; with kind 48 before kind 45, Coaster descent with kind 14 before kind 97.
; Today's Coaster descent begins with kind 48 before kind 97. A0 text.
hud_odd_text:
        lea hud_odd_large(pc),a0
        lea editor_track+68(pc),a1
        move.w editor_track+28(pc),d1
        subq.w #2,d1
        bmi.s .steep
.find:  cmpi.b #48,(a1)
        bne.s .next
        cmpi.b #45,8(a1)
        beq.s .found
.next:  addq.l #8,a1
        dbra d1,.find
.steep: lea hud_odd_steep(pc),a0
.found: rts

; Right end of L1: "20/64" and the track's word. A star marks unsaved changes,
; which L2 can not always say.
hud_count_line:
        lea ui_next_count(pc),a1
        move.w hud_count(pc),d0
        bsr hud_put_decimal
        lea hud_capacity_text(pc),a0
        bsr hud_put_text
        clr.b (a1)
        lea ui_next_word(pc),a1
        lea hud_open_text(pc),a0
        cmpi.w #2,practice_class-module_start(a5)
        bne.s .word
        lea hud_ready_text(pc),a0
.word:  bsr hud_put_text
        tst.w building_dirty-module_start(a5)
        beq.s .end
        move.b #'*',(a1)+
.end:   clr.b (a1)
        rts

; Copy a zero-terminated string A0 to A1 without its terminator.
hud_put_text:
        move.b (a0)+,d1
        beq.s .done
        move.b d1,(a1)+
        bra.s hud_put_text
.done:  rts

; Unsigned decimal of D0.w to A1. D0/D1 destroyed.
hud_put_decimal:
        andi.l #$ffff,d0
        cmpi.w #10,d0
        blo.s .digit
        divu.w #10,d0
        move.l d0,-(sp)
        andi.l #$ffff,d0
        bsr hud_put_decimal
        move.l (sp)+,d0
        swap d0
.digit:
        addi.b #'0',d0
        move.b d0,(a1)+
        rts

hud_fail_texts:
        dc.w .red-hud_fail_texts,.limit-hud_fail_texts,.map-hud_fail_texts
        dc.w .height-hud_fail_texts,.low-hud_fail_texts,.next-hud_fail_texts
        dc.w .overlap-hud_fail_texts,.low-hud_fail_texts
.red: dc.b 'This block cannot be added here.',0
.limit: dc.b 'Too long: 78 pieces is the limit.',0
.map: dc.b 'Runs off the map.',0
.height: dc.b 'Road would go too high.',0
.low: dc.b 'Road would go too low.',0
.next: dc.b 'Next section would not join.',0
.overlap: dc.b 'Crosses road already built.',0
hud_closes_text: dc.b 'This section closes the track.',0
hud_no_way_text: dc.b 'No way back from here.',0
hud_height_text: dc.b 'Reaches the start at the wrong height.',0
hud_fills_text: dc.b 'This section fills the gap.',0
hud_no_way_gap_text: dc.b 'No way to the gap from here.',0
hud_gap_height_text: dc.b 'Reaches the gap at the wrong height.',0
hud_to_gap_text: dc.b ' to the gap.',0
hud_gap_text: dc.b 'Gap',0
hud_none_text: dc.b 'Nothing fits here. Undo or Del.',0
hud_least_text: dc.b 'At least ',0
hud_more_text: dc.b ' more section',0
hud_to_start_text: dc.b ' to the start.',0
hud_odd_large: dc.b 'Height never meets: undo the Downhill large.',0
hud_odd_steep: dc.b 'Height never meets: undo the steep descent.',0
hud_overview_text: dc.b 'Overview. Press V to go back.',0
hud_section_text: dc.b 'Section',0
hud_start_line_text: dc.b 'Start line',0
hud_of_text: dc.b ' of ',0
hud_open_text: dc.b 'Open',0
hud_ready_text: dc.b 'Ready',0
hud_start_text: dc.b 'Start',0
hud_left_text: dc.b ' left',0
hud_right_text: dc.b ' right',0
hud_forward_text: dc.b ' ahead',0
hud_back_text: dc.b ' back',0
hud_up_text: dc.b ' +',0
hud_down_text: dc.b ' -',0
hud_face_text: dc.b ' face ',0
hud_reverse_text: dc.b '180',0
hud_capacity_text: dc.b '/','0'+EDITOR_MAX_PIECES/10,'0'+EDITOR_MAX_PIECES-EDITOR_MAX_PIECES/10*10,0
        even
hud_choosing: dc.w 0
hud_preview_valid: dc.w 0
hud_closes: dc.w 0
hud_count: dc.w 0
hud_aid_valid: dc.w 0
hud_side: dc.w 0
hud_ahead: dc.w 0
hud_rise: dc.w 0
hud_turn: dc.w 0
hud_line: dcb.b 48,0
