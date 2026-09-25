; Keep race time real when a drawn frame is late: repeat fixed race steps.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Auto frame rate: keep race time real when a drawn frame is late.
; Every race step stays the fixed 20 ms step (Game Speed 20..30 ms). When
; a drawn frame covered N >= 2 PAL VBLs, the next N-1 loop iterations are
; logic-only: the 3D drawing $64f80..$650e1 and the pacing and display
; swap $5dac0 are skipped, everything else runs (input, physics, part A of
; $64e4c with the opponent and link hooks, lap clock, end checks, pause).
; Crane lifts use the same bounded catch-up with their existing fixed
; 20 ms physics step. Setup rendering stays complete, and the first
; regular drawn frame anchors the clock without catching up setup time.
;
; Hooks (custom HOOKS, original bytes checked before install):
;   $5d5a0 jsr $5dac0  -> auto_pace        loop pacing and swap
;   $5d574 jsr $5dac0  -> auto_pace_end    race-end pacing and swap
;   $5d5a6 jsr $5d9dc  -> auto_pause       pause check; paused time excluded
;   $64f80 move.b #$80,d0 / move.b d0,$1bc14 -> auto_render_gate (JMP)
; The VBL count comes from editor_vbl (the game's VBL call at $f0e4).
AUTO_MAX_STEPS equ 4            ; steps per drawn frame (80 ms)
AUTO_RESYNC equ 50              ; longer gaps (1 s) are not caught up

auto_state:
auto_vbl_count: dc.w 0          ; VBL interrupts
auto_last: dc.w 0               ; VBL count at the previous drawn frame
auto_pending: dc.b 0            ; logic-only steps still due
auto_skip: dc.b 0               ; this iteration is logic-only
auto_frames: dc.l 0             ; drawn race frames
auto_extra: dc.l 0              ; logic-only steps run
auto_late: dc.l 0               ; drawn frames that covered >= 2 VBLs
auto_max: dc.w 0                ; longest drawn frame in VBLs
auto_crane_late: dc.l 0         ; late crane frames eligible for catch-up
auto_crane_primed: dc.b 0       ; first regular drawn frame only anchors time
        even

; Race loop pacing. Logic-only iteration: no wait, no swap.
auto_pace:
        movem.l d0-d1/a0,-(sp)
        lea auto_state(pc),a0
        tst.b auto_skip-auto_state(a0)
        beq.s .drawn
        addq.l #1,auto_extra-auto_state(a0)
        subq.b #1,auto_pending-auto_state(a0)
        tst.b auto_pending-auto_state(a0)
        sne auto_skip-auto_state(a0)
        movem.l (sp)+,d0-d1/a0
        rts
.drawn:
        movem.l (sp)+,d0-d1/a0
        jsr $5dac0
        movem.l d0-d1/a0,-(sp)
        lea auto_state(pc),a0
        addq.l #1,auto_frames-auto_state(a0)
        move.w auto_vbl_count-auto_state(a0),d0
        move.w d0,d1
        sub.w auto_last-auto_state(a0),d1
        move.w d0,auto_last-auto_state(a0)
        clr.b auto_pending-auto_state(a0)
        clr.b auto_skip-auto_state(a0)
        tst.b auto_crane_primed-auto_state(a0)
        bne.s .primed
        st auto_crane_primed-auto_state(a0)
        bra.s .done                 ; exclude setup/fade from race-step debt
.primed:
        cmpi.w #AUTO_RESYNC,d1
        bhi.s .done                 ; race start or other discontinuity
        cmp.w auto_max-auto_state(a0),d1
        bls.s .max
        move.w d1,auto_max-auto_state(a0)
.max:   cmpi.w #2,d1
        bcs.s .done
        addq.l #1,auto_late-auto_state(a0)
        tst.b $1bbdf                ; count late crane frames separately
        beq.s .catch
        addq.l #1,auto_crane_late-auto_state(a0)
.catch: cmpi.w #AUTO_MAX_STEPS,d1
        bls.s .steps
        moveq #AUTO_MAX_STEPS,d1
.steps: subq.w #1,d1
        move.b d1,auto_pending-auto_state(a0)
        st auto_skip-auto_state(a0)
.done:  movem.l (sp)+,d0-d1/a0
        rts

; Race end: a logic-only iteration keeps the last drawn frame on screen.
auto_pace_end:
        move.l a0,-(sp)
        move.l d0,-(sp)
        lea auto_state(pc),a0
        move.b auto_skip-auto_state(a0),d0
        clr.b auto_skip-auto_state(a0)
        clr.b auto_pending-auto_state(a0)
        tst.b d0
        movem.l (sp)+,d0/a0         ; MOVEM keeps the flags of TST
        bne.s .skip
        jmp $5dac0
.skip:  rts

; Pause: time spent inside the pause check is not caught up.
auto_pause:
        movem.l d0/a0,-(sp)
        lea auto_state(pc),a0
        move.w auto_vbl_count-auto_state(a0),-(sp)
        jsr $5d9dc
        lea auto_state(pc),a0
        move.w auto_vbl_count-auto_state(a0),d0
        sub.w (sp)+,d0
        cmpi.w #2,d0
        bcs.s .run
        add.w d0,auto_last-auto_state(a0)
.run:   movem.l (sp)+,d0/a0
        rts

; Start of the drawing part of $64e4c. Logic-only iteration: skip the 3D
; drawing ($64f80..$650e1) and continue at $650e2, the join point that the
; other path of part A already uses. From there the current code runs
; unchanged: the dust/effects call (the runtime has replaced $60c92/$60cf8
; at $650f6), $662b4, the cheap HUD digits (into the hidden buffer, redrawn
; by the next drawn frame), engine sound $5e778 and $5e508, then RTS to
; $5d49c. The link receive tail at $650a8 lies inside the skipped range and
; is called through its current JSR target. The dust code indexes with
; D1.W after a byte load; the drawn path leaves the upper byte clear, so
; D0-D3 are cleared here.
auto_render_gate:
        ; race_init clears the performance active byte before the two
        ; setup draws, including recovery via $5d608 -> $5d402. Those
        ; draws use direct swaps and must never inherit a logic-only flag.
        tst.b AUTO_CRANE_ACTIVE_ADDR
        bne.s .regular
        move.l a0,-(sp)
        lea auto_state(pc),a0
        clr.b auto_pending-auto_state(a0)
        clr.b auto_skip-auto_state(a0)
        clr.b auto_crane_primed-auto_state(a0)
        movea.l (sp)+,a0
        bra.s .draw
.regular:
        tst.b auto_skip(pc)
        bne.s .logic
.draw:
        move.b #$80,d0              ; displaced original instructions
        move.b d0,$1bc14
        jmp $64f8a
.logic:
        tst.b $57c3c
        beq.s .join
        cmpi.w #$4eb9,$650a8        ; JSR abs.l as checked at install
        bne.s .join
        movea.l $650aa,a0           ; link receive tail ($57440 or hook)
        jsr (a0)
.join:  moveq #0,d0
        moveq #0,d1
        moveq #0,d2
        moveq #0,d3
        jmp $650e2
