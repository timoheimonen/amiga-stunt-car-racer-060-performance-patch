; Finish an open track: search for sections that reach the start line or close a gap.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Track Editor: Finish builds the rest of an open track. It looks from the open
; end as it is, then with one section taken off, then two, as Del would take
; them, for sections that reach the start line or the far side of the gap at
; its height. The search is weighted A* with f = g + FINISH_WEIGHT*h, a binary heap of f<<24 | h<<16 |
; node, tails known by a 32-bit hash, FINISH_BUDGET expansions and FINISH_POOL
; nodes for each end. What is taken off and what is added is one Undo step.
;
; The search borrows the depth buffer, which a full render clears before it
; reads it, and the render after the change is a full one.
FINISH_SCRATCH equ DEPTH_BUFFER
FINISH_MEMO_KEYS equ FINISH_SCRATCH
FINISH_MEMO_G equ FINISH_MEMO_KEYS+FINISH_MEMO_SLOTS*4
FINISH_NODES equ FINISH_MEMO_G+FINISH_MEMO_SLOTS
FINISH_HEAP equ FINISH_NODES+FINISH_POOL*4
; The grids hold a long per map cell.
FINISH_GRID_BYTES equ MAP_CELLS*MAP_CELLS*4
FINISH_ROOT_GRID equ FINISH_HEAP+FINISH_POOL*4
FINISH_GRID equ FINISH_ROOT_GRID+FINISH_GRID_BYTES
; For each surface of a piece, the cells around it where it forbids others: a
; count word, then cell x and z offsets as words and the surfaces it forbids
; there as a long. building_collision_masks turned round.
FINISH_SPREAD_STRIDE equ 2+25*8
FINISH_SPREAD equ FINISH_GRID+FINISH_GRID_BYTES
; For each variant, FINISH_LIST_BYTES: its piece count, then surface, cell x and
; cell z of each.
FINISH_LIST_SHIFT equ 5
FINISH_LIST_BYTES equ 1<<FINISH_LIST_SHIFT
FINISH_PIECES equ FINISH_SPREAD+EDITOR_SURFACE_COUNT*FINISH_SPREAD_STRIDE
FINISH_PATH equ FINISH_PIECES+BLOCK_VARIANT_COUNT*FINISH_LIST_BYTES
FINISH_SCRATCH_END equ FINISH_PATH+EDITOR_MAX_PIECES+2
        ifgt FINISH_SCRATCH_END-FINISH_SCRATCH-DEPTH_BUFFER_BYTES
        fail "Finish needs more than the depth buffer"
        endif

; F in Browse. Older tracks have no Finish, and a closed one has nothing to do.
finish_key:
        cmpi.l #SCTR_BLOCKS_REVISION,editor_track+SCTR_REVISION-module_start(a5)
        blo.s .done
        tst.w editor_track+SCTR_CLOSED-module_start(a5)
        bne.s .closed
        bsr editor_model_build
        tst.w d0
        beq.s .done
        bra.s finish_track
.closed:
        lea finish_closed_text(pc),a0
        bra ui_refuse
.done:  rts

finish_track:
        movem.l d0-d7/a0-a4,-(sp)
        move.l ui_ms(pc),finish_started-module_start(a5)
        clr.w finish_mismatch-module_start(a5)
        move.w editor_gap(pc),finish_gap-module_start(a5)
        lea finish_looking_text(pc),a0
        tst.w finish_gap-module_start(a5)
        beq.s .say
        lea finish_looking_gap_text(pc),a0
.say:   bsr ui_say
        bsr ui_l2_show
        bsr finish_search
        move.w d0,finish_found-module_start(a5)
        move.l ui_ms(pc),d1
        sub.l finish_started(pc),d1
        move.l d1,finish_ms-module_start(a5)
        clr.l ui_said-module_start(a5)
        move.w #1,ui_line_due-module_start(a5)
        ; A result from before the search ran out of time while it ran, and
        ; its end would take the new status with it.
        clr.b ui_next_result-module_start(a5)
        clr.b ui_shown_result-module_start(a5)
        tst.w d0
        beq.s .none
        bsr finish_commit
        tst.w finish_mismatch-module_start(a5)
        beq.s .done
