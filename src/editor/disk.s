; Import and export editor tracks using the DF1 track disk.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; DF1-only external project transport. No OS calls, no DF0 fallback.
DISK_CATALOG_BACKUP equ $50000
DISK_TRACK_BACKUP equ $50800
DISK_HEADER equ $50b00
DISK_CANDIDATE equ $50d00

; External drive ID is shifted on select edges with the motor off.
; FS-UAE DRIVE_ID_35DD=$ffffffff, NONE=0, independent of inserted media.
disk_detect:
        movem.l d0-d2,-(sp)
        move.w sr,-(sp)
        ori.w #$0700,sr
        moveq #0,d1
        moveq #31,d2
.loop:
        move.b #$ff,$bfd100
        move.b #$ef,$bfd100
        lsl.l #1,d1
        btst #5,$bfe001
        bne.s .next
        addq.l #1,d1
.next:
        dbra d2,.loop
        move.b #$ff,$bfd100
        clr.w disk_available-module_start(a5)
        cmpi.l #-1,d1
        bne.s .done
        move.w #1,disk_available-module_start(a5)
.done:
        move.w (sp)+,sr
        movem.l (sp)+,d0-d2
        rts

; Return CIA status for DF1, motor off; always deselect afterwards.
disk_status:
        move.b #$ff,$bfd100
        move.b #$ef,$bfd100
        moveq #0,d0
        move.b $bfe001,d0
        move.b #$ff,$bfd100
        rts

disk_write_guard:
        bsr disk_status
        btst #2,d0
        beq.s .changed
        btst #3,d0
        beq.s .protected
        moveq #0,d0
        rts
.changed:
        moveq #29,d0
        rts
.protected:
        moveq #28,d0
        rts

; Scoped raw I/O. Caller supplies D1 sector, D2 count, D3 direction.
disk_io:
        move.w #1,disk_io_active-module_start(a5)
        bsr storage_io
        clr.w disk_io_active-module_start(a5)
        tst.l d0
        rts

disk_read_header:
        moveq #0,d1
        moveq #1,d2
        moveq #0,d3
        bra disk_io

; Storage core identity hook: exact reviewed header + current media latch.
disk_identity:
        movem.l d1-d3/a0-a1,-(sp)
        bsr disk_status
        btst #2,d0
        beq.s .bad
        moveq #0,d1
        moveq #1,d2
        moveq #0,d3
        bsr storage_io
        bne.s .bad
        movea.l 28(a5),a0
        adda.l #16384,a0
        lea DISK_HEADER(a5),a1
        moveq #127,d1
.compare:
        cmpm.l (a0)+,(a1)+
        bne.s .bad
        dbra d1,.compare
        moveq #0,d0
        bra.s .done
.bad:
        moveq #1,d0
.done:
        movem.l (sp)+,d1-d3/a0-a1
        tst.l d0
        rts

disk_open:
        bsr disk_detect
        tst.w disk_available-module_start(a5)
        beq .done
        tst.w storage_continue-module_start(a5)
        bne .done               ; dirty-action Save must persist to DF0
        move.w storage_modal(pc),disk_mode-module_start(a5)
        move.w storage_slot(pc),disk_game_slot-module_start(a5)
        move.w storage_page(pc),disk_game_page-module_start(a5)
        move.l storage_generation(pc),disk_game_generation-module_start(a5)
        lea storage_catalog(pc),a0
        lea DISK_CATALOG_BACKUP(a5),a1
        move.w #2048,d0
        bsr storage_copy
        move.w #5,storage_modal-module_start(a5)
        clr.w disk_error-module_start(a5)
        clr.w storage_status-module_start(a5)
.done:  rts

disk_cancel:
        bsr editor_release
        move.w disk_mode(pc),storage_modal-module_start(a5)
        bsr disk_restore_context
        rts

