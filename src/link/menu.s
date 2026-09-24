; Computer Link menu: explicit Host/Join choice and bounded role offer.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Bound the legacy menu offer loop before the negotiated owner transition.
; Each transmitted offer is followed by the game's 10 ms CIA-A wait.
; 500 offers give a nominal five-second wait; CPU/UI overhead adds time.
; This is an attempt budget, not the active transport's TOD deadline.
; Explicit Host / Join avoids symmetric automatic role election.
; No timer ownership or UART format changes in this menu stage.
SCR20_MENU_LEFT   equ $409c
SCR20_MENU_EXPIRED equ $409e

scr20_menu_begin:
        move.w sr,-(sp)
        movem.l d0-d7/a0-a6,-(sp)
        lea module_start(pc),a5
        bsr.w scr20_resume_legacy
        tst.l d0
        beq.w .cancel
        move.w #501,SCR20_MENU_LEFT(a5)
        clr.w SCR20_MENU_EXPIRED(a5)
        ; A previous connection is not evidence for this attempt.
        clr.b $57c5b
        clr.b $57c3c
        jsr $570d8.l
        lea scr20_role_text(pc),a0
        moveq #0,d3
        jsr $57de6.l
.choose:
        moveq #$45,d1
        jsr $612be.l
        beq.s .cancel
        moveq #$25,d1             ; Amiga H
        jsr $612be.l
        beq.s .host
        moveq #$26,d1             ; Amiga J
        jsr $612be.l
        bne.s .choose
        lea scr20_menu_join(pc),a0
        move.l a0,62(sp)
        bra.s .return
.host:
        move.l #$57cea,62(sp)
        bra.s .return
.cancel:
        move.l #$57d8a,62(sp)
.return:
        ; The game's glyphs are drawn over the panel, so spaces cannot erase
        ; the prompt. Redraw the Link panel and header as the entry at
        ; $57c8e/$57c9c does; $6a58c still addresses the displayed buffer.
        jsr $64c6e.l
        jsr $64b0e.l
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        rts

; Join waits for a Host offer without ever sending an offer itself.
; Same bounded 10 ms wait and Esc test as Host. Unknown bytes do not
; renew the budget. The existing six-response path completes the role.
scr20_menu_join:
        moveq #$23,d3
        jsr $57dc2.l
.poll:
        moveq #$45,d1
        bsr.w scr20_menu_poll
        beq.s .abandon
        jsr $5703a.l
        beq.s .wait
        jsr $5705a.l
        cmpi.b #$a0,d0
        beq.s .joined
.wait:
        jsr $5714c.l
        bra.s .poll
.joined:
        jmp $57cc6.l
.abandon:
        jmp $57d8a.l

scr20_role_text:
        dc.b $1f,6,16,'H Host / J Join / Esc Return',$ff
        even

scr20_menu_poll:
        ; Preserve the original key test's registers and flags. Expiry
        ; synthesizes only Z=1, using the existing Link abandoned branch.
        jsr $612be.l
        beq.s .return
        move.w sr,-(sp)
        move.l a5,-(sp)
        lea module_start(pc),a5
        tst.w SCR20_MENU_LEFT(a5)
        beq.s .expired
        subq.w #1,SCR20_MENU_LEFT(a5)
        beq.s .expired
        move.l (sp)+,a5
        move.w (sp)+,sr
.return:
        rts
.expired:
        move.w #1,SCR20_MENU_EXPIRED(a5)
        move.l (sp)+,a5
        move.w (sp)+,sr
        ori.b #4,ccr
        rts
