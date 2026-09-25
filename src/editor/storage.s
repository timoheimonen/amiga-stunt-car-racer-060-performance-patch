; Read and write track projects in guarded game-disk storage banks.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; A5=module base. Exclusive synchronous I/O in editor main loop.
; Banks begin on physical tracks 110 and 122 (11 sectors/track), slot stride 4.
; The game driver uses disk DMA AND blitter decoding: both A0 and A1 are Chip.
editor_storage_keys:
        cmpi.w #7,storage_modal-module_start(a5)
        beq disk_initialize_step
        tst.w storage_modal-module_start(a5)
        bne storage_modal_keys
        tst.w editing_prompt-module_start(a5)
        bne.s .done
        tst.w building_exit-module_start(a5)
        bne.s .done
        cmpi.b #$b3,editor_input_keys+$21(a5)
        beq.s .save
        cmpi.b #$b3,editor_input_keys+$28(a5)
        beq.s .load
.done:
        rts
.save:
        bsr editor_release
        clr.w storage_continue-module_start(a5)
        bra storage_open_save
.load:
        ; S/L explicitly discard only the unconfirmed preview.
        clr.w building_mode-module_start(a5)
        clr.w building_candidate_count-module_start(a5)
        moveq #2,d0
        bra editing_request

; D1=sector, D2=count (1, 2 or 3), D3=read/write. A0 always Chip+16384.
; Only fixed callers below may write. No OS calls after takeover.
storage_io:
        movem.l d1-d7/a0-a6,-(sp)
        move.w sr,-(sp)
        ; Level-1 DSKBLK handler would acknowledge the driver's polled bit.
        ; CIA keyboard/timer handlers must not change its timer while active.
        ori.w #$0700,sr
        move.w $dff002,d6
        andi.w #$7ff,d6
        move.w $dff010,d7
        andi.w #$7fff,d7
        movea.l 28(a5),a1
        lea 16384(a1),a0
        bsr cache_flush
        moveq #0,d0           ; DF0 unless a scoped external operation
        tst.w disk_io_active-module_start(a5)
        beq.s .drive_ready
        bsr disk_status
        btst #2,d0
        bne.s .external_present
        moveq #29,d0
        bra.s .io_result
.external_present:
        tst.w d3
        beq.s .external_drive
        bsr disk_write_guard
        tst.l d0
        bne.s .io_result
.external_drive:
        moveq #1,d0           ; DF1 only, never fallback
.drive_ready:
        jsr $62e86            ; exclude game's sound/gameplay wrapper
.io_result:
        move.l d0,storage_io_error-module_start(a5)
        move.l d0,-(sp)
        move.w #$7fff,$dff09e
        ori.w #$8000,d7
        move.w d7,$dff09e
        ; The disk driver only enables DSKEN/BLTEN ($0010/$0040).
        ; Clear just the bits it added. Dropping all DMA here also stops
        ; bitplanes and copper at an arbitrary beam position during loading.
        move.w d6,d0
        not.w d0
        andi.w #$0050,d0
        move.w d0,$dff096
        bsr cache_flush
        jsr $ee8a             ; original I/O return's CIA timer/IRQ setup
        move.l (sp)+,d0
        move.w (sp)+,sr
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts

storage_identity:
        tst.w disk_io_active-module_start(a5)
        bne disk_identity
        move.w #1200,d1
        moveq #1,d2
        moveq #0,d3
        bsr storage_io
        bne.s .bad
        movea.l 28(a5),a0
        lea 16384(a0),a0
        lea storage_disk_id(pc),a1
        moveq #5,d1
.compare:
        cmpm.l (a0)+,(a1)+
        bne.s .bad
        dbra d1,.compare
        move.w #121,d1
.padding:
        tst.l (a0)+
        bne.s .bad
        dbra d1,.padding
        moveq #0,d0
        rts
.bad:
        moveq #1,d0
        rts
storage_disk_id:
        dc.b 'SCIE-DRAFT-DISK',0
        dc.l 2,1760

; A0 source, A1 destination, D0 byte count divisible by four.
storage_copy:
        lsr.w #2,d0
        subq.w #1,d0
.loop:
        move.l (a0)+,(a1)+
        dbra d0,.loop
        rts