.none:  lea finish_none_text(pc),a0
        tst.w finish_gap-module_start(a5)
        beq.s .refuse
        lea finish_none_gap_text(pc),a0
.refuse:
        bsr ui_say
.done:  movem.l (sp)+,d0-d7/a0-a4
        rts

; With the model built -> D0 sections in FINISH_PATH, 0 when no end found any.
; finish_e is then the end the sections go on.
finish_search:
        bsr finish_prepare
        bsr field_refresh
        move.w editor_gap(pc),d0
        mulu.w #EDITOR_GEOMETRY_STRIDE,d0
        lea model_geometry(pc),a0
        adda.l d0,a0
        lea finish_goal(pc),a1
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.w editor_track+SCTR_COUNT(pc),finish_total-module_start(a5)
        bsr editor_end
        move.w d0,finish_e0-module_start(a5)
        move.w d0,finish_e-module_start(a5)
        clr.w finish_deleted-module_start(a5)
        clr.l finish_expanded_total-module_start(a5)
.root:  bsr finish_root
        bsr finish_end
        tst.w d0
        bne.s .done
        ; The next end: the section before this one goes, as Del takes it.
        move.w finish_e(pc),d0
        bsr section_before
        tst.w d0
        beq.s .none
        move.w d0,d3
        move.w finish_e(pc),d1
        bsr section_keeps_finish
        beq.s .none
        move.w d3,finish_e-module_start(a5)
        addq.w #1,finish_deleted-module_start(a5)
        bra.s .root
.none:  moveq #0,d0
.done:  rts

; The spread of the collision masks and the pieces of every variant.
finish_prepare:
        lea building_collision_masks(pc),a0
        lea FINISH_SPREAD(a5),a1
        moveq #EDITOR_SURFACE_COUNT-1,d7
.surface:
        movea.l a1,a3
        clr.w (a1)+
        moveq #0,d6
.cell:  moveq #0,d0
        moveq #0,d5
        movea.l a0,a2
.other: move.l (a2)+,d1
        btst d6,d1
        beq.s .free
        bset d5,d0
.free:  addq.w #1,d5
        cmpi.w #EDITOR_SURFACE_COUNT,d5
        blo.s .other
        tst.l d0
        beq.s .empty
        addq.w #1,(a3)
        moveq #0,d1
        move.w d6,d1
        divu.w #5,d1
        swap d1
        subq.w #2,d1
        move.w d1,(a1)+
        swap d1
        subq.w #2,d1
        move.w d1,(a1)+
        move.l d0,(a1)+
.empty: addq.w #1,d6
        cmpi.w #25,d6
        blo.s .cell
        lea FINISH_SPREAD_STRIDE(a3),a1
        adda.w #EDITOR_SURFACE_COUNT*4,a0
        dbra d7,.surface
        lea FINISH_PIECES(a5),a1
        moveq #0,d6
.variant:
        move.w d6,d0
        bsr block_descriptor
        movea.l a1,a2
        move.w (a4),d5
        move.b d5,(a2)+
        subq.w #1,d5
        addq.l #8,a4
.piece: moveq #0,d0
        move.b (a4),d0
        subq.w #1,d0
        lsl.w #2,d0
        moveq #0,d1
        move.b 1(a4),d1
        add.w d1,d0
        add.w d0,d0
        lea building_surface_map(pc),a0
        move.w (a0,d0.w),d0
        move.b d0,(a2)+
        move.b 5(a4),(a2)+
        move.b 7(a4),(a2)+
        addq.l #8,a4
        dbra d5,.piece
        adda.w #FINISH_LIST_BYTES,a1
        addq.w #1,d6
        cmpi.w #BLOCK_VARIANT_COUNT,d6
        blo.s .variant
        rts

