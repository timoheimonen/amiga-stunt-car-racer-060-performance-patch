; Key codes and input state constants of the track editor.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; The key states of the game's table at $ead6 and the editor's input table.
; The builder gives the raw key codes as RAW_<name>.
; EDITOR_INPUT_STATE holds three banks of EDITOR_INPUT_BANK bytes: the keys
; the handlers read (editor_input_keys), the captured state and the suppressed
; keys. In each, indices 0..RAW_KEYS-1 are raw keys and EDITOR_INPUT_JOY holds
; U/D/L/R/fire, active high.
KEY_DOWN equ $b3                ; a held key
RAW_KEYS equ 96
EDITOR_INPUT_JOY equ RAW_KEYS
EDITOR_INPUT_FIRE equ 4         ; bit of EDITOR_INPUT_JOY
EDITOR_INPUT_ENTRIES equ EDITOR_INPUT_JOY+1
EDITOR_INPUT_BANK equ $80
; A held arrow, or a held bar row, steps again after EDITOR_REPEAT_DELAY ticks
; (VBL) and then every EDITOR_REPEAT_RATE.
EDITOR_REPEAT_DELAY equ 20
EDITOR_REPEAT_RATE equ 8
