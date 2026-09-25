; Install editor hooks and manage editor entry, operation and exit.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

EDITOR_MAX_ROWS equ 14
EDITOR_GEOMETRY_STRIDE equ EDITOR_MAX_ROWS*12
; relocatable editor lifecycle, height renderer and modal storage. Fast allocation lives until reset.
module_start:
        bra.w main_loaded
        dc.b 'SCIE'
        dc.w 1,32
module_state: dc.l 0
module_base: dc.l 0
        dc.l FAST_BYTES
        dc.l MODULE_BYTES
        dc.l 0
main_loaded:
        move.w ccr,-(sp)
        movem.l d0-d7/a0-a6,-(sp)
        lea module_start(pc),a5
        ; Validate every runtime edit before publishing any of them.
        cmpi.w #$4eb9,$5e8c8
        bne .failed
        cmpi.l #$5b840,$5e8ca
        bne .failed
        cmpi.w #$4eb9,$5e930
        bne .failed
        cmpi.l #$57c78,$5e932
        bne .failed
        cmpi.w #$4eb9,$f0e4
        bne .failed
        cmpi.l #$616dc,$f0e6
        bne .failed
        cmpi.w #$4eb9,$f05e
        bne .failed
        cmpi.l #$f06a,$f060
        bne .failed
        ; Template 0: 18 points and constant X edges; guarded by builder hash.
        cmpi.l #$40030000,$1f0dd
        bne .failed
        lea old_label(pc),a0
        lea $5ebf0.l,a1
        moveq #12,d0
.verify_label:
        cmpm.b (a0)+,(a1)+
        bne .failed
        dbra d0,.verify_label
        bsr custom_verify_hooks
        tst.w d0
        beq .failed
        bsr custom_install_hooks
        lea title_menu_select(pc),a0
        move.l a0,$5e8ca
        lea title_menu_dispatch(pc),a0
        move.l a0,$5e932
        lea editor_vbl(pc),a0
        move.l a0,$f0e6
        lea editor_keyboard(pc),a0
        move.l a0,$f060
        move.l #2,module_state-module_start(a5)
        ifd SERIAL_ENABLED
        movea.l serial_module_base(pc),a0
        jsr (a0)               ; guarded dormant install; no hardware takeover
        endif
        bsr cache_flush
        bra.s .done
.failed:
        move.l #3,module_state-module_start(a5)
.done:
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,ccr
        movea.l #$e700,a0
        rts
        ifd SERIAL_ENABLED
serial_module_base: dc.l 0
        endif
cpu_attn_flags: dc.w 0          ; Exec AttnFlags, stored by the bootstrap

; Push and invalidate caches after code installation or disk DMA.
; Supervisor mode only; preserves all registers and CCR.
; 68040/68060: CPUSHA. 68020/68030: CACR clear. 68000/68010: no cache.
cache_flush:
        move.w ccr,-(sp)
        movem.l d0-d1,-(sp)
        move.w cpu_attn_flags(pc),d1
        andi.w #$0088,d1        ; AFF_68040 | AFF_68060
        bne.s .push
        move.w cpu_attn_flags(pc),d1
        btst #1,d1              ; AFF_68020, also set on 68030
        beq.s .done
        movec cacr,d0
        ori.w #$0008,d0         ; CI: clear instruction cache
        btst #2,d1              ; AFF_68030
        beq.s .write
        ori.w #$0800,d0         ; CD: clear write-through data cache
.write: movec d0,cacr
        bra.s .done
.push:  cpusha bc
.done:  movem.l (sp)+,d0-d1
        move.w (sp)+,ccr
        rts

; Only the title menu owns the extra row. Preserve original menu result.
title_menu_select:
        move.l a0,-(sp)
        lea title_menu_active(pc),a0
        move.b #1,(a0)
        movea.l (sp)+,a0
        move.b #3,d2
        jsr $5b840.l
        move.w ccr,-(sp)
        move.l a0,-(sp)
        lea title_menu_active(pc),a0
        clr.b (a0)
        movea.l (sp)+,a0
        move.w (sp)+,ccr
        rts

