; Read and write the custom track files in the tracks drawer.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Custom tracks as files of the WHDLoad install, read and written whole
; through the slave's file service. A5=module base. Exclusive synchronous I/O
; in the editor's main loop or in the game's menus. STORAGE_SLOTS slots, a
; build define.
; tracks/TrackNNN.sct is an IFF FORM SCTF: TRAK the SCTR model as it stands in
; editor_track, STAT the class the editor computed for it (1 Draft, 2 Ready,
; the checker's version and TRAK's own CRC), unknown chunks, which a Save
; keeps, and CRC, the CRC-32 of the file before that chunk. Files are at most
; STORAGE_FILE_BYTES; the buffers are Fast areas outside the module image
; (STORAGE_FILE, STORAGE_EXTRAS, RECORDS_CACHE), and the builder gives
; STORAGE_FILE_BYTES.
FS_SIZE equ 1
FS_LOAD equ 2
FS_SAVE equ 3
FS_LIST equ 4
FS_DELETE equ 5
FS_EXAMINE equ 6
; A listing gives each name a FileInfoBlock fib_FileName of this many bytes.
FS_LIST_NAME equ 108
; FS_EXAMINE fills a FileInfoBlock of FIB_BYTES: fib_DirEntryType, above 0 a
; directory, and the low byte of fib_Protection, bit 0 set: not deletable.
FIB_BYTES equ 260
FIB_DIR_ENTRY_TYPE equ 4
FIB_PROTECTION_LOW equ 119
ID_FORM equ $464f524d
ID_CRC equ $43524320
ID_SCTF equ $53435446
ID_SCTR equ $53435452
ID_TRAK equ $5452414b
ID_STAT equ $53544154
ID_SCIE equ $53434945
; The catalog row of a slot, CATALOG_ROW bytes (storage_entry_fill). The
; classes CLASS_DRAFT and CLASS_READY are those of the STAT chunk.
CATALOG_KIND equ 0              ; .l CATALOG_FILE, CATALOG_BUNDLED or 0 none
CATALOG_CRC equ 4               ; .l TRAK's CRC
CATALOG_NAME equ 8              ; the name, SCTR_NAME_BYTES
CATALOG_CLASS equ 32            ; .w CLASS_*
CATALOG_NEWER equ 34            ; .w 1 if it needs a later version
CATALOG_IDENTITY equ 36         ; the SCTR identity, SCTR_IDENTITY_BYTES
CATALOG_LISTED equ 62           ; .w 1 if the listing of tracks/ has its file
CATALOG_FILE equ 1
CATALOG_BUNDLED equ 3
CLASS_EMPTY equ 0
CLASS_UNUSABLE equ 3
editor_storage_keys:
        tst.w storage_modal-module_start(a5)
        bne storage_modal_keys
        tst.w editing_prompt-module_start(a5)
        bne.s .done
        tst.w building_exit-module_start(a5)
        bne.s .done
        tst.w place_active-module_start(a5)
        bne.s .load_key
        cmpi.b #KEY_DOWN,editor_input_keys+$50(a5)       ; F1
        beq.s .save
.load_key:
        cmpi.b #KEY_DOWN,editor_input_keys+$28(a5)
        beq.s .load
.done:
        rts
.save:
        bsr editor_release
        clr.w storage_continue-module_start(a5)
        bra storage_open_save
.load:
        ; S/L explicitly discard only the unconfirmed preview.
        bsr ui_choose_end
        moveq #2,d0
        bra editing_request

; The WHDLoad slave's file service (FS_* in patches/whdload/slave.s): D0
; operation, A0 name, A1 buffer, D1 byte count. Returns D0 with the flags set
; from it and preserves the other registers. Without the slave (the disk
; started as such) D0 = 0 and storage_service stays 0. Interrupts are masked
; during the call; then come the game's CIA setup and the editor's input
; state, since a file access may show the system.
storage_file:
        movem.l d1-d7/a0-a6,-(sp)
        move.l d0,d7
        move.l storage_service(pc),d0
        bne.s .found
        bsr storage_service_find
        move.l storage_service(pc),d0
        beq.s .done
