; Validate track models and generate their world geometry.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; canonical SCTR model and independent world geometry. A5 = module base.
; No Chip/DMA access. All geometry words are X,Y,Z (unsigned world X/Z).
; A0 = 8-byte piece; A1 = capacity for 2*EDITOR_MAX_ROWS XYZ points; D7 = base height.
; Returns D0 = cross-row count or zero; A1 advances only on success/partial
; failure. Caller never publishes partially generated geometry.
editor_piece_geometry:
        movem.l d1-d7/a0/a2-a4,-(sp)
        tst.l (a0)
        beq .bad
        moveq #0,d0
        move.b 4(a0),d0
        subq.w #1,d0
        cmpi.w #EDITOR_KIND_COUNT-1,d0
        bhi .bad
        cmpi.w #7,d0
        blo.s .kind_valid
        cmpi.l #3,editor_track+24-module_start(a5)
        bne .bad
        movem.l d0/a4,-(sp)
        bsr practice_catalog_entry
        move.b 3(a4),d0
        subq.b #2,d0
        cmp.b 6(a0),d0
        movem.l (sp)+,d0/a4
        bne .bad
.kind_valid:
        add.w d0,d0
        lea editor_catalog(pc),a2
        move.w (a2,d0.w),d0
        adda.w d0,a2
        moveq #0,d6
        move.w (a2),d6
        cmpi.w #9,d6
        blo .bad
        cmpi.w #EDITOR_MAX_ROWS,d6
        bhi .bad
        movea.l a2,a4
        move.w 4(a2),d0       ; signed relative height-array offset
        tst.b 6(a0)
        beq.s .height_offset
        move.w 6(a2),d0
.height_offset:
        adda.w d0,a4
        adda.w 2(a2),a2       ; shared immutable X/Z rows
.height_revision:
        cmpi.l #1,editor_track+24-module_start(a5)
        bne.s .height_ready
        cmpi.b #2,4(a0)
        blo.s .height_ready
        cmpi.b #3,4(a0)
        bhi.s .height_ready
        lea model_legacy_flat(pc),a4
.height_ready:
        moveq #0,d5
        move.b 5(a0),d5
        cmpi.w #3,d5
        bhi .bad
        cmpi.b #1,6(a0)
        bhi .bad
        cmpi.l #32767,d7
        bhi .bad
        moveq #0,d3
        move.b 7(a0),d3
        moveq #0,d4
        move.w d3,d4
        andi.w #15,d3
        lsr.w #4,d4
        lsl.w #8,d3
        lsl.w #3,d3
        lsl.w #8,d4
        lsl.w #3,d4
        moveq #4,d2
        tst.b 6(a0)
        beq.s .forward
        move.w d6,d0
        lsl.w #3,d0
        subq.w #4,d0
        adda.w d0,a2
        moveq #-4,d2
.forward:
        movea.w d2,a3
        move.w d6,-(sp)
        add.w d6,d6
        subq.w #1,d6
.point:
        move.w (a2),d0
        move.w 2(a2),d1
        adda.w a3,a2
        tst.w d5
        beq.s .translated
        cmpi.w #2,d5
        beq.s .half
        exg d0,d1
        cmpi.w #1,d5
        beq.s .quarter
        neg.w d0
        addi.w #2048,d0
        bra.s .translated
.quarter:
        neg.w d1
        addi.w #2048,d1
        bra.s .translated
.half:
        neg.w d0
        neg.w d1
        addi.w #2048,d0
        addi.w #2048,d1
.translated:
        ext.l d0
        ext.l d1
        add.l d3,d0
        add.l d4,d1
        cmpi.l #32768,d0
        bhi.s .bad_pop
        cmpi.l #32768,d1
        bhi.s .bad_pop
        move.w d0,(a1)+
        move.w (a4)+,d0
        ext.l d0
        add.l d7,d0
        cmpi.l #32767,d0
        bhi.s .bad_pop
        move.w d0,(a1)+
        move.w d1,(a1)+
        dbra d6,.point
        moveq #0,d0
        move.w (sp)+,d0
        bra.s .done
.bad_pop:
        addq.l #2,sp
.bad:
        moveq #0,d0
.done:
        movem.l (sp)+,d1-d7/a0/a2-a4
        rts

; Validate canonical payload, then build private geometry. D0=1 success / 0
; failure; all other registers preserved. Geometry cache is invalid on error.
editor_model_refresh:
        move.w #1,model_refresh-module_start(a5)
        bsr editor_model_build
        clr.w model_refresh-module_start(a5)
        movem.l d0-d3/a0,-(sp)
        lea editor_track(pc),a0
        move.w 6(a0),d0
        subq.w #4,d0
        bsr storage_crc
        move.l d0,(a0)
        movem.l (sp)+,d0-d3/a0
        rts
editor_model_build:
        movem.l d1-d7/a0-a4,-(sp)
        clr.w model_valid-module_start(a5)
        clr.w practice_class-module_start(a5)
        clr.w practice_runtime_valid-module_start(a5)
        lea editor_track(pc),a0
        cmpi.l #$53435452,(a0)
        bne .bad
        cmpi.w #1,4(a0)
        bne .bad
        cmpi.l #1,24(a0)
        blo .bad
        cmpi.l #3,24(a0)
        bhi .bad
        moveq #0,d6
        move.w 28(a0),d6
        beq .bad
        cmpi.w #64,d6
        bhi .bad
        move.w d6,d0
        lsl.w #3,d0
        addi.w #68,d0
        cmp.w 6(a0),d0
        bne .bad
        cmpi.w #1,30(a0)
        bhi .bad
        tst.w 34(a0)
        bne .bad
        moveq #0,d7
        move.w 32(a0),d7
        bmi .bad
        move.l 8(a0),d0
        or.l 12(a0),d0
        or.l 16(a0),d0
        or.l 20(a0),d0
        beq .bad
        ; Nonempty printable ASCII followed only by zero padding.
        lea 40(a0),a2
        tst.b (a2)
        beq .bad
        moveq #23,d1
        moveq #0,d2