; Tail calls preserve the original caller's return address and callee CCR.
title_menu_dispatch:
        move.w ccr,-(sp)
        cmpi.b #2,d0
        beq.s .link
        cmpi.b #3,d0
        beq.s .editor
        move.w (sp)+,ccr
        ori.b #1,ccr
        rts
.link:  move.w (sp)+,ccr
        jmp $57c78.l
.editor:move.w (sp)+,ccr
        bra editor_enter

title_menu_active: dc.b 0
        even
title_editor_label: dc.b 'Track Editor',0
        even

; C=1 selects the original title-menu loop.
; Preserve all registers and all other CCR bits. No OS allocation in game.
editor_enter:
        move.w ccr,-(sp)
        movem.l d0-d7/a0-a6,-(sp)
        lea module_start(pc),a5
        move.b #1,editor_active-module_start(a5)
        addq.l #1,entry_count-module_start(a5)
        move.w $dff002,d0
        andi.w #$2f,d0
        move.w d0,saved_audio_dma-module_start(a5)
        move.w #$2f,$dff096
        ; Title buffers: four 8000-byte planes, two consecutive surfaces.
        movea.l $6a584,a0
        move.l a0,saved_screen-module_start(a5)
        movea.l a5,a1
        adda.l #$40000,a1
        move.w #15999,d0
.backup:
        move.l (a0),(a1)+
        clr.l (a0)+
        dbra d0,.backup
        lea $6a584.l,a0
        lea saved_display(pc),a1
        moveq #3,d0
.save_display:
        move.l (a0)+,(a1)+
        dbra d0,.save_display
        move.l $1b812,saved_publication-module_start(a5)
        move.b $1b816,saved_pending-module_start(a5)
        lea $e74e.l,a0
        lea saved_copper(pc),a1
        moveq #7,d0
.save_copper:
        move.l (a0)+,(a1)+
        dbra d0,.save_copper
        bsr editor_model_view
        clr.w overview_active-module_start(a5)
        clr.w overview_key-module_start(a5)
        clr.l camera_route-module_start(a5)
        move.w #3,camera_buttons-module_start(a5)
        bsr editor_building_reset
        bsr editor_release_physical
        bsr editor_input_start
        clr.w editor_view_valid-module_start(a5)
editor_loop:
        bsr editor_wait_vbl
        addq.l #1,editor_poll_count-module_start(a5)
        bsr editor_input_next
        bsr editor_sample_directions
        move.w d0,editor_directions-module_start(a5)
        bsr editor_building_keys
        bsr editor_storage_keys
        bsr editor_camera
        tst.w building_exit-module_start(a5)
        bne editor_leave
        bsr editor_view_changed
        beq editor_loop
render_begin:
        bsr block_render_enter
        bsr editor_render_adapter
        bsr block_render_exit
        bsr editor_storage_text
        bsr editor_building_text
        bsr storage_modal_text
render_end:
        ; Use original publication, but do not call gameplay's swap wrapper.
        move.l $6a588,d0
        move.l $6a58c,$6a588
        move.l d0,$6a58c
        jsr $1b7b6
.wait_publication:
        tst.b $1b816
        bne.s .wait_publication
        tst.w building_exit-module_start(a5)
        beq editor_loop
editor_leave:
        clr.w editor_input_enabled-module_start(a5)
        bsr editor_release_physical
editor_exit:
        movea.l saved_screen(pc),a0
        movea.l a5,a1
        adda.l #$40000,a1
        move.w #15999,d0
.restore:
        move.l (a1)+,(a0)+
        dbra d0,.restore
        lea saved_display(pc),a0
        lea $6a584.l,a1
        moveq #3,d0
.restore_display:
        move.l (a0)+,(a1)+
        dbra d0,.restore_display
        move.l saved_publication(pc),$1b812
        move.b saved_pending(pc),$1b816
        lea saved_copper(pc),a0
        lea $e74e.l,a1
        moveq #7,d0