storage_backup:
        lea editor_track(pc),a0
        lea storage_work(pc),a1
        move.w #580,d0
        bra storage_copy
storage_restore:
        lea storage_work(pc),a0
        lea editor_track(pc),a1
        move.w #580,d0
        bra storage_copy

; A0 data, D0 count. D0 returns CRC32, A0 advances; D1-D3 clobbered.
storage_crc:
        move.w d0,d2
        subq.w #1,d2
        moveq #-1,d0
.byte:
        moveq #0,d1
        move.b (a0)+,d1
        eor.l d1,d0
        moveq #7,d3
.bit:
        lsr.l #1,d0
        bcc.s .next
        eori.l #$edb88320,d0
.next:
        dbra d3,.bit
        dbra d2,.byte
        not.l d0
        rts

; A0=1024-byte envelope. Returns generation or zero. Semantic validation
; uses editor_track temporarily; storage_scan always restores the RAM draft.
storage_validate:
        movem.l d1-d7/a0-a4,-(sp)
        movea.l a0,a4
        cmpi.l #$53434553,(a0)
        bne .bad
        cmpi.l #$00020020,4(a0)
        beq.s .version_ok
        cmpi.l #$00010020,4(a0) ; single-slot compatibility
        bne .bad
        tst.w storage_slot-module_start(a5)
        bne .bad
.version_ok:
        tst.l 8(a0)
        beq .bad
        move.w storage_slot(pc),d1
        cmp.w 14(a0),d1
        bne .bad
        move.w 12(a0),d4
        cmpi.w #76,d4
        blo .bad
        cmpi.w #580,d4
        bhi .bad
        cmp.w 38(a0),d4       ; SCTR length must equal envelope length
        bne .bad
        lea 16(a0),a1
        moveq #3,d1
.reserved:
        tst.l (a1)+
        bne .bad
        dbra d1,.reserved
        adda.w d4,a1
        move.w #987,d1
        sub.w d4,d1
.padding:
        tst.b (a1)+
        bne .bad
        dbra d1,.padding
        move.w #1020,d0
        bsr storage_crc
        cmp.l 1020(a4),d0
        bne .bad
        lea 32(a4),a0
        lea editor_track(pc),a1
        move.w #580,d0
        bsr storage_copy
        bsr editor_model_build
        tst.w d0
        beq.s .bad
        move.l 8(a4),d0
        bra.s .done
.bad:
        moveq #0,d0
.done:
        movem.l (sp)+,d1-d7/a0-a4
        rts

storage_scan:
        clr.w storage_read_error-module_start(a5)
        clr.l storage_gen_a-module_start(a5)
        clr.l storage_gen_b-module_start(a5)
        bsr storage_sector_a
        lea storage_a(pc),a4
        bsr .read
        bne.s .a_failed
        lea storage_a(pc),a0
        bsr .validate
        move.l d0,storage_gen_a-module_start(a5)
        bra.s .read_b
.a_failed:
        move.w #1,storage_read_error-module_start(a5)
.read_b:
        bsr storage_sector_a
        addi.w #132,d1
        lea storage_b(pc),a4
        bsr .read
        bne.s .b_failed
        lea storage_b(pc),a0
        bsr .validate
        move.l d0,storage_gen_b-module_start(a5)
        bra.s .restore
.b_failed:
        move.w #1,storage_read_error-module_start(a5)
.restore:
        bsr storage_restore
        move.l storage_gen_a(pc),d0
        or.l storage_gen_b(pc),d0
        bne.s .ok
        moveq #0,d0
        move.w storage_read_error(pc),d0
        rts
.ok:
        moveq #0,d0
        rts
; A corrupt nonempty envelope is not an empty slot. If no valid copy
; remains, refuse Save as well as Load; preserve unknown/recoverable media.
.validate:
        bsr storage_validate
        tst.l d0
        bne.s .validated
        move.w #255,d1
.nonempty:
        tst.l (a0)+
        bne.s .invalid
        dbra d1,.nonempty
.validated:
        rts
.invalid:
        move.w #1,storage_read_error-module_start(a5)
        rts