.name:
        move.b (a2)+,d0
        beq.s .padding
        tst.b d2
        bne .bad
        cmpi.b #32,d0
        blo .bad
        cmpi.b #126,d0
        bhi .bad
        bra.s .next_char
.padding:
        moveq #1,d2
.next_char:
        dbra d1,.name
        tst.w model_refresh-module_start(a5)
        bne .crc_ok
        ; IEEE CRC32 over header and active piece bytes, excluding CRC itself.
        moveq #0,d2
        move.w 6(a0),d2
        subq.w #5,d2
        movea.l a0,a2
        moveq #-1,d0
.crc_byte:
        moveq #0,d1
        move.b (a2)+,d1
        eor.l d1,d0
        moveq #7,d3
.crc_bit:
        lsr.l #1,d0
        bcc.s .crc_next
        eori.l #$edb88320,d0
.crc_next:
        dbra d3,.crc_bit
        dbra d2,.crc_byte
        not.l d0
        cmp.l (a2),d0
        bne .bad
.crc_ok:
        lea 64(a0),a0
        lea model_geometry(pc),a1
        lea model_row_counts(pc),a4
        moveq #0,d4
        moveq #0,d5
.piece:
        ; Stable IDs must be nonzero and unique. Finish ID must name a straight.
        lea editor_track+64(pc),a2
        move.w d4,d1
        beq.s .unique
        subq.w #1,d1
.id:
        move.l (a0),d0
        cmp.l (a2),d0
        beq .bad
        addq.l #8,a2
        dbra d1,.id
.unique:
        move.l (a0),d0
        cmp.l editor_track+36(pc),d0
        bne.s .not_finish
        cmpi.b #1,4(a0)
        bne .bad
        addq.w #1,d5
.not_finish:
        cmpi.l #3,editor_track+24-module_start(a5)
        blo.s .revision_ok
        cmpi.b #2,4(a0)
        beq .bad
        cmpi.b #3,4(a0)
        beq .bad
.revision_ok:
        movea.l a1,a3
        bsr editor_piece_geometry
        tst.w d0
        beq .bad
        move.w d0,(a4)+
        ; Every piece owns a fixed cache stride (max EDITOR_MAX_ROWS rows).
        lea EDITOR_GEOMETRY_STRIDE(a3),a1
        tst.w d4
        beq.s .first
        movem.l d0-d7/a0-a4,-(sp)
        movea.l a3,a1
        movea.l a3,a0
        suba.w #EDITOR_GEOMETRY_STRIDE,a0
        move.w -4(a4),d0
        subq.w #1,d0
        mulu.w #12,d0
        adda.w d0,a0
        bsr editor_join
        tst.w d0
        movem.l (sp)+,d0-d7/a0-a4
        beq .bad
.first:
        move.w -2(a4),d7
        subq.w #1,d7
        mulu.w #12,d7
        moveq #0,d0
        move.w 2(a3,d7.w),d0
        move.l d0,d7
        addq.l #8,a0
        addq.w #1,d4
        cmp.w d6,d4
        blo .piece
        cmpi.w #1,d5
        bne .bad
        ; Last exit vs first entrance must agree with stored Open/Closed.
        movea.l a3,a0
        move.w -2(a4),d0
        subq.w #1,d0
        mulu.w #12,d0
        adda.w d0,a0
        lea model_geometry(pc),a1
        bsr editor_join
        tst.w model_refresh-module_start(a5)
        beq.s .check_closed
        move.w d0,editor_track+30-module_start(a5)
.check_closed:
        cmp.w editor_track+30(pc),d0
        bne .bad
        move.w #1,model_valid-module_start(a5)
        bsr practice_classify
        moveq #1,d0
        bra.s .done
.bad:
        moveq #0,d0
.done:
        movem.l (sp)+,d1-d7/a0-a4
        rts

; Ordered ports A0/A1: left XYZ, right XYZ. One unit in X/Z,
; exact Y. Both edges in order imply matching normal for this fixed-width
; library (width >=271); reversed ports cannot pass the tolerance check.
editor_join:
        moveq #5,d2
.coord:
        moveq #0,d0
        moveq #0,d1
        move.w (a0)+,d0
        move.w (a1)+,d1
        sub.l d1,d0
        bpl.s .absolute
        neg.l d0
.absolute:
        cmpi.w #4,d2
        beq.s .height
        cmpi.w #1,d2
        beq.s .height
        cmpi.l #1,d0
        bhi.s .bad
        bra.s .next
.height:
        tst.l d0
        bne.s .bad
.next:
        dbra d2,.coord
        moveq #1,d0
        rts
.bad:
        moveq #0,d0
        rts

editor_model_view:
        bra editor_model_build
model_refresh: dc.w 0
model_valid: dc.w 0
model_row_counts: dcb.w 64,0
model_geometry: dcb.b 64*EDITOR_GEOMETRY_STRIDE,0

model_legacy_flat: dcb.w 20,0
