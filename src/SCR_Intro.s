; Display the animated flag intro with mouse-button dismissal.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Position-independent Finnish flag boot intro, KS3.1 PAL. Called before SuperState.
; Intuition owns display/input; no CIA/custom register takeover.
; All pointers are relative to A5, the loaded code base. Payload is CHIP.
        org 0
start:
        movem.l d0-d7/a0-a6,-(sp)
        lea start(pc),a5
        move.l 4.w,a6
        lea intuition_name(pc),a1
        moveq #39,d0
        jsr -552(a6)
        move.l d0,ibase-start(a5)
        beq cleanup
        lea graphics_name(pc),a1
        moveq #39,d0
        jsr -552(a6)
        move.l d0,gbase-start(a5)
        beq cleanup
        move.l #40960,d0
        move.l #$10001,d1
        jsr -198(a6)
        move.l d0,backbuffer-start(a5)
        beq cleanup
        move.l #128*129*12,d0
        moveq #1,d1             ; PUBLIC geometry; Fast preferred, Chip fallback
        jsr -198(a6)
        move.l d0,flag_frames-start(a5)
        beq cleanup
        bsr prepare_flag_frames
        move.l ibase-start(a5),a6
        suba.l a0,a0
        lea screen_tags(pc),a1
        jsr -612(a6)
        move.l d0,screen-start(a5)
        beq cleanup
        move.l d0,window_screen-start(a5)
        lea new_window(pc),a0
        jsr -204(a6)
        move.l d0,window-start(a5)
        beq cleanup
        move.l d0,a0
        lea blank_pointer(pc),a1
        moveq #1,d0
        moveq #16,d1
        moveq #0,d2
        moveq #0,d3
        jsr -270(a6)
        move.l gbase-start(a5),a6
        move.l screen-start(a5),a0
        move.l 88(a0),a2
        move.l 8(a2),plane-start(a5)
        move.l 12(a2),plane1-start(a5)
        move.l 16(a2),plane2-start(a5)
        move.l 20(a2),plane3-start(a5)
        move.w (a2),rowbytes-start(a5)
        lea 44(a0),a0
        lea palette(pc),a1
        jsr -882(a6)            ; LoadRGB32, exact 24-bit palette
        bsr draw_static
        bsr draw_frame
        bsr present_full
        move.l ibase-start(a5),a6
        move.l screen-start(a5),a0
        jsr -252(a6)
        bsr read_vbl_count
        move.l d0,flag_start_vbl-start(a5)
frame_loop:
        bsr read_vbl_count
        sub.l flag_start_vbl-start(a5),d0
        and.l #$ffffff,d0
        sub.l #100,d0           ; Hold Finland for 100 PAL vertical blanks.
        blo.s .draw
        cmp.l #50,d0            ; Then wipe right-to-left over 50 vertical blanks.
        bhs.s .checkered
        lsl.l #7,d0
        divu #50,d0
        move.w #128,d1
        sub.w d0,d1
        move.w d1,wipe_column-start(a5)
        bra.s .draw
.checkered:
        clr.w wipe_column-start(a5)
        move.w #1,flag_kind-start(a5)
.draw:
        bsr draw_frame
        move.l gbase-start(a5),a6
        jsr -270(a6)            ; WaitTOF, PAL clock without speed changes
        bsr present
        addq.w #2,phase-start(a5)
        addq.w #2,scroll_x-start(a5)
        cmp.w #SCROLL_CYCLE,scroll_x-start(a5)
        blo.s .input
        clr.w scroll_x-start(a5)
.input:
        move.l window-start(a5),a0
        move.l 86(a0),a0
        move.l 4.w,a6
        jsr -372(a6)
        tst.l d0
        beq frame_loop
        move.l d0,a1
        move.l 20(a1),d2
        move.w 24(a1),d3
        jsr -378(a6)
        tst.l pressed_class-start(a5)
        bne.s .release
        cmp.l #8,d2
        bne.s .input
        cmp.w #$68,d3
        blo.s .input
        cmp.w #$6a,d3
        bhi.s .input
.press:
        move.l d2,pressed_class-start(a5)
        or.w #$80,d3
        move.w d3,pressed_code-start(a5)
        bra.s .input
.release:
        cmp.l pressed_class-start(a5),d2
        bne.s .input
        cmp.w pressed_code-start(a5),d3
        bne.s .input
        bra cleanup
read_vbl_count:
        ; Read-only CIA-A TOD snapshot: high read latches, low releases it.
        moveq #0,d0
        move.b $bfea01,d0
        lsl.l #8,d0
        move.b $bfe901,d0
        lsl.l #8,d0
        move.b $bfe801,d0
        rts
