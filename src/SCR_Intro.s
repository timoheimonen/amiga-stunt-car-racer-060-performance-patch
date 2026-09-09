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
        bsr draw_frame
        bsr present
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
        cmp.l #$400,d2
        bne.s .mouse
        cmp.w #$40,d3
        bne.s .input
        bra.s .press
.mouse:
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

; Clear and redraw into private PUBLIC RAM. The screen uses its own CHIP plane.
draw_flag:
        move.l backbuffer-start(a5),a0
        move.w #10239,d0
.clear: clr.l (a0)+
        dbra d0,.clear
        ; Fixed five-pixel silver flagpole beside the anchored cloth edge.
        move.l backbuffer-start(a5),a0
        adda.w #24*40+4,a0
        move.w #174,d0
        moveq #6,d1
        moveq #64,d2
        bsr paint_span
        move.l backbuffer-start(a5),a0
        adda.w #24*40+4,a0
        move.w #174,d0
        moveq #7,d1
        moveq #32,d2
        bsr paint_span
        move.l backbuffer-start(a5),a0
        adda.w #24*40+4,a0
        move.w #174,d0
        moveq #7,d1
        moveq #16,d2
        bsr paint_span
        move.l backbuffer-start(a5),a0
        adda.w #24*40+4,a0
        move.w #174,d0
        moveq #6,d1
        moveq #8,d2
        bsr paint_span
        move.l backbuffer-start(a5),a0
        adda.w #24*40+4,a0
        move.w #174,d0
        moveq #4,d1
        moveq #4,d2
        bsr paint_span
        ; Small rounded finial, drawn from seven procedural row masks.
        move.l backbuffer-start(a5),a0
        adda.w #20*40+4,a0
        lea finial(pc),a1
        moveq #6,d0
.finial:
        move.b (a1)+,d1
        or.b d1,(a0)
        or.b d1,10240(a0)
        or.b d1,20480(a0)
        adda.w #40,a0
        dbra d0,.finial
        moveq #0,d0
        move.w phase-start(a5),d0
        and.w #254,d0
        lsr.w #1,d0
        mulu #129*12,d0
        move.l flag_frames-start(a5),a3
        adda.l d0,a3
        moveq #0,d7
.strip:
        move.w (a3),d6
        move.w 12(a3),d5
        subq.w #1,d5
        cmp.w d6,d5
        blt .next_strip
        moveq #0,d4
        cmp.w #36,d7            ; physical X / width: blue cross from 5/18 to 8/18
        blo.s .pixel_column
        cmp.w #57,d7
        bhs.s .pixel_column
        moveq #1,d4
.pixel_column:
        move.w 2(a3),d0
        mulu #40,d0
        move.l backbuffer-start(a5),a0
        adda.l d0,a0
        move.w d6,d0
        lsr.w #3,d0
        adda.w d0,a0
        move.w d6,d0
        and.w #7,d0
        move.w #$80,d2
        lsr.w d0,d2
        move.w 4(a3),d3
        sub.w 2(a3),d3          ; complete projected height, without dropped remainder
        tst.w flag_kind-start(a5)
        bne .checker
        cmp.w wipe_column-start(a5),d7
        bhs .checker
        tst.w d4
        beq.s .horizontal
        move.w d3,d0
        subq.w #1,d0
        bsr blue_shade
        bsr paint_span
        bra .next_column
.horizontal:
        move.w 8(a3),d0
        move.w d0,cell_height-start(a5) ; upper white field: 4/11
        subq.w #1,d0
        move.w 6(a3),d1
        bsr paint_span
        move.w 10(a3),d0
        move.w d0,blue_end-start(a5)
        sub.w cell_height-start(a5),d0
        subq.w #1,d0
        bsr blue_shade
        bsr paint_span
        move.w d3,d0
        sub.w blue_end-start(a5),d0
        subq.w #1,d0
        move.w 6(a3),d1
        bsr paint_span
        bra .next_column
.checker:
        clr.w checker_row-start(a5)
        clr.w checker_prev-start(a5)
.checker_row:
        moveq #0,d0
        move.w checker_row-start(a5),d0
        addq.w #1,d0
        mulu d3,d0
        divu #5,d0
        move.w d0,d1
        sub.w checker_prev-start(a5),d0
        move.w d1,checker_prev-start(a5)
        subq.w #1,d0
        move.w d7,d1
        lsr.w #4,d1
        move.w checker_row-start(a5),d4
        eor.w d4,d1
        and.w #1,d1
        beq.s .black_cell
        moveq #7,d1
        bra.s .paint_cell
.black_cell:
        moveq #1,d1
.paint_cell:
        bsr paint_span
        addq.w #1,checker_row-start(a5)
        cmp.w #5,checker_row-start(a5)
        blo.s .checker_row
.next_column:
        addq.w #1,d6
        cmp.w d6,d5
        bge .pixel_column
.next_strip:
        adda.w #12,a3
        addq.w #1,d7
        cmp.w #128,d7
        blo .strip
        rts

draw_frame:
        bsr draw_flag           ; Render only the current frame from prepared geometry.
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
present:
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
; D0 count-1, D1 palette index, D2 pixel mask, A0 advances down the plane.
; Dispatch outside the loop, avoiding per-pixel colour tests.
blue_shade:
        moveq #3,d1            ; uniform blue cross
        rts
paint_span:
        add.w d1,d1
        move.w .offsets(pc,d1.w),d1
        jmp .offsets(pc,d1.w)
.offsets:
        dc.w .c0-.offsets,.c1-.offsets,.c2-.offsets,.c3-.offsets
        dc.w .c4-.offsets,.c5-.offsets,.c6-.offsets,.c7-.offsets
.c0:    adda.w #40,a0
        dbra d0,.c0
        rts
.c1:    or.b d2,(a0)
        adda.w #40,a0
        dbra d0,.c1
        rts
.c2:    or.b d2,10240(a0)
        adda.w #40,a0
        dbra d0,.c2
        rts
.c3:    or.b d2,(a0)
        or.b d2,10240(a0)
        adda.w #40,a0
        dbra d0,.c3
        rts
.c4:    or.b d2,20480(a0)
        adda.w #40,a0
        dbra d0,.c4
        rts
.c5:    or.b d2,(a0)
        or.b d2,20480(a0)
        adda.w #40,a0
        dbra d0,.c5
        rts
.c6:    or.b d2,10240(a0)
        or.b d2,20480(a0)
        adda.w #40,a0
        dbra d0,.c6
        rts
.c7:    or.b d2,(a0)
        or.b d2,10240(a0)
        or.b d2,20480(a0)
        adda.w #40,a0
        dbra d0,.c7
        rts
finial: dc.b $7c,$fe,$fe,$fe,$fe,$fe,$7c
        even
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
        dc.l $408,$31940,0,0,0
window_screen: dc.l 0
        dc.l 0
        dc.w 0,0,320,256,$f
; White fabric and display-quantized PMS 294 C approximation (#003366).
palette:
        dc.l $000c0000
        dc.l $99999999,$cccccccc,$ffffffff
        dc.l $00000000,$00000000,$00000000
        dc.l $00000000,$22222222,$55555555
        dc.l $00000000,$33333333,$66666666
        dc.l $88888888,$88888888,$88888888
        dc.l $aaaaaaaa,$aaaaaaaa,$aaaaaaaa
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

cell_height: dc.w 0
blue_end: dc.w 0
flag_frames: dc.l 0

flag_kind: dc.w 0
checker_row: dc.w 0
checker_prev: dc.w 0
flag_start_vbl: dc.l 0
wipe_column: dc.w 128
