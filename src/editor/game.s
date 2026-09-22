; Install custom-track game hooks and connect the editor to Practise.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Practice adapter. Private identity; legacy track ID is always bounded 0.
; All hooks checked by main_loaded before any hook is installed.
custom_verify_hooks:
        lea custom_hooks(pc),a4
        moveq #CUSTOM_HOOK_COUNT-1,d7
.loop:
        movea.l (a4)+,a0
        addq.l #6,a4
        move.w (a4)+,d6
        subq.w #1,d6
.bytes:
        cmpm.b (a4)+,(a0)+
        bne.s .bad
        dbra d6,.bytes
        dbra d7,.loop
        moveq #1,d0
        rts
.bad:   moveq #0,d0
        rts
custom_install_hooks:
        lea custom_hooks(pc),a4
        moveq #CUSTOM_HOOK_COUNT-1,d7
.loop:
        movea.l (a4)+,a0
        move.l (a4)+,d0
        add.l a5,d0
        move.w (a4)+,(a0)+
        move.l d0,(a0)+
        move.w (a4)+,d6
        adda.w d6,a4
        subq.w #6,d6
        beq.s .next
.pad:   move.w #$4e71,(a0)+
        subq.w #2,d6
        bne.s .pad
.next:  dbra d7,.loop
        rts

custom_select:
        tst.b $5eb76
        bne .legacy
        tst.b $1ca31
        bne .legacy
.divisions:
        lea module_start(pc),a5
        move.w #1,custom_menu-module_start(a5)
        move.b #$80,$5eb75
        moveq #3,d2
        moveq #0,d0
        moveq #28,d1
        jsr $5b840
        lea module_start(pc),a5
        clr.w custom_menu-module_start(a5)
        clr.b $5eb75           ; original text bank before every exit branch
        andi.w #255,d0
        cmpi.w #1,d0
        beq.s .scan
        cmpi.w #2,d0
        beq .editor
        bhi .cancel
        jsr $5fb62
        bra .legacy_result
.editor:
        bsr editor_enter
        bra .divisions
.scan:
        ; Storage uses full-width registers; original menu/drawing code often
        ; replaces only a byte before using a word index. Preserve its context.
        movem.l d1-d7/a0-a6,-(sp)
        bsr storage_catalog_scan
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        bne .error
        clr.w custom_count-module_start(a5)
        lea storage_catalog(pc),a0
        lea custom_slots(pc),a1
        moveq #0,d1
.filter:
        cmpi.w #2,32(a0)
        bne.s .next
        move.w d1,(a1)+
        addq.w #1,custom_count-module_start(a5)
.next:
        adda.w #64,a0
        addq.w #1,d1
        cmpi.w #32,d1
        blo.s .filter
        clr.w custom_page-module_start(a5)
.page:
        move.w #2,custom_menu-module_start(a5)
        move.b #$40,$5eb75
        moveq #3,d2
        moveq #0,d0
        moveq #28,d1
        jsr $5b840
        lea module_start(pc),a5
        clr.w custom_menu-module_start(a5)
        clr.b $5eb75
        andi.w #255,d0
        cmpi.w #3,d0
        beq .divisions
        cmpi.w #2,d0
        beq .next_page
        add.w custom_page(pc),d0
        cmp.w custom_count(pc),d0
        bhs .page
        add.w d0,d0
        lea custom_slots(pc),a0
        move.w (a0,d0.w),storage_slot-module_start(a5)
        movem.l d1-d7/a0-a6,-(sp)
        bsr custom_prepare
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        beq .error
        move.b $1ca33,custom_saved_road-module_start(a5)
        move.b $1ca21,custom_saved_aux-module_start(a5)
        movem.l d0-d7/a0-a6,-(sp)
        bsr custom_save_times
        movem.l (sp)+,d0-d7/a0-a6
        tst.w records_error-module_start(a5)
        beq.s .records_ready
.record_retry:
        move.w #4,custom_menu-module_start(a5)
        moveq #0,d0
        moveq #1,d2
        moveq #28,d1
        jsr $5b840
        lea module_start(pc),a5
        clr.w custom_menu-module_start(a5)
        tst.b d0
        bne.s .records_ready
        movem.l d0-d7/a0-a6,-(sp)
        bsr records_begin
        movem.l (sp)+,d0-d7/a0-a6
        tst.w records_error-module_start(a5)
        bne.s .record_retry
.records_ready:
        move.w #1,custom_active-module_start(a5)
        clr.b $1ca33
        clr.b $1ca22
        move.b #8,$1ca21
        move.b #1,$5eb7d
        jmp $5ba3e
.next_page:
        addq.w #2,custom_page-module_start(a5)
        move.w custom_page(pc),d0
        cmp.w custom_count(pc),d0
        blo .page
        clr.w custom_page-module_start(a5)
        bra .page
.error:
        move.w #3,custom_menu-module_start(a5)
        moveq #1,d2
        moveq #0,d0
        moveq #28,d1
        jsr $5b840
        bra .divisions
.legacy:
        jsr $5fb62
.legacy_result:
        cmpi.b #2,d0
        bhs.s .cancel
        jmp $5ba86
.cancel:
        ; Original $5fb62 consumes this practice re-entry flag at $5fb6c.
        ; Our category Cancel bypasses that routine; leaving it set makes
        ; $5baf2 immediately reopen this selector instead of its parent.
        clr.b $5eb7d
        jmp $5baea

; Reread the selected generation/CRC, validate again, compile privately.
; The unsaved editor model, undo, selection and saved identity remain owned
; by the editor. Storage validators only borrow its model buffer.
custom_prepare:
        clr.w custom_prepared-module_start(a5)
        bsr storage_backup
        bsr storage_identity
        bne .done
        bsr storage_scan
        bne .done
        bsr storage_select
        tst.l d4
        beq .done
        bsr storage_entry
        cmp.l (a3),d4
        bne .done
        move.l 1020(a4),d0
        cmp.l 4(a3),d0
        bne .done
        movea.l a4,a0
        bsr storage_validate
        tst.l d0
        beq .restore
        bsr validate_for_practice
        tst.w d0
        beq .restore
        move.w storage_slot(pc),records_slot-module_start(a5)
        move.l d4,records_project_generation-module_start(a5)
        move.l 1020(a4),records_project_crc-module_start(a5)
        bsr records_key_build
        move.l editor_track+24(pc),custom_geometry_revision-module_start(a5)
        lea practice_runtime(pc),a0
        lea custom_record(pc),a1
        move.b 3(a0),(a1)+
        move.b 5(a0),(a1)+
        move.b 7(a0),(a1)+
        move.b 9(a0),(a1)+
        move.w editor_track+32(pc),d0
        move.b d0,(a1)+
        lsr.w #8,d0
        move.b d0,(a1)+
        move.w 2(a0),d7
        subq.w #1,d7
        adda.w #16,a0
.piece:
        move.b 5(a0),(a1)+
        move.b 4(a0),(a1)+
        move.b 6(a0),(a1)+
        btst #5,5(a0)
        bne.s .one_profile
        move.b 7(a0),d0
        andi.b #127,d0
        move.b d0,(a1)+
.one_profile:
        adda.w #16,a0
        dbra d7,.piece
        move.b #6,(a1)+
        move.b #5,(a1)+
        move.b #34,(a1)+
        move.b #47,(a1)+
        clr.b (a1)+
        movea.l a1,a2
        clr.b (a1)+
        lea practice_runtime+16(pc),a0
        move.w editor_track+28(pc),d7
        subq.w #1,d7
        moveq #0,d6
.exclusions:
        tst.w 14(a0)
        bne.s .safe
        cmpi.b #32,(a2)
        bhs .restore
        move.b d6,(a1)+
        addq.b #1,(a2)
.safe:
        addq.w #1,d6
        adda.w #16,a0
        dbra d7,.exclusions
        lea editor_track+40(pc),a0
        lea custom_track_name(pc),a1
        moveq #24,d0
        bsr storage_copy
        ; Retain the validated track description.
        lea practice_runtime(pc),a0
        lea custom_runtime(pc),a1
        move.w #1040,d0
        bsr storage_copy
        move.w #1,custom_prepared-module_start(a5)
.restore:
        bsr storage_restore
.done:
        bsr editor_model_view
        move.w custom_prepared(pc),d0
        rts

custom_menu_row:
        tst.b title_menu_active(pc)
        beq.s .custom
        cmpi.b #3,$1bb18
        bne .original
        movem.l d0-d7/a0-a6,-(sp)
        lea title_editor_label(pc),a0
        bra .text
.custom:
        tst.w custom_menu(pc)
        beq .original
        movem.l d0-d7/a0-a6,-(sp)
        moveq #0,d0
        move.b $1bb18,d0
        cmpi.w #1,custom_menu(pc)
        beq.s .division
        cmpi.w #4,custom_menu(pc)
        beq.s .record_error
        cmpi.w #3,custom_menu(pc)
        beq .error
        cmpi.w #3,d0
        beq.s .cancel
        cmpi.w #2,d0
        beq.s .next
        add.w custom_page(pc),d0
        cmp.w custom_count(pc),d0
        bhs.s .empty
        add.w d0,d0
        lea custom_slots(pc),a0
        move.w (a0,d0.w),d0
        lsl.w #6,d0
        lea storage_catalog+8(pc),a0
        adda.w d0,a0
        bra.s .text
