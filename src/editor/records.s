; Store and restore custom-track records for normal and super leagues.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; SCER v1: exact 288-byte identity, two 32-byte league records.
; Cache at Fast+$1fa00 is outside the 64000-byte display backup.
; Shared storage scratch is used only synchronously outside gameplay.
records_cache:
        movea.l a5,a4
        adda.l #$1fa00,a4
        rts
records_key_build:
        lea records_key(pc),a1
        moveq #71,d0
.zero:  clr.l (a1)+
        dbra d0,.zero
        lea editor_track+8(pc),a0
        lea records_key(pc),a1
        moveq #20,d0
        bsr storage_copy
        move.w editor_track+28(pc),(a1)+
        move.w editor_track+32(pc),(a1)+
        move.w practice_runtime+6(pc),(a1)+
        addq.l #6,a1
        lea editor_track+68(pc),a0
        move.w editor_track+28(pc),d0
        subq.w #1,d0
.piece: move.l (a0),(a1)+
        addq.l #8,a0
        dbra d0,.piece
        rts
records_eligible:
        moveq #0,d0
        cmpi.w #20,$18243a
        bne.s .done
        tst.b $182445
        bne.s .done
        tst.b $182446
        bne.s .done
        moveq #1,d0
.done:  rts

; A0 envelope -> generation/0, D6 sticky invalid-nonempty flag.
records_validate:
        movem.l d1-d3/a0,-(sp)
        cmpi.l #$53434552,(a0)
        bne .bad
        cmpi.l #$00010020,4(a0)
        bne .bad
        move.w records_slot(pc),d0
        cmp.w 12(a0),d0
        bne .bad
        cmpi.w #1,14(a0)       ; fixed policy/gameplay revision
        bne .bad
        tst.l 8(a0)
        beq .bad
        lea 16(a0),a1
        moveq #3,d0
.reserved:
        tst.l (a1)+
        bne .bad
        dbra d0,.reserved
        lea 384(a0),a1
        move.w #158,d0
.padding:
        tst.l (a1)+
        bne .bad
        dbra d0,.padding
        lea 320(a0),a1
        moveq #3,d2
.times:
        moveq #11,d1
.name:
        move.b (a1)+,d0
        beq.s .char_ok
        cmpi.b #32,d0
        blo .bad
        cmpi.b #126,d0
        bhi .bad
.char_ok:
        dbra d1,.name
        cmpi.b #9,(a1)+
        bhi .bad
        move.b (a1)+,d0
        cmpi.b #$59,d0
        bhi .bad
        andi.b #15,d0
        cmpi.b #9,d0
        bhi .bad
        move.b (a1)+,d0
        cmpi.b #$99,d0
        bhi .bad
        andi.b #15,d0
        cmpi.b #9,d0
        bhi .bad
        tst.b (a1)+
        bne .bad
        dbra d2,.times
        move.w #1020,d0
        bsr storage_crc
        cmp.l (a0),d0
        bne .bad
        move.l -1012(a0),d0
        bra.s .done
.bad:
        movea.l 12(sp),a0
        move.w #255,d0
.nonempty:
        tst.l (a0)+
        bne.s .invalid
        dbra d0,.nonempty
        bra.s .zero
.invalid: moveq #1,d6
.zero:  moveq #0,d0
.done:  movem.l (sp)+,d1-d3/a0
        rts

; Return D0=0 success; A4 newest (or empty A), D4 generation,
; records_target inactive bank. Refuse damaged/unknown nonempty copies.
records_scan:
        clr.l storage_gen_a-module_start(a5)
        clr.l storage_gen_b-module_start(a5)
        moveq #0,d6
        bsr records_sector
        lea storage_a(pc),a4
        bsr .read
        move.l d0,storage_gen_a-module_start(a5)
        bsr records_sector
        addi.w #132,d1
        lea storage_b(pc),a4
        bsr .read
        move.l d0,storage_gen_b-module_start(a5)
        tst.w d6
        bne .bad
        bsr records_sector
        move.w d1,records_target-module_start(a5)
        move.l storage_gen_b(pc),d4
        lea storage_b(pc),a4
        cmp.l storage_gen_a(pc),d4
        bhi.s .selected
        move.l storage_gen_a(pc),d4
        lea storage_a(pc),a4
        addi.w #132,records_target-module_start(a5)
        tst.l d4
        bne.s .selected
        move.w d1,records_target-module_start(a5)
.selected:
        moveq #0,d0
        rts
.bad:   moveq #1,d0
        rts
.read:
        moveq #2,d2
        moveq #0,d3
        bsr storage_io
        bne.s .return
        movea.l 28(a5),a0
        lea 16384(a0),a0
        movea.l a4,a1
        move.w #1024,d0
        bsr storage_copy
        movea.l a4,a0
        bsr records_validate
        rts
.return: moveq #1,d6
        moveq #0,d0
        rts
records_sector:
        move.w records_slot(pc),d1
        lsl.w #2,d1
        addi.w #1212,d1
        rts

records_begin:
        clr.w records_dirty-module_start(a5)
        clr.w records_allowed-module_start(a5)
        clr.w records_error-module_start(a5)
        bsr records_eligible
        tst.w d0
        beq .done
        bsr records_scan
        tst.w d0
        bne .error
        move.l d4,records_generation-module_start(a5)
        move.l 1020(a4),records_crc-module_start(a5)
        movea.l a4,a0
        bsr records_cache
        movea.l a4,a1
        move.w #1024,d0
        bsr storage_copy
        lea 32(a4),a0
        lea records_key(pc),a1
        moveq #71,d0