.found:
        movea.l d0,a2
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.l d7,d0
        jsr (a2)
        move.l d0,d7
        bsr cache_flush
        jsr $ee8a.l           ; original I/O return's CIA timer/IRQ setup
        bsr editor_input_resync
        move.w (sp)+,sr
        move.l d7,d0
.done:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts

; storage_service = the slave's file service, or 0. The slave jumps from the
; game's driver at $62e86 to its own driver, which has the service's tag in
; front: 'SCFS', the version, and the service's offset from the driver.
FILE_SERVICE_VERSION equ 2
storage_service_find:
        movem.l d0/a0,-(sp)
        clr.l storage_service-module_start(a5)
        cmpi.w #$4ef9,$62e86.l
        bne.s .done
        movea.l $62e88.l,a0
        cmpi.l #$53434653,-8(a0)
        bne.s .done
        cmpi.w #FILE_SERVICE_VERSION,-4(a0)
        bne.s .done
        move.w -2(a0),d0
        adda.w d0,a0
        move.l a0,storage_service-module_start(a5)
.done:
        movem.l (sp)+,d0/a0
        rts

; A0 source, A1 destination, D0 byte count divisible by four.
storage_copy:
        lsr.w #2,d0
        subq.w #1,d0
.loop:
        move.l (a0)+,(a1)+
        dbra d0,.loop
        rts
; The track and its gap words: validation borrows them.
storage_backup:
        lea editor_track(pc),a0
        lea storage_work(pc),a1
        move.w #EDITOR_STATE_BYTES,d0
        bra storage_copy
storage_restore:
        lea storage_work(pc),a0
        lea editor_track(pc),a1
        move.w #EDITOR_STATE_BYTES,d0
        bra storage_copy

