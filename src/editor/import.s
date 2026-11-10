; Import the old track and lap record files into the tracks drawer.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Old tracks of 1.6.0-2.2.0 to tracks/. Only this import reads the old files:
; TrackNN.sct (SCES v1/v2, 1024 bytes) and TrackNN.rec (SCER
; v1, 1024 bytes), NN 01..32, in the root of the install, and TrackIndex,
; which only a deletion touches.
;
; Before the first title menu of a session one listing of the root looks for
; them. Unless tracks/Imported says the question was answered, the game asks
; in its own menu ($5b840). While the root holds old files, Practise has the
; row Import Old Tracks, so the import stays reachable after a No and for
; files copied there later.
;
; An old track keeps its number unless tracks/ holds a track or records file
; there (records of a bundled track too); then it goes with its records to
; the first slot without either, after the tracks that keep theirs. A track
; already in a slot (the same identity and records key, whatever its name)
; is not written again. Records go with the Ready track whose key they
; match, or to a bundled track still in its slot; into a records file of the
; same track only the better old times go. A first run without writing
; counts the files to write for the progress screen. Every written file is
; read back and compared; a difference stops the import without a deletion
; question or the marker. A write error ends WHDLoad (WHDLF_NoError).
; Damaged and unmatched old files are skipped and stay. The marker comes
; before a deletion, which takes only the old files whose tracks or records
; are now in tracks/, and TrackIndex, and leaves delete-protected files.
; The builder gives IMPORT_SLOTS and IMPORT_OLD_BYTES and
; where an old records file keeps the key: its first IMPORT_KEY_LOW bytes at 32,
; the rest from IMPORT_KEY_HIGH_AT to IMPORT_KEY_END.
; The normal and the super league times, IMPORT_OLD_NORMAL and IMPORT_OLD_SUPER,
; follow the first part.
ID_SCES equ $53434553
ID_SCER equ $53434552
IMPORT_SCREEN_COLUMNS equ 40

; Before the first title menu of a session. Every register and CCR kept.
import_startup:
        move.w ccr,-(sp)
        movem.l d0-d7/a0-a6,-(sp)
        lea module_start(pc),a5
        tst.w import_checked-module_start(a5)
        bne.s .done
        move.w #1,import_checked-module_start(a5)
        bsr import_list
        beq.s .done
        bsr import_marker_present
        bne.s .done
        moveq #1,d7
        bsr import_offer
.done:
import_startup_end:
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,ccr
        rts

; Practise's menu: D2 = its last row. With old files in the root the row
; Import Old Tracks comes before Cancel: five rows, which the speed menu's
; hooks place and number as in the Single Player menu while its context byte
; is 3 (no menu of its own has that value).
import_practise_rows:
        clr.w import_practise-module_start(a5)
        tst.l import_found_tracks-module_start(a5)
        bne.s .row
        tst.l import_found_records-module_start(a5)
        beq.s .done
.row:   move.w #1,import_practise-module_start(a5)
        moveq #4,d2
        move.b #3,SPEED_MENU_ACTIVE
.done:  rts

; D7 = 1 from the startup, 0 from Practise. Asks, imports on a Yes.
import_offer:
        move.w d7,import_from_startup-module_start(a5)
        bsr import_ask_texts
        moveq #IMPORT_MENU_ASK,d6
        moveq #1,d2
        moveq #0,d0
        bsr import_menu
        tst.w d0
        beq.s .yes
        bra import_marker_write
.yes:   bsr import_run
        bra import_finish

; D6 custom_menu, D2 last row, D0 default row. D0 = the chosen row.
import_menu:
        movem.l d1-d7/a0-a6,-(sp)
        move.b $5eb75,-(sp)     ; the caller's text bank ($80 at the title menu)
        move.w d6,custom_menu-module_start(a5)
        move.w d2,import_menu_last-module_start(a5)
        move.b #$40,$5eb75
        bsr custom_menu_run
        move.b (sp)+,$5eb75
        andi.l #255,d0
        movem.l (sp)+,d1-d7/a0-a6
        rts

; The title of an import menu ($5b86e; speed_menu_title for the others).
custom_menu_title:
        cmpi.w #IMPORT_MENU_ASK,custom_menu(pc)
        bhs.s .import
        jmp SPEED_MENU_TITLE
.import:
        movem.l d0-d7/a0-a6,-(sp)
        lea import_title(pc),a0
        bsr import_print
        movem.l (sp)+,d0-d7/a0-a6
        rts

; Row D0 of an import menu (custom_menu_row). After the last row come the
; info lines below it.
import_menu_row:
        lea import_rows(pc),a0
        lsl.w #5,d0
        adda.w d0,a0
        bsr import_print
        moveq #0,d0
        move.b $1bb18,d0
        cmp.w import_menu_last(pc),d0
        bne.s .done
        lea import_info(pc),a0
        bsr import_print
.done:  rts

; A0 text with pen codes, ended by zero, through the game's printer.
import_print:
        move.b (a0)+,d0
        beq.s .done
        jsr $594c6
        bra.s import_print
.done:  rts

;---------------------------------------------------------------------------
; The listing

; D0 (flags set) = the old track and records files of the root as bits
; (import_found_tracks, import_found_records); none without tracks/.
import_list:
        movem.l d1-d3/a0-a2,-(sp)
        clr.l import_found_tracks-module_start(a5)
        clr.l import_found_records-module_start(a5)
        clr.w import_found_index-module_start(a5)
        bsr storage_folder_check
        beq.s .done
        lea import_root(pc),a0
        lea IMPORT_LISTING(a5),a1
        move.l #IMPORT_LISTING_BYTES,d1
        moveq #FS_LIST,d0
        bsr storage_file
        move.l d0,d2
        movea.l a1,a2
        movea.l a1,a0
        adda.l #IMPORT_LISTING_BYTES-FS_LIST_NAME,a0
        bra.s .test
.name:  cmpa.l a0,a2            ; a listing that ended early: the names it has
        bhs.s .done
        bsr import_name
        bmi.s .test
        cmpi.w #2,d1
        beq.s .index
        move.l import_found_tracks(pc),d3
        tst.w d1
        beq.s .track
        move.l import_found_records(pc),d3
        bset d0,d3
        move.l d3,import_found_records-module_start(a5)
        bra.s .test
