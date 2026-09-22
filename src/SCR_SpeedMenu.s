; Display and handle the game Settings menu.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Main menu and Settings share the original input/release loop.
; Context: 0 = other menus, 1 = main menu, 2 = settings.
; Number keys highlight; Space/Return/fire confirms once per release.
        machine 68000
speed_menu:
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
        moveq #4,d2
        jsr $5b840.l
        tst.b d0
        beq.s .game
        cmpi.b #1,d0
        beq.s .ai
        cmpi.b #2,d0
        beq.s .boost
        cmpi.b #3,d0
        beq.s .damage
        move.b #1,speed_menu_active
        moveq #4,d0
        bra.s .again
.game:
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
.done:
        clr.b speed_menu_active
        rts

speed_next:
        addq.w #1,speed_k
        cmpi.w #30,speed_k
        bls.s speed_update
        move.w #20,speed_k
speed_update:
        movem.l d0/a0,-(sp)
        move.w speed_k(pc),d0
        subi.w #20,d0
        mulu.w #6,d0
        lea speed_coefficients(pc),a0
        adda.w d0,a0
        move.w (a0)+,speed_multiplier
        move.w (a0)+,speed_spring
        move.w (a0)+,speed_decay
        movem.l (sp)+,d0/a0
        rts

ai_difficulty_next:
        addq.w #1,ai_difficulty_k
        cmpi.w #30,ai_difficulty_k
        bls.s .done
        move.w #20,ai_difficulty_k
.done:
        rts

speed_menu_row:
        move.b $1bb18.l,d2
        cmpi.b #2,speed_menu_active
        beq.s .settings
        cmpi.b #1,speed_menu_active
        bne.s .original
        cmpi.b #4,d2
        beq.s .main_speed
.original:
        jmp $5b8e4.l
.main_speed:
        lea speed_label(pc),a2
        bra.s .label_only
.settings:
        tst.b d2
        beq.s .game
        cmpi.b #1,d2
        beq.s .ai
        cmpi.b #2,d2
        beq.s .boost
        cmpi.b #3,d2
        beq.s .damage
        lea speed_return_label(pc),a2
.label_only:
        bsr.w speed_print_label
        jmp $5b914.l
.boost:
        lea speed_boost_no_label(pc),a2
        tst.b infinite_boost_enabled
        beq.s .label_only
        lea speed_boost_yes_label(pc),a2
        bra.s .label_only
.damage:
        lea speed_damage_no_label(pc),a2
        tst.b disable_damage_enabled
        beq.s .label_only
        lea speed_damage_yes_label(pc),a2
        bra.s .label_only
.game:
        lea speed_game_label(pc),a2
        move.w speed_k(pc),-(sp)
        bra.s .setting_label
.ai:
        lea speed_ai_label(pc),a2
        move.w ai_difficulty_k(pc),-(sp)
.setting_label:
        bsr.w speed_print_label
        move.w (sp)+,d0
.percent:
        mulu.w #5,d0
        divu.w #100,d0
        addi.b #'0',d0
        jsr $594c6.l
        swap d0
        andi.l #$ffff,d0
        divu.w #10,d0
        addi.b #'0',d0
        jsr $594c6.l
        swap d0
        addi.b #'0',d0
        jsr $594c6.l
        moveq #'%',d0
        jsr $594c6.l
        jmp $5b914.l

speed_print_label:
        move.b (a2)+,d0
        beq.s .done
        jsr $594c6.l
        bra.s speed_print_label
.done:
        rts

; Only the settings context replaces the original SELECT title. The byte
; printer uses $1f,column,row for position and preserves D0-D5/A0-A1.
speed_menu_title:
        cmpi.b #2,speed_menu_active
        beq.s .settings
        jmp $5a656.l
.settings:
        move.l a2,-(sp)
        lea speed_settings_title(pc),a2
        bsr.s speed_print_label
        movea.l (sp)+,a2
        rts

; Original row-position routine continues with MOVE.B (A0,D1.W),D0.
speed_menu_position:
        cmpi.b #2,speed_menu_active
        beq.s .settings
        lea speed_row_positions(pc),a0
        tst.b speed_menu_active
        bne.s .ready
        movea.l #$64af4,a0
.ready:
        jmp $64b3a.l
.settings:
        lea speed_settings_positions(pc),a0
        bra.s .ready

speed_menu_keys:
        lea speed_number_keys(pc),a2
        tst.b speed_menu_active
        bne.s .ready
        movea.l #$60c8d,a2
.ready:
        jmp $5b9d8.l

; The original font contains fill data at '%'. Supply a private glyph only
; in the settings menu; the game's glyph renderer stays in use.
speed_menu_font:
        movea.l #$1fe82,a0
        cmpi.b #2,speed_menu_active
        bne.s .ready
        cmpi.l #40,d0
        bne.s .ready
        lea speed_percent_glyph-40(pc),a0
.ready:
        jmp $595c8.l
speed_percent_glyph:
        dc.b $00,$62,$64,$08,$10,$26,$46,$00

speed_label: dc.b 'Settings',0
speed_game_label: dc.b 'Game Speed     ',0
speed_ai_label: dc.b 'AI Difficulty  ',0
speed_boost_no_label: dc.b 'Infinite Boost No',0
speed_boost_yes_label: dc.b 'Infinite Boost Yes',0
speed_damage_no_label: dc.b 'Disable Damage No',0
speed_damage_yes_label: dc.b 'Disable Damage Yes',0
speed_return_label: dc.b 'Return',0
speed_settings_title: dc.b $1f,16,11,'Settings',0
speed_row_positions: dc.b 13,15,17,19,21
speed_settings_positions: dc.b 13,15,17,19,21
speed_number_keys: dc.b 1,2,3,4,5
        even
speed_state_start:
speed_k: dc.w 20
speed_multiplier: dc.w 2380
speed_spring: dc.w 1656
speed_decay: dc.w 3068
ai_difficulty_k: dc.w 20
speed_menu_active: dc.b 0
infinite_boost_enabled: dc.b 0
disable_damage_enabled: dc.b 0
        even
speed_state_end:
; round(33120/k), round(65536*(1-(1-3068/65536)^(k/20))).
speed_coefficients:
        dc.w 2380,1656,3068
        dc.w 2499,1577,3218
        dc.w 2618,1505,3367
        dc.w 2737,1440,3516
        dc.w 2856,1380,3664
        dc.w 2975,1325,3812
        dc.w 3094,1274,3960
        dc.w 3213,1227,4108
        dc.w 3332,1183,4255
        dc.w 3451,1142,4401
        dc.w 3570,1104,4548