; A0 data, D0 count. D0 returns CRC32, A0 advances; D1-D3 clobbered. A byte
; at a time from storage_crc_table (the builder's, of polynomial $edb88320).
storage_crc:
        move.l a1,-(sp)
        lea storage_crc_table(pc),a1
        move.w d0,d2
        subq.w #1,d2
        moveq #-1,d0
.byte:  moveq #0,d1
        move.b (a0)+,d1
        eor.b d0,d1
        lsl.w #2,d1
        lsr.l #8,d0
        move.l (a1,d1.w),d3
        eor.l d3,d0
        dbra d2,.byte
        not.l d0
        movea.l (sp)+,a1
        rts


; A1 = the file buffer.
storage_buffer:
        lea STORAGE_FILE(a5),a1
        rts

; D0 slot, D1 0 for the track or 1 for its records. A0 = storage_path, the
; file's name: tracks/TrackNNN.sct or .rec, NNN = slot + 1.
storage_path_make:
        movem.l d0/a1,-(sp)
        lea storage_path+12(pc),a1
        bsr storage_number
        bsr.s storage_suffix_put
        lea storage_path(pc),a0
        movem.l (sp)+,d0/a1
        rts

; D1 0 for a track or 1 for its records: that suffix and its zero at A1, which
; advances past them. A0 changes.
storage_suffix_put:
        lea storage_suffix_track(pc),a0
        tst.w d1
        beq.s .copy
        lea storage_suffix_records(pc),a0
.copy:  move.b (a0)+,(a1)+
        bne.s .copy
        rts

; D0 slot. Reads its track file, or without one the module's bundled track
; of the slot, to the file buffer. D0 = its size (storage_size, flags set), 0
; if the slot is empty, -1 if the file is too large to be a track file.
; storage_from_module = 1 for a bundled track.
storage_slot_read:
        movem.l d1-d2/a0-a2,-(sp)
        clr.w storage_from_module-module_start(a5)
        move.w d0,d2
        moveq #0,d1
        bsr storage_path_make
        bsr storage_buffer
        move.l #STORAGE_FILE_BYTES,d1
        moveq #FS_LOAD,d0
        bsr storage_file
        beq.s storage_bundled_in
        cmp.l d1,d0
        bls.s storage_slot_done
        moveq #-1,d0
        bra.s storage_slot_done
; D0 slot without a file in tracks/: its bundled track, as storage_slot_read.
storage_bundled_read:
        movem.l d1-d2/a0-a2,-(sp)
        clr.w storage_from_module-module_start(a5)
        move.w d0,d2
        bsr storage_buffer
storage_bundled_in:
        lea storage_bundled(pc),a0
        move.w (a0)+,d1
        bra.s .test
.entry: cmp.w (a0),d2
        beq.s .found
        addq.l #6,a0
.test:  dbra d1,.entry
        moveq #0,d0
        bra.s .done
.found: moveq #0,d0
        move.w 2(a0),d0
        lea storage_bundled(pc),a2
        adda.w 4(a0),a2
        move.w d0,d1
        subq.w #1,d1
.copy:  move.b (a2)+,(a1)+
        dbra d1,.copy
        move.w #1,storage_from_module-module_start(a5)
        bra.s storage_slot_done
.done:  moveq #0,d0
storage_slot_done:
        move.l d0,storage_size-module_start(a5)
        movem.l (sp)+,d1-d2/a0-a2
        tst.l d0
        rts

; Marks the catalog row (CATALOG_LISTED, which storage_entry_fill clears) of every
; tracks/TrackNNN.sct that tracks/ holds, from one listing. Without the
; folder none. A listing that may have ended early marks every row, and the
; scan then reads each slot.
storage_listing:
        movem.l d0-d3/a0-a3,-(sp)
        bsr storage_folder_check
        beq.s .done
        lea storage_folder_name(pc),a0
        lea STORAGE_LISTING(a5),a1
        move.l #STORAGE_LISTING_BYTES,d1
        moveq #FS_LIST,d0
        bsr storage_file
        move.l d0,d2
        movea.l a1,a2
        movea.l a1,a0
        adda.l #STORAGE_LISTING_BYTES-FS_LIST_NAME,a0
        bra.s .test
.name:  cmpa.l a0,a2
        bhs.s .all
        bsr storage_name_slot
        bmi.s .test
        bsr storage_entry_of
        move.w #1,CATALOG_LISTED(a3)
.test:  subq.l #1,d2
        bpl.s .name
        cmpa.l a0,a2
        blo.s .done
.all:   moveq #0,d0
        bsr storage_entry_of
        move.w #STORAGE_SLOTS-1,d1
.mark:  move.w #1,CATALOG_LISTED(a3)
        adda.w #CATALOG_ROW,a3
        dbra d1,.mark
.done:  movem.l (sp)+,d0-d3/a0-a3
        rts

; A2 a listed name, A2 after its zero byte on return. D0 (flags set) its slot
; if it is TrackNNN.sct of a slot, in any case, otherwise -1.
storage_name_slot:
        movem.l d1-d3/a0,-(sp)
        moveq #-1,d0
        moveq #0,d3
        lea storage_name_pattern(pc),a0
.char:  moveq #0,d1
        move.b (a2)+,d1
        beq.s .ended
        move.b (a0)+,d2
        beq.s .skip
        cmpi.b #'#',d2
        beq.s .digit
        ori.b #$20,d1
        cmp.b d2,d1
        beq.s .char
.skip:  tst.b (a2)+
        bne.s .skip
        bra.s .done
.digit: subi.b #'0',d1
        cmpi.b #9,d1
        bhi.s .skip
        mulu.w #10,d3
        add.w d1,d3
        bra.s .char
.ended: tst.b (a0)
        bne.s .done
        subq.w #1,d3
        cmpi.w #STORAGE_SLOTS,d3
        bhs.s .done
        moveq #0,d0
        move.w d3,d0
.done:  movem.l (sp)+,d1-d3/a0
        tst.l d0
        rts

; A0 name: its FileInfoBlock in the file buffer, A1 = it. D0 (flags set) as
; storage_file returns it; D1 changes.
storage_examine:
        bsr storage_buffer
        move.l #FIB_BYTES,d1
        moveq #FS_EXAMINE,d0
        bra storage_file

; D0 = 1 (flags set) when tracks/ is a directory. Examined once a session:
; while WHDLoad runs the game, no directory appears or goes. A save into a
; missing directory would end WHDLoad with an error.
storage_folder_check:
        movem.l d1/a0-a1,-(sp)
        move.w storage_folder(pc),d0
        bne.s .known
        lea storage_folder_name(pc),a0
        bsr.s storage_examine
        beq.s .missing
        moveq #1,d0
        tst.l FIB_DIR_ENTRY_TYPE(a1)
        bgt.s .store
.missing:
        moveq #-1,d0
.store: move.w d0,storage_folder-module_start(a5)
.known: movem.l (sp)+,d1/a0-a1
        tst.w d0
        bpl.s .present
        moveq #0,d0
        rts
.present:
        moveq #1,d0
        rts

; A4 file, D5 chunk offset, D6 file size. D0 = offset of the next chunk, or 0
; if this one does not fit in the file; D3 its id, D4 its data length. The
; data is padded to an even length.
storage_chunk:
        moveq #0,d0
        move.l d5,d3
        addq.l #8,d3
        cmp.l d6,d3
        bhi.s .done
        move.l 4(a4,d5.l),d4
        cmp.l d6,d4
        bhi.s .done
        move.l d4,d0
        addq.l #1,d0
        bclr #0,d0
        add.l d3,d0
        cmp.l d6,d0
        bls.s .fits
        moveq #0,d0
        rts
.fits:  move.l (a4,d5.l),d3
.done:  rts

; A4 file, D0 size, D1 FORM type. D0 = 1 (flags set) if the FORM holds: its
; length, every chunk within it, and last the CRC chunk with the CRC-32 of
; everything before it.
storage_form:
        movem.l d1-d6/a0,-(sp)
        move.l d0,d6
        cmpi.l #24,d6
        blo.s .bad
        cmpi.l #STORAGE_FILE_BYTES,d6
        bhi.s .bad
        cmpi.l #ID_FORM,(a4)
        bne.s .bad
        cmp.l 8(a4),d1
        bne.s .bad
        move.l 4(a4),d0
        addq.l #8,d0
        cmp.l d6,d0
        bne.s .bad
        moveq #12,d5
.chunk: bsr storage_chunk
        tst.l d0
        beq.s .bad
        cmpi.l #ID_CRC,d3
        beq.s .crc
        move.l d0,d5
        bra.s .chunk
.crc:   cmpi.l #4,d4
        bne.s .bad
        cmp.l d6,d0
        bne.s .bad
        movea.l a4,a0
        move.l d5,d0
        bsr storage_crc
        cmp.l 8(a4,d5.l),d0
        bne.s .bad
        moveq #1,d0
        bra.s .done
.bad:   moveq #0,d0
.done:  movem.l (sp)+,d1-d6/a0
        tst.l d0
        rts

; A4 file, A1 the end of its last chunk: the CRC chunk last, then the FORM
; length and the CRC as storage_form checks them. D0 = the file's bytes, A1
; its end; the other registers are kept.
storage_form_close:
        move.l #ID_CRC,(a1)+
        moveq #4,d0
        move.l d0,(a1)+
        addq.l #4,a1
        move.l a1,d0
        sub.l a4,d0
; A4 file, D0 its bytes, the CRC chunk last: the FORM length and the CRC
; renewed. Every register is kept.
storage_form_seal:
        movem.l d0-d3/a0,-(sp)
        subq.l #8,d0
        move.l d0,4(a4)
        subq.l #4,d0
        movea.l a4,a0
        bsr storage_crc
        move.l d0,8(a0)
        movem.l (sp)+,d0-d3/a0
        rts

; A4 file of D0 bytes that storage_form accepted, D1 chunk id. D0 = offset
; of the first such chunk's data or 0, D1 its length, D2 the number of such
; chunks.
storage_find:
        movem.l d3-d7/a0,-(sp)
        move.l d0,d6
        moveq #12,d5
        moveq #0,d2
        moveq #0,d7
        suba.l a0,a0
.loop:  bsr storage_chunk
        cmpi.l #ID_CRC,d3
        beq.s .end
        cmp.l d1,d3
        bne.s .next
        tst.l d2
        bne.s .count
        move.l d5,d7
        addq.l #8,d7
        movea.l d4,a0
.count: addq.l #1,d2
.next:  move.l d0,d5
        bra.s .loop
.end:   move.l d7,d0
        move.l a0,d1
        movem.l (sp)+,d3-d7/a0
        rts

; A0 SCTR, D1.l its bytes in the file. D0 (flags set) = 1 if its frame
; holds: the id, version 1, SCTR_MIN_BYTES..EDITOR_TRACK_BYTES bytes and its
; own length; 2 if it is of a later version, whatever its size; 0 if not.
; The other registers are kept.
storage_sctr_check:
        moveq #0,d0
        cmpi.l #6,d1
        blo.s .done
        cmpi.l #ID_SCTR,SCTR_ID(a0)
        bne.s .done
        cmpi.w #1,SCTR_VERSION(a0)
        blo.s .done
        bhi.s .newer
        cmpi.l #SCTR_MIN_BYTES,d1
        blo.s .done
        cmpi.l #EDITOR_TRACK_BYTES,d1
        bhi.s .done
        cmp.w SCTR_LENGTH(a0),d1
        bne.s .done
        moveq #1,d0
        rts
.newer: moveq #2,d0
        rts
.done:  tst.l d0
        rts

; A4 track file, D0 size. D0 (flags set) = 1 if it is a track file of this
; version, 2 if its TRAK is of a later SCTR version, 0 if damaged. Then
; storage_trak and storage_trak_bytes locate TRAK, and storage_known is the
; class in STAT (1 Draft, 2 Ready) if STAT is of this checker and of this
; TRAK, otherwise 0.
storage_track_check:
        movem.l d1-d3/d6/a0,-(sp)
        clr.w storage_known-module_start(a5)
        move.l d0,d6
        move.l #ID_SCTF,d1
        bsr storage_form
        beq .bad
        move.l d6,d0
        move.l #ID_TRAK,d1
        bsr storage_find
        cmpi.l #1,d2
        bne .bad
        move.w d0,storage_trak-module_start(a5)
        move.w d1,storage_trak_bytes-module_start(a5)
        lea (a4,d0.l),a0
        bsr storage_sctr_check
        beq .bad
        subq.l #1,d0
        bne.s .newer
        move.l -4(a0,d1.l),d3
        move.l d6,d0
        move.l #ID_STAT,d1
        bsr storage_find
        cmpi.l #1,d2
        bhi.s .bad
        bne.s .ok
        cmpi.l #8,d1
        blo.s .ok
        lea (a4,d0.l),a0
        cmpi.w #STAT_VERSION,2(a0)
        bne.s .ok
        cmp.l 4(a0),d3
        bne.s .ok
        move.w (a0),d0
        beq.s .ok
        cmpi.w #CLASS_READY,d0
        bhi.s .ok
        move.w d0,storage_known-module_start(a5)
.ok:    moveq #1,d0
        bra.s .done
.newer: moveq #2,d0
        bra.s .done
.bad:   moveq #0,d0
.done:  movem.l (sp)+,d1-d3/d6/a0
        tst.l d0
        rts

; D0 slot: storage_slot_read, then as storage_read_track.
storage_slot_track:
        bsr storage_slot_read
; After storage_slot_read or storage_bundled_read, with D0 and its flags as
; they return: A4 = the file buffer. D0 (flags set) = 1 when it holds a track
; file of this version, 0 when the slot is empty, -1 otherwise (too large,
; damaged or of a later version). A1 changes.
storage_read_track:
        ble.s .done
        bsr storage_buffer
        movea.l a1,a4
        bsr storage_track_check
        subq.l #1,d0
        beq.s .current
        moveq #-1,d0
.done:  rts
.current:
        moveq #1,d0
        rts

; TRAK of the checked file at A4 to editor_track as storage_sctr_load does.
; D0 = editor_model_build's result.
storage_trak_load:
        move.l a0,-(sp)
        moveq #0,d0
        move.w storage_trak(pc),d0
        lea (a4,d0.l),a0
        move.w storage_trak_bytes(pc),d0
        bsr.s storage_sctr_load
        movea.l (sp)+,a0
        rts

; A0 an SCTR of D0.w bytes to editor_track, the rest of it zero, no gap. D0
; changes; D1, A0 and A1 are kept.
storage_sctr_copy:
        movem.l d1/a0-a1,-(sp)
        move.w d0,d1
        lea editor_track(pc),a1
        move.w #EDITOR_TRACK_BYTES/4-1,d0
.clear: clr.l (a1)+
        dbra d0,.clear
        lea editor_track(pc),a1
        subq.w #1,d1
.copy:  move.b (a0)+,(a1)+
        dbra d1,.copy
        clr.l editor_gap-module_start(a5)
        movem.l (sp)+,d1/a0-a1
        rts
; The same, then the model. D0 = editor_model_build's result.
storage_sctr_load:
        bsr.s storage_sctr_copy
        bra editor_model_build

; The catalog row A3 from the track file at A4 (D0 bytes, storage_from_module
; set). Checking a file without a valid STAT borrows editor_track; the caller
; restores it. Row: 0.l 1 file or 3 bundled track (0 none), 4.l TRAK's CRC,
; 8 name[24], 32.w class (0 empty, 1 Draft, 2 Ready, 3 unusable), 34.w 1 if
; it needs a later version, 36 SCTR identity[16], rest zero (CATALOG_*).
storage_entry_fill:
        movem.l d0-d2/a0-a2,-(sp)
        movea.l a3,a1
        moveq #CATALOG_ROW/4-1,d1
.clear: clr.l (a1)+
        dbra d1,.clear
        bsr storage_track_check
        beq.s .unusable
        cmpi.w #2,d0
        beq.s .newer
        moveq #0,d0
        move.w storage_trak(pc),d0
        lea (a4,d0.l),a0
        moveq #CATALOG_FILE,d0
        tst.w storage_from_module-module_start(a5)
        beq.s .file
        moveq #CATALOG_BUNDLED,d0
.file:  move.l d0,CATALOG_KIND(a3)
        move.w storage_trak_bytes(pc),d0
        move.l -4(a0,d0.w),CATALOG_CRC(a3)
        movea.l a0,a2
        lea SCTR_NAME(a0),a0
        lea CATALOG_NAME(a3),a1
        moveq #SCTR_NAME_BYTES,d0
        bsr storage_copy
        lea SCTR_IDENTITY(a2),a0
        lea CATALOG_IDENTITY(a3),a1
        moveq #SCTR_IDENTITY_BYTES,d0
        bsr storage_copy
        move.w storage_known(pc),d0
        bne.s .class
        bsr storage_trak_load
        tst.w d0
        beq.s .unusable
        bsr storage_stat_class
.class: move.w d0,CATALOG_CLASS(a3)
        bra.s .done
.newer: move.w #1,CATALOG_NEWER(a3)
.unusable:
        move.w #CLASS_UNUSABLE,CATALOG_CLASS(a3)
.done:  movem.l (sp)+,d0-d2/a0-a2
        rts

; The unknown chunks of the file at A4 (storage_size bytes), in their order,
; to the extras buffer, for the next Save.
storage_extras_keep:
        movem.l d0-d6/a0-a2,-(sp)
        clr.w storage_extras_bytes-module_start(a5)
        lea STORAGE_EXTRAS(a5),a2
        move.l storage_size(pc),d6
        moveq #12,d5
.loop:  bsr storage_chunk
        cmpi.l #ID_CRC,d3
        beq.s .done
        cmpi.l #ID_TRAK,d3
        beq.s .next
        cmpi.l #ID_STAT,d3
        beq.s .next
        lea (a4,d5.l),a0
        move.l d0,d1
        sub.l d5,d1
        add.w d1,storage_extras_bytes-module_start(a5)
        subq.w #1,d1
.copy:  move.b (a0)+,(a2)+
        dbra d1,.copy
.next:  move.l d0,d5
        bra.s .loop
.done:  movem.l (sp)+,d0-d6/a0-a2
        rts

; Save: the model, then tracks/TrackNNN.sct of storage_slot written whole. A
; WHDLoad write fails only by ending WHDLoad, so no readback (which would
; come from WHDLoad's cache anyway).
editor_save:
        movem.l d0-d7/a0-a4,-(sp)
        move.w #STORAGE_SAY_SAVE_FAILED,storage_status-module_start(a5)
        bsr editor_model_build
        tst.w d0
        beq storage_save_done
        bsr storage_folder_check
        beq storage_save_folder
        lea editor_track(pc),a0
        moveq #0,d0
        move.w SCTR_LENGTH(a0),d0
        moveq #0,d1
        move.w storage_extras_bytes(pc),d1
        bsr storage_track_form
        beq storage_save_done
        move.l d0,d5
        move.w storage_slot(pc),d0
        moveq #0,d1
        bsr storage_path_make
        movea.l a4,a1
        move.l d5,d1
        moveq #FS_SAVE,d0
storage_write_begin:
        bsr storage_file
storage_write_end:
        beq storage_save_done
        bsr editing_mark_saved
        move.w storage_slot(pc),storage_active_slot-module_start(a5)
        move.w #STORAGE_SAY_SAVED,storage_status-module_start(a5)
        clr.w editor_view_valid-module_start(a5)
        move.w storage_slot(pc),d0
        move.l d5,d1
        bsr storage_row_written
        bra.s storage_save_done
storage_save_folder:
        move.w #STORAGE_SAY_NO_DRAWER,storage_status-module_start(a5)
storage_save_done:
        bsr editor_model_view
        movem.l (sp)+,d0-d7/a0-a4
        rts

; A0 an SCTR of D0.l bytes (a multiple of 4), D1.l bytes of unknown chunks at
; STORAGE_EXTRAS to keep (0 none): its track file in the file buffer, A4 = it,
; closed. D0 (flags set) = the file's bytes, or 0 when it would be larger than
; STORAGE_FILE_BYTES. D1, A0 and A1 change.
storage_track_form:
        bsr storage_buffer
        movea.l a1,a4
        move.l #ID_FORM,(a1)+
        addq.l #4,a1                    ; the length: storage_form_close
        move.l #ID_SCTF,(a1)+
        move.l #ID_TRAK,(a1)+
        move.l d0,(a1)+
        bsr storage_copy
        move.l #ID_STAT,(a1)+
        moveq #8,d0
        move.l d0,(a1)+
        bsr storage_stat_class
        move.w d0,(a1)+
        move.w #STAT_VERSION,(a1)+
        move.l -4(a0),(a1)+             ; the CRC of TRAK
        ; The unknown chunks of the loaded track, then CRC.
        move.l a1,d0
        sub.l a4,d0
        add.l d1,d0
        addi.l #12,d0
        cmpi.l #STORAGE_FILE_BYTES,d0
        bhi.s .large
        lea STORAGE_EXTRAS(a5),a0
        bra.s .extras_next
.extras:
        move.b (a0)+,(a1)+
.extras_next:
        dbra d1,.extras
        bsr storage_form_close
        tst.l d0
        rts
.large: moveq #0,d0
        rts
        ; Import writes no extras and never reaches the limit.
        ifgt EDITOR_TRACK_BYTES+48-STORAGE_FILE_BYTES
        fail "A track file without extras can exceed STORAGE_FILE_BYTES"
        endif

; D0 = the STAT class of the model: CLASS_READY when it is Ready, else
; CLASS_DRAFT.
storage_stat_class:
        moveq #CLASS_DRAFT,d0
        cmpi.w #PRACTICE_READY,practice_class-module_start(a5)
        bne.s .done
        moveq #CLASS_READY,d0
.done:  rts

; D0 slot, D1 the bytes of the track file just written from A4: its catalog row
; from the file, whose STAT is current. A3 = the row; D0 changes.
storage_row_written:
        bsr storage_entry_of
        clr.w storage_from_module-module_start(a5)
        move.l d1,storage_size-module_start(a5)
        move.l d1,d0
        bra storage_entry_fill

; Load storage_slot: its file or bundled track, checked again, to the editor.
editor_load:
        movem.l d0-d7/a0-a4,-(sp)
        move.w #STORAGE_SAY_LOAD_FAILED,storage_status-module_start(a5)
        bsr storage_backup
        move.w storage_slot(pc),d0
        bsr storage_slot_track
        beq.s .empty
        bmi.s .done
        bsr storage_trak_load
        tst.w d0
        beq.s .restore
        bsr storage_extras_keep
        move.w storage_slot(pc),storage_active_slot-module_start(a5)
        bsr editing_opened
        bra.s .done
.restore:
        bsr storage_restore
        bra.s .done
.empty:
        move.w #STORAGE_SAY_EMPTY,storage_status-module_start(a5)
.done:
        bsr editor_model_view
        movem.l (sp)+,d0-d7/a0-a4
        rts

; Independent 8x7 CPU text into four Chip bitplanes; no game font globals.
editor_storage_text:
        bsr hud_status_line
        bsr hud_count_line
        tst.w custom_pick-module_start(a5)
        beq.s .editor
        lea ui_next_count(pc),a0        ; the Custom Tracks list says nothing of the editor's track
        clr.b (a0)
        lea ui_next_word(pc),a0
        clr.b (a0)
        rts
.editor:
        tst.w storage_status-module_start(a5)
        bne.s .result
        tst.w building_dirty-module_start(a5)
        beq.s .done
        lea storage_unsaved(pc),a0
        moveq #UI_SAY_UNSAVED,d0
        bra ui_status_put
.result:
        bsr storage_message
        moveq #UI_SAY_RESULT,d0
        bra ui_status_put
.done:  rts

; storage_status -> A0 text.
storage_message:
        move.w storage_status(pc),d0
        cmpi.w #FINISH_STATUS,d0
        beq.s .finish
        add.w d0,d0
        lea storage_messages(pc),a0
        adda.w (a0,d0.w),a0
        rts
.finish:
        lea finish_text(pc),a0
        rts

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
        move.b d0,SCREEN_PLANE_BYTES(a3)
        move.b d0,2*SCREEN_PLANE_BYTES(a3)
        move.b d0,3*SCREEN_PLANE_BYTES(a3)
        adda.w #SCREEN_ROW_BYTES,a3
        dbra d1,.row
        addq.l #1,a1
        bra.s storage_text_line
.done:
        rts
storage_untitled: dc.b 'Untitled',0
storage_track_text: dc.b 'TRACK',0
storage_unsaved: dc.b 'Unsaved changes.',0
storage_folder_name: dc.b 'tracks',0
storage_name_pattern: dc.b 'track###.sct',0
storage_path: dc.b 'tracks/Track000.sct',0
storage_suffix_track: dc.b '.sct',0
storage_suffix_records: dc.b '.rec',0
        even
storage_status: dc.w 0
storage_service: dc.l 0
storage_size: dc.l 0
; 0 not examined yet, 1 tracks/ is a directory, -1 it is missing.
storage_folder: dc.w 0
storage_from_module: dc.w 0
storage_trak: dc.w 0
storage_trak_bytes: dc.w 0
storage_known: dc.w 0
storage_extras_bytes: dc.w 0
storage_work: dcb.b EDITOR_STATE_BYTES,0
; The tracks the game ships with, used for their slots while tracks/ has no
; file there: count, then slot, bytes and offset of each FORM SCTF.
storage_bundled:
        include "bundled-data.s"
        cnop 0,4
        include "crc-table.s"