.track: bset d0,d3
        move.l d3,import_found_tracks-module_start(a5)
        bra.s .test
.index: move.w #1,import_found_index-module_start(a5)
.test:  subq.l #1,d2
        bpl.s .name
.done:  move.l import_found_tracks(pc),d0
        or.l import_found_records(pc),d0
        movem.l (sp)+,d1-d3/a0-a2
        tst.l d0
        rts

; A2 a listed name, after its zero byte on return. D0 (flags set) = NN-1 of
; TrackNN.sct (D1 = 0) or TrackNN.rec (D1 = 1), NN 01..32, or 0 for
; TrackIndex (D1 = 2), in any case; otherwise -1.
import_name:
        movem.l d2-d3/a0-a1,-(sp)
        moveq #0,d1
        movea.l a2,a1
.end:   tst.b (a2)+
        bne.s .end
        lea import_word_track(pc),a0
        bsr import_match
        bne.s .no
        move.l a1,d3
        lea import_word_index(pc),a0
        bsr import_match
        bne.s .number
        tst.b (a1)
        bne.s .no
        moveq #2,d1
        moveq #0,d0
        bra.s .done
.number:
        movea.l d3,a1
        moveq #0,d2
        move.b (a1)+,d2
        subi.b #'0',d2
        cmpi.b #9,d2
        bhi.s .no
        mulu.w #10,d2
        moveq #0,d3
        move.b (a1)+,d3
        subi.b #'0',d3
        cmpi.b #9,d3
        bhi.s .no
        add.w d3,d2
        subq.w #1,d2
        cmpi.w #IMPORT_SLOTS,d2
        bhs.s .no
        move.l a1,d3
        lea storage_suffix_track(pc),a0
        bsr import_match
        beq.s .suffix
        movea.l d3,a1
        moveq #1,d1
        lea storage_suffix_records(pc),a0
        bsr import_match
        bne.s .no
.suffix:
        tst.b (a1)
        bne.s .no
        moveq #0,d0
        move.w d2,d0
        bra.s .done
.no:    moveq #-1,d0            ; import_match leaves 1 in D0
.done:  movem.l (sp)+,d2-d3/a0-a1
        tst.l d0
        rts

; A0 a lower-case word, A1 a name. D0 = 0 (Z set) and A1 after the word if
; the name begins with it, letters in any case; otherwise D0 = 1.
import_match:
        move.l d1,-(sp)
.char:  move.b (a0)+,d0
        beq.s .yes
        move.b (a1)+,d1
        cmpi.b #'A',d1
        blo.s .compare
        cmpi.b #'Z',d1
        bhi.s .compare
        ori.b #$20,d1
.compare:
        cmp.b d0,d1
        beq.s .char
        moveq #1,d0
        bra.s .done
.yes:   moveq #0,d0
.done:  move.l (sp)+,d1
        tst.l d0
        rts

; D0 slot, D1 0 for TrackNN.sct or 1 for TrackNN.rec. A0 = its name.
import_old_path:
        movem.l d0/a1,-(sp)
        lea import_path+5(pc),a1
        andi.l #$ffff,d0
        addq.l #1,d0
        divu.w #10,d0
        addi.b #'0',d0
        move.b d0,(a1)+
        swap d0
        addi.b #'0',d0
        move.b d0,(a1)+
        bsr storage_suffix_put
        lea import_path(pc),a0
        movem.l (sp)+,d0/a1
        rts

; D0 old slot, D1 0 for its track or 1 for its records. A1 = its buffer.
import_old_buffer:
        movem.l d0-d1,-(sp)
        andi.l #$ffff,d0
        tst.w d1
        beq.s .track
        addi.w #IMPORT_SLOTS,d0
.track: moveq #10,d1
        lsl.l d1,d0
        lea IMPORT_OLD(a5),a1
        adda.l d0,a1
        movem.l (sp)+,d0-d1
        rts

import_marker_present:
        move.l a0,-(sp)
        lea import_marker_name(pc),a0
        moveq #FS_SIZE,d0
        bsr storage_file
        movea.l (sp)+,a0                ; keeps storage_file's flags
        rts

; tracks/Imported, unless it is there. Without tracks/ nothing.
import_marker_write:
        movem.l d0-d1/a0-a1,-(sp)
        bsr storage_folder_check
        beq.s .done
        bsr import_marker_present
        bne.s .done
        lea import_marker_name(pc),a0
        lea import_marker_text(pc),a1
        moveq #import_marker_end-import_marker_text,d1
        moveq #FS_SAVE,d0
        bsr storage_file
.done:  movem.l (sp)+,d0-d1/a0-a1
        rts

;---------------------------------------------------------------------------
; The import

import_run:
        movem.l d0-d7/a0-a6,-(sp)
        lea import_results(pc),a0
        moveq #(import_results_end-import_results)/2-1,d0
.clear: clr.w (a0)+
        dbra d0,.clear
        bsr storage_catalog_scan
        bsr storage_backup
        move.w storage_slot(pc),-(sp)
        bsr import_load
        ; First without writing: the number of files to write, which the
        ; progress screen counts to. Then the catalog rows that run filled
        ; as they were, and the import itself.
        move.w #1,import_dry-module_start(a5)
        bsr import_passes
        bsr import_rows_restore
        move.w import_progress(pc),import_total-module_start(a5)
        lea import_run_state(pc),a0
        moveq #(import_results_end-import_run_state)/2-1,d0
.again: clr.w (a0)+
        dbra d0,.again
        clr.w import_dry-module_start(a5)
        bsr import_passes
        move.w (sp)+,storage_slot-module_start(a5)
        bsr storage_restore
        bsr editor_model_view
        ; Skipped: the old files that are not in tracks/ now.
        move.l import_done_tracks(pc),d0
        not.l d0
        and.l import_found_tracks(pc),d0
        bsr import_bits
        move.w d0,d1
        move.l import_done_records(pc),d0
        not.l d0
        and.l import_found_records(pc),d0
        bsr import_bits
        add.w d1,d0
        move.w d0,import_skipped-module_start(a5)
        movem.l (sp)+,d0-d7/a0-a6
        rts

; The tracks that keep their number, then the others, then the records left
; for bundled tracks; a failed write stops. D6-D7 are used.
import_passes:
        moveq #0,d7