disk_restore_context:
        clr.w editor_view_valid-module_start(a5)
        lea DISK_CATALOG_BACKUP(a5),a0
        lea storage_catalog(pc),a1
        move.w #2048,d0
        bsr storage_copy
        move.w disk_game_slot(pc),storage_slot-module_start(a5)
        move.w disk_game_page(pc),storage_page-module_start(a5)
        move.l disk_game_generation(pc),storage_generation-module_start(a5)
        clr.w disk_mode-module_start(a5)
        clr.w disk_io_active-module_start(a5)
        clr.w disk_error-module_start(a5)
        rts

disk_complete:
        bsr disk_restore_context
        clr.w storage_modal-module_start(a5)
        rts

; Dialog 5 insert/retry, 6 initialize confirmation, 7 progress, 9 replace.
disk_modal_keys:
        cmpi.b #$b3,editor_input_keys+$45(a5)
        beq disk_cancel
        cmpi.w #6,storage_modal-module_start(a5)
        beq.s .choice
        cmpi.w #9,storage_modal-module_start(a5)
        bne.s .confirm
.choice:
        move.w editor_directions(pc),d0
        beq.s .confirm
        eori.w #1,disk_choice-module_start(a5)
        bra editor_release
.confirm:
        cmpi.b #$b3,editor_input_keys+$44(a5)
        beq.s .go
        cmpi.b #$b3,editor_input_keys+$40(a5)
        beq.s .go
        btst #4,editor_input_keys+96(a5)
        beq.s .done
.go:
        bsr editor_release
        cmpi.w #5,storage_modal-module_start(a5)
        beq disk_probe
        tst.w disk_choice-module_start(a5)
        beq disk_cancel
        cmpi.w #9,storage_modal-module_start(a5)
        beq disk_save
        bra disk_initialize_begin
.done:  rts

; Review media without writes. A failed read is never an empty disk.
disk_probe:
        clr.w disk_error-module_start(a5)
        bsr disk_detect
        tst.w disk_available-module_start(a5)
        beq disk_unavailable
        ; A step acknowledges media change; an empty drive keeps CHNG low.
        ; Select DF1 only, direction away from cylinder zero, motor off.
        bsr disk_status
        btst #2,d0
        bne.s .latched
        move.b #$ed,$bfd100
        move.b #$ec,$bfd100
        move.b #$ed,$bfd100
        move.b #$ff,$bfd100
.latched:
        ; Force the original driver's DF1 cylinder cache to recalibrate.
        move.w #-1,$63686
        bsr disk_read_header
        bne disk_io_failed
        movea.l 28(a5),a0
        adda.l #16384,a0
        lea DISK_HEADER(a5),a1
        move.w #512,d0
        bsr storage_copy
        lea DISK_HEADER(a5),a0
        cmpi.l #$53435444,(a0)   ; SCTD
        beq .known
        cmpi.l #$53435449,(a0)   ; SCTI interrupted initialization
        beq .unfinished
        cmpi.w #2,disk_mode-module_start(a5)
        beq disk_wrong
        ; Reject known SCR boot code as well as editor game identity.
        cmpi.l #$24494ffa,12(a0)
        bne.s .game_identity
        cmpi.l #$03f02c78,16(a0)
        bne.s .game_identity
        cmpi.l #$00044eae,20(a0)
        beq disk_wrong
.game_identity:
        move.w #1200,d1
        moveq #1,d2
        moveq #0,d3
        bsr disk_io
        bne disk_io_failed
        movea.l 28(a5),a0
        cmpi.l #$53434945,16384(a0)
        beq disk_wrong
        bra.s .offer
.unfinished:
        cmpi.w #2,disk_mode-module_start(a5)
        beq disk_wrong
        bra.s .known
.offer:
        bsr disk_write_guard
        bne disk_io_failed
        clr.w disk_choice-module_start(a5)
        move.w #6,storage_modal-module_start(a5)
        rts
.known:
        cmpi.l #$00020010,4(a0)
        bne disk_wrong
        cmpi.l #1760,8(a0)
        bne disk_wrong
        cmpi.l #32,12(a0)
        bne disk_wrong
        lea 32(a0),a1
        move.w #118,d1
