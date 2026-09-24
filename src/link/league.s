; Link championship: seasons run through Divisions 4 to 1.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Link championship through the divisions.
; The original link league plays four seasons ($57c67 = 0..3, the last is
; "FINAL SEASON") with cumulative points, but always in the Host's league
; division $1c9ce (0 = Division 4 .. 3 = Division 1): its season end
; ($5d1b4) skips the single-player promotion path. In a link league the
; season number now selects the division, so the championship runs
; Division 4, 3, 2 and 1. $1c9ce itself (the solo league) is not written.
;
; Two readers of $1c9ce are replaced by JSR (same 6 bytes):
;   $645c6  move.b $1c9ce,d0   division for tracks ($1bb1b) and display ($1bb5f)
;   $5ee8a  move.b $1c9ce,d2   division whose drivers the link season uses
; Both return the value in the low byte only and set N/Z like MOVE.B
; (the $5ee8a caller branches on Z). Link league: role $57c3c and link
; players $5eb76 both non-zero. A new link league starts at season 0
; because the link start calls the new-game reset $5aa38 ($5832e).

scr20_league_division_d0:
        move.b $1c9ce,d0
        tst.b $57c3c
        beq.s .done
        tst.b $5eb76
        beq.s .done
        move.b $57c67,d0
        cmpi.b #3,d0
        bls.s .done
        move.b #3,d0
.done:  tst.b d0
        rts

scr20_league_division_d2:
        move.l d0,-(sp)
        bsr.s scr20_league_division_d0
        move.b d0,d2
        move.l (sp)+,d0
        tst.b d2
        rts