.restore_copper:
        move.l (a0)+,(a1)+
        dbra d0,.restore_copper
        move.w saved_audio_dma(pc),d0
        ori.w #$8000,d0
        move.w d0,$dff096
        clr.b editor_active-module_start(a5)
        addq.l #1,exit_count-module_start(a5)
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,ccr
        ori.b #1,ccr
        rts

; Wait for non-modifier raw keys and both port fire buttons to be released.
; Exclude persistent Shift/Ctrl/lock modifiers ($60+). Read physical game
; input state without the menu reader's RNG side effect.
editor_release_physical:
        bsr.s editor_wait_vbl
        lea $ead6.l,a0
        moveq #95,d0
.keys:
        tst.b (a0)+
        bne.s editor_release_physical
        dbra d0,.keys
        bsr editor_read_directions
        tst.w d0
        bne.s editor_release_physical
        btst #6,$bfe001
        beq.s editor_release_physical
        btst #7,$bfe001
        beq.s editor_release_physical
        rts
editor_wait_vbl:
        move.w editor_ticks(pc),d0
.wait:
        cmp.w editor_ticks(pc),d0
        beq.s .wait
        rts

; Existing VBL interrupt saves all registers. Bypass game audio/timers only
; while owned; keyboard and display interrupts keep their original handlers.
editor_vbl:
        tst.b editor_active(pc)
        beq.s .game
        lea editor_ticks(pc),a0
        addq.w #1,(a0)
        bra editor_input_vbl
.game:
        move.l a0,-(sp)
        lea auto_vbl_count(pc),a0
        addq.w #1,(a0)
        movea.l (sp)+,a0
        jmp $616dc
old_label: dc.b 'Computer Link'
        even
editor_active: dc.b 0
        even
editor_ticks: dc.w 0
saved_audio_dma: dc.w 0
saved_screen: dc.l 0
entry_count: dc.l 0
exit_count: dc.l 0

saved_display: dcb.l 4,0
saved_publication: dc.l 0
saved_pending: dc.b 0
        even
saved_copper: dcb.l 8,0
        include "src/editor/input.s"
        include "src/editor/refresh.s"
        include "src/editor/render.s"

        include "src/editor/model.s"
        include "model-data.s"
        include "src/editor/storage.s"
        include "storage-font.s"
        include "src/editor/storage-ui.s"

        include "src/editor/building.s"
        include "building-data.s"
        include "src/editor/blocks.s"
        include "block-data.s"
        include "src/editor/editing.s"
        include "editing-data.s"

        include "src/editor/practice.s"

        include "src/editor/game.s"
        include "src/editor/preview-arrow.s"
        include "src/editor/auto-frame.s"
        include "src/editor/hud-copy.s"

; Port 2 JOY1DAT quadrature decoding, matching original read.joystick.
; D0 bits: up/down/left/right = 0/1/2/3. Keyboard arrows remain aliases.
editor_read_directions:
        bsr editor_read_joystick
        bra.s editor_physical_arrows
editor_read_joystick:
        movem.l d1-d2,-(sp)
        moveq #0,d0
        move.w $dff00c,d1
        move.w d1,d2
        lsr.w #1,d2
        eor.w d1,d2
        btst #8,d2
        beq.s .down
        bset #0,d0
.down:  btst #0,d2
        beq.s .left
        bset #1,d0
.left:  btst #9,d1
        beq.s .right
        bset #2,d0
.right: btst #1,d1
        beq.s .keyboard
        bset #3,d0
.keyboard:
        movem.l (sp)+,d1-d2
        rts
editor_physical_arrows:
        cmpi.b #$b3,$eb22
        bne.s .kd
        bset #0,d0
.kd:    cmpi.b #$b3,$eb23
        bne.s .kl
        bset #1,d0
.kl:    cmpi.b #$b3,$eb25
        bne.s .kr
        bset #2,d0
.kr:    cmpi.b #$b3,$eb24
        bne.s .done
        bset #3,d0
.done:  rts
editor_directions: dc.w 0

        include "src/editor/disk.s"