.pass:  moveq #0,d6
.track: move.l import_valid_tracks(pc),d0
        btst d6,d0
        beq.s .next
        move.l import_handled_tracks(pc),d0
        btst d6,d0
        bne.s .next
        bsr import_track
        tst.w import_failed-module_start(a5)
        bne.s .stop
.next:  addq.w #1,d6
        cmpi.w #IMPORT_SLOTS,d6
        blo.s .track
        addq.w #1,d7
        cmpi.w #2,d7
        blo.s .pass
        bra import_bundled_records
.stop:  rts

; D6 old slot: A1 = where the catalog row of its track's slot is kept.
import_row_area:
        move.l d0,-(sp)
        moveq #0,d0
        move.w d6,d0
        lsl.w #CATALOG_ROW_SHIFT,d0
        lea IMPORT_ROWS(a5),a1
        adda.l d0,a1
        move.l (sp)+,d0
        rts

; D4 slot, D6 old slot: the catalog row of D4 kept before the track of D6
; fills it.
import_row_save:
        movem.l d0/a0-a1/a3,-(sp)
        move.w d4,d0
        bsr storage_entry_of
        movea.l a3,a0
        bsr import_row_area
        moveq #CATALOG_ROW,d0
        bsr storage_copy
        movem.l (sp)+,d0/a0-a1/a3
        rts

; After the run without writing: each catalog row it filled as it was.
import_rows_restore:
        movem.l d0/d6/a0-a1/a3,-(sp)
        moveq #0,d6
.slot:  lea import_placed(pc),a0
        move.w d6,d0
        add.w d0,d0
        move.w (a0,d0.w),d0
        beq.s .next
        subq.w #1,d0
        bsr storage_entry_of
        bsr import_row_area
        movea.l a1,a0
        movea.l a3,a1
        moveq #CATALOG_ROW,d0
        bsr storage_copy
.next:  addq.w #1,d6
        cmpi.w #IMPORT_SLOTS,d6
        blo.s .slot
        movem.l (sp)+,d0/d6/a0-a1/a3
        rts

; Each found old file to its buffer; the ones whose envelope holds are valid.
import_load:
        moveq #0,d6
.loop:  moveq #0,d1
        move.l import_found_tracks(pc),d0
        btst d6,d0
        beq.s .records
        bsr.s .read
        bne.s .records
        bsr import_sces_check
        beq.s .records
        move.l import_valid_tracks(pc),d0
        bset d6,d0
        move.l d0,import_valid_tracks-module_start(a5)
.records:
        moveq #1,d1
        move.l import_found_records(pc),d0
        btst d6,d0
        beq.s .next
        bsr.s .read
        bne.s .next
        bsr import_scer_check
        beq.s .next
        move.l import_valid_records(pc),d0
        bset d6,d0
        move.l d0,import_valid_records-module_start(a5)
.next:  addq.w #1,d6
        cmpi.w #IMPORT_SLOTS,d6
        blo.s .loop
        rts
; D6 slot, D1 kind: A1 the file, Z set if it is 1024 bytes.
.read:  move.w d6,d0
        bsr import_old_path
        bsr import_old_buffer
        move.l #IMPORT_OLD_BYTES,d1
        moveq #FS_LOAD,d0
        bsr storage_file
        cmpi.l #IMPORT_OLD_BYTES,d0
        rts

; A1 old track file. D0 = 1 (flags set) if its SCES envelope holds: version
; 1 or 2, header 32, an SCTR v1 payload of 76..EDITOR_TRACK_BYTES bytes whose
; own length agrees, zero reserved bytes and the CRC-32 of bytes 0..1019 at
; 1020. Generation and slot are not looked at, so a renamed file works.
import_sces_check:
        movem.l d1-d3/a0,-(sp)
        cmpi.l #ID_SCES,(a1)
        bne.s .bad
        move.w 4(a1),d0
        beq.s .bad
        cmpi.w #2,d0
        bhi.s .bad
        cmpi.w #32,6(a1)
        bne.s .bad
        moveq #0,d1
        move.w 12(a1),d1
        move.w d1,d0
        andi.w #3,d0
        bne.s .bad
        ; Only version 1: its id, size and own length.
        lea 32(a1),a0
        bsr storage_sctr_check
        subq.l #1,d0
        bne.s .bad
        lea 16(a1),a0
        moveq #16,d0
        bsr import_zero
        bne.s .bad
        lea 32(a1,d1.l),a0
        move.l #IMPORT_OLD_BYTES-4-32,d0
        sub.l d1,d0
        bsr import_zero
        bne.s .bad
        bsr import_old_crc
        bne.s .bad
        moveq #1,d0
        bra.s .done
.bad:   moveq #0,d0
.done:  movem.l (sp)+,d1-d3/a0
        tst.l d0
        rts

; A1 old records file. D0 = 1 (flags set) if its SCER v1 envelope holds:
; header 32, this policy, zero reserved bytes, the CRC-32 and valid times.
; Generation and slot are not looked at.
import_scer_check:
        movem.l d1-d3/a0-a1,-(sp)
        cmpi.l #ID_SCER,(a1)
        bne.s .bad
        cmpi.l #$00010020,4(a1)
        bne.s .bad
        cmpi.w #RECORDS_POLICY,14(a1)
        bne.s .bad
        lea 16(a1),a0
        moveq #16,d0
        bsr import_zero
        bne.s .bad
        lea IMPORT_KEY_END(a1),a0
        move.l #IMPORT_OLD_BYTES-4-IMPORT_KEY_END,d0
        bsr import_zero
        bne.s .bad
        bsr import_old_crc
        bne.s .bad
        lea IMPORT_OLD_NORMAL(a1),a1
        bsr records_times_check
        beq.s .bad
        lea RECORDS_TIMES_BYTES(a1),a1
        bsr records_times_check
        beq.s .bad
        moveq #1,d0
        bra.s .done
.bad:   moveq #0,d0
.done:  movem.l (sp)+,d1-d3/a0-a1
        tst.l d0
        rts

; A0 bytes, D0 count. Z set if they are all zero.
import_zero:
        subq.l #1,d0
        bmi.s .zero
