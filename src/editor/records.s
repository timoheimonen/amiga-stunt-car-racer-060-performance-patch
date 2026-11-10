; Store and restore custom-track records for normal and super leagues.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Lap records of a custom track: tracks/TrackNNN.rec, an IFF FORM SCTT.
; RKEY: the policy word, a zero word and the exact identity of the track,
; RECORDS_KEY_BYTES: 32 bytes and 4 per piece; NORM and SUPR: the two best
; times of each league as the game keeps them (name[12], minute, second and
; fraction in BCD, zero); CRC.
; The whole file stays in the Fast cache at RECORDS_CACHE from the race start
; to its write on the return to the menus, so unknown chunks are written back
; as they were read. Shared storage scratch is used only outside gameplay.
; RECORDS_POLICY is a build define:
; 100 percent, finite boost, damage enabled; gameplay revision 1.
; NORM and SUPR hold RECORDS_TIMES_BYTES each (a build define), the two times
; of a league.
RECORDS_NORM equ 24+RECORDS_KEY_BYTES+8
RECORDS_SUPR equ RECORDS_NORM+RECORDS_TIMES_BYTES+8
ID_SCTT equ $53435454
ID_RKEY equ $524b4559
ID_NORM equ $4e4f524d
ID_SUPR equ $53555052
records_cache:
        lea RECORDS_CACHE(a5),a4
        rts
records_key_build:
        lea records_key(pc),a1
        moveq #RECORDS_KEY_BYTES/4-1,d0
.zero:  clr.l (a1)+
        dbra d0,.zero
        lea editor_track+SCTR_IDENTITY(pc),a0
        lea records_key(pc),a1
        moveq #SCTR_IDENTITY_BYTES+4,d0 ; the identity and the revision
        bsr storage_copy
        move.w editor_track+SCTR_COUNT(pc),(a1)+
        move.w editor_track+SCTR_HEIGHT(pc),(a1)+
        move.w practice_runtime+6(pc),(a1)+
        addq.l #6,a1
        lea editor_track+SCTR_PIECES+PIECE_KIND(pc),a0
        move.w editor_track+SCTR_COUNT(pc),d0
        subq.w #1,d0
.piece: move.l (a0),(a1)+
        addq.l #PIECE_BYTES,a0
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
        tst.b $182447          ; Original timing makes no records
        bne.s .done
        moveq #1,d0
.done:  rts


; A1 = two records of a league. D0 = 1 (flags set) if their names are
; printable or zero and their times BCD.
records_times_check:
        movem.l d1-d2/a1,-(sp)
        moveq #1,d2
.times: moveq #11,d1
.name:  move.b (a1)+,d0
        beq.s .char_ok
        cmpi.b #32,d0
        blo.s .bad
        cmpi.b #126,d0
        bhi.s .bad
.char_ok:
        dbra d1,.name
        cmpi.b #9,(a1)+
        bhi.s .bad
        move.b (a1)+,d0
        cmpi.b #$59,d0
        bhi.s .bad
        andi.b #15,d0
        cmpi.b #9,d0
        bhi.s .bad
        move.b (a1)+,d0
        cmpi.b #$99,d0
        bhi.s .bad
        andi.b #15,d0
        cmpi.b #9,d0
        bhi.s .bad
        tst.b (a1)+
        bne.s .bad
        dbra d2,.times
        moveq #1,d0
        bra.s .done
.bad:   moveq #0,d0
.done:  movem.l (sp)+,d1-d2/a1
        tst.l d0
        rts

; A4 = records file of D0 bytes. D0 = 1 (flags set) if it is a FORM SCTT of
; this policy with one RKEY, NORM and SUPR each and valid times; then
; records_rkey, records_norm and records_supr are their data offsets.
records_check:
        movem.l d1-d2/d6/a1,-(sp)
        move.l d0,d6
        move.l #ID_SCTT,d1
        bsr storage_form
        beq.s .bad
        move.l d6,d0
        move.l #ID_RKEY,d1
        bsr storage_find
        cmpi.l #1,d2
        bne.s .bad
        cmpi.l #RECORDS_KEY_BYTES+4,d1
        bne.s .bad
        move.w d0,records_rkey-module_start(a5)
        cmpi.l #RECORDS_POLICY<<16,(a4,d0.l)
        bne.s .bad
        move.l d6,d0
        move.l #ID_NORM,d1
        bsr.s .times
        beq.s .bad
        move.w d0,records_norm-module_start(a5)
        move.l d6,d0
        move.l #ID_SUPR,d1
        bsr.s .times
        beq.s .bad
        move.w d0,records_supr-module_start(a5)
        moveq #1,d0
        bra.s .done
.bad:   moveq #0,d0
.done:  movem.l (sp)+,d1-d2/d6/a1
        tst.l d0
        rts
; D1 chunk id: D0 = its data offset if it is there once with valid times, else 0.
.times: bsr storage_find
        cmpi.l #1,d2
        bne.s .none
        cmpi.l #RECORDS_TIMES_BYTES,d1
        bne.s .none
        lea (a4,d0.l),a1
        move.l d0,d2
        bsr records_times_check
        beq.s .none
        move.l d2,d0
        rts
.none:  moveq #0,d0
        rts