.padding:
        tst.l (a1)+
        bne disk_wrong
        dbra d1,.padding
        move.w #508,d0
        bsr storage_crc
        cmp.l DISK_HEADER+508(a5),d0
        bne disk_wrong
        cmpi.l #$53435449,DISK_HEADER(a5)
        beq .offer
        move.w #1,disk_io_active-module_start(a5)
        bsr storage_catalog_scan
        clr.w disk_io_active-module_start(a5)
        tst.w d0
        bne disk_wrong
        clr.w storage_slot-module_start(a5)
        clr.w storage_page-module_start(a5)
        cmpi.w #2,disk_mode-module_start(a5)
        beq.s .load
        bsr disk_write_guard
        bne disk_io_failed
        bra storage_begin_name
.load:
        move.w #2,storage_modal-module_start(a5)
        lea storage_catalog+32(pc),a0
        moveq #31,d0
.nonempty:
        tst.w (a0)
        bne.s .loaded_list
        adda.w #64,a0
        dbra d0,.nonempty
        move.w #10,storage_status-module_start(a5)
.loaded_list:
        rts

disk_unavailable:
        moveq #3,d0
        bra.s disk_error_dialog
disk_wrong:
        moveq #2,d0
        bra.s disk_error_dialog
disk_io_failed:
        moveq #1,d1
        cmpi.l #28,d0
        bne.s .set
        moveq #4,d1
.set:   move.w d1,d0
disk_error_dialog:
        move.w d0,disk_error-module_start(a5)
        move.w #5,storage_modal-module_start(a5)
        clr.w disk_io_active-module_start(a5)
        rts

; Snapshot full header used to review format consent, then verify again.
disk_initialize_begin:
        move.w #1,disk_io_active-module_start(a5)
        bsr disk_identity
        clr.w disk_io_active-module_start(a5)
        tst.l d0
        bne disk_wrong
        bsr disk_write_guard
        bne disk_io_failed
        lea DISK_CANDIDATE(a5),a0
        moveq #127,d0
.zero:
        clr.l (a0)+
        dbra d0,.zero
        lea DISK_CANDIDATE(a5),a0
        move.l #$53435449,(a0)
        move.l #$00020010,4(a0)
        move.l #1760,8(a0)
        move.l #32,12(a0)
        ; Session/cycle material identifies this media, never a security token.
        move.l editor_ticks(pc),16(a0)
        move.l $dff004,20(a0)
        move.l a5,24(a0)
        move.l disk_serial(pc),28(a0)
        addq.l #1,disk_serial-module_start(a5)
        move.w #508,d0
        bsr storage_crc
        move.l d0,DISK_CANDIDATE+508(a5)
        moveq #0,d1
        lea DISK_CANDIDATE(a5),a0
        bsr disk_write_sector
        bne disk_io_failed
        lea DISK_CANDIDATE(a5),a0
        lea DISK_HEADER(a5),a1
        move.w #512,d0
        bsr storage_copy
        move.w #1,disk_progress-module_start(a5)
        move.w #7,storage_modal-module_start(a5)
        rts

; One physical track at a time, with interrupts restored between calls.
; Sector zero remains an invalid SCTI marker until the entire disk is clean.
disk_initialize_step:
        bsr disk_write_guard
        bne disk_io_failed
        move.w disk_progress(pc),d1
        cmpi.w #1760,d1
        bhs .finish
        moveq #11,d2
        tst.w d1
        bne.s .not_zero
        moveq #1,d2
.not_zero:
        cmpi.w #1,d1
        bne.s .count
        moveq #10,d2
.count:
        movea.l 28(a5),a0
        adda.l #16384,a0
        move.w d2,d0
        lsl.w #7,d0
        subq.w #1,d0
.zero:
        clr.l (a0)+
        dbra d0,.zero
        moveq #1,d3
        bsr disk_io
        bne disk_io_failed
        movea.l 28(a5),a0
        adda.l #16384,a0
        move.w d2,d0
        lsl.w #7,d0
        subq.w #1,d0