.loop:  tst.b (a0)+
        bne.s .done
        subq.l #1,d0
        bpl.s .loop
.zero:  moveq #0,d0
.done:  rts

; A1 old file. Z set if the CRC-32 of bytes 0..1019 is at 1020.
import_old_crc:
        movea.l a1,a0
        move.w #IMPORT_OLD_BYTES-4,d0
        bsr storage_crc
        cmp.l IMPORT_OLD_BYTES-4(a1),d0
        rts

; D6 old slot, D7 pass (0: its own number only, 1: the first empty slot).
import_track:
        movem.l d0-d5/a0-a4,-(sp)
        move.w d6,d0
        moveq #0,d1
        bsr import_old_buffer
        lea 32(a1),a2
        moveq #0,d5
        move.w 12(a1),d5
        bsr import_same_slot
        bpl .already
        tst.w d7
        bne.s .move
        move.w d6,d0
        bsr storage_entry_of
        cmpi.l #CATALOG_FILE,CATALOG_KIND(a3) ; tracks/ has a track file there
        beq .done
        cmpi.w #CLASS_UNUSABLE,CATALOG_CLASS(a3) ; or one that cannot be used
        beq .done
        move.w d6,d0
        bsr import_records_there ; or records, also of a bundled track
        bne .done
        move.w d6,d4
        bra.s .write
.move:  bsr import_empty_slot
        bmi.s .skip
        move.w d0,d4
.write: bsr import_handled
        bsr import_model
        beq.s .done
        bsr import_row_save
        lea 40(a2),a0
        bsr import_show
        bsr import_track_write
        bne.s .done
        lea import_placed(pc),a0
        move.w d6,d0
        add.w d0,d0
        move.w d4,d1
        addq.w #1,d1
        move.w d1,(a0,d0.w)
        move.l import_done_tracks(pc),d0
        bset d6,d0
        move.l d0,import_done_tracks-module_start(a5)
        addq.w #1,import_tracks-module_start(a5)
        tst.w d7
        beq.s .records
        addq.w #1,import_moved-module_start(a5)
.records:
        bsr import_track_records
        bra.s .done
.already:
        move.w d0,d4
        bsr import_handled
        move.l import_done_tracks(pc),d0
        bset d6,d0
        move.l d0,import_done_tracks-module_start(a5)
        addq.w #1,import_already-module_start(a5)
        bsr import_model
        beq.s .done
        bsr import_track_records
        bra.s .done
.skip:  bsr import_handled
.done:  movem.l (sp)+,d0-d5/a0-a4
        rts

; D0 slot. D0 (flags set) = the size of tracks/TrackNNN.rec, 0 without one.
import_records_there:
        movem.l d1/a0,-(sp)
        moveq #1,d1
        bsr storage_path_make
        moveq #FS_SIZE,d0
        bsr storage_file
        movem.l (sp)+,d1/a0             ; keeps storage_file's flags
        rts

; D6 old slot: handled.
import_handled:
        move.l d0,-(sp)
        move.l import_handled_tracks(pc),d0
        bset d6,d0
        move.l d0,import_handled_tracks-module_start(a5)
        move.l (sp)+,d0
        rts

; A2 SCTR, D5 its bytes. D0 (flags set) = the first slot, a file or a bundled
; track, that holds the same track: the same identity and records key, so a
; renamed track is the same and a reshaped one is not; or -1. The same own
; CRC needs no further look.
import_same_slot:
        movem.l d1-d2/a0-a1/a3,-(sp)
        move.l -4(a2,d5.l),d1
        moveq #0,d0
        bsr storage_entry_of
        moveq #0,d2
.row:   tst.l CATALOG_KIND(a3)
        beq.s .next
        lea CATALOG_IDENTITY(a3),a0
        lea SCTR_IDENTITY(a2),a1
        moveq #SCTR_IDENTITY_BYTES/4-1,d0
.identity:
        cmpm.l (a0)+,(a1)+
        bne.s .next
        dbra d0,.identity
        cmp.l CATALOG_CRC(a3),d1
        beq.s .found
        move.w d2,d0
        bsr import_row_sctr
        beq.s .next
        movea.l a2,a1
        bsr import_key_same
        beq.s .found
.next:  adda.w #CATALOG_ROW,a3
        addq.w #1,d2
        cmpi.w #STORAGE_SLOTS,d2
        blo.s .row
        moveq #-1,d0
        bra.s .done
.found: moveq #0,d0
        move.w d2,d0
.done:  movem.l (sp)+,d1-d2/a0-a1/a3
        tst.l d0
        rts

; D0 slot of a catalog row with a track. A0 = its SCTR and D0 = 1 (flags
; set), or D0 = 0 if it cannot be read. A track that this import wrote is in
; its old buffer (the run without writing wrote none); any other is read
; from tracks/ or the module to the file buffer.
import_row_sctr:
        movem.l d1-d2/a1/a4,-(sp)
        move.w d0,d2
        addq.w #1,d2
        lea import_placed(pc),a0
        moveq #IMPORT_SLOTS-1,d1
.placed:
        cmp.w (a0)+,d2
        dbeq d1,.placed
        bne.s .read
        moveq #IMPORT_SLOTS-1,d0
        sub.w d1,d0
        moveq #0,d1
        bsr import_old_buffer
        lea 32(a1),a0
        moveq #1,d0
        bra.s .done
.read:  subq.w #1,d2
        move.w d2,d0
        bsr storage_slot_track
        ble.s .none
        moveq #0,d0
        move.w storage_trak(pc),d0
        lea (a4,d0.l),a0
        moveq #1,d0
        bra.s .done
.none:  moveq #0,d0
.done:  movem.l (sp)+,d1-d2/a1/a4
        tst.l d0
        rts

; A0, A1 two SCTR payloads. Z set if their records keys agree (records.s):
; identity and revision, count, initial height, the finish piece's place in
; the list and bytes 4-7 of each piece. A count that does not fit the
; payload's size agrees with nothing.
import_key_same:
        movem.l d0-d3/a0-a3,-(sp)
        lea SCTR_IDENTITY(a0),a2
        lea SCTR_IDENTITY(a1),a3
        moveq #(SCTR_IDENTITY_BYTES+4)/4-1,d0