cleanup:
        move.l ibase-start(a5),a6
        move.l window-start(a5),d0
        beq.s .no_window
        move.l d0,a0
        jsr -72(a6)
.no_window:
        move.l screen-start(a5),d0
        beq.s .no_screen
        move.l d0,a0
        jsr -66(a6)
.no_screen:
        move.l gbase-start(a5),d0
        beq.s .no_wait
        move.l d0,a6
        jsr -228(a6)
        jsr -270(a6)
        jsr -270(a6)
.no_wait:
        move.l 4.w,a6
        move.l backbuffer-start(a5),d0
        beq.s .no_buffer
        move.l d0,a1
        move.l #40960,d0
        jsr -210(a6)
.no_buffer:
        move.l flag_frames-start(a5),d0
        beq.s .no_flag_frames
        move.l d0,a1
        move.l #128*129*12,d0
        jsr -210(a6)
.no_flag_frames:
        move.l gbase-start(a5),d0
        beq.s .no_gfx
        move.l d0,a1
        jsr -414(a6)
.no_gfx:
        move.l ibase-start(a5),d0
        beq.s .done
        move.l d0,a1
        jsr -414(a6)
.done:
        movem.l (sp)+,d0-d7/a0-a6
        rts

prepare_flag_frames:
        ; Perspective project a cloth surface with Finnish 18:11 proportions. X is world-space;
        ; wave Z grows towards the free edge. Camera distance is 384.
        lea sine(pc),a2
        move.l flag_frames-start(a5),a3
.phase:
        moveq #0,d7
.project:
        move.w phase-start(a5),d0
        move.w d7,d1
        add.w d1,d1
        sub.w d1,d0
        and.w #255,d0
        move.w d0,d6
        move.b (a2,d0.w),d0
        ext.w d0
        muls d7,d0
        asr.l #8,d0
        move.w d0,d5
        asr.w #2,d5             ; free-edge vertical lift follows the wave
        move.w d7,d1
        sub.w #64,d1
        asr.w #1,d1             ; modest yaw contributes depth
        add.w d1,d0
        add.w #384,d0           ; camera denominator, always positive
        move.w d0,d1
        move.w d7,d2
        sub.w #64,d2
        muls #672,d2
        divs d1,d2
        add.w #160,d2
        move.w d2,(a3)+         ; screen X boundary
        move.l #26283,d3
        divs d1,d3             ; projected half-height
        move.w d7,d4
        lsr.w #3,d4
        neg.w d4
        add.w #108,d4          ; slight roll, centre 92..108
        add.w d5,d4
        move.w d4,d2
        sub.w d3,d2
        move.w d2,(a3)+         ; top boundary
        add.w d3,d4
        move.w d4,(a3)+         ; bottom boundary
        move.w #7,(a3)+         ; pure white
        sub.w d2,d4             ; projected height, precompute cross boundaries
        moveq #0,d0
        move.w d4,d0
        lsl.l #2,d0
        divu #11,d0
        move.w d0,(a3)+
        moveq #0,d0
        move.w d4,d0
        mulu #7,d0
        divu #11,d0
        move.w d0,(a3)+
        addq.w #1,d7
        cmp.w #129,d7
        blo .project
        addq.w #2,phase-start(a5)
        cmp.w #256,phase-start(a5)
        blo .phase
        clr.w phase-start(a5)
        rts

FLAG_ROWS equ 183               ; cloth markers end at row 182
TEXT_ROW equ 218
TEXT_ROWS equ 16

; Planes 0-2 of the flag area are rebuilt in private PUBLIC RAM each frame:
; XOR edge markers per column, then a downward long-word fill. The plaque,
; plane 3 and the rows below the cloth stay static after present_full.
draw_static:
        ; Raised pale-green plaque: 304x40, three-pixel upper/lower bevels.
        move.l backbuffer-start(a5),a0
        adda.w #204*40+1,a0
        moveq #0,d7
.plaque_row:
        moveq #0,d1
        moveq #0,d2
        cmp.w #3,d7
        bhs.s .not_top
        moveq #-1,d1
.not_top:
        cmp.w #37,d7
        blo.s .not_bottom
        moveq #-1,d2
.not_bottom:
        moveq #37,d6
.plaque_byte:
        move.b d1,(a0)
        move.b d2,10240(a0)
        move.b #$ff,30720(a0)
        addq.l #1,a0
        dbra d6,.plaque_byte
        addq.l #2,a0
        addq.w #1,d7
        cmp.w #40,d7
        blo.s .plaque_row
        rts