; The end finish_e: its piece count, its tail and the road around it, which is
; every piece but the sections taken off.
finish_root:
        move.w finish_total(pc),d0
        sub.w finish_e0(pc),d0
        add.w finish_e(pc),d0
        move.w d0,finish_root_count-module_start(a5)
        move.w finish_e(pc),d0
        bsr piece_tail_row
        lea finish_root_tail(pc),a1
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        lea FINISH_ROOT_GRID(a5),a2
        movea.l a2,a0
        move.w #FINISH_GRID_BYTES/4-1,d0
.clear: clr.l (a0)+
        dbra d0,.clear
        moveq #0,d6
.piece: cmp.w finish_total(pc),d6
        bhs.s .done
        cmp.w finish_e(pc),d6
        blo.s .take
        cmp.w finish_e0(pc),d6
        blo.s .next
.take:  move.w d6,d0
        lsl.w #PIECE_SHIFT,d0
        lea editor_track+SCTR_PIECES(pc),a0
        adda.w d0,a0
        bsr building_variant
        bsr building_surface_variant
        moveq #0,d1
        move.b PIECE_CELL(a0),d1
        move.w d1,d2
        andi.w #MAP_CELLS-1,d1
        lsr.w #MAP_CELL_BITS,d2
        bsr finish_mark
.next:  addq.w #1,d6
        bra.s .piece
.done:  rts

; One end: weighted A* -> D0 sections in FINISH_PATH, 0 when none was found.
finish_end:
        lea finish_root_tail(pc),a1
        move.w finish_root_count(pc),d3
        bsr finish_bound
        tst.w d0
        bmi .fail
        lea FINISH_NODES(a5),a0
        move.l #$0000ff00,(a0)
        move.w #1,finish_nodes_used-module_start(a5)
        clr.w finish_heap_size-module_start(a5)
        moveq #FINISH_WEIGHT,d1
        mulu.w d0,d1
        lsl.l #8,d1
        add.w d0,d1
        swap d1
        clr.w d1
        move.l d1,d0
        bsr finish_push
        lea FINISH_MEMO_KEYS(a5),a0
        move.w #FINISH_MEMO_SLOTS-1,d0
.clear: clr.l (a0)+
        dbra d0,.clear
        lea finish_root_tail(pc),a1
        bsr finish_hash
        bsr finish_memo
        moveq #0,d2
        bsr finish_memo_set
        clr.l finish_expanded-module_start(a5)
.loop:  tst.w finish_heap_size-module_start(a5)
        beq.s .fail
        cmpi.l #FINISH_BUDGET,finish_expanded-module_start(a5)
        bhs.s .fail
        bsr finish_pop
        move.w d0,finish_index-module_start(a5)
        addq.l #1,finish_expanded-module_start(a5)
        addq.l #1,finish_expanded_total-module_start(a5)
        tst.b ui_yield_flag(pc)
        beq.s .go
        bsr ui_yield
.go:    bsr finish_replay
        bsr finish_children
        tst.w d0
        beq.s .loop
        rts
.fail:  moveq #0,d0
        rts

; The popped node's sections from the end into FINISH_PATH, and the grid, the
; tail and the piece count with them.
finish_replay:
        lea FINISH_NODES(a5),a0
        move.w finish_index(pc),d1
        moveq #0,d2
.count: move.w d1,d0
        lsl.w #2,d0
        cmpi.b #$ff,2(a0,d0.w)
        beq.s .counted
        addq.w #1,d2
        move.w (a0,d0.w),d1
        bra.s .count
.counted:
        move.w d2,finish_depth-module_start(a5)
        lea FINISH_PATH(a5),a1
        adda.w d2,a1
        move.w finish_index(pc),d1
        bra.s .fill_next
.fill:  move.w d1,d0
        lsl.w #2,d0
        move.b 2(a0,d0.w),-(a1)
        move.w (a0,d0.w),d1
.fill_next:
        dbra d2,.fill
        lea FINISH_ROOT_GRID(a5),a0
        lea FINISH_GRID(a5),a2
        movea.l a2,a1
        move.w #FINISH_GRID_BYTES/4-1,d0
