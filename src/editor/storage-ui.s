; Handle track save and load menus, slot selection and names.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Fixed slot allocation, records authoritative; directory is a rebuildable
; index. A committed, read-back record is visible even if index writing fails.
; Cache entries (64 bytes): generation, envelope CRC, name[24], class.w,
; reserved.w, uid[16], reserved[12]. class: 0 empty, 1 Draft, 2 Ready, 3 invalid.
storage_entry:
        move.w storage_slot(pc),d0
        lsl.w #6,d0
        lea storage_catalog(pc),a3
        adda.w d0,a3
        rts
storage_update_entry:
        clr.w editor_view_valid-module_start(a5)
        bsr storage_entry
        move.l 8(a4),(a3)
        move.l 1020(a4),4(a3)
        lea 72(a4),a0
        lea 8(a3),a1
        moveq #24,d0
        bsr storage_copy
        lea 40(a4),a0
        lea 36(a3),a1
        moveq #16,d0
        bsr storage_copy
        ; Recheck the selected record, not the last record examined by scan.
        movea.l a4,a0
        bsr storage_validate
        move.w #1,32(a3)
        cmpi.w #2,practice_class-module_start(a5)
        bne.s .done
        move.w #2,32(a3)
.done:
        bra storage_restore

storage_catalog_scan:
        clr.w editor_view_valid-module_start(a5)
        bsr storage_backup
        bsr storage_identity
        bne .wrong
        lea storage_catalog(pc),a0
        move.w #511,d0
.clear:
        clr.l (a0)+
        dbra d0,.clear
        move.w storage_slot(pc),-(sp)
        clr.w storage_slot-module_start(a5)
.loop:
        bsr storage_scan
        move.w d0,d5
        bsr storage_entry
        tst.w d5
        beq.s .valid
        move.w #3,32(a3)
        bra.s .next
.valid:
        bsr storage_select
        tst.l d4
        beq.s .next
        bsr storage_update_entry
.next:
        addq.w #1,storage_slot-module_start(a5)
        cmpi.w #32,storage_slot-module_start(a5)
        blo.s .loop
        move.w (sp)+,storage_slot-module_start(a5)
        bsr storage_directory_pack
        bsr storage_directories_check
        bsr editor_model_view
        moveq #0,d0
        rts
.wrong:
        move.w #5,storage_status-module_start(a5)
        moveq #1,d0
        rts

; Directory: SCED, version=2, header=32, slots=32, stride=4, reserved;
; entries: generation/record CRC/name. All other bytes zero. CRC at 1532.
; No persisted Ready bit: it is always recomputed by the shared validator.
storage_directory_pack:
        lea storage_pending(pc),a0
        move.w #383,d0
.clear:
        clr.l (a0)+
        dbra d0,.clear
        lea storage_pending(pc),a0
        move.l #$53434544,(a0)
        move.l #$00020020,4(a0)
        move.l #$00200004,8(a0)
        lea 32(a0),a1
        lea storage_catalog(pc),a0
        moveq #31,d4
.entry:
        moveq #7,d0
.copy:
        move.l (a0)+,(a1)+
        dbra d0,.copy
        adda.w #32,a0
        dbra d4,.entry
        lea storage_pending(pc),a0
        move.w #1532,d0
        bsr storage_crc
        move.l d0,storage_pending+1532-module_start(a5)
        rts
storage_directories_check:
        move.w #1474,d1
        bsr .check
        move.w #1485,d1
.check:
        moveq #3,d2
        moveq #0,d3
        bsr storage_io
        bne.s .recover
        movea.l 28(a5),a0
        lea 16384(a0),a0
        lea storage_pending(pc),a1
        move.w #383,d0
.compare:
        cmpm.l (a0)+,(a1)+
        bne.s .recover
        dbra d0,.compare
        rts
.recover:
        move.w #8,storage_status-module_start(a5)
        rts
storage_directories_write:
        bsr storage_directory_pack
        move.w #1474,d1
        bsr .write
        move.w #1485,d1
