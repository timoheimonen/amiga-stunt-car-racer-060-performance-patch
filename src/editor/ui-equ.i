; Track Editor bar: constants of the widget service.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT. See the LICENSE file for details.

UI_CELL_WIDTH       equ 6
UI_LINE_HEIGHT      equ 8
UI_GLYPH_ROWS       equ 7

; Target: plane 0 address, bytes from one plane to the next, and a 16-byte
; table mapping the roles below to colour indices 0-15. Rows are 40 bytes and
; there are four planes.
UI_TARGET_PLANE     equ 0
UI_TARGET_STRIDE    equ 4
UI_TARGET_ROLES     equ 8
UI_TARGET_BYTES     equ 12
UI_ROW_BYTES        equ 40

; Commands: one opcode word followed by word arguments. Inline strings end
; with a zero byte and are padded to an even address.
UI_END              equ 0
UI_RECT             equ 1   ; x,y,w,h,role
UI_FRAME            equ 2   ; x,y,w,h,role
UI_TEXT             equ 3   ; x,y,w,role,align, inline string
UI_TEXT_AT          equ 4   ; x,y,w,role,align, string address (long)
UI_BUTTON           equ 5   ; x,y,w,h,state, inline label
UI_BUTTON_AT        equ 6   ; x,y,w,h,state, label address (long)
UI_BUTTON_REF       equ 7   ; x,y,w,h, state word address (long), label address (long)
UI_ROW_AT           equ 8   ; x,y,w,h,state, label address (long): flat list row
UI_LAST_COMMAND     equ 8

; Text alignment within the field [x,x+w).
UI_LEFT             equ 0
UI_CENTER           equ 1
UI_RIGHT            equ 2
UI_LEFT_CLIPPED     equ 3   ; left, cut after the last glyph that fits

; Button states. A button label may mark its key with an underscore before
; the letter ("_Save"): the letter is underlined and the underscore is not
; drawn. List rows draw their labels as they are.
UI_NORMAL           equ 0
UI_HOVER            equ 1
UI_ACTIVE           equ 2
UI_DISABLED         equ 3
UI_DEFAULT          equ 4
UI_DEFAULT_HOVER    equ 5
UI_DEFAULT_ACTIVE   equ 6   ; selected or held down, and framed
UI_KEY_MARK         equ '_'

; Colour roles.
UI_BG               equ 0
UI_PANEL            equ 1
UI_FACE             equ 2
UI_FACE_HOVER       equ 3
UI_LIGHT            equ 4
UI_SHADOW           equ 5
UI_INK              equ 6
UI_DIM              equ 7
UI_ACCENT           equ 8
UI_SELECT           equ 9
UI_ERROR            equ 10
UI_OK               equ 11
UI_WARN             equ 12