.grid:  move.l (a0)+,(a1)+
        dbra d0,.grid
        lea finish_root_tail(pc),a0
        lea finish_tail(pc),a1
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.w finish_root_count(pc),finish_count-module_start(a5)
        lea FINISH_PATH(a5),a4
        move.w finish_depth(pc),d7
        bra.s .section_next
.section:
        moveq #0,d6
        move.b (a4)+,d6
        lea finish_tail(pc),a0
        move.w d6,d0
        bsr finish_shift
        move.w d6,d0
        bsr finish_occupy
        lea finish_tail(pc),a0
        movea.l a0,a1
        bsr finish_exit
        move.w d6,d0
        bsr finish_piece_list
        moveq #0,d0
        move.b (a1),d0
        add.w d0,finish_count-module_start(a5)
.section_next:
        dbra d7,.section
        rts

; From the replayed tail: every section in socket order. D0 sections in
; FINISH_PATH when one closes, else 0 with the kept ones on the heap.
finish_children:
        lea FINISH_NODES(a5),a0
        move.w finish_index(pc),d0
        lsl.w #2,d0
        moveq #0,d1
        move.b 3(a0,d0.w),d1
        addq.w #1,d1
        move.w d1,finish_g-module_start(a5)
        lea finish_tail(pc),a0
        move.w 6(a0),d1
        sub.w (a0),d1
        move.w 10(a0),d2
        sub.w 4(a0),d2
        bsr view_axis_index
        lea block_sockets(pc),a4
        moveq #BLOCK_DIAGONAL_SOCKETS-1,d7
        btst #0,d1
        bne.s .list
        moveq #BLOCK_AXIS_SOCKETS-1,d7
.list:  move.b (a4,d1.w),d1
        andi.w #255,d1
        adda.w d1,a4
.child: moveq #0,d6
        move.b (a4)+,d6
        move.w d6,d0
        bsr finish_piece_list
        moveq #0,d3
        move.b (a1),d3
        add.w finish_count(pc),d3
        cmpi.w #EDITOR_MAX_PIECES,d3
        bhi .next
        lea finish_tail(pc),a0
        move.w d6,d0
        bsr finish_shift
        bsr finish_inside
        beq .next
        lea FINISH_GRID(a5),a2
        move.w d6,d0
        bsr finish_clear
        beq .next
        lea finish_end_row(pc),a1
        bsr finish_exit
        lea finish_end_row(pc),a0
        lea finish_goal(pc),a1
        bsr editor_join
        tst.w d0
        bne.s .closes
        lea finish_end_row(pc),a1
        move.w 4(a3),d4
        bsr finish_bound_heading
        tst.w d0
        bmi.s .next
        move.w d0,d5
        bsr finish_hash
        bsr finish_memo
        move.w finish_g(pc),d4
        cmp.w d4,d2
        bls.s .next
        cmpi.w #FINISH_POOL,finish_nodes_used-module_start(a5)
        bhs.s .next
        move.w d4,d2
        bsr finish_memo_set
        ; The node: its parent, its section and its g.
        lea FINISH_NODES(a5),a0
        move.w finish_nodes_used(pc),d1
        move.w d1,d0
        lsl.w #2,d0
        adda.w d0,a0
        move.w finish_index(pc),(a0)+
        move.b d6,(a0)+
        move.b d4,(a0)
        ; f<<24 | h<<16 | node
        moveq #FINISH_WEIGHT,d0
        mulu.w d5,d0
        add.w d4,d0
        lsl.w #8,d0
        or.w d5,d0
        swap d0
        move.w d1,d0
        bsr finish_push
        addq.w #1,finish_nodes_used-module_start(a5)
.next:  dbra d7,.child
        moveq #0,d0
        rts
.closes:
        lea FINISH_PATH(a5),a0
        move.w finish_depth(pc),d0
        move.b d6,(a0,d0.w)
        addq.w #1,d0
        rts

; D0 variant -> A1 its piece list. D0 destroyed.
finish_piece_list:
        lsl.w #FINISH_LIST_SHIFT,d0
        lea FINISH_PIECES(a5),a1
        adda.w d0,a1
        rts

; D0 variant, A0 tail -> A3 its record, D1 and D2 its shift in cells as
; entry_shift gives it. D0 destroyed.
finish_shift:
        lsl.w #FINISH_RECORD_SHIFT,d0
        lea finish_records(pc),a3
        adda.w d0,a3
; A0 tail row, A3 the entry's X and Z words -> D1 and D2 the shift in cells,
; rounded, that puts the entry on the tail's left point. D0 destroyed, A0 and
; A3 kept.
entry_shift:
        moveq #0,d1
        move.w (a0),d1
        move.w (a3),d0
        ext.l d0
        sub.l d0,d1
        addi.l #MAP_CELL/2,d1
        asr.l #8,d1
        asr.l #MAP_CELL_SHIFT-8,d1
        moveq #0,d2
        move.w 4(a0),d2
        move.w 2(a3),d0
        ext.l d0
        sub.l d0,d2
        addi.l #MAP_CELL/2,d2
        asr.l #8,d2
        asr.l #MAP_CELL_SHIFT-8,d2
        rts

; A0 tail, A3 record, D1 and D2 the shift -> D0=1 when the section stays on the
; map and inside the height limits.
finish_inside:
        movem.l d3-d4,-(sp)
        moveq #MAP_CELL_SHIFT,d4
        move.l d1,d3
        asl.l d4,d3
        move.w 20(a3),d0
        ext.l d0
        add.l d3,d0
        bmi.s .out
        move.w 22(a3),d0
        ext.l d0
        add.l d3,d0
        cmpi.l #MAP_SIZE,d0
        bgt.s .out
        move.l d2,d3
        asl.l d4,d3
        move.w 24(a3),d0
        ext.l d0
        add.l d3,d0
        bmi.s .out
        move.w 26(a3),d0
        ext.l d0
        add.l d3,d0
        cmpi.l #MAP_SIZE,d0
        bgt.s .out
        move.w 2(a0),d3
        ext.l d3
        move.w 30(a3),d0
        ext.l d0
        add.l d3,d0
        cmpi.l #FINISH_MAX_TOP,d0
        bgt.s .out
        move.w 28(a3),d0
        ext.l d0
        add.l d3,d0
        cmpi.l #FINISH_MIN_ROAD,d0
        blt.s .out
        movem.l (sp)+,d3-d4
        moveq #1,d0
        rts
.out:   movem.l (sp)+,d3-d4
        moveq #0,d0
        rts

; D0 variant, D1 and D2 the shift, A2 grid -> D0=1 when no piece of it stands
; where the road already built forbids it.
finish_clear:
        movem.l d1-d5/a1,-(sp)
        bsr finish_piece_list
        moveq #0,d3
        move.b (a1)+,d3
        subq.w #1,d3
.piece: moveq #0,d0
        move.b (a1)+,d0
        move.b (a1)+,d4
        ext.w d4
        add.w d1,d4
        move.b (a1)+,d5
        ext.w d5
        add.w d2,d5
        lsl.w #MAP_CELL_BITS,d5
        add.w d4,d5
        lsl.w #2,d5
        move.l (a2,d5.w),d4
        btst d0,d4
        bne.s .hit
        dbra d3,.piece
        movem.l (sp)+,d1-d5/a1
        moveq #1,d0
        rts
.hit:   movem.l (sp)+,d1-d5/a1
        moveq #0,d0
        rts

; D0 variant, D1 and D2 the shift, A2 grid: its pieces join the road.
finish_occupy:
        movem.l d0-d4/a1,-(sp)
        move.w d1,d3
        move.w d2,d4
        bsr finish_piece_list
        moveq #0,d0
        move.b (a1)+,d0
        move.w d0,-(sp)
        bra.s .next
.piece: moveq #0,d0
        move.b (a1)+,d0
        move.b (a1)+,d1
        ext.w d1
        add.w d3,d1
        move.b (a1)+,d2
        ext.w d2
        add.w d4,d2
        bsr finish_mark
.next:  subq.w #1,(sp)
        bpl.s .piece
        addq.l #2,sp
        movem.l (sp)+,d0-d4/a1
        rts