.read:
        moveq #2,d2
        moveq #0,d3
        bsr storage_io
        bne.s .done
        movea.l 28(a5),a0
        lea 16384(a0),a0
        movea.l a4,a1
        move.w #1024,d0
        bsr storage_copy
        moveq #0,d0
.done:
        rts

; Prefer A on equal generations. No generation wrapping: exhausted media
; reports failure rather than allowing an older record to appear newer.
storage_select:
        move.l storage_gen_a(pc),d4
        lea storage_a(pc),a4
        bsr storage_sector_a
        addi.w #132,d1
        move.w d1,storage_target-module_start(a5)
        cmp.l storage_gen_b(pc),d4
        bhs.s .done
        move.l storage_gen_b(pc),d4
        lea storage_b(pc),a4
        bsr storage_sector_a
        move.w d1,storage_target-module_start(a5)
.done:
        tst.l d4
        bne.s .return
        bsr storage_sector_a
        move.w d1,storage_target-module_start(a5)
.return:
        rts

storage_sector_a:
        move.w storage_slot(pc),d1
        lsl.w #2,d1
        addi.w #1210,d1
        rts

editor_save:
        movem.l d0-d7/a0-a4,-(sp)
        move.w #3,storage_status-module_start(a5)
        bsr editor_model_build
        tst.w d0
        beq storage_save_done
        bsr storage_backup
        bsr storage_identity
        bne storage_save_wrong
        bsr storage_scan
        bne storage_save_done
        bsr storage_select
        ; Refuse a changed slot/media after the user reviewed the list.
        bsr storage_entry
        cmp.l (a3),d4
        bne storage_save_done
        tst.l d4
        beq.s .same_slot
        move.l 1020(a4),d0
        cmp.l 4(a3),d0
        bne storage_save_done
.same_slot:
        tst.w disk_io_active-module_start(a5)
        beq.s .identity_checked
        bsr disk_identity
        bne storage_save_wrong
.identity_checked:
        addq.l #1,d4
        beq storage_save_done
        lea storage_pending(pc),a0
        move.w #255,d0
.clear:
        clr.l (a0)+
        dbra d0,.clear
        lea storage_pending(pc),a4
        move.l #$53434553,(a4)
        move.l #$00020020,4(a4)
        move.w storage_slot(pc),14(a4)
        move.l d4,8(a4)
        move.w editor_track+6(pc),12(a4)
        lea editor_track(pc),a0
        lea 32(a4),a1
        move.w 12(a4),d0
        subq.w #1,d0
.payload:
        move.b (a0)+,(a1)+
        dbra d0,.payload
        movea.l a4,a0
        move.w #1020,d0
        bsr storage_crc
        move.l d0,1020(a4)
        movea.l a4,a0
        movea.l 28(a5),a1
        lea 16384(a1),a1
        move.w #1024,d0
        bsr storage_copy
        move.w storage_target(pc),d1
        moveq #2,d2
        moveq #1,d3
storage_write_begin:
        bsr storage_io
storage_write_end:
        bne storage_save_done
        ; Poison the entire sector buffer to prove fresh physical readback.
        movea.l 28(a5),a0
        lea 16384(a0),a0
        move.w #255,d0
.poison:
        move.l #$a55aa55a,(a0)+
        dbra d0,.poison
        moveq #0,d3
        bsr storage_io
        bne storage_save_done
        movea.l 28(a5),a0
        lea 16384(a0),a0
        lea storage_pending(pc),a1
        move.w #255,d0
.compare:
        cmpm.l (a0)+,(a1)+
        bne storage_save_done
        dbra d0,.compare
        move.l d4,storage_generation-module_start(a5)
        tst.w disk_io_active-module_start(a5)
        bne.s .external_saved
        bsr editing_mark_saved
        move.w storage_slot(pc),storage_active_slot-module_start(a5)
.external_saved:
        move.w #1,storage_status-module_start(a5)
        bsr storage_update_entry
        bsr storage_directories_write
        bra.s storage_save_done
storage_save_wrong:
        move.w #5,storage_status-module_start(a5)
storage_save_done:
        bsr editor_model_view
        movem.l (sp)+,d0-d7/a0-a4
        rts