.id:    cmpm.l (a2)+,(a3)+
        bne.s .done
        dbra d0,.id
        move.w SCTR_HEIGHT(a0),d0
        cmp.w SCTR_HEIGHT(a1),d0
        bne.s .done
        moveq #0,d1
        move.w SCTR_COUNT(a0),d1
        cmp.w SCTR_COUNT(a1),d1
        bne.s .done
        movea.l a0,a2
        bsr.s .finish
        move.l d0,d2
        bmi.s .differ
        movea.l a1,a2
        bsr.s .finish
        cmp.l d0,d2
        bne.s .done
        lea 68(a0),a2
        lea 68(a1),a3
        subq.w #1,d1
.piece: cmpm.l (a2)+,(a3)+
        bne.s .done
        addq.l #4,a2
        addq.l #4,a3
        dbra d1,.piece
.done:  movem.l (sp)+,d0-d3/a0-a3
        rts
.differ:
        moveq #1,d0
        bra.s .done
; A2 SCTR, D1 its count: D0 = the index of its first piece whose ID is the
; finish ID, or -1 (also when the count does not fit the size).
.finish:
        tst.w d1
        beq.s .none
        move.w d1,d0
        lsl.w #PIECE_SHIFT,d0
        addi.w #SCTR_FRAME_BYTES,d0
        cmp.w SCTR_LENGTH(a2),d0
        bne.s .none
        move.l SCTR_FINISH(a2),d3
        lea SCTR_PIECES(a2),a2
        moveq #0,d0
.search:
        cmp.l (a2),d3
        beq.s .found
        addq.l #8,a2
        addq.w #1,d0
        cmp.w d1,d0
        blo.s .search
.none:  moveq #-1,d0
.found: rts

; D0 (flags set) = the first slot without a file, a bundled track or a
; records file, or -1.
import_empty_slot:
        movem.l d1/a3,-(sp)
        moveq #0,d0
        bsr storage_entry_of
        moveq #0,d1
.row:   tst.l CATALOG_KIND(a3)
        bne.s .next
        tst.w CATALOG_CLASS(a3)
        bne.s .next
        move.w d1,d0
        bsr import_records_there
        beq.s .found
.next:  adda.w #CATALOG_ROW,a3
        addq.w #1,d1
        cmpi.w #STORAGE_SLOTS,d1
        blo.s .row
        moveq #-1,d0
        bra.s .done
.found: moveq #0,d0
        move.w d1,d0
.done:  movem.l (sp)+,d1/a3
        tst.l d0
        rts

; A2 SCTR, D5 its bytes, to editor_track and the model. D0 (flags set) = 1
; if the model holds; then practice_class is its class.
import_model:
        move.l a0,-(sp)
        movea.l a2,a0
        move.w d5,d0
        bsr storage_sctr_load
        movea.l (sp)+,a0
        tst.l d0
        rts

; D4 slot, A2 SCTR, D5 its bytes, the class in practice_class: the track
; file as Save writes it, written, read back and compared; then its catalog
; row. D0 (flags set) = 0, or 1 when the readback differs.
import_track_write:
        movem.l d1-d3/a0-a4,-(sp)
        movea.l a2,a0
        move.l d5,d0
        moveq #0,d1
        bsr storage_track_form
        move.l d0,d3
        move.w d4,d0
        moveq #0,d1
        bsr storage_path_make
        bsr import_write
        bne.s .done
        move.w d4,d0
        move.l d3,d1
        bsr storage_row_written
        moveq #0,d0
.done:  movem.l (sp)+,d1-d3/a0-a4
        tst.l d0
        rts

; A0 name, A4 data, D3 bytes: written, then read back and compared. D0
; (flags set) = 0, or 1 with import_failed when the readback differs. The
; run without writing only returns 0.
import_write:
        tst.w import_dry-module_start(a5)
        beq.s .write
        moveq #0,d0
        rts
.write: movem.l d1-d2/a0-a1,-(sp)
        movea.l a4,a1
        move.l d3,d1
        moveq #FS_SAVE,d0
        bsr storage_file
        lea IMPORT_CHECK(a5),a1
        move.l #STORAGE_FILE_BYTES,d1
        moveq #FS_LOAD,d0
        bsr storage_file
        cmp.l d3,d0
        bne.s .bad
        movea.l a4,a0
        move.l d3,d2
        subq.l #1,d2
.compare:
        cmpm.b (a0)+,(a1)+
        bne.s .bad
        subq.l #1,d2
        bpl.s .compare
        moveq #0,d0
        bra.s .done
.bad:   move.w #1,import_failed-module_start(a5)
        moveq #1,d0
.done:  movem.l (sp)+,d1-d2/a0-a1
        tst.l d0
        rts

; D6 old slot, D4 slot of its track in tracks/, the model built. A Ready
; track takes the old records whose key is its own, those of its own number
; first.
import_track_records:
        movem.l d0-d1,-(sp)
        cmpi.w #PRACTICE_READY,practice_class-module_start(a5)
        bne.s .done
        bsr validate_for_practice
        tst.w d0
        beq.s .done
        bsr records_key_build
        move.w d6,d0
        bsr import_record_match
        beq.s .found
        moveq #0,d0
.any:   bsr import_record_match
        beq.s .found
        addq.w #1,d0
        cmpi.w #IMPORT_SLOTS,d0
        blo.s .any
        bra.s .done
.found: bsr import_record_place
.done:  movem.l (sp)+,d0-d1
        rts

; D0 old slot. Z set if its records are valid, unused and of records_key.
import_record_match:
        movem.l d0-d1/a0-a2,-(sp)
        move.l import_valid_records(pc),d1
        btst d0,d1
        beq.s .no
        move.l import_used_records(pc),d1
        btst d0,d1
        bne.s .no
        moveq #1,d1
        bsr import_old_buffer
        movea.l a1,a2
        lea 32(a2),a0
        lea records_key(pc),a1
        move.w #IMPORT_KEY_LOW/4-1,d0
.low:   cmpm.l (a0)+,(a1)+
        bne.s .no
        dbra d0,.low
        lea IMPORT_KEY_HIGH_AT(a2),a0
        move.w #(RECORDS_KEY_BYTES-IMPORT_KEY_LOW)/4-1,d0
.high:  cmpm.l (a0)+,(a1)+
        bne.s .no
        dbra d0,.high
        moveq #0,d0
        bra.s .done