.division:
        lea custom_division_names(pc),a0
        lsl.w #4,d0
        adda.w d0,a0
        bra.s .text
.record_error:
        lea records_retry_text(pc),a0
        tst.w d0
        beq.s .text
        lea records_continue_text(pc),a0
        bra.s .text
.error:
        lea custom_error_text(pc),a0
        tst.w d0
        beq.s .text
.cancel:lea custom_cancel_text(pc),a0
        bra.s .text
.next:  lea custom_next_text(pc),a0
        bra.s .text
.empty: lea custom_empty_text(pc),a0
.text:  bsr custom_print
        movem.l (sp)+,d0-d7/a0-a6
        rts
.original: jmp $5a656
custom_menu_name:
        tst.w custom_menu(pc)
        bne.s .skip
        cmpi.b #28,d0
        beq.s .name
.skip:  jmp $5b888
.name:  jmp $5b932

custom_menu_enter:
        movem.l d0-d7/a0-a6,-(sp)
        lea module_start(pc),a5
        clr.w custom_menu-module_start(a5)
        clr.b $5eb75           ; cancel must not leak division text bank
        tst.w custom_active-module_start(a5)
        beq .done
.save_records:
        bsr records_commit
        tst.w d0
        beq.s .saved
        move.w #4,custom_menu-module_start(a5)
        moveq #0,d0
        moveq #1,d2
        moveq #28,d1
        jsr $5b840
        lea module_start(pc),a5
        clr.w custom_menu-module_start(a5)
        tst.b d0
        beq.s .save_records
        clr.w records_dirty-module_start(a5)
.saved:
        lea custom_original_times(pc),a0
        moveq #-1,d0
        bsr custom_transfer_times
        move.b custom_saved_road(pc),$1ca33
        move.b custom_saved_aux(pc),$1ca21
        clr.w custom_active-module_start(a5)
.done:
        movem.l (sp)+,d0-d7/a0-a6
        move.b #0,$5b83d
        jmp $5baf2

custom_load:
        tst.w custom_active(pc)
        beq.s .original
        ; No I/O or fallible work after this point: immutable checked record.
        movem.l d0/a0-a1,-(sp)
        lea custom_bridge_profile(pc),a0
        lea $1f785.l,a1
        moveq #71,d0
.copy:  move.b (a0)+,(a1)+
        dbra d0,.copy
        move.l custom_geometry_revision(pc),d0
        cmpi.l #3,d0
        bhs.s .original_profiles
        bsr custom_set_bank
        bra.s .profiles_ready
.original_profiles:
        bsr custom_restore_bank
.profiles_ready:
        movem.l (sp)+,d0/a0-a1
        lea custom_record(pc),a5
        ; The original parser clears only D1.b before indexing with D1.w.
        ; Storage I/O may leave a sector number in its upper byte.
        moveq #0,d1
        jmp $5ae74
.original:
        bsr custom_restore_bank
        move.b d1,d0
        asl.b #1,d0
        move.b d0,d2
        jmp $5ae4c
custom_name:
        tst.w custom_active(pc)
        beq.s .original
        movem.l d0-d7/a0-a6,-(sp)
        lea custom_track_name(pc),a0
        bsr custom_print
        movem.l (sp)+,d0-d7/a0-a6
        rts
.original:
        movea.l #$1edaa,a0
        jmp $64c44
custom_parameters:
        tst.w custom_active(pc)
        beq.s .original
        clr.w d1                       ; original $63ab0 caller contract
        move.b $1ca2a,d2
        tst.b $1c9d0
        beq.s .normal
        move.b $1ca2b,d2
.normal:
        move.b d2,$63ce2
        clr.b $63ce0
        clr.b $63ce1
        rts
.original: jmp $63a8e
custom_visibility:
        tst.w custom_active(pc)
        beq.s .original
        lea $65e70.l,a0
        ; Downstream geometry routines replace only D3.b and index D3.w.
        ; Original visibility setup leaves its upper byte zero.
        moveq #0,d3
        rts
.original:
        clr.w d3
        movea.l #$65e70,a0
        jmp $65df2
custom_visibility_limit:
        movea.l #$65e70,a0
        tst.w custom_active(pc)
        beq.s .original
        cmpi.b #$78,d1
        rts
.original:
        cmp.b (a0,d2.w),d1
        rts