.write:
        lea storage_pending(pc),a0
        movea.l 28(a5),a1
        lea 16384(a1),a1
        move.w #1536,d0
        bsr storage_copy
        moveq #3,d2
        moveq #1,d3
        bsr storage_io
        bne.s .failed
        movea.l 28(a5),a0
        lea 16384(a0),a0
        move.w #383,d0
.poison:
        move.l #$a55aa55a,(a0)+
        dbra d0,.poison
        moveq #0,d3
        bsr storage_io
        bne.s .failed
        movea.l 28(a5),a0
        lea 16384(a0),a0
        lea storage_pending(pc),a1
        move.w #383,d0
.compare:
        cmpm.l (a0)+,(a1)+
        bne.s .failed
        dbra d0,.compare
        rts
.failed:
        move.w #7,storage_status-module_start(a5)
        rts

; Modal: 1 save list, 2 load list, 3 name, 4 overwrite.
storage_open_save:
        moveq #1,d6
        bra.s storage_open
storage_open_load:
        clr.w storage_continue-module_start(a5)
        moveq #2,d6
storage_open:
        clr.w disk_mode-module_start(a5)
        bsr disk_detect
        clr.w building_mode-module_start(a5)
        clr.w building_candidate_count-module_start(a5)
        clr.w storage_status-module_start(a5)
        movem.l d6,-(sp)
        bsr storage_catalog_scan
        movem.l (sp)+,d6
        move.w d0,disk_game_error-module_start(a5)
        move.w d6,storage_modal-module_start(a5)
        move.w storage_active_slot(pc),d0
        bpl.s .select
        moveq #0,d0
.select:
        move.w d0,storage_slot-module_start(a5)
        andi.w #16,d0
        move.w d0,storage_page-module_start(a5)
.done:
        rts

storage_modal_keys:
        cmpi.w #5,storage_modal-module_start(a5)
        bhs disk_modal_keys
        cmpi.b #$b3,editor_input_keys+$45(a5)
        beq .cancel
        cmpi.w #3,storage_modal-module_start(a5)
        beq storage_name_keys
        cmpi.b #$b3,editor_input_keys+$44(a5)
        beq .confirm
        cmpi.b #$b3,editor_input_keys+$40(a5)       ; Space
        beq .confirm
        btst #4,editor_input_keys+96(a5)
        bne .confirm
        cmpi.w #4,storage_modal-module_start(a5)
        beq .done
        moveq #-1,d4
        move.w editor_directions(pc),d0
        andi.w #5,d0          ; up or left
        bne.s .move
        moveq #1,d4
        move.w editor_directions(pc),d0
        andi.w #10,d0         ; down or right
        beq .done
.move:
        ; Map global slot/action to the visible row (16 tracks + actions).
        move.w storage_slot(pc),d0
        cmpi.w #32,d0
        bhs.s .action_row
        sub.w storage_page(pc),d0
        bra.s .advance
.action_row:
        subi.w #16,d0
        tst.w disk_mode-module_start(a5)
        beq.s .advance
        subq.w #1,d0             ; DF1 has no Disk row
.advance:
        add.w d4,d0
        moveq #19,d1
        tst.w disk_mode-module_start(a5)
        beq.s .limit
        subq.w #1,d1
.limit:
        tst.w d0
        bpl.s .upper
        move.w d1,d0
        subq.w #1,d0
.upper:
        cmp.w d1,d0
        blo.s .selected
        clr.w d0
.selected:
        cmpi.w #16,d0
        bhs.s .action_slot
        add.w storage_page(pc),d0
        bra.s .store
.action_slot:
        addi.w #16,d0
        tst.w disk_mode-module_start(a5)
        beq.s .store
        addq.w #1,d0
.store:
        move.w d0,storage_slot-module_start(a5)
        bra editor_release
.confirm:
        bsr editor_release
        cmpi.w #33,storage_slot-module_start(a5)
        beq .previous_page
        cmpi.w #34,storage_slot-module_start(a5)
        beq .next_page
        cmpi.w #32,storage_slot-module_start(a5)
        beq disk_open
        tst.w disk_mode-module_start(a5)
        bne.s .allow_slot
        tst.w disk_game_error-module_start(a5)
        bne .done