; D0 surface, D1 cell x, D2 cell z, A2 grid: the 25 cells around the piece take
; the surfaces it forbids there.
finish_mark:
        movem.l d0/d3-d5/a0,-(sp)
        mulu.w #FINISH_SPREAD_STRIDE,d0
        lea FINISH_SPREAD(a5),a0
        adda.l d0,a0
        move.w (a0)+,d3
        bra.s .next
.cell:  move.w (a0)+,d4
        add.w d1,d4
        move.w (a0)+,d5
        add.w d2,d5
        move.l (a0)+,d0
        cmpi.w #MAP_CELLS-1,d4
        bhi.s .next
        cmpi.w #MAP_CELLS-1,d5
        bhi.s .next
        lsl.w #MAP_CELL_BITS,d5
        add.w d4,d5
        lsl.w #2,d5
        or.l d0,(a2,d5.w)
.next:  dbra d3,.cell
        movem.l (sp)+,d0/d3-d5/a0
        rts

; A0 tail, A3 record, D1 and D2 the shift, A1 row: the open end after the
; section. A1 may be A0.
finish_exit:
        movem.l d0/d3-d5,-(sp)
        moveq #MAP_CELL_SHIFT,d0
        move.w d1,d3
        lsl.w d0,d3
        move.w d2,d5
        lsl.w d0,d5
        move.w 2(a0),d4
        move.w 8(a3),d0
        add.w d3,d0
        move.w d0,(a1)
        move.w 10(a3),d0
        add.w d4,d0
        move.w d0,2(a1)
        move.w 12(a3),d0
        add.w d5,d0
        move.w d0,4(a1)
        move.w 14(a3),d0
        add.w d3,d0
        move.w d0,6(a1)
        move.w 16(a3),d0
        add.w d4,d0
        move.w d0,8(a1)
        move.w 18(a3),d0
        add.w d5,d0
        move.w d0,10(a1)
        movem.l (sp)+,d0/d3-d5
        rts

; A1 row, D3 its piece count -> D0 h, the fewest sections still needed as far
; as the field and the height know, or -1 when the end is not kept.
finish_bound:
        movem.l d1-d2/a0,-(sp)
        move.w (a1),d0
        or.w 4(a1),d0
        bmi finish_none
        bsr field_index
        bra.s finish_level
; The same, D4 the heading of the row: the exit of a section is known.
finish_bound_heading:
        movem.l d1-d2/a0,-(sp)
        move.w (a1),d0
        or.w 4(a1),d0
        bmi finish_none
        move.w d4,d1
        lsl.w #8,d1
        move.w 4(a1),d0
        lsr.w #7,d0
        andi.w #$f0,d0
        or.w d0,d1
        move.w (a1),d0
        moveq #11,d2
        lsr.w d2,d0
        or.w d0,d1
; D1 the field index of the row.
finish_level:
        lea FIELD_OFFSET(a5),a0
        moveq #0,d0
        move.b (a0,d1.w),d0
        cmpi.w #FIELD_NO_ROUTE,d0
        bhs finish_none
        move.w finish_goal+2(pc),d1
        sub.w 2(a1),d1
        moveq #63,d2
        and.w d1,d2
        bne finish_none
        asr.w #6,d1
        addi.w #FINISH_RISE_ENTRIES/2,d1
        lea finish_pieces(pc),a0
        moveq #0,d2
        move.b (a0,d1.w),d2
        cmp.w d0,d2
        bhs.s .fewest
        move.w d0,d2
.fewest:
        add.w d3,d2
        cmpi.w #EDITOR_MAX_PIECES,d2
        bhi finish_none
        lea finish_sections(pc),a0
        moveq #0,d2
        move.b (a0,d1.w),d2
        cmpi.w #FINISH_NONE,d2
        beq finish_none
        cmp.w d0,d2
        bls.s finish_bound_done
        move.w d2,d0
finish_bound_done:
        movem.l (sp)+,d1-d2/a0
        rts
finish_none:
        moveq #-1,d0
        bra.s finish_bound_done

; A1 row -> D0 its hash, never 0.
finish_hash:
        movem.l d1-d2/a1,-(sp)
        moveq #0,d0
        moveq #5,d2