; Session cache; disk writes are deferred until return to menus.
custom_records:
        tst.w custom_active(pc)
        beq.s .original
        movem.l d0-d7/a0-a6,-(sp)
        lea module_start(pc),a5
        move.w d0,-(sp)
        lea custom_session_times(pc),a0
        bsr custom_transfer_times
        move.w (sp)+,d0
        tst.b d0
        bmi.s .read_only
        bsr records_changed
.read_only:
        movem.l (sp)+,d0-d7/a0-a6
        rts
.original:
        move.b d0,$1bb1b
        jmp $5f260
custom_save_times:
        lea custom_original_times(pc),a0
        moveq #0,d0
        bsr custom_transfer_times
        lea custom_session_times(pc),a0
        moveq #31,d0
.clear: clr.b (a0)+
        dbra d0,.clear
        lea custom_session_times(pc),a0
        moveq #11,d0
.names: move.b #'-',16(a0)
        move.b #'-',(a0)+
        dbra d0,.names
        move.b #9,(a0)
        move.b #9,16(a0)
        bra records_begin
custom_times_load:
        tst.w custom_active(pc)
        beq.s .original
        movem.l d0-d7/a0-a6,-(sp)
        moveq #-1,d0
        bsr custom_records
        movem.l (sp)+,d0-d7/a0-a6
.original: jmp $64304
custom_lap:
        tst.w custom_active(pc)
        beq.s .original
        move.w ccr,-(sp)
        movem.l d0-d7/a0-a6,-(sp)
        moveq #0,d1
        moveq #14,d2
        jsr $5dc38
        bcs.s .done
        moveq #0,d1
        move.w #$c9,d2
        jsr $5f21e
        moveq #0,d0
        bsr custom_records
.done:  movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,ccr
        rts
.original: jmp $5f16c

custom_transfer_times:
        lea $5ec48.l,a1
        lea $5ec55.l,a2
        tst.b d0
        bmi.s .read
        moveq #11,d7
.write_names:
        move.b (a1)+,(a0)+
        move.b (a2)+,15(a0)
        dbra d7,.write_names
        move.b $1c916,(a0)
        move.b $1c92e,1(a0)
        move.b $1c946,2(a0)
        move.b $1c917,16(a0)
        move.b $1c92f,17(a0)
        move.b $1c947,18(a0)
        bra.s .done
.read:
        moveq #11,d7
.read_names:
        move.b 16(a0),(a2)+
        move.b (a0)+,(a1)+
        dbra d7,.read_names
        move.b (a0),$1c916
        move.b 1(a0),$1c92e
        move.b 2(a0),$1c946
        move.b 16(a0),$1c917
        move.b 17(a0),$1c92f
        move.b 18(a0),$1c947
.done:  rts


custom_print:
        moveq #23,d5
.loop:  move.b (a0)+,d0
        beq.s .done
        movem.l d5/a0,-(sp)
        jsr $594c6
        movem.l (sp)+,d5/a0
        dbra d5,.loop
.done:  rts
custom_division_names:
        dc.b 'Original Tracks',0
        dc.b 'Custom Tracks',0,0,0
        dc.b 'Track Editor',0,0,0,0
        dc.b 'Cancel',0,0,0,0,0,0,0,0,0,0
custom_cancel_text: dc.b 'Cancel',0
custom_next_text: dc.b 'Next page',0
custom_empty_text: dc.b 'No ready track',0
custom_error_text: dc.b 'Track unavailable',0
        even
custom_menu: dc.w 0
custom_count: dc.w 0
custom_page: dc.w 0
custom_prepared: dc.w 0
custom_active: dc.w 0
custom_saved_road: dc.b 0
custom_saved_aux: dc.b 0
custom_slots: dcb.w 32,0
custom_original_times: dcb.b 32,0
custom_session_times: dcb.b 32,0
custom_track_name: dcb.b 24,0
        dc.b 0,0
custom_geometry_revision: dc.l 0
custom_record: dcb.b 332,0
custom_runtime: dcb.b 1040,0
custom_bridge_profile:
        include "bridge-data.s"
custom_hooks:
        include "custom-hooks.s"

custom_set_bank:
        movem.l d0/a0-a1,-(sp)
        lea custom_bank_profile(pc),a0
        bra.s custom_copy_bank
custom_restore_bank:
        movem.l d0/a0-a1,-(sp)
        lea custom_original_bank(pc),a0
custom_copy_bank:
        lea $1f49f.l,a1
        moveq #9,d0
.copy:  move.b (a0)+,(a1)+
        dbra d0,.copy
        movem.l (sp)+,d0/a0-a1
        rts
custom_bank_profile:
        include "bank-data.s"
custom_original_bank:
        include "original-bank.s"

records_retry_text: dc.b 'Records error: Retry',0
records_continue_text: dc.b 'Use session times only',0
        even
        include "src/editor/records.s"