.compare:
        cmpm.l (a0)+,(a1)+
        bne.s .new
        dbra d0,.compare
        bra.s .load
.new:
        movea.l a4,a0
        move.w #255,d0
.clear: clr.l (a0)+
        dbra d0,.clear
        move.l #$53434552,(a4)
        move.l #$00010020,4(a4)
        move.w records_slot(pc),12(a4)
        move.w #1,14(a4)
        lea records_key(pc),a0
        lea 32(a4),a1
        move.w #288,d0
        bsr storage_copy
        lea custom_session_times(pc),a0
        lea 320(a4),a1
        moveq #32,d0
        bsr storage_copy
        lea custom_session_times(pc),a0
        lea 352(a4),a1
        moveq #32,d0
        bsr storage_copy
.load:
        move.w #1,records_allowed-module_start(a5)
        moveq #0,d0
        tst.b $1c9d0
        beq.s .league
        moveq #32,d0
.league:
        move.w d0,records_league-module_start(a5)
        lea 320(a4),a0
        adda.w d0,a0
        lea custom_session_times(pc),a1
        moveq #32,d0
        bsr storage_copy
.done:  rts
.error: move.w #1,records_error-module_start(a5)
        rts

records_changed:
        tst.w records_allowed-module_start(a5)
        beq.s .done
        bsr records_eligible
        tst.w d0
        beq.s .disable
        moveq #0,d0
        tst.b $1c9d0
        beq.s .league
        moveq #32,d0
.league:
        cmp.w records_league(pc),d0
        bne.s .disable
        bsr records_cache
        lea custom_session_times(pc),a0
        lea 320(a4),a1
        adda.w records_league(pc),a1
        moveq #32,d0
        bsr storage_copy
        move.w #1,records_dirty-module_start(a5)
.done:  rts
.disable:
        clr.w records_allowed-module_start(a5)
        clr.w records_dirty-module_start(a5)
        rts

; No gameplay disk I/O: call on return to menus. Preserve original model.
records_commit:
        tst.w records_dirty-module_start(a5)
        beq .ok
        bsr storage_identity
        bne .bad
        move.w storage_slot(pc),-(sp)
        move.w records_slot(pc),storage_slot-module_start(a5)
        bsr storage_backup
        bsr storage_scan
        move.w (sp)+,storage_slot-module_start(a5)
        tst.w d0
        bne .bad
        ; Compare the selected project's generation and CRC without editing it.
        move.l storage_gen_a(pc),d0
        lea storage_a(pc),a0
        cmp.l storage_gen_b(pc),d0
        bhs.s .project
        move.l storage_gen_b(pc),d0
        lea storage_b(pc),a0
.project:
        cmp.l records_project_generation(pc),d0
        bne .bad
        move.l 1020(a0),d0
        cmp.l records_project_crc(pc),d0
        bne .bad
        bsr records_scan
        tst.w d0
        bne .bad
        cmp.l records_generation(pc),d4
        beq.s .unchanged
        ; A write may have succeeded before its readback failed. Retrying
        ; that exact transaction is idempotent, never a second generation.
        movea.l a4,a0
        bsr records_cache
        movea.l a4,a1
        move.w #255,d0
.retry:
        cmpm.l (a0)+,(a1)+
        bne .bad
        dbra d0,.retry
        bra .committed
.unchanged:
        move.l 1020(a4),d0
        cmp.l records_crc(pc),d0
        bne .bad
        addq.l #1,d4
        beq .bad
        bsr records_cache
        move.l d4,8(a4)
        movea.l a4,a0
        move.w #1020,d0
        bsr storage_crc
        move.l d0,1020(a4)
        movea.l a4,a0
        movea.l 28(a5),a1
        lea 16384(a1),a1
        move.w #1024,d0
        bsr storage_copy
        move.w records_target(pc),d1
        moveq #2,d2
        moveq #1,d3
        bsr storage_io
        bne .bad
        movea.l 28(a5),a0
        lea 16384(a0),a0
        move.w #255,d0
.poison:move.l #$a55aa55a,(a0)+
        dbra d0,.poison
        moveq #0,d3
        bsr storage_io
        bne .bad
        movea.l 28(a5),a0
        lea 16384(a0),a0
        movea.l a4,a1
        move.w #255,d0
.verify:cmpm.l (a0)+,(a1)+
        bne .bad
        dbra d0,.verify
.committed:
        move.l d4,records_generation-module_start(a5)
        move.l 1020(a4),records_crc-module_start(a5)
        clr.w records_dirty-module_start(a5)
.ok:    clr.w records_error-module_start(a5)
        moveq #0,d0
        rts
.bad:   move.w #1,records_error-module_start(a5)
        moveq #1,d0
        rts
records_key: dcb.b 288,0
records_slot: dc.w 0
records_league: dc.w 0
records_allowed: dc.w 0
records_dirty: dc.w 0
records_error: dc.w 0
records_target: dc.w 0
records_generation: dc.l 0
records_crc: dc.l 0
records_project_generation: dc.l 0
records_project_crc: dc.l 0
