; Timing Performance/Original: the original 120 ms race loop and physics on request.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Settings row 5, Timing: Performance (default) or Original.
; Original keeps the performance runtime inactive for the whole race. The
; frame gate in frame_begin takes the historical 120 ms path, so every
; active-gated hook runs its displaced original instructions and the loop
; waits six VBLs. legacy_due stays 1, so the in-place impact cooldown and
; the smoke phase advance once per loop as in the original game.
; Link races always run Performance. Everything here is appended to the
; runtime; no earlier runtime address moves. original_mode is the former
; padding byte of the speed state ($182447).
        machine 68000

; Runtime overlay at frame_gate: JSR original_gate.l / BNE.S frame_unsupported
; / NOP. frame_begin has saved D0/A0. Z=0 selects the original 120 ms frame.
original_gate:
        tst.b original_mode
        beq.s .done
        tst.b $57c3c.l           ; link role: the race stays Performance
        bne.s .performance
        move.b #1,legacy_due     ; Z=0
.done:  rts
.performance:
        ori #4,ccr               ; Z=1
        rts

; The yaw correction gate sits in the game's own hook at $611ce
; (its instruction overlay in src/patches.json), so that Performance runs no
; extra runtime code.

; $5f18c and $5f1f6 compare a lap and a race time with the track records
; (time indices 14 and 15). Original timing makes no records: answer "not
; faster" (carry set) with the address registers of $5dc38's rejection.
timing_record:
        tst.b original_mode
        beq.s .compare
        tst.b $57c3c.l
        bne.s .compare
        movea.l #$1c938,a0
        movea.l #$1c920,a1
        movea.l #$1c908,a2
        move.b (0,a2,d1.w),d0
        ori #1,ccr
        rts
.compare:
        jmp $5dc38.l

; Main menu and the six-row Settings menu (speed_menu with one more row).
timing_menu:
        move.b #1,speed_menu_active
.again:
        moveq #0,d1
        moveq #4,d2
        jsr $5b840.l
        cmpi.b #4,d0
        bne.s .done
        move.b #2,speed_menu_active
        moveq #0,d0
.settings:
        moveq #0,d1
        moveq #5,d2
        jsr $5b840.l
        tst.b d0
        beq.s .game
        cmpi.b #1,d0
        beq.s .ai
        cmpi.b #2,d0
        beq.s .boost
        cmpi.b #3,d0
        beq.s .damage
        cmpi.b #4,d0
        beq.s .timing
        move.b #1,speed_menu_active
        moveq #4,d0
        bra.s .again
.game:
        tst.b original_mode      ; locked at 100 % in Original
        bne.s .settings
        bsr.w speed_next
        bra.s .settings
.ai:
        bsr.w ai_difficulty_next
        bra.s .settings
.boost:
        eori.b #1,infinite_boost_enabled
        bra.s .settings
.damage:
        eori.b #1,disable_damage_enabled
        bra.s .settings
.timing:
        eori.b #1,original_mode
        bra.s .settings
.done:
        clr.b speed_menu_active
        rts

; Row text. The Timing row and the locked Game Speed are new; every other
; row and menu continues in speed_menu_row, which reloads D2 itself.
timing_menu_row:
        cmpi.b #2,speed_menu_active
        bne.w speed_menu_row
        move.b $1bb18.l,d2
        cmpi.b #4,d2
        beq.s .timing
        tst.b d2
        bne.w speed_menu_row
        tst.b original_mode
        beq.w speed_menu_row
        lea timing_speed_locked_label(pc),a2
        bra.s .label
.timing:
        lea timing_performance_label(pc),a2
        tst.b original_mode
        beq.s .label
        lea timing_original_label(pc),a2
.label:
        bsr.w speed_print_label
        jmp $5b914.l

; Settings rows 13..23 and number keys 1..6; other menus are unchanged.
timing_menu_position:
        cmpi.b #2,speed_menu_active
        bne.w speed_menu_position
        lea timing_positions(pc),a0
        jmp $64b3a.l

timing_menu_keys:
        cmpi.b #2,speed_menu_active
        bne.w speed_menu_keys
        lea timing_keys(pc),a2
        jmp $5b9d8.l

timing_speed_locked_label: dc.b 'Game Speed     100%',0
timing_performance_label: dc.b 'Timing Performance',0
timing_original_label: dc.b 'Timing Original',0
timing_positions: dc.b 13,15,17,19,21,23
timing_keys: dc.b 1,2,3,4,5,6
        even
timing_end:
