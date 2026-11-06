; Run a test drive on the track in memory.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Test drive: a Practise race on the track in memory, without its menus, run
; from the top of editor_loop where no key handler is active. Nothing reaches a
; file or the lap records.
TEST_COPPER equ $23a6c
TEST_COPPER_BYTES equ 300

; $5d2fc: the track preview waits for Fire. TST leaves C=0, which the caller
; takes as Fire. Practise keeps the original call.
test_preview:
        tst.w test_mode(pc)
        beq.s .original
        rts
.original:
        jmp $5d980

test_drive:
        clr.w test_request-module_start(a5)
        bsr validate_for_practice
        tst.w d0
        beq.s .not_ready
        bsr custom_compile
        bne.s .start
.not_ready:
        move.w #11,storage_status-module_start(a5)
        rts
.start:
        clr.w editor_input_enabled-module_start(a5)
        bsr editor_release_physical
        bsr ui_display_exit
        lea COPPER_LIST.l,a0
        lea TEST_COPPER(a5),a1
        move.w #TEST_COPPER_BYTES,d0
        bsr storage_copy
        clr.b editor_active-module_start(a5)
        move.b $1ca33,custom_saved_road-module_start(a5)
        move.b $1ca21,custom_saved_aux-module_start(a5)
        move.b $1ca22,test_saved_mode-module_start(a5)
        move.b $5eb75,test_saved_bank-module_start(a5)
        move.l records_allowed(pc),test_saved_records-module_start(a5)
        move.w #1,test_mode-module_start(a5)
        bsr custom_save_times
        move.w #1,custom_active-module_start(a5)
        clr.b $1ca33
        clr.b $1ca22
        clr.b $5eb75
        move.b #8,$1ca21
        move.b #$12,$57c62
        jsr $5d20c
        move.b #0,$57c62
        jsr $5d326
        jsr $64532
        lea module_start(pc),a5
        lea custom_original_times(pc),a0
        moveq #-1,d0
        bsr custom_transfer_times
        move.b custom_saved_road(pc),$1ca33
        move.b custom_saved_aux(pc),$1ca21
        move.b test_saved_mode(pc),$1ca22
        move.b test_saved_bank(pc),$5eb75
        move.l test_saved_records(pc),records_allowed-module_start(a5)
        clr.w custom_active-module_start(a5)
        clr.w test_mode-module_start(a5)
        addq.l #1,test_runs-module_start(a5)
        ; Back to the editor. editor_enter would save race pixels over the
        ; title backup, so only its display steps run here.
        move.b #1,editor_active-module_start(a5)
        move.w #$2f,$dff096
        movea.l saved_screen(pc),a0
        move.w #15999,d0
.blank: clr.l (a0)+
        dbra d0,.blank
        lea saved_display(pc),a0
        lea $6a584.l,a1
        moveq #16,d0
        bsr storage_copy
        lea TEST_COPPER(a5),a0
        lea COPPER_LIST.l,a1
        move.w #TEST_COPPER_BYTES,d0
        bsr storage_copy
        clr.l field_key-module_start(a5)
        bsr editor_model_view
        bsr editor_input_start
        ; A key or button held since the race stays ignored until its release.
        move.w #EDITOR_INPUT_HOLDOFF,editor_input_holdoff-module_start(a5)
        clr.w editor_view_valid-module_start(a5)
        bsr ui_display_enter
        move.w #13,storage_status-module_start(a5)
        rts

test_request: dc.w 0
test_mode: dc.w 0
test_runs: dc.l 0
test_saved_records: dc.l 0
test_saved_mode: dc.b 0
test_saved_bank: dc.b 0
