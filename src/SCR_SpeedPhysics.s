; Scale the simulation step for the Game Speed setting.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; SPEED ADJUST: one 50 Hz update, selected simulated step 20..30 ms.
; Existing entry addresses, state records and reset/clamp hooks are retained.
; Five entry prefixes dispatch through guarded absolute JMPs.
; All instructions are 68000-compatible. Clocks and crane code are unchanged.

; The shared spring entry is reached by JMP from spring_entry, leaving the
; original game JSR return on the stack. Player returns are 61c36/61d5e/61e86;
; opponent returns are 63f46/63fae/64016. Only player crane physics stays 100%.
speed_start:
speed_spring20:
        move.w speed_spring(pc),d3
        tst.b $1bbdf.l
        beq.s .selected
        cmpi.l #$62000,(sp)
        bcc.s .selected
        move.w #1656,d3
.selected:
        muls.w d3,d0
        jmp spring20+6       ; unchanged shift, saturation and final TST.W

; D1.w indexes the original 12 unsigned remainder words. Units become
; 1/15360 for every speed, including the baseline used during a crane lift.
speed_scale20:
        movem.l d3/a0,-(sp)
        move.w d2,d3
        andi.w #$ff00,d3
        bne.w invalid_coefficient
        lea remainders(pc),a0
        move.w #2380,d3
        tst.b $1bbdf.l
        bne.s .selected
        move.w speed_multiplier(pc),d3
.selected:
        muls.w d3,d0
        moveq #0,d3
        move.w (0,a0,d1.w),d3
        add.l d3,d0
        divs.w #15360,d0
        move.l d0,d3
        swap d3
        tst.w d3
        bpl.s .positive
        subq.w #1,d0
        addi.w #15360,d3
.positive:
        move.w d3,(0,a0,d1.w)
        ext.l d0
        jmp scale_done

; The original wrappers supply denominator 1536/3072. Multiply it by ten
; only in the active path; inactive original arithmetic retains its contract.
speed_opponent_factor:
        tst.b active
        beq.w op_original
        lea op_targets(pc),a0
        movea.l (0,a0,d1.w),a1
        lea op_state(pc),a0
        move.l a1,d3
        beq.s .no_target
        move.w (a1),d3
        cmp.w (2,a0,d1.w),d3
        beq.s .no_target
        clr.w (0,a0,d1.w)
.no_target:
        mulu.w #10,d4
        muls.w speed_multiplier(pc),d0
        bsr.w op_divide
        move.l a1,d3
        beq.s .done
        move.w (a1),d3
        add.w d0,d3
        move.w d3,(2,a0,d1.w)
.done:
        rts

; Physical rates use floor((value*k+remainder)/120). Damage channel +56
; retains floor((value+remainder)/6), matching the unchanged damage clock.
speed_op_rate:
        movem.l d3-d4/a0,-(sp)
        ext.l d0
        tst.b active
        beq.s .done
        lea op_state(pc),a0
        moveq #6,d4
        cmpi.w #56,d1
        beq.s .divide
        muls.w speed_k(pc),d0
        moveq #120,d4
.divide:
        bsr.w op_divide
.done:
        movem.l (sp)+,d3-d4/a0
        rts

; Keep all contact behavior and the Q16 fractional accumulator. D2 is saved
; as in the old entry; it temporarily selects baseline decay during a lift.
speed_decay_step:
        tst.b active
        bne.s .active
        jmp $60fbe.l
.active:
        move.w $1bd30.l,d0
        bpl.s .absolute
        neg.w d0
.absolute:
        move.w d0,$1bd5c.l
        move.b $1bb7e.l,d1
        beq.s .air
        clr.w decay_fraction
        jmp $60fea.l
.air:
        movem.l d2-d3,-(sp)
        move.w #3068,d2
        tst.b $1bbdf.l
        bne.s .selected
        move.w speed_decay(pc),d2
.selected:
        move.w $1bc62.l,d0
        mulu.w d2,d0
        moveq #0,d3
        move.w decay_fraction,d3
        add.l d3,d0
        move.w d0,decay_fraction
        swap d0
        movem.l (sp)+,d2-d3
        sub.w d0,$1bc62.l
        rts

; Only the neutral correction prefix is redirected. The original damping
; tail and manual-steering branch retain their original addresses.
; Signed remainder uses denominator120 at every speed; reset is unchanged.
speed_yaw_correction:
        move.l d0,-(sp)
        moveq #20,d2
        tst.b $1bbdf.l
        bne.s .selected
        move.w speed_k(pc),d2
.selected:
        muls.w d2,d0
        move.w op_state+58(pc),d2
        ext.l d2
        add.l d2,d0
        divs.w #120,d0
        swap d0
        move.w d0,op_state+58
        swap d0
        add.w d0,$1bce6.l
        move.l (sp)+,d0
        jmp $611f2.l          ; yaw_damping20 in the guarded 1.0.2 hook