.no:    moveq #1,d0
.done:  movem.l (sp)+,d0-d1/a0-a2
        rts

; D0 old slot of records matching records_key, D4 the slot of their track.
; Written as tracks/TrackNNN.rec. When that file already holds records of
; this track, each old entry with a better (lower) time goes into it with its
; name, and the rest of the file stays as it was; without a better time the
; file is not written. A file that cannot be read stays and the old file is
; skipped; records of another track are replaced, as a race would.
import_record_place:
        movem.l d0-d6/a0-a4,-(sp)
        move.w d0,d6
        move.l import_used_records(pc),d1
        bset d6,d1
        move.l d1,import_used_records-module_start(a5)
        moveq #1,d1
        bsr import_old_buffer
        movea.l a1,a2
        move.w d4,d0
        lea IMPORT_CHECK(a5),a1
        bsr records_read
        bmi .done
        beq .write
        move.l d0,d3
        ; Records of this track: the file in the file buffer with the better
        ; old times and a new CRC.
        movea.l a4,a0
        bsr storage_buffer
        movea.l a1,a4
        move.l d3,d0
        addq.l #3,d0
        andi.w #$fffc,d0
        bsr storage_copy
        lea IMPORT_OLD_NORMAL(a2),a0
        moveq #0,d0
        move.w records_norm(pc),d0
        lea (a4,d0.l),a1
        bsr import_times_merge
        move.w d0,d5
        lea IMPORT_OLD_SUPER(a2),a0
        moveq #0,d0
        move.w records_supr(pc),d0
        lea (a4,d0.l),a1
        bsr import_times_merge
        or.w d0,d5
        beq .done_file
        move.l d3,d0
        bsr storage_form_seal
        bra .save
.write: bsr storage_buffer
        movea.l a1,a4
        lea IMPORT_OLD_NORMAL(a2),a0
        lea IMPORT_OLD_SUPER(a2),a2
        bsr records_fresh
        move.l d0,d3
        ; A4 the file, D3 its bytes.
.save:  lea import_records_name(pc),a0
        bsr import_show
        move.w d4,d0
        moveq #1,d1
        bsr storage_path_make
        bsr import_write
        bne .done
        addq.w #1,import_records-module_start(a5)
.done_file:
        move.l import_done_records(pc),d1
        bset d6,d1
        move.l d1,import_done_records-module_start(a5)
.done:  movem.l (sp)+,d0-d6/a0-a4
        rts

; A0 the two old records of a league, A1 the two of a records file. Each old
; entry whose time is lower replaces the file's, with its name. D0 (flags
; set) = 1 if one did.
import_times_merge:
        movem.l d1-d2/a0-a1,-(sp)
        moveq #0,d0
        moveq #1,d2
.entry: move.l 12(a0),d1        ; minute, second, fraction in BCD, zero
        cmp.l 12(a1),d1
        bhs.s .keep
        move.l (a0),(a1)
        move.l 4(a0),4(a1)
        move.l 8(a0),8(a1)
        move.l d1,12(a1)
        moveq #1,d0
.keep:  lea 16(a0),a0
        lea 16(a1),a1
        dbra d2,.entry
        movem.l (sp)+,d1-d2/a0-a1
        tst.l d0
        rts

; The old records left: those of a bundled track still in its slot.
import_bundled_records:
        movem.l d0-d7/a0-a4,-(sp)
        moveq #0,d7
.entry: lea storage_bundled(pc),a0
        cmp.w (a0),d7
        bhs .done
        move.l import_valid_records(pc),d0
        move.l import_used_records(pc),d1
        not.l d1
        and.l d1,d0
        beq .done
        move.w d7,d0
        mulu.w #6,d0
        move.w 2(a0,d0.w),d4
        move.w d4,d0
        bsr storage_entry_of
        cmpi.l #CATALOG_BUNDLED,CATALOG_KIND(a3)
        bne .next
        move.w d4,d0
        bsr storage_bundled_read
        bsr storage_read_track
        ble .next
        bsr storage_trak_load
        tst.w d0
        beq .next
        bsr validate_for_practice
        tst.w d0
        beq .next
        bsr records_key_build
        moveq #0,d0
.record:
        bsr import_record_match
        bne .other
        bsr import_record_place
        tst.w import_failed-module_start(a5)
        bne .done
        bra .next
.other: addq.w #1,d0
        cmpi.w #IMPORT_SLOTS,d0
        blo .record
.next:  addq.w #1,d7
        bra .entry
.done:  movem.l (sp)+,d0-d7/a0-a4
        rts

; D0 long -> D0 the number of its set bits.
import_bits:
        movem.l d1-d2,-(sp)
        move.l d0,d1
        moveq #0,d0
        moveq #31,d2
.bit:   lsr.l #1,d1
        bcc.s .zero
        addq.w #1,d0
.zero:  dbra d2,.bit
        movem.l (sp)+,d1-d2
        rts

;---------------------------------------------------------------------------
; After the import: the summary, then Keep or Delete.

import_finish:
        tst.w import_failed-module_start(a5)
        bne .stopped
        bsr import_done_texts
        move.l import_done_tracks(pc),d0
        or.l import_done_records(pc),d0
        beq.s .summary
        moveq #IMPORT_MENU_DONE,d6
        moveq #1,d2
        moveq #0,d0
        bsr import_menu
        ; The marker first: a deletion that fails ends WHDLoad.
        bsr import_marker_write
        tst.w d0
        beq.s .kept
        bra import_delete
.kept:  rts
.summary:
        moveq #IMPORT_MENU_SUMMARY,d6
        moveq #0,d2
        moveq #0,d0
        bsr import_menu
        bra import_marker_write
.stopped:
        bsr import_stopped_texts
        moveq #IMPORT_MENU_STOPPED,d6
        moveq #0,d2
        moveq #0,d0
        bra import_menu