.poison:
        move.l #$a55aa55a,(a0)+
        dbra d0,.poison
        moveq #0,d3
        bsr disk_io
        bne disk_io_failed
        movea.l 28(a5),a0
        adda.l #16384,a0
        move.w d2,d0
        lsl.w #7,d0
        subq.w #1,d0
.verify:
        tst.l (a0)+
        bne disk_wrong
        dbra d0,.verify
        add.w d2,disk_progress-module_start(a5)
        rts
.finish:
        move.w #1,disk_io_active-module_start(a5)
        bsr disk_identity
        clr.w disk_io_active-module_start(a5)
        tst.l d0
        bne disk_wrong
        lea DISK_HEADER(a5),a0
        lea DISK_CANDIDATE(a5),a1
        move.w #512,d0
        bsr storage_copy
        lea DISK_CANDIDATE(a5),a0
        move.l #$53435444,(a0)
        move.w #508,d0
        bsr storage_crc
        move.l d0,DISK_CANDIDATE+508(a5)
        lea DISK_CANDIDATE(a5),a0
        moveq #0,d1
        bsr disk_write_sector
        bne disk_io_failed
        bra disk_probe

; Write one sector and compare a fresh read. D1 retained by storage_io.
disk_write_sector:
        movea.l 28(a5),a1
        adda.l #16384,a1
        move.w #512,d0
        bsr storage_copy
        moveq #1,d2
        moveq #1,d3
        bsr disk_io
        bne.s .done
        movea.l 28(a5),a0
        adda.l #16384,a0
        moveq #127,d0
.poison:
        move.l #$a55aa55a,(a0)+
        dbra d0,.poison
        moveq #0,d3
        bsr disk_io
        bne.s .done
        lea DISK_CANDIDATE(a5),a0
        movea.l 28(a5),a1
        adda.l #16384,a1
        moveq #127,d1
.compare:
        cmpm.l (a0)+,(a1)+
        bne.s .bad
        dbra d1,.compare
        moveq #0,d0
        rts
.bad:   moveq #-1,d0
.done:  rts

disk_name_commit:
        bsr editor_release
        lea storage_name(pc),a0
        moveq #23,d1
.uppercase:
        move.b (a0),d0
        cmpi.b #97,d0
        blo.s .next_case
        cmpi.b #122,d0
        bhi.s .next_case
        subi.b #32,(a0)
.next_case:
        addq.l #1,a0
        dbra d1,.uppercase
        ; Trim trailing spaces and reject an all-space name.
        move.w storage_name_length(pc),d0
        lea storage_name(pc),a0
.trim:
        tst.w d0
        beq .done
        cmpi.b #32,-1(a0,d0.w)
        bne.s .ready
        subq.w #1,d0
        clr.b (a0,d0.w)
        bra.s .trim
.ready:
        move.w d0,storage_name_length-module_start(a5)
        move.w #-1,disk_free_slot-module_start(a5)
        move.w #-1,disk_match_slot-module_start(a5)
        clr.w storage_slot-module_start(a5)
.find:
        bsr storage_entry
        tst.w 32(a3)
        beq.s .empty
        cmpi.w #3,32(a3)
        beq.s .next
        lea 8(a3),a0
        lea storage_name(pc),a1
        moveq #23,d1
.compare:
        move.b (a0)+,d0
        cmpi.b #97,d0
        blo.s .upper
        cmpi.b #122,d0
        bhi.s .upper
        subi.b #32,d0
.upper:
        cmp.b (a1)+,d0
        bne.s .next
        dbra d1,.compare
        move.w storage_slot(pc),disk_match_slot-module_start(a5)
        bra.s .found
.empty:
        tst.w disk_free_slot-module_start(a5)
        bpl.s .next
        move.w storage_slot(pc),disk_free_slot-module_start(a5)
.next:
        addq.w #1,storage_slot-module_start(a5)
        cmpi.w #32,storage_slot-module_start(a5)
        blo .find
.found:
        move.w disk_match_slot(pc),d0
        bmi.s .new
        move.w d0,storage_slot-module_start(a5)
        clr.w disk_choice-module_start(a5)
        move.w #9,storage_modal-module_start(a5)
        rts