editor_load:
        movem.l d0-d7/a0-a4,-(sp)
        move.w #4,storage_status-module_start(a5)
        bsr storage_backup
        bsr storage_identity
        bne .wrong
        bsr storage_scan
        bne .done
        bsr storage_select
        tst.l d4
        beq .empty
        ; A disk/slot changed after listing must be reviewed again.
        bsr storage_entry
        cmp.l (a3),d4
        bne .done
        move.l 1020(a4),d0
        cmp.l 4(a3),d0
        bne .done
        tst.w disk_io_active-module_start(a5)
        beq.s .identity_checked
        bsr disk_identity
        bne .wrong
.identity_checked:
        lea 32(a4),a0
        lea editor_track(pc),a1
        move.w #580,d0
        bsr storage_copy
        move.l d4,storage_generation-module_start(a5)
        tst.w disk_io_active-module_start(a5)
        beq .game_slot
        move.w #-1,storage_active_slot-module_start(a5)
        move.w #-1,storage_saved_slot-module_start(a5)
        bra.s .slot_ready
.game_slot:
        move.w storage_slot(pc),storage_active_slot-module_start(a5)
.slot_ready:
        bsr editor_building_reset
        clr.w editing_undo_valid-module_start(a5)
        clr.l camera_route-module_start(a5)
        tst.w disk_io_active-module_start(a5)
        beq .mark_game_saved
        clr.w editing_saved_track+6-module_start(a5)
        move.w #1,building_dirty-module_start(a5)
        bra.s .loaded
.mark_game_saved:
        bsr editing_mark_saved
.loaded:
        addq.l #1,building_revision-module_start(a5)
        move.w #2,storage_status-module_start(a5)
        bra.s .done
.empty:
        move.w #6,storage_status-module_start(a5)
        bra.s .done
.wrong:
        move.w #5,storage_status-module_start(a5)
.done:
        bsr editor_model_view
        movem.l (sp)+,d0-d7/a0-a4
        rts

; Independent 8x7 CPU text into four Chip bitplanes; no game font globals.
editor_storage_text:
        lea storage_help(pc),a0
        movea.l draw_surface(pc),a1
        adda.w #322,a1
        bsr storage_text_line
        bsr practice_text
        movea.l draw_surface(pc),a1
        adda.w #7682,a1
        bsr storage_text_line
        move.w storage_status(pc),d0
        lsl.w #5,d0
        lea storage_messages(pc),a0
        adda.w d0,a0
        tst.w storage_status-module_start(a5)
        bne.s .status
        tst.w building_dirty-module_start(a5)
        beq.s .status
        lea storage_unsaved(pc),a0
.status:
        movea.l draw_surface(pc),a1
        adda.w #722,a1
        bra storage_text_line
storage_text_line:
        moveq #0,d0
        move.b (a0)+,d0
        beq.s .done
        cmpi.b #97,d0
        blo.s .font_range
        cmpi.b #122,d0
        bhi.s .font_range
        subi.b #32,d0
.font_range:
        cmpi.b #32,d0
        blo.s .unknown
        cmpi.b #90,d0
        bls.s .glyph
.unknown:
        moveq #63,d0
.glyph:
        subi.w #32,d0
        lsl.w #3,d0
        lea storage_font(pc),a2
        adda.w d0,a2
        movea.l a1,a3
        moveq #6,d1
.row:
        move.b (a2)+,d0
        move.b d0,(a3)
        move.b d0,8000(a3)
        move.b d0,16000(a3)
        move.b d0,24000(a3)
        adda.w #40,a3
        dbra d1,.row
        addq.l #1,a1
        bra.s storage_text_line
.done:
        rts
storage_help: dc.b 'S SAVE L LOAD N NEW V VIEW ESC EXIT',0
        even
storage_edit_help: dc.b 'U UNDO  BACKSPACE DELETE LAST',0
storage_unsaved: dc.b 'UNSAVED CHANGES',0
        even
storage_status: dc.w 0
storage_target: dc.w 0
storage_read_error: dc.w 0
storage_io_error: dc.l 0
storage_generation: dc.l 0
storage_gen_a: dc.l 0
storage_gen_b: dc.l 0
storage_work: dcb.b 580,0
storage_a: dcb.b 1024,0
storage_b: dcb.b 1024,0
storage_pending: dcb.b 1536,0