draw_frame:
        bsr clear_dynamic
        bsr mark_flag           ; Render only the current frame from prepared geometry.
        bsr fill_flag
        bsr draw_pole
        ; Black glyphs use colour 11; sky remains colour 0. Clip to plaque edges.
        moveq #0,d4
        move.w scroll_x-start(a5),d4
        move.w d4,d5
        and.w #15,d5
        lsr.w #4,d4
        add.w d4,d4
        lea scroll_data(pc),a2
        adda.w d4,a2
        move.l backbuffer-start(a5),a1
        adda.l #30720+218*40,a1
        moveq #7,d7
.scroll_row:
        move.l a2,a0
        moveq #19,d6
.word: move.l (a0),d0
        lsl.l d5,d0
        swap d0
        cmp.w #17,d6
        bhs.s .skip_word
        cmp.w #3,d6
        blo.s .skip_word
        or.w d0,-30720(a1)
        or.w d0,-30680(a1)
        or.w d0,-20480(a1)
        or.w d0,-20440(a1)
.skip_word:
        addq.l #2,a1
        addq.l #2,a0
        dbra d6,.word
        adda.w #40,a1
        adda.w #SCROLL_STRIDE,a2
        dbra d7,.scroll_row
        ; Each end wraps around a convex surface. Sample each projected column.
        lea scroll_edges(pc),a3
        moveq #79,d7
.edge_column:
        moveq #0,d0
        move.w (a3)+,d0
        add.w scroll_x-start(a5),d0
        move.w d0,d3
        and.w #7,d3
        eor.w #7,d3
        lsr.w #3,d0
        lea scroll_data(pc),a2
        adda.w d0,a2
        move.l backbuffer-start(a5),a1
        adda.w (a3)+,a1
        move.w (a3)+,d4
        move.w (a3)+,d6
        move.w d6,d0
        subq.w #8,d0
        lsl.w #5,d0
        lea scroll_row_offsets(pc),a0
        adda.w d0,a0
        moveq #0,d5
.edge_row:
        move.w (a0)+,d0
        move.b (a2,d0.w),d2
        btst d3,d2
        beq.s .edge_blank
        or.b d4,(a1)
        or.b d4,10240(a1)
.edge_blank:
        adda.w #40,a1
        addq.w #1,d5
        cmp.w d6,d5
        blo.s .edge_row
        dbra d7,.edge_column
        rts

clear_dynamic:
        moveq #0,d0
        moveq #0,d1
        moveq #0,d2
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        move.l backbuffer-start(a5),a2
        bsr.s .flag_plane
        lea 10240(a2),a2
        bsr.s .flag_plane
        lea 10240(a2),a2
        bsr.s .flag_plane
        ; Scroller rows of planes 0 and 1; the plaque sets no bits there.
        move.l backbuffer-start(a5),a0
        adda.w #(TEXT_ROW+TEXT_ROWS)*40,a0
        bsr.s .text_plane
        adda.w #10240+TEXT_ROWS*40,a0
.text_plane:
        rept TEXT_ROWS*40/32
        movem.l d0-d7,-(a0)
        endr
        rts
; A2 plane base: clear bytes 4..35 of rows 0..FLAG_ROWS-1, bottom-up.
.flag_plane:
        lea (FLAG_ROWS-1)*40+36(a2),a0
        lea -4(a2),a1
.flag_row:
        movem.l d0-d7,-(a0)
        subq.l #8,a0
        cmpa.l a1,a0
        bhi.s .flag_row
        rts

; Each geometry strip toggles one bit per plane at every colour boundary.
; Planes 0 and 1 cover white (7) and blue (3); plane 2 covers white only.
; The checkered flag is black (1) and white (7).
mark_flag:
        moveq #0,d0
        move.w phase-start(a5),d0
        and.w #254,d0
        lsr.w #1,d0
        mulu #129*12,d0
        move.l flag_frames-start(a5),a3
        adda.l d0,a3
        moveq #0,d7