.new:
        move.w disk_free_slot(pc),d0
        bmi.s .full
        move.w d0,storage_slot-module_start(a5)
        bra disk_save
.full:
        clr.w storage_slot-module_start(a5)
        move.w #9,storage_status-module_start(a5)
.done:  rts

disk_save:
        lea editor_track(pc),a0
        lea DISK_TRACK_BACKUP(a5),a1
        move.w #580,d0
        bsr storage_copy
        lea storage_name(pc),a0
        lea editor_track+40(pc),a1
        moveq #24,d0
        bsr storage_copy
        bsr editor_model_refresh
        move.w #1,disk_io_active-module_start(a5)
        bsr editor_save
        clr.w disk_io_active-module_start(a5)
        lea DISK_TRACK_BACKUP(a5),a0
        lea editor_track(pc),a1
        move.w #580,d0
        bsr storage_copy
        bsr editor_model_view
        cmpi.w #1,storage_status-module_start(a5)
        beq disk_complete
        cmpi.w #7,storage_status-module_start(a5)
        beq disk_complete
        move.l storage_io_error(pc),d0
        bra disk_io_failed

disk_load:
        move.w #1,disk_io_active-module_start(a5)
        bsr editor_load
        clr.w disk_io_active-module_start(a5)
        cmpi.w #2,storage_status-module_start(a5)
        beq disk_complete
        rts

; One button below the 16 slots. Disabled without DF1 or during dirty Save.
disk_button_text:
        tst.w disk_mode-module_start(a5)
        bne.s .done
        lea disk_button(pc),a0
        tst.w disk_available-module_start(a5)
        beq.s .disabled
        tst.w storage_continue-module_start(a5)
        beq.s .selectable
        lea disk_button_save_first(pc),a0
        bra.s .draw
.selectable:
        cmpi.w #32,storage_slot-module_start(a5)
        bne.s .draw
        lea disk_button_selected(pc),a0
        bra.s .draw
.disabled:
        lea disk_button_disabled(pc),a0
.draw:
        movea.l draw_surface(pc),a1
        adda.w #6082,a1
        bsr storage_text_line
        tst.w disk_available-module_start(a5)
        beq.s .gray
        tst.w storage_continue-module_start(a5)
        beq.s .done
.gray:
        movea.l draw_surface(pc),a0
        adda.w #6082,a0
        moveq #6,d1
.gray_row:
        moveq #35,d0
.gray_byte:
        clr.b 16000(a0)
        clr.b 24000(a0)
        addq.l #1,a0
        dbra d0,.gray_byte
        addq.l #4,a0
        dbra d1,.gray_row
.done:  rts

disk_modal_text:
        movea.l draw_surface(pc),a0
        move.w #7999,d0
.clear:
        clr.l (a0)+
        dbra d0,.clear
        lea disk_insert(pc),a0
        cmpi.w #6,storage_modal-module_start(a5)
        bne.s .progress
        lea disk_initialize_title(pc),a0
.progress:
        cmpi.w #7,storage_modal-module_start(a5)
        bne.s .replace
        lea disk_progress_title(pc),a0
.replace:
        cmpi.w #9,storage_modal-module_start(a5)
        bne.s .title
        lea disk_replace_title(pc),a0
.title:
        movea.l draw_surface(pc),a1
        adda.w #962,a1
        bsr storage_text_line
        lea disk_retry(pc),a0
        cmpi.w #6,storage_modal-module_start(a5)
        beq.s .choice
        cmpi.w #9,storage_modal-module_start(a5)
        bne.s .progress_help
.choice:
        lea disk_cancel_choice(pc),a0
        cmpi.w #9,storage_modal-module_start(a5)
        bne.s .selection
        lea disk_cancel_replace(pc),a0
.selection:
        tst.w disk_choice-module_start(a5)
        beq.s .help
        lea disk_erase_choice(pc),a0
        cmpi.w #9,storage_modal-module_start(a5)
        bne.s .help
        lea disk_replace_choice(pc),a0
        bra.s .help
.progress_help:
        cmpi.w #7,storage_modal-module_start(a5)
        bne.s .help
        lea disk_wait(pc),a0
.help:
        movea.l draw_surface(pc),a1
        adda.w #4162,a1
        bsr storage_text_line
        cmpi.w #6,storage_modal-module_start(a5)
        beq.s .choice_help
        cmpi.w #9,storage_modal-module_start(a5)
        bne.s .detail_select
.choice_help:
        lea disk_choice_help(pc),a0
        movea.l draw_surface(pc),a1
        adda.w #4802,a1
        bsr storage_text_line
.detail_select:
        cmpi.w #6,storage_modal-module_start(a5)
        bne.s .name
        lea disk_erase_warning(pc),a0
        bra.s .detail
.name:
        cmpi.w #9,storage_modal-module_start(a5)
        bne.s .error
        lea storage_name(pc),a0
.detail:
        movea.l draw_surface(pc),a1
        adda.w #2242,a1
        bsr storage_text_line
.error:
        cmpi.w #7,storage_modal-module_start(a5)
        bne.s .error_text
        moveq #0,d0
        move.w disk_progress(pc),d0
        mulu.w #100,d0
        divu.w #1760,d0
        andi.l #$ffff,d0
        divu.w #10,d0
        lea storage_line(pc),a0
        addi.b #48,d0
        move.b d0,(a0)
        swap d0
        addi.b #48,d0
        move.b d0,1(a0)
        move.b #32,2(a0)
        move.b #47,3(a0)
        move.l #$20313030,4(a0)
        clr.b 8(a0)
        movea.l draw_surface(pc),a1
        adda.w #2882,a1
        bsr storage_text_line
.error_text:
        move.w disk_error(pc),d0
        lsl.w #5,d0
        lea disk_errors(pc),a0
        adda.w d0,a0
        movea.l draw_surface(pc),a1
        adda.w #6402,a1
        bra storage_text_line

disk_save_title: dc.b 'SAVE TO DF1 - ENTER TRACK NAME',0
disk_load_title: dc.b 'LOAD FROM DF1 - SELECT TRACK',0
disk_button: dc.b '  DISK...',0
disk_button_selected: dc.b '> DISK...',0
disk_button_disabled: dc.b '  DISK... (DF1 NOT AVAILABLE)',0
disk_button_save_first: dc.b '  DISK... (SAVE TO GAME FIRST)',0
disk_insert: dc.b 'INSERT TRACK DISK IN DF1',0
disk_initialize_title: dc.b 'INITIALIZE TRACK DISK IN DF1?',0
disk_erase_warning: dc.b 'ALL DATA ON THIS DISK WILL BE ERASED.',0
disk_progress_title: dc.b 'INITIALIZING TRACK DISK IN DF1',0
disk_replace_title: dc.b 'REPLACE TRACK ON DF1?',0
disk_retry: dc.b 'FIRE/ENTER CONTINUE   ESC CANCEL',0
disk_cancel_choice: dc.b '> CANCEL    ERASE AND INITIALIZE',0
disk_cancel_replace: dc.b '> CANCEL    REPLACE',0
disk_choice_help: dc.b 'JOY SELECT  FIRE/ENTER OK  ESC CANCEL',0
disk_erase_choice: dc.b '  CANCEL  > ERASE AND INITIALIZE',0
disk_replace_choice: dc.b '  CANCEL  > REPLACE',0
disk_wait: dc.b 'PLEASE WAIT - DO NOT REMOVE DISK',0
        even
disk_errors:
        dcb.b 32,0
        dc.b 'DISK I/O ERROR - RETRY',0
        dcb.b 10,0
        dc.b 'WRONG OR DAMAGED DISK',0
        dcb.b 11,0
        dc.b 'DF1 NOT AVAILABLE',0
        dcb.b 14,0
        dc.b 'DISK IS WRITE PROTECTED',0
        dcb.b 9,0
        even
disk_serial: dc.l 1