; D0 slot, A1 a buffer of STORAGE_FILE_BYTES: the slot's records file read
; there, A4 = A1. D0 (flags set) = its bytes when it holds the records of
; records_key (records_rkey, records_norm and records_supr then point into
; it), 0 when there is none or it is another track's, -1 when it can not be
; used: too large (kept for a later version) or damaged. D1, A0 and A1 change.
records_read:
        moveq #1,d1
        bsr storage_path_make
        movea.l a1,a4
        move.l #STORAGE_FILE_BYTES,d1
        moveq #FS_LOAD,d0
        bsr storage_file
        beq.s .done
        cmp.l d1,d0
        bhi.s .bad
        move.l d0,d1
        bsr records_check
        beq.s .bad
        moveq #0,d0
        move.w records_rkey(pc),d0
        lea 4(a4,d0.l),a0
        lea records_key(pc),a1
        move.w #RECORDS_KEY_BYTES/4-1,d0
.compare:
        cmpm.l (a0)+,(a1)+
        dbne d0,.compare
        bne.s .other
        move.l d1,d0
        rts
.other: moveq #0,d0
        rts
.bad:   moveq #-1,d0
.done:  rts

; A4 the file buffer, A0 the NORM times, A2 the SUPR times: a new records
; file of records_key there, closed. D0 = its bytes; A0 and A1 change.
records_fresh:
        movea.l a4,a1
        move.l #ID_FORM,(a1)+
        addq.l #4,a1                    ; the length: storage_form_close
        move.l #ID_SCTT,(a1)+
        move.l #ID_RKEY,(a1)+
        move.l #RECORDS_KEY_BYTES+4,(a1)+
        move.l #RECORDS_POLICY<<16,(a1)+
        move.l a0,-(sp)
        lea records_key(pc),a0
        move.w #RECORDS_KEY_BYTES,d0
        bsr storage_copy
        movea.l (sp)+,a0
        move.l #ID_NORM,(a1)+
        moveq #RECORDS_TIMES_BYTES,d0
        move.l d0,(a1)+
        bsr storage_copy
        move.l #ID_SUPR,(a1)+
        moveq #RECORDS_TIMES_BYTES,d0
        move.l d0,(a1)+
        movea.l a2,a0
        bsr storage_copy
        bra storage_form_close

records_begin:
        clr.w records_dirty-module_start(a5)
        clr.w records_allowed-module_start(a5)
        clr.w records_error-module_start(a5)
        bsr records_eligible
        tst.w d0
        beq .done
        bsr records_cache
        move.w records_slot(pc),d0
        movea.l a4,a1
        bsr records_read
        bmi .error
        beq.s .new
        move.l d0,records_bytes-module_start(a5)
        bra.s .load
        ; No file, or one of another track: a new file with the session times.
.new:   lea custom_session_times(pc),a0
        movea.l a0,a2
        bsr records_fresh
        move.w #RECORDS_NORM,records_norm-module_start(a5)
        move.w #RECORDS_SUPR,records_supr-module_start(a5)
        move.l d0,records_bytes-module_start(a5)
.load:
        move.w #1,records_allowed-module_start(a5)
        bsr.s records_league_offset
        move.w d0,records_league-module_start(a5)
        movea.l a4,a0
        adda.w d0,a0
        lea custom_session_times(pc),a1
        moveq #RECORDS_TIMES_BYTES,d0
        bsr storage_copy
.done:  rts
.error: move.w #1,records_error-module_start(a5)
        rts

; D0 = where the times of the league being raced are in the records file:
; records_norm, or records_supr in the Super League ($1c9d0 set).
records_league_offset:
        move.w records_norm(pc),d0
        tst.b $1c9d0
        beq.s .done
        move.w records_supr(pc),d0
.done:  rts

records_changed:
        tst.w records_allowed-module_start(a5)
        beq.s .done
        bsr records_eligible
        tst.w d0
        beq.s .disable
        bsr.s records_league_offset
        cmp.w records_league(pc),d0
        bne.s .disable
        bsr records_cache
        lea custom_session_times(pc),a0
        movea.l a4,a1
        adda.w records_league(pc),a1
        moveq #RECORDS_TIMES_BYTES,d0
        bsr storage_copy
        move.w #1,records_dirty-module_start(a5)
.done:  rts
.disable:
        clr.w records_allowed-module_start(a5)
        clr.w records_dirty-module_start(a5)
        rts

; No gameplay disk I/O: call on return to menus. The cache with its CRC
; renewed, written whole.
records_commit:
        tst.w records_dirty-module_start(a5)
        beq.s .ok
        bsr storage_folder_check
        beq.s .bad
        bsr records_cache
        move.l records_bytes(pc),d5
        move.l d5,d0
        bsr storage_form_seal
        move.w records_slot(pc),d0
        moveq #1,d1
        bsr storage_path_make
        movea.l a4,a1
        move.l d5,d1
        moveq #FS_SAVE,d0
        bsr storage_file
        beq.s .bad
        clr.w records_dirty-module_start(a5)
.ok:    clr.w records_error-module_start(a5)
        moveq #0,d0
        rts
.bad:   move.w #1,records_error-module_start(a5)
        moveq #1,d0
        rts
records_key: dcb.b RECORDS_KEY_BYTES,0
records_bytes: dc.l 0
records_slot: dc.w 0
records_league: dc.w 0
records_allowed: dc.w 0
records_dirty: dc.w 0
records_error: dc.w 0
records_rkey: dc.w 0
records_norm: dc.w 0
records_supr: dc.w 0
