; Independent opponent integration. Every rendered frame recomputes springs,
; acceleration and position. Only random AI decisions retain the legacy pulse.
; Integrator channels: three vertical speeds/heights, road speed and progress.
; Entry wrappers replace the original 238/256 multiply/shift blocks.
OP_FACTOR macro
        movem.l d1/d3-d5/a0-a1,-(sp)
        move.w #\1,d1
        move.w #\2,d4
        bsr.w opponent_factor
        movem.l (sp)+,d1/d3-d5/a0-a1
        move.b #$ee,d2
        jmp \3.l
        endm
op_v0: OP_FACTOR 0,1536,$640fe
op_y0: OP_FACTOR 4,3072,$64118
op_v1: OP_FACTOR 8,1536,$64130
op_y1: OP_FACTOR 12,3072,$6414a
op_v2: OP_FACTOR 16,1536,$64162
op_y2: OP_FACTOR 20,3072,$6417c
op_speed: OP_FACTOR 24,1536,$63bf0
op_progress: OP_FACTOR 28,1536,$63a04

opponent_factor:
        tst.b active
        beq.s op_original
        lea op_targets(pc),a0
        movea.l (0,a0,d1.w),a1
        lea op_state(pc),a0
        move.l a1,d3
        beq.s op_no_target
        move.w (a1),d3
        cmp.w (2,a0,d1.w),d3
        beq.s op_no_target
        clr.w (0,a0,d1.w)   ; constraints/collisions externally changed state
op_no_target:
        muls.w #238,d0
        bsr.s op_divide
        move.l a1,d3
        beq.s op_factor_done
        move.w (a1),d3
        add.w d0,d3
        move.w d3,(2,a0,d1.w)
op_factor_done:
        rts
op_original:
        move.b #$ee,d2
        muls.w d2,d0
        asr.l #8,d0
        cmpi.w #3072,d4
        bne.s op_factor_done
        asr.w #1,d0
        rts

; D0.l signed numerator, D4.w positive denominator. Floor quotient D0.l.
; D1 indexes a four-byte state record (unsigned remainder, expected word).
op_divide:
        moveq #0,d3
        move.w (0,a0,d1.w),d3
        add.l d3,d0
        divs.w d4,d0
        move.l d0,d3
        swap d3
        tst.w d3
        bpl.s op_remainder_ok
        subq.w #1,d0
        add.w d4,d3
op_remainder_ok:
        move.w d3,(0,a0,d1.w)
        ext.l d0
        rts

; Unweighted per-step rates use the same exact signed fractional carry.
op_rate:
        movem.l d3-d4/a0,-(sp)
        ext.l d0
        tst.b active
        beq.s op_rate_done
        lea op_state(pc),a0
        moveq #6,d4
        bsr.s op_divide
op_rate_done:
        movem.l (sp)+,d3-d4/a0
        rts

op_steer:
        movem.l d1-d2,-(sp)
        ext.w d0             ; original decision supplies +9 or -9
        moveq #32,d1
        bsr.s op_rate
        movem.l (sp)+,d1-d2
        add.b $1bbed.l,d0
        rts

op_air_tilt:
        move.l d1,-(sp)
        move.w d1,-(sp)
        add.w d1,d1
        addi.w #36,d1       ; channels 9..11, indexed by wheel 0/2/4
        bsr.s op_rate
        move.w (sp)+,d1
        add.w d0,(0,a4,d1.w)
        subq.b #2,d1         ; displaced loop decrement sets caller flags
        addq.l #4,sp
        rts

op_collision_speed:
        movem.l d1/d3,-(sp)
        move.w d0,d3
        move.w $1bd58.l,d0
        moveq #48,d1
        bsr.w op_rate
        sub.w d0,d3
        move.w d3,d0
        movem.l (sp)+,d1/d3
        tst.w d0
        rts

op_collision_vertical:
        move.l d1,-(sp)
        move.w $1bd56.l,d0
        asr.w #4,d0
        moveq #52,d1
        bsr.w op_rate
        move.l (sp)+,d1
        jmp $63e72.l

op_damage:
        movem.l d0-d1,-(sp)
        moveq #0,d0
        move.b d3,d0
        moveq #56,d1
        bsr.w op_rate
        move.w d0,d3
        movem.l (sp)+,d0-d1
        movea.l #$1bb4f,a0
        rts

op_contact_tick:
        tst.b active
        beq.s op_contact_advance
        tst.b legacy_due
        beq.s op_contact_done
op_contact_advance:
        subq.b #1,$1bbc3.l
op_contact_done:
        rts

op_ai:
        tst.b active
        beq.s op_ai_advance
        tst.b legacy_due
        beq.s op_ai_done
op_ai_advance:
        jmp $5bd1e.l
op_ai_done:
        rts

op_random:
        tst.b active
        beq.s op_random_advance
        tst.b legacy_due
        beq.s op_random_skip
op_random_advance:
        move.b $1ca29.l,d1
        jmp $640b0.l
op_random_skip:
        jmp $640ec.l

opponent_reset:
        movem.l d0/a0,-(sp)
        lea op_state(pc),a0
        moveq #29,d0
op_reset_loop:
        clr.w (a0)+
        dbra d0,op_reset_loop
        movem.l (sp)+,d0/a0
        rts

op_targets:
        dc.l $1bd76,$1bd66,$1bd78,$1bd68,$1bd7a,$1bd6a,$1bbee,0
op_state: dcb.w 30,0

; 6181e adds a one-off BCD track-position penalty via the secondary clock
; entry at 5df32. That entry lies inside the main 5df2e JMP patch: redirect
; its caller here, retaining D0.b and bypassing the periodic tick gate.
lap_penalty:
        movea.l #$1c938,a0
        jmp $5df38.l