.strip:
        move.w (a3),d6          ; first pixel column
        move.w 12(a3),d5
        subq.w #1,d5            ; last pixel column
        cmp.w d6,d5
        blt .next_strip
        lea marker_list(pc),a1
        move.w 2(a3),d0
        mulu #40,d0             ; top row offset
        move.w 4(a3),d1
        mulu #40,d1             ; bottom row offset, exclusive
        move.w d0,(a1)+         ; plane 0 spans the whole cloth in every pattern
        move.w d1,(a1)+
        tst.w flag_kind-start(a5)
        bne.s .checker
        cmp.w wipe_column-start(a5),d7
        bhs.s .checker
        move.w d0,d2
        add.w #10240,d2
        move.w d2,(a1)+         ; white and blue both set plane 1
        move.w d1,d2
        add.w #10240,d2
        move.w d2,(a1)+
        cmp.w #36,d7            ; physical X / width: blue cross from 5/18 to 8/18
        blo.s .horizontal
        cmp.w #57,d7
        blo.s .emit
.horizontal:
        move.w d0,d2            ; white fields 0..4/11 and 7/11..1 set plane 2
        add.w #20480,d2
        move.w d2,(a1)+
        move.w 8(a3),d2
        mulu #40,d2
        add.w d0,d2
        add.w #20480,d2
        move.w d2,(a1)+
        move.w 10(a3),d2
        mulu #40,d2
        add.w d0,d2
        add.w #20480,d2
        move.w d2,(a1)+
        move.w d1,d2
        add.w #20480,d2
        move.w d2,(a1)+
        bra.s .emit
.checker:
        move.w 4(a3),d3
        sub.w 2(a3),d3          ; complete projected height
        move.w d7,d4
        lsr.w #4,d4
        and.w #1,d4
        eor.w #1,d4             ; first white row of five
.cell:
        move.w d4,d2
        bsr.s .row_offset
        move.w d4,d2
        addq.w #1,d2
        bsr.s .row_offset
        addq.w #2,d4
        cmp.w #5,d4
        blo.s .cell
.emit:
        move.w #-1,(a1)
.byte:
        move.w d6,d0
        lsr.w #3,d0
        move.w d6,d3
        or.w #7,d3              ; last column of this byte
        cmp.w d5,d3
        bls.s .mask
        move.w d5,d3
.mask:
        move.w d6,d1
        and.w #7,d1
        move.w #$ff,d2
        lsr.w d1,d2
        move.w d3,d1
        and.w #7,d1
        eor.w #7,d1
        moveq #-1,d4
        lsl.w d1,d4
        and.w d4,d2             ; columns d6..d3 within the byte
        move.l backbuffer-start(a5),a0
        adda.w d0,a0
        lea marker_list(pc),a1
.mark:
        move.w (a1)+,d0
        bmi.s .marked
        eor.b d2,(a0,d0.w)
        bra.s .mark
.marked:
        move.w d3,d6
        addq.w #1,d6
        cmp.w d5,d6
        bls.s .byte
.next_strip:
        adda.w #12,a3
        addq.w #1,d7
        cmp.w #128,d7
        blo .strip
        rts
; D2 checker row boundary 0..5: planes 1 and 2 toggle at top + D2*height/5.
.row_offset:
        mulu d3,d2
        divu #5,d2
        mulu #40,d2
        add.w d0,d2
        add.w #10240,d2
        move.w d2,(a1)+
        add.w #10240,d2
        move.w d2,(a1)+
        rts

; Running XOR down each long column turns the markers into filled spans.
fill_flag:
        move.l backbuffer-start(a5),a1
        addq.l #4,a1            ; longs 1..8 hold every cloth and pole column
        bsr.s .plane
        lea 10240-FLAG_ROWS*40(a1),a1
        bsr.s .plane
        lea 10240-FLAG_ROWS*40(a1),a1
.plane:
        moveq #0,d0
        moveq #0,d1
        moveq #0,d2
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        lea FLAG_ROWS*40(a1),a4
.row:
        eor.l d0,(a1)
        move.l (a1)+,d0
        eor.l d1,(a1)
        move.l (a1)+,d1
        eor.l d2,(a1)
        move.l (a1)+,d2
        eor.l d3,(a1)
        move.l (a1)+,d3
        eor.l d4,(a1)
        move.l (a1)+,d4
        eor.l d5,(a1)
        move.l (a1)+,d5
        eor.l d6,(a1)
        move.l (a1)+,d6
        eor.l d7,(a1)
        move.l (a1)+,d7
        addq.l #8,a1
        cmpa.l a4,a1
        blo.s .row
        rts

draw_pole:
        ; Finnish flagpole from the generated tables: shaded white body
        ; segments, then the gilded knob. Long masks cover x 16..47.
        lea pole_segments(pc),a1
.segment:
        move.w (a1)+,d0
        bmi.s .knob
        move.l backbuffer-start(a5),a0
        adda.w d0,a0
        move.w (a1)+,d0
        movem.l (a1)+,d1-d3