.allow_slot:
        cmpi.w #4,storage_modal-module_start(a5)
        beq storage_begin_name
        bsr storage_entry
        cmpi.w #3,32(a3)
        beq .invalid
        cmpi.w #2,storage_modal-module_start(a5)
        beq.s .load
        tst.l (a3)
        beq storage_begin_name
        ; Always confirm occupied slots: safe even for two distinct drafts
        ; whose imported legacy IDs happen to match.
        move.w #4,storage_modal-module_start(a5)
        rts
.load:
        tst.w disk_mode-module_start(a5)
        bne disk_load
        bsr editor_load
        cmpi.w #2,storage_status-module_start(a5)
        bne.s .done
        clr.w storage_modal-module_start(a5)
        rts
.previous_page:
        clr.w storage_page-module_start(a5)
        clr.w storage_slot-module_start(a5)
        rts
.next_page:
        move.w #16,storage_page-module_start(a5)
        move.w #16,storage_slot-module_start(a5)
        rts
.invalid:
        move.w #4,storage_status-module_start(a5)
.done:
        rts
.cancel:
        tst.w disk_mode-module_start(a5)
        bne disk_cancel
        bsr editor_release
        clr.w storage_modal-module_start(a5)
        clr.w storage_continue-module_start(a5)
        ; Dirty-action prompt remains underneath a cancelled/failed Save.
        rts

storage_begin_name:
        lea editor_track+40(pc),a0
        lea storage_name(pc),a1
        moveq #24,d0
        bsr storage_copy
        lea storage_name(pc),a0
        moveq #0,d0
.length:
        tst.b (a0)+
        beq.s .ready
        addq.w #1,d0
        cmpi.w #24,d0
        blo.s .length
.ready:
        move.w d0,storage_name_length-module_start(a5)
        move.w #3,storage_modal-module_start(a5)
        rts
storage_name_keys:
        cmpi.b #$b3,editor_input_keys+$44(a5)       ; Return ends text entry; Space types a space
        beq storage_name_commit
        btst #4,editor_input_keys+96(a5)
        bne storage_name_commit
        cmpi.b #$b3,editor_input_keys+$41(a5)
        beq.s .backspace
        lea storage_keymap(pc),a0
        lea editor_input_keys(a5),a1
        moveq #0,d4
.search:
        cmpi.b #$b3,(a1)+
        bne.s .next
        moveq #0,d5
        move.b (a0,d4.w),d5
        beq.s .next
        move.w storage_name_length(pc),d0
        cmpi.w #24,d0
        bhs editor_release
        lea storage_name(pc),a0
        move.b d5,(a0,d0.w)
        addq.w #1,storage_name_length-module_start(a5)
        bra editor_release
.next:
        addq.w #1,d4
        cmpi.w #65,d4
        blo.s .search
        rts
.backspace:
        move.w storage_name_length(pc),d0
        beq editor_release
        subq.w #1,d0
        move.w d0,storage_name_length-module_start(a5)
        lea storage_name(pc),a0
        clr.b (a0,d0.w)
        bra editor_release
storage_name_commit:
        tst.w disk_mode-module_start(a5)
        bne disk_name_commit
        bsr editor_release
        tst.w storage_name_length-module_start(a5)
        beq .done
        move.w #3,storage_status-module_start(a5)
        ; Save has its own scan backup. This separate snapshot preserves RAM
        ; bytes and dirty state if a renamed save cannot commit.
        lea editor_track(pc),a0
        lea storage_ui_backup(pc),a1
        move.w #580,d0
        bsr storage_copy
        lea storage_name(pc),a0
        lea editor_track+40(pc),a1
        moveq #24,d0
        bsr storage_copy
        move.w storage_slot(pc),d0
        cmp.w storage_active_slot(pc),d0
        beq.s .identity_done
        bsr storage_entry
        move.l (a3),d0
        addq.l #1,d0
        beq.s .rollback
        move.l #$53434945,editor_track+8-module_start(a5)
        moveq #0,d1
        move.w storage_slot(pc),d1
        move.l d1,editor_track+12-module_start(a5)
        move.l d0,editor_track+16-module_start(a5)
        move.l #$56303901,editor_track+20-module_start(a5)