.word:  move.l d0,d1
        lsl.l #5,d0
        sub.l d1,d0
        moveq #0,d1
        move.w (a1)+,d1
        add.l d1,d0
        dbra d2,.word
        tst.l d0
        bne.s .done
        moveq #1,d0
.done:  movem.l (sp)+,d1-d2/a1
        rts

; D0 hash -> D1 its slot, D2 the fewest sections it was reached with, FINISH_NONE
; when it was not.
finish_memo:
        move.l a0,-(sp)
        lea FINISH_MEMO_KEYS(a5),a0
        ; The low bits of a hash follow the low bits of the coordinates, which
        ; are much the same: the slot comes from the top bits of a product.
        move.l d0,d1
        mulu.l #$9e3779b1,d1
        moveq #FINISH_MEMO_BITS,d2
        rol.l d2,d1
        andi.w #FINISH_MEMO_SLOTS-1,d1
.probe: move.w d1,d2
        lsl.w #2,d2
        move.l (a0,d2.w),d2
        beq.s .empty
        cmp.l d0,d2
        beq.s .found
        addq.w #1,d1
        andi.w #FINISH_MEMO_SLOTS-1,d1
        bra.s .probe
.empty: move.w #FINISH_NONE,d2
        movea.l (sp)+,a0
        rts
.found: lea FINISH_MEMO_G(a5),a0
        moveq #0,d2
        move.b (a0,d1.w),d2
        movea.l (sp)+,a0
        rts

; D0 hash, D1 slot, D2 sections: the slot keeps them.
finish_memo_set:
        movem.l d1/a0,-(sp)
        lea FINISH_MEMO_G(a5),a0
        move.b d2,(a0,d1.w)
        lea FINISH_MEMO_KEYS(a5),a0
        lsl.w #2,d1
        move.l d0,(a0,d1.w)
        movem.l (sp)+,d1/a0
        rts

; D0 key onto the heap.
finish_push:
        movem.l d1-d5/a0,-(sp)
        lea FINISH_HEAP(a5),a0
        move.w finish_heap_size(pc),d1
        addq.w #1,finish_heap_size-module_start(a5)
.up:    tst.w d1
        beq.s .put
        move.w d1,d2
        subq.w #1,d2
        lsr.w #1,d2
        move.w d2,d3
        lsl.w #2,d3
        move.l (a0,d3.w),d4
        cmp.l d0,d4
        bls.s .put
        move.w d1,d5
        lsl.w #2,d5
        move.l d4,(a0,d5.w)
        move.w d2,d1
        bra.s .up
.put:   lsl.w #2,d1
        move.l d0,(a0,d1.w)
        movem.l (sp)+,d1-d5/a0
        rts

; -> D0 the smallest key, taken off the heap.
finish_pop:
        movem.l d1-d7/a0,-(sp)
        lea FINISH_HEAP(a5),a0
        move.l (a0),d0
        subq.w #1,finish_heap_size-module_start(a5)
        move.w finish_heap_size(pc),d5
        beq.s .done
        move.w d5,d1
        lsl.w #2,d1
        move.l (a0,d1.w),d4
        moveq #0,d1
.down:  move.w d1,d2
        add.w d2,d2
        addq.w #1,d2
        cmp.w d5,d2
        bhs.s .place
        move.w d2,d3
        lsl.w #2,d3
        move.l (a0,d3.w),d6
        move.w d2,d3
        addq.w #1,d3
        cmp.w d5,d3
        bhs.s .one
        lsl.w #2,d3
        move.l (a0,d3.w),d7
        cmp.l d6,d7
        bhs.s .one
        move.l d7,d6
        addq.w #1,d2
.one:   cmp.l d4,d6
        bhs.s .place
        move.w d1,d3
        lsl.w #2,d3
        move.l d6,(a0,d3.w)
        move.w d2,d1
        bra.s .down
.place: lsl.w #2,d1
        move.l d4,(a0,d1.w)
.done:  movem.l (sp)+,d1-d7/a0
        rts

; The sections Del would take go, the found sections follow, all one Undo step.
finish_commit:
        bsr editing_backup
        move.w finish_e(pc),d4
        move.w finish_e0(pc),d3
        cmp.w d3,d4
        beq .add
        ; The sections go as Del takes them: pieces after a gap move down to
        ; the new end of the road before it.
        bsr track_cut
        clr.w editor_track+SCTR_CLOSED-module_start(a5)
        bsr editor_model_refresh
        ; block_make keeps no register, so the step is counted in memory.
.add:   clr.w finish_step-module_start(a5)
.section:
        move.w finish_step(pc),d0
        cmp.w finish_found(pc),d0
        bhs.s .placed
        move.w #1,building_mode-module_start(a5)
        bsr block_context
        tst.w d0
        beq.s .mismatch
        lea FINISH_PATH(a5),a0
        move.w finish_step(pc),d0
        moveq #0,d1
        move.b (a0,d0.w),d1
        move.w d1,d0
        bsr block_make
        tst.w d0
        beq.s .refused
        addq.w #1,finish_step-module_start(a5)
        bra.s .section
.placed:
        clr.w building_mode-module_start(a5)
        ; As a placed section: the Add slot while the track stays open.
        move.w block_insert(pc),building_selected-module_start(a5)
        tst.w editor_track+SCTR_CLOSED-module_start(a5)
        bne.s .selected
        move.w editor_track+SCTR_COUNT(pc),building_selected-module_start(a5)
.selected:
        bsr editing_changed
        bsr finish_result_text
        move.w #FINISH_STATUS,storage_status-module_start(a5)
        rts
; The module refused what the search found: the track goes back as it was.
.refused:
        bsr block_restore
.mismatch:
        move.w #1,finish_mismatch-module_start(a5)
        clr.w building_mode-module_start(a5)
        bsr editing_undo
        clr.w editing_redo_count-module_start(a5)
        rts

; finish_text: what L2 says of the change.
finish_result_text:
        lea finish_text(pc),a1
        move.w finish_deleted(pc),d1
        bne.s .took
        lea finish_closed_with_text(pc),a0
        tst.w finish_gap-module_start(a5)
        beq.s .first
        lea finish_filled_with_text(pc),a0
.first: bsr text_append
        move.w finish_found(pc),d0
        bsr text_decimal
        lea finish_section_text(pc),a0
        tst.w finish_gap-module_start(a5)
        bne.s .plural
        lea finish_more_text(pc),a0
        bra.s .plural
.took:  lea finish_closed_off_text(pc),a0
        tst.w finish_gap-module_start(a5)
        beq.s .off
        lea finish_filled_off_text(pc),a0
.off:   bsr text_append
        move.w d1,d0
        bsr text_decimal
        lea finish_added_text(pc),a0
        bsr text_append
        move.w finish_found(pc),d0
        bsr text_decimal
        lea finish_section_text(pc),a0
.plural:
        bsr text_append
        cmpi.w #1,finish_found-module_start(a5)
        beq.s .stop
        move.b #'s',(a1)+
.stop:  move.b #'.',(a1)+
        clr.b (a1)
        rts

finish_goal: dcb.w 6,0
finish_root_tail: dcb.w 6,0
finish_tail: dcb.w 6,0
finish_end_row: dcb.w 6,0
finish_started: dc.l 0
; Kept for the checker: the time and the expansions of the last Finish.
finish_ms: dc.l 0
finish_expanded_total: dc.l 0
finish_expanded: dc.l 0
finish_e0: dc.w 0
finish_e: dc.w 0
finish_total: dc.w 0
finish_deleted: dc.w 0
finish_root_count: dc.w 0
finish_count: dc.w 0
finish_g: dc.w 0
finish_index: dc.w 0
finish_nodes_used: dc.w 0
finish_heap_size: dc.w 0
finish_depth: dc.w 0
finish_found: dc.w 0
finish_step: dc.w 0
finish_gap: dc.w 0
finish_mismatch: dc.w 0
finish_text: dcb.b UI_LINE_CHARS+2,0
        even