.row:   or.l d1,(a0)
        or.l d2,10240(a0)
        or.l d3,20480(a0)
        adda.w #40,a0
        dbra d0,.row
        bra.s .segment
.knob:
        move.l backbuffer-start(a5),a0
        adda.w #KNOB_TOP*40+2,a0
        moveq #KNOB_ROWS-1,d0
.knob_row:
        movem.l (a1)+,d1-d3
        or.l d1,(a0)
        or.l d2,10240(a0)
        or.l d3,20480(a0)
        adda.w #40,a0
        dbra d0,.knob_row
        rts

; Copy only what draw_frame can change: planes 0-2, bytes 4..35 of the
; cloth rows, and the scroller rows of planes 0 and 1.
present:
        moveq #0,d2
        move.w rowbytes-start(a5),d2
        move.l backbuffer-start(a5),a0
        addq.l #4,a0
        lea plane(pc),a2
        moveq #2,d3
.plane:
        move.l (a2)+,a1
        addq.l #4,a1
        move.w #FLAG_ROWS-1,d1
.row:
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        addq.l #8,a0
        lea -32(a1,d2.l),a1
        dbra d1,.row
        lea 10240-FLAG_ROWS*40(a0),a0
        dbra d3,.plane
        move.l backbuffer-start(a5),a0
        adda.w #TEXT_ROW*40,a0
        lea plane(pc),a2
        moveq #1,d3
.text_plane:
        move.l d2,d0
        mulu #TEXT_ROW,d0
        move.l (a2)+,a1
        adda.l d0,a1
        moveq #TEXT_ROWS-1,d1
.text_row:
        moveq #9,d0
.copy:  move.l (a0)+,(a1)+
        dbra d0,.copy
        lea -40(a1,d2.l),a1
        dbra d1,.text_row
        adda.w #10240-TEXT_ROWS*40,a0
        dbra d3,.text_plane
        rts
present_full:
        move.l backbuffer-start(a5),a0
        lea plane(pc),a2
        moveq #3,d3
.plane:
        move.l (a2)+,a1
        moveq #0,d2
        move.w rowbytes-start(a5),d2
        sub.w #40,d2
        move.w #255,d1
.row:   moveq #9,d0
.copy:  move.l (a0)+,(a1)+
        dbra d0,.copy
        adda.w d2,a1
        dbra d1,.row
        dbra d3,.plane
        rts
intuition_name: dc.b 'intuition.library',0
graphics_name: dc.b 'graphics.library',0
        even
screen_tags:
        dc.l $80000023,320,$80000024,256,$80000025,4
        dc.l $80000032,0,$80000036,0,$80000037,1
        dc.l $80000038,1,$8000003e,0,0,0
new_window:
        dc.w 0,0,320,256
        dc.b 0,0
        dc.l $8,$31940,0,0,0    ; IDCMP_MOUSEBUTTONS only; no keyboard events
window_screen: dc.l 0
        dc.l 0
        dc.w 0,0,320,256,$f
; White fabric and display-quantized PMS 294 C approximation (#003366);
; colours 2 and 5 are the dark and light gold of the flagpole knob.
palette:
        dc.l $000c0000
        dc.l $99999999,$cccccccc,$ffffffff
        dc.l $00000000,$00000000,$00000000
        dc.l $aaaaaaaa,$77777777,$11111111
        dc.l $00000000,$33333333,$66666666
        dc.l $88888888,$88888888,$88888888
        dc.l $eeeeeeee,$bbbbbbbb,$33333333
        dc.l $cccccccc,$cccccccc,$cccccccc
        dc.l $ffffffff,$ffffffff,$ffffffff
        dc.l $bbbbbbbb,$dddddddd,$aaaaaaaa
        dc.l $dddddddd,$ffffffff,$cccccccc
        dc.l $66666666,$88888888,$55555555
        dc.l $00000000,$00000000,$00000000
        dc.l 0
blank_pointer: dcb.l 3,0
ibase: dc.l 0
gbase: dc.l 0
screen: dc.l 0
window: dc.l 0
backbuffer: dc.l 0
plane: dc.l 0
plane1: dc.l 0
plane2: dc.l 0
plane3: dc.l 0
pressed_class: dc.l 0
pressed_code: dc.w 0
rowbytes: dc.w 0
phase: dc.w 0
scroll_x: dc.w 0
flag_frames: dc.l 0

flag_kind: dc.w 0
flag_start_vbl: dc.l 0
wipe_column: dc.w 128
marker_list: dcb.w 16,0