; The old files whose tracks or records are in tracks/, and TrackIndex.
import_delete:
        movem.l d0-d7/a0-a4,-(sp)
        move.l import_done_tracks(pc),d0
        bsr import_bits
        move.w d0,d7
        move.l import_done_records(pc),d0
        bsr import_bits
        add.w d0,d7
        add.w import_found_index(pc),d7
        move.w d7,import_total-module_start(a5)
        clr.w import_progress-module_start(a5)
        move.w #1,import_deleting-module_start(a5)
        moveq #0,d1
        move.l import_done_tracks(pc),d5
        bsr.s .kind
        moveq #1,d1
        move.l import_done_records(pc),d5
        bsr.s .kind
        tst.w import_found_index-module_start(a5)
        beq.s .done
        lea import_index_name(pc),a0
        bsr.s .delete
.done:  clr.w import_deleting-module_start(a5)
        bsr import_list
        movem.l (sp)+,d0-d7/a0-a4
        rts
.kind:  moveq #0,d6
.slot:  btst d6,d5
        beq.s .next
        move.w d6,d0
        bsr import_old_path
        bsr.s .delete
.next:  addq.w #1,d6
        cmpi.w #IMPORT_SLOTS,d6
        blo.s .slot
        rts
; A0 name: shown, then deleted unless its protection bits forbid it
; (fib_Protection bit 0 set), which would end WHDLoad.
.delete:
        movem.l d1/a0-a1,-(sp)
        bsr import_show
        bsr storage_examine
        beq.s .kept
        btst #0,FIB_PROTECTION_LOW(a1)
        bne.s .kept
        moveq #FS_DELETE,d0
        bsr storage_file
.kept:  movem.l (sp)+,d1/a0-a1
        rts

;---------------------------------------------------------------------------
; Texts. Titles are centred on line 11 as the game centres its own; info
; lines below the last row of a menu.

; The progress screen before each file written or deleted: the menu box,
; "Importing n/N" (or Deleting) and the text at A0 (24 characters at most,
; trailing spaces dropped) below it. Each file write of WHDLoad shows the
; system for its time, so the screen comes back between the files. The run
; without writing only counts.
import_show:
        movem.l d0-d7/a0-a6,-(sp)
        addq.w #1,import_progress-module_start(a5)
        tst.w import_dry-module_start(a5)
        beq.s .show
        movem.l (sp)+,d0-d7/a0-a6
        rts
.show:  movea.l a0,a3
        lea import_line(pc),a1
        lea import_text_importing(pc),a0
        tst.w import_deleting-module_start(a5)
        beq.s .verb
        lea import_text_deleting(pc),a0
.verb:  bsr text_append
        move.w import_progress(pc),d0
        bsr text_decimal
        move.b #'/',(a1)+
        move.w import_total(pc),d0
        bsr text_decimal
        clr.b (a1)
        lea import_title(pc),a1
        moveq #11,d1
        bsr import_center
        lea import_line(pc),a1
        movea.l a3,a0
        moveq #23,d0
.name:  move.b (a0)+,(a1)+
        dbeq d0,.name
        clr.b (a1)
        lea import_line(pc),a2
.trim:  cmpa.l a2,a1
        bls.s .trimmed
        move.b -(a1),d0
        beq.s .cut
        cmpi.b #' ',d0
        bne.s .trimmed
.cut:   clr.b (a1)
        bra.s .trim
.trimmed:
        lea import_info(pc),a1
        moveq #14,d1
        bsr import_center
        move.b $5eb75,-(sp)
        move.b #$40,$5eb75
        jsr $645c6
        moveq #1,d0
        jsr $59806
        lea import_title(pc),a0
        bsr import_print
        lea import_info(pc),a0
        bsr import_print
        jsr $6483e
        move.b (sp)+,$5eb75
        ; Two VBLs: the screen is shown whole before a write shows the system.
        move.w auto_vbl_count(pc),d1
.shown: move.w auto_vbl_count(pc),d0
        sub.w d1,d0
        cmpi.w #2,d0
        blo.s .shown
import_shown:
        movem.l (sp)+,d0-d7/a0-a6
        rts

; The question "Import old tracks?", Yes and No, and below them "Found n
; tracks and n records", from the startup also a line on Practise. Every
; text stays on line 11 or below: the menu box keeps parts of line 9, and
; the game's font has no comma.
import_ask_texts:
        movem.l d0-d1/a0-a1,-(sp)
        lea import_text_ask(pc),a0
        lea import_title(pc),a1
        moveq #11,d1
        bsr import_center_from
        lea import_rows(pc),a1
        lea import_text_yes(pc),a0
        bsr text_append
        clr.b (a1)
        lea import_rows+32(pc),a1
        lea import_text_no(pc),a0
        bsr text_append
        clr.b (a1)
        lea import_line(pc),a1
        lea import_text_found(pc),a0
        bsr text_append
        move.l import_found_tracks(pc),d0
        bsr import_bits
        move.w d0,d1
        move.l import_found_records(pc),d0
        bsr import_bits
        exg d0,d1
        bsr import_counts
        lea import_info(pc),a1
        moveq #18,d1
        bsr import_center
        tst.w import_from_startup-module_start(a5)
        beq.s .done
        lea import_text_later(pc),a0
        moveq #20,d1
        bsr import_center_from
.done:  movem.l (sp)+,d0-d1/a0-a1
        rts

; D0 tracks, D1 records: "n tracks and n records", either alone when the
; other is none, at A1, ended by zero.
import_counts:
        movem.l d0-d2/a0,-(sp)
        move.w d1,d2
        tst.w d0
        beq.s .records
        lea import_text_track(pc),a0
        bsr import_count
        tst.w d2
        beq.s .end
        lea import_text_and(pc),a0
        bsr text_append
.records:
        move.w d2,d0
        lea import_text_record(pc),a0
        bsr import_count
.end:   clr.b (a1)
        movem.l (sp)+,d0-d2/a0
        rts

; "Added n tracks and n records" (30 characters at most, the box holds 32)
; or "Nothing new to import"; the rows Keep and Delete (or Continue); the
; moved, already there and skipped lines.
import_done_texts:
        movem.l d0-d2/a0-a1,-(sp)
        lea import_title(pc),a1
        move.w import_tracks(pc),d0
        or.w import_records(pc),d0
        bne.s .imported
        lea import_text_nothing(pc),a0
        moveq #11,d1
        bsr import_center_from
        bra.s .rows
.imported:
        lea import_line(pc),a1
        lea import_text_added(pc),a0
        bsr text_append
        move.w import_tracks(pc),d0
        move.w import_records(pc),d1
        bsr import_counts
        lea import_title(pc),a1
        moveq #11,d1
        bsr import_center