.identity_done:
        bsr editor_model_refresh
        bsr editor_save
        cmpi.w #1,storage_status-module_start(a5)
        beq.s .success
        cmpi.w #7,storage_status-module_start(a5)
        beq.s .success
.rollback:
        lea storage_ui_backup(pc),a0
        lea editor_track(pc),a1
        move.w #580,d0
        bsr storage_copy
        bsr editor_model_view
        rts
.success:
        clr.w storage_modal-module_start(a5)
        tst.w storage_continue-module_start(a5)
        beq.s .done
        clr.w storage_continue-module_start(a5)
        bra editing_execute
.done:
        rts

; Opaque modal screen, 16 rows at 8 pixels/row. 40 columns, ASCII 5x7.
storage_modal_text:
        cmpi.w #5,storage_modal-module_start(a5)
        bhs disk_modal_text
        tst.w storage_modal-module_start(a5)
        beq .done
        movea.l draw_surface(pc),a0
        move.w #7999,d0
.clear:
        clr.l (a0)+
        dbra d0,.clear
        lea storage_save_title(pc),a0
        cmpi.w #2,storage_modal-module_start(a5)
        bne.s .title
        lea storage_load_title(pc),a0
.title:
        tst.w disk_mode-module_start(a5)
        beq.s .draw_title
        lea disk_save_title(pc),a0
        cmpi.w #2,disk_mode-module_start(a5)
        bne.s .draw_title
        lea disk_load_title(pc),a0
.draw_title:
        movea.l draw_surface(pc),a1
        adda.w #322,a1
        bsr storage_text_line
        move.w storage_slot(pc),-(sp)
        move.w storage_page(pc),storage_slot-module_start(a5)
.row:
        lea storage_line(pc),a0
        moveq #37,d0
.blank:
        move.b #32,(a0)+
        dbra d0,.blank
        clr.b (a0)
        bsr storage_entry
        lea storage_line(pc),a0
        move.w storage_slot(pc),d0
        cmp.w (sp),d0
        bne.s .number
        move.b #62,(a0)
.number:
        addq.w #1,d0
        divu.w #10,d0
        addi.b #48,d0
        move.b d0,1(a0)
        swap d0
        addi.b #48,d0
        move.b d0,2(a0)
        lea storage_empty(pc),a2
        cmpi.w #3,32(a3)
        bne.s .available
        lea storage_damaged(pc),a2
.available:
        tst.l (a3)
        beq.s .label
        lea 8(a3),a2
.label:
        lea 4(a0),a1
        moveq #23,d0
.name:
        move.b (a2)+,d1
        beq.s .state
        ; Legacy lower case is displayed using the uppercase font.
        cmpi.b #97,d1
        blo.s .char
        cmpi.b #122,d1
        bhi.s .char
        subi.b #32,d1
.char:
        move.b d1,(a1)+
        dbra d0,.name
.state:
        lea storage_draft(pc),a2
        cmpi.w #2,32(a3)
        bne.s .invalid
        lea storage_ready(pc),a2
.invalid:
        cmpi.w #3,32(a3)
        bne.s .status
        lea storage_invalid(pc),a2
.status:
        tst.w 32(a3)
        beq.s .draw
        lea 29(a0),a1
.copy_state:
        move.b (a2)+,(a1)+
        bne.s .copy_state
.draw:
        move.w storage_slot(pc),d4
        sub.w storage_page(pc),d4
        mulu.w #320,d4
        addi.w #962,d4
        movea.l draw_surface(pc),a1
        adda.w d4,a1
        bsr storage_text_line
        addq.w #1,storage_slot-module_start(a5)
        move.w storage_slot(pc),d0
        sub.w storage_page(pc),d0
        cmpi.w #16,d0
        blo .row
        move.w (sp)+,storage_slot-module_start(a5)
        bsr storage_page_text
        bsr disk_button_text
        lea storage_list_help(pc),a0
        cmpi.w #4,storage_modal-module_start(a5)
        bne.s .name_prompt
        lea storage_overwrite(pc),a0
