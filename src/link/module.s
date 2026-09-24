; Link module entry: verify the game code and install the 20 Hz link hooks.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Relocatable 68000 serial module. Boot loads code into a private Fast block.
; Version-gate the menu handshake and install owner dispatchers. The
; playable build also connects the race lifecycle to this module.
; Ownership changes only through the explicit acquire/release interface.
; Entry is called after main-game load, before the editor's cache flush.
; Preserve all registers and CCR; use the game's existing stack.
module_start:
        bra.w module_loaded
        dc.b 'SC20'
        dc.w 1,32
module_state: dc.l 0
module_base: dc.l 0
        dc.l $8000,$4000
editor_base: dc.l 0

module_loaded:
        move.w sr,-(sp)
        movem.l d0-d7/a0-a6,-(sp)
        lea module_start(pc),a5
        cmpi.l #1,module_state-module_start(a5)
        bne.w .return
        move.l a5,d0
        cmp.l module_base-module_start(a5),d0
        bne.w .failed
        ; Check IRQ and auxiliary TX call sites before installing dispatchers.
        ; Merely loading the module must not take timers from AmigaOS or game.
        cmpi.w #$4eb9,$eed4
        bne.w .failed
        cmpi.l #$f148,$eed6
        bne.w .failed
        cmpi.w #$4eb9,$efd0
        bne.w .failed
        cmpi.l #$f1e0,$efd2
        bne.w .failed
        cmpi.w #$4eb9,$eff0
        bne.w .failed
        cmpi.l #$f0aa,$eff2
        bne.w .failed
        cmpi.w #$4eb9,$f106
        bne.w .failed
        cmpi.l #$f148,$f108
        bne.w .failed
        cmpi.w #$4eb9,$f2c0
        bne.w .failed
        cmpi.l #$f148,$f2c2
        bne.w .failed
        cmpi.w #$4eb9,$57ca2
        bne.w .failed
        cmpi.l #$570d8,$57ca4
        bne.w .failed
        cmpi.w #$4eb9,$57d04
        bne.w .failed
        cmpi.l #$612be,$57d06
        bne.w .failed
        cmpi.w #$207c,$f28e
        bne.w .failed
        cmpi.l #$ec56,$f290
        bne.w .failed
        ; Wire revision SC20: offer $a0, response $60. Internal roles remain
        ; $80/$40. Check every instruction before writing any of them.
        ; The editor flushes the instruction cache after this entry returns.
        cmpi.l #$0c000080,$57cbe
        bne.w .failed
        cmpi.l #$103c0040,$57cd2
        bne.w .failed
        cmpi.l #$103c0080,$57d0e
        bne.w .failed
        cmpi.l #$0c000040,$57d34
        bne.w .failed
        ifd SCR20_PLAYABLE
        cmpi.w #$4eb9,$5d342
        bne.w .failed
        cmpi.l #$57134,$5d344
        bne.w .failed
        cmpi.w #$4eb9,$5d35e
        bne.w .failed
        cmpi.l #$1bace,$5d360
        bne.w .failed
        cmpi.w #$4eb9,$5d47e
        bne.w .failed
        cmpi.l #$18271a,$5d480
        bne.w .failed
        cmpi.w #$4eb9,$5da7e
        bne.w .failed
        cmpi.l #$57b86,$5da80
        bne.w .failed
        cmpi.w #$4eb9,$5d66e
        bne.w .failed
        cmpi.l #$57964,$5d670
        bne.w .failed
        cmpi.w #$4eb9,$5d58a
        bne.w .failed
        cmpi.l #$57964,$5d58c
        bne.w .failed
        cmpi.w #$4eb9,$5d116
        bne.w .failed
        cmpi.l #$5867a,$5d118
        bne.w .failed
        cmpi.w #$4eb9,$5d12a
        bne.w .failed
        cmpi.l #$5f25a,$5d12c
        bne.w .failed
        cmpi.w #$4eb9,$64ea0
        bne.w .failed
        cmpi.l #$571ce,$64ea2
        bne.w .failed
        cmpi.w #$4eb9,$64f54
        bne.w .failed
        cmpi.l #$571ce,$64f56
        bne.w .failed
        cmpi.w #$4eb9,$650a8
        bne.w .failed
        cmpi.l #$57440,$650aa
        bne.w .failed
        cmpi.l #$10390001,$645c6        ; move.b $1c9ce,d0
        bne.w .failed
        cmpi.w #$c9ce,$645ca
        bne.w .failed
        cmpi.l #$14390001,$5ee8a        ; move.b $1c9ce,d2
        bne.w .failed
        cmpi.w #$c9ce,$5ee8e
        bne.w .failed
        endif
        ; The original Join path repeats the same response six times.
        ; A single response is enough for Host's acknowledgement test and
        ; avoids leaving five legacy bytes behind the local complete flag.
        cmpi.l #$3e3c0005,$57cce
        bne.w .failed
        move.w #$00a0,$57cc0
        move.w #$0060,$57cd4
        move.w #$00a0,$57d10
        move.w #$0060,$57d36
        move.w #0,$57cd0
        lea scr20_game_tx(pc),a0
        move.l a0,$eed6
        move.l a0,$f108
        move.l a0,$f2c2
        lea scr20_game_rx(pc),a0
        move.l a0,$efd2
        lea scr20_game_cia(pc),a0
        move.l a0,$eff2
        lea scr20_menu_begin(pc),a0
        move.l a0,$57ca4
        lea scr20_menu_poll(pc),a0
        move.l a0,$57d06
        lea scr20_legacy_enqueue(pc),a0
        move.w #$4ef9,$f28e
        move.l a0,$f290
        ifd SCR20_PLAYABLE
        lea scr20_race_handoff(pc),a0
        move.l a0,$5d344
        lea scr20_race_acquire(pc),a0
        move.l a0,$5d360
        lea scr20_race_frame_begin(pc),a0
        move.l a0,$5d480
        lea scr20_race_pause(pc),a0
        move.l a0,$5da80
        lea scr20_race_end(pc),a0
        move.l a0,$5d670
        move.l a0,$5d58c
        lea scr20_race_results(pc),a0
        move.l a0,$5d118
        lea scr20_race_records(pc),a0
        move.l a0,$5d12c
        lea scr20_race_draw(pc),a0
        move.l a0,$64ea2
        move.l a0,$64f56
        lea scr20_race_receive_tail(pc),a0
        move.l a0,$650aa
        move.w #$4eb9,$645c6
        lea scr20_league_division_d0(pc),a0
        move.l a0,$645c8
        move.w #$4eb9,$5ee8a
        lea scr20_league_division_d2(pc),a0
        move.l a0,$5ee8c
        endif
        move.l #2,module_state-module_start(a5)
        bra.s .return
.failed:
        move.l #3,module_state-module_start(a5)
.return:
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        rts

; Same publication/state ABI as the verified standalone transport.
published       equ $401a
published_slot  equ $4050
producer_slot   equ $4052
prepared_at     equ $4054
active_at       equ $4058
sent_at         equ $405c
sent_sequence   equ $4060
prepared        equ $4300
active          equ $4340
        include "src/link/menu.s"
        include "src/link/game-uart.s"
        include "src/link/publication.s"
        include "src/link/frame.s"
        include "src/link/receive.s"
        include "src/link/transmit.s"
        include "src/link/clock.s"
        ifd SCR20_PLAYABLE
        include "src/link/race.s"
        include "src/link/race-loop.s"
        include "src/link/view.s"
        include "src/link/race-end.s"
        include "src/link/league.s"
        endif
code_end:
        dcb.b $4000-(*-module_start),0