.rows:  lea import_rows(pc),a1
        lea import_text_keep(pc),a0
        moveq #18,d2            ; info lines every other line below the rows
        move.l import_done_tracks(pc),d0
        or.l import_done_records(pc),d0
        bne.s .keep
        lea import_text_continue(pc),a0
        moveq #16,d2
.keep:  bsr text_append
        clr.b (a1)
        lea import_rows+32(pc),a1
        lea import_text_delete(pc),a0
        bsr text_append
        clr.b (a1)
        ; Info lines
        lea import_info(pc),a1
        clr.b (a1)
        move.w import_moved(pc),d0
        beq.s .already
        lea import_text_moved(pc),a0
        cmpi.w #1,d0
        bne.s .moved
        lea import_text_moved_one(pc),a0
.moved: bsr.s .line
.already:
        move.w import_already(pc),d0
        beq.s .skipped
        lea import_text_already(pc),a0
        cmpi.w #1,d0
        bne.s .there
        lea import_text_already_one(pc),a0
.there: bsr.s .line
.skipped:
        move.w import_skipped(pc),d0
        beq.s .done
        lea import_text_skipped(pc),a0
        cmpi.w #1,d0
        bne.s .skip
        lea import_text_skipped_one(pc),a0
.skip:  bsr.s .line
.done:  movem.l (sp)+,d0-d2/a0-a1
        rts
; D0 count, A0 the text after it, A1 the info so far, D2 its line.
.line:  move.l a1,-(sp)
        lea import_line(pc),a1
        bsr text_decimal
        bsr text_append
        clr.b (a1)
        movea.l (sp)+,a1
.end:   tst.b (a1)+
        bne.s .end
        subq.l #1,a1
        move.w d2,d1
        bsr import_center
        addq.w #2,d2
        rts

import_stopped_texts:
        movem.l d0-d1/a0-a1,-(sp)
        lea import_text_stopped(pc),a0
        lea import_title(pc),a1
        moveq #11,d1
        bsr import_center_from
        lea import_rows(pc),a1
        lea import_text_continue(pc),a0
        bsr text_append
        clr.b (a1)
        lea import_text_readback(pc),a0
        lea import_info(pc),a1
        moveq #16,d1
        bsr import_center_from
        movem.l (sp)+,d0-d1/a0-a1
        rts

; D0 count, A0 "track" or "record": "n track" or "n tracks" at A1.
import_count:
        bsr text_decimal
        move.b #' ',(a1)+
        bsr text_append
        cmpi.w #1,d0
        beq.s .one
        move.b #'s',(a1)+
.one:   rts

; import_line centred on line D1 at A1: pen code, text, zero; A1 at that zero.
import_center:
        lea import_line(pc),a0
; The same for the text at A0.
import_center_from:
        movem.l d0/a0,-(sp)
        moveq #0,d0
.length:
        tst.b (a0)+
        beq.s .counted
        addq.w #1,d0
        bra.s .length
.counted:
        movea.l 4(sp),a0
        neg.w d0
        addi.w #IMPORT_SCREEN_COLUMNS+1,d0
        asr.w #1,d0
        move.b #$1f,(a1)+
        move.b d0,(a1)+
        move.b d1,(a1)+
.copy:  move.b (a0)+,(a1)+
        bne.s .copy
        subq.l #1,a1
        movem.l (sp)+,d0/a0
        rts

import_root: dc.b 0
import_word_track: dc.b 'track',0
import_word_index: dc.b 'index',0
import_path: dc.b 'Track00.sct',0
import_index_name: dc.b 'TrackIndex',0
import_marker_name: dc.b 'tracks/Imported',0
import_marker_text: dc.b 'Old tracks: the import question was answered.',10
import_marker_end:
import_records_name: dc.b 'Lap records',0
import_text_ask: dc.b 'Import old tracks?',0
import_text_found: dc.b 'Found ',0
import_text_and: dc.b ' and ',0
import_text_yes: dc.b 'Yes',0
import_text_no: dc.b 'No',0
import_text_track: dc.b 'track',0
import_text_record: dc.b 'record',0
import_text_later: dc.b 'Practise can import them later',0
import_text_importing: dc.b 'Importing ',0
import_text_deleting: dc.b 'Deleting ',0
import_text_added: dc.b 'Added ',0
import_text_nothing: dc.b 'Nothing new to import',0
import_text_keep: dc.b 'Keep old files',0
import_text_delete: dc.b 'Delete old files',0
import_text_continue: dc.b 'Continue',0
import_text_moved: dc.b ' tracks moved to free slots',0
import_text_moved_one: dc.b ' track moved to a free slot',0
import_text_already: dc.b ' tracks were already there',0
import_text_already_one: dc.b ' track was already there',0
import_text_skipped: dc.b ' files skipped and left as is',0
import_text_skipped_one: dc.b ' file skipped and left as is',0
import_text_stopped: dc.b 'Import stopped',0
import_text_readback: dc.b 'A file read back wrong',0
import_row_text: dc.b 'Import Old Tracks',0
        even
import_checked: dc.w 0
import_from_startup: dc.w 0
import_practise: dc.w 0
import_menu_last: dc.w 0
import_deleting: dc.w 0
import_found_tracks: dc.l 0
import_found_records: dc.l 0
import_found_index: dc.w 0
import_total: dc.w 0
import_dry: dc.w 0
; Cleared by each import; from import_run_state on again after the count.
import_results:
import_valid_tracks: dc.l 0
import_valid_records: dc.l 0
import_run_state:
import_handled_tracks: dc.l 0
import_used_records: dc.l 0
import_done_tracks: dc.l 0
import_done_records: dc.l 0
import_tracks: dc.w 0
import_records: dc.w 0
import_moved: dc.w 0
import_already: dc.w 0
import_skipped: dc.w 0
import_failed: dc.w 0
import_progress: dc.w 0
import_placed: dcb.w IMPORT_SLOTS,0     ; per old track: 1 + the slot it was written to
import_results_end:
import_title: dcb.b 48,0
import_line: dcb.b 48,0
import_rows: dcb.b 64,0
import_info: dcb.b 112,0
        even