.name_prompt:
        cmpi.w #3,storage_modal-module_start(a5)
        bne.s .help
        lea storage_name_help(pc),a0
.help:
        movea.l draw_surface(pc),a1
        adda.w #7202,a1
        cmpi.w #3,storage_modal-module_start(a5)
        beq.s .compact_help
        cmpi.w #4,storage_modal-module_start(a5)
        bne.s .draw_help
.compact_help:
        suba.w #800,a1
.draw_help:
        bsr storage_text_line
        cmpi.w #3,storage_modal-module_start(a5)
        bne.s .message
        lea storage_name(pc),a0
        movea.l draw_surface(pc),a1
        adda.w #6802,a1
        bsr storage_text_line
.message:
        move.w storage_status(pc),d0
        lsl.w #5,d0
        lea storage_messages(pc),a0
        adda.w d0,a0
        movea.l draw_surface(pc),a1
        adda.w #7522,a1
        bsr storage_text_line
.done:
        rts
storage_page_text:
        lea storage_page_label(pc),a0
        move.b #49,5(a0)
        tst.w storage_page-module_start(a5)
        beq.s .label
        move.b #50,5(a0)
.label:
        movea.l draw_surface(pc),a1
        adda.w #642,a1
        bsr storage_text_line
        cmpi.w #3,storage_modal-module_start(a5)
        beq.s .done
        cmpi.w #4,storage_modal-module_start(a5)
        beq.s .done
        lea storage_previous(pc),a0
        move.b #32,(a0)
        cmpi.w #33,storage_slot-module_start(a5)
        bne.s .previous
        move.b #62,(a0)
.previous:
        movea.l draw_surface(pc),a1
        adda.w #6402,a1
        bsr storage_text_line
        lea storage_next(pc),a0
        move.b #32,(a0)
        cmpi.w #34,storage_slot-module_start(a5)
        bne.s .next
        move.b #62,(a0)
.next:
        movea.l draw_surface(pc),a1
        adda.w #6722,a1
        bsr storage_text_line
.done:  rts
storage_page_label: dc.b 'PAGE 1/2',0
storage_previous: dc.b '  PREVIOUS PAGE',0
storage_next: dc.b '  NEXT PAGE',0
        even
storage_page: dc.w 0
storage_save_title: dc.b 'SAVE TRACK - SELECT SLOT',0
storage_load_title: dc.b 'LOAD TRACK - SELECT SLOT',0
storage_list_help: dc.b 'JOY SELECT  FIRE/SPACE OK  ESC CANCEL',0
storage_overwrite: dc.b 'OVERWRITE? FIRE/SPACE YES  ESC CANCEL',0
storage_name_help: dc.b 'NAME: ENTER/FIRE SAVE / ESC CANCEL',0
storage_empty: dc.b 'EMPTY',0
storage_damaged: dc.b 'UNREADABLE',0
storage_draft: dc.b 'DRAFT',0
storage_ready: dc.b 'READY',0
storage_invalid: dc.b 'INVALID',0
        even
storage_slot: dc.w 0
storage_active_slot: dc.w -1
storage_saved_slot: dc.w -1
storage_modal: dc.w 0
storage_continue: dc.w 0
storage_name_length: dc.w 0
storage_name: dcb.b 24,0
        dc.b 0,0
storage_line: dcb.b 40,0
storage_catalog: dcb.b 2048,0
storage_ui_backup: dcb.b 580,0
        include "storage-keymap.s"

; External state is independent of the selected DF0 slot. Buffers are private
; Fast scratch at +$50000, outside module, screen backup and renderer caches.
disk_state:
disk_mode: dc.w 0
disk_available: dc.w 0
disk_game_error: dc.w 0
disk_choice: dc.w 0
disk_progress: dc.w 0
disk_io_active: dc.w 0
disk_error: dc.w 0
disk_game_slot: dc.w 0
disk_game_page: dc.w 0
disk_game_generation: dc.l 0
disk_free_slot: dc.w 0
disk_match_slot: dc.w 0
disk_state_end:
