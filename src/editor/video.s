; Select the PAL or NTSC display window of the game screens.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; PAL/NTSC display window of the game screens (menus, preview, race, editor).
; Hook at $edfc replaces three MOVE.W (24 bytes): DIWSTRT $3c81, DIWSTOP
; $04c1 and the sprite vertical origin $69ec4 = 60 (used by $69e30 and
; $69f04). PAL keeps them; NTSC shows the same 200 lines 16 lines higher,
; at 44..243, the standard NTSC area. The copper wait at line 250 ($e82e)
; stays: it exists in both modes. video_ntsc is set by the bootstrap.
; The following MOVE at $ee14 sets CCR again; registers are preserved.
video_game_window:
        tst.b video_ntsc(pc)
        bne.s .ntsc
        move.w #$3c81,$dff08e
        move.w #$04c1,$dff090
        move.w #$003c,$69ec4
        rts
.ntsc:  move.w #$2c81,$dff08e
        move.w #$f4c1,$dff090
        move.w #$002c,$69ec4
        rts
video_ntsc: dc.b 0              ; 1 = NTSC, measured at boot
        even
