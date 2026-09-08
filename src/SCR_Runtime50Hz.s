; 50 Hz player and computer-opponent runtime.
        include "src/SCR_Player20ms.s"
runtime_header:
        dc.l $52323031
        dc.l linear_entry,angular_entry,pose_entry,spring_entry
        dc.l race_init,frame_begin,event_clock,reload_wait,animation_step,decay_step
        dc.l lap_clock,wheel_phase,contact_reload,collision_reload,respawn_tick,race_exit
        dc.l display_swap,active,legacy_due,phase,next_gate,runtime_end

linear_entry:
        tst.b active
        bne.s linear_active
        move.w $1bcf6.l,d0       ; displaced original instruction
        jmp $61ae2.l
linear_active:
        bsr.w detect_linear
        bsr.w linear20
        bsr.w remember_linear
        rts
angular_entry:
        tst.b active
        bne.s angular_active
        move.w $1bcfc.l,d0
        jmp $61b2c.l
angular_active:
        bsr.w detect_angular
        bsr.w angular20
        bsr.w remember_angular
        rts
pose_entry:
        tst.b active
        bne.s pose_active
        move.w $1bcea.l,d0
        jmp $61956.l
pose_active:
        bsr.w detect_pose
        bsr.w pose20
        bsr.w remember_pose
        rts
spring_entry:
        tst.b active
        bne.s spring_active
        jmp $6180e.l
spring_active:
        jmp spring20

race_init:
        ; Original race/respawn initializer runs before the new state reset.
        jsr $605b6.l
        movem.l d0-d7/a0-a6,-(sp)
        move.w sr,-(sp)
        bsr.w reset20
        bsr.w opponent_reset
        clr.b active
        clr.b legacy_due
        move.b #5,phase
        clr.w decay_fraction
        move.w (sp)+,ccr
        movem.l (sp)+,d0-d7/a0-a6
        rts

frame_begin:
        movem.l d0/a0,-(sp)
        tst.b active
        bne.s frame_already_active
        tst.b $1ca22.l
        nop
        nop
        bsr.w reset20
        bsr.w opponent_reset
        move.b $1bbcd.l,next_gate
        move.b #5,phase
        move.b #1,active
frame_already_active:
        addq.b #1,phase
        cmpi.b #6,phase
        bcs.s frame_intermediate
        clr.b phase
        move.b #1,legacy_due
        move.b next_gate,$1bbcd.l
        subq.b #1,$1bbac.l
        bra.s frame_done
frame_intermediate:
        clr.b legacy_due
        move.b #$ff,$1bbcd.l
        bra.s frame_done
frame_unsupported:
        subq.b #1,$1bbac.l
frame_done:
        movem.l (sp)+,d0/a0
        rts

event_clock:
        tst.b active
        bne.s event_active
        addq.b #1,$1bbc9.l
        jmp $5db3a.l
event_active:
        tst.b legacy_due
        bne.s event_legacy
        move.b #$ff,$1bbcd.l
        jmp $5db72.l           ; keep event detection every frame
event_legacy:
        addq.b #1,$1bbc9.l
        move.b #0,d2
        move.b #$ee,d0
        add.b d0,$1bbcf.l
        bcs.s event_carry
        subq.b #1,d2
event_carry:
        move.b d2,$1bbcd.l
        move.b d2,next_gate
        jmp $5db58.l           ; original direct timer decrement and events

reload_wait:
        tst.b active
        beq.s reload_original
        move.b #1,$616d8.l
        rts
reload_original:
        move.b #6,$616d8.l
        rts

animation_step:
        tst.b active
        beq.s animation_advance
        tst.b legacy_due
        beq.s animation_compare
animation_advance:
        addq.b #1,d0
animation_compare:
        cmpi.b #3,d0
        rts

decay_step:
        tst.b active
        bne.s decay_active
        jmp $60fbe.l
decay_active:
        move.w $1bd30.l,d0
        bpl.s decay_abs
        neg.w d0
decay_abs:
        move.w d0,$1bd5c.l
        move.b $1bb7e.l,d1
        beq.s decay_air
        clr.w decay_fraction
        jmp $60fea.l
decay_air:
        movem.l d2-d3,-(sp)
        move.w $1bc62.l,d0
        mulu.w #3068,d0        ; 1 - sixth_root(3/4), quantized to Q16
        moveq #0,d3
        move.w decay_fraction,d3
        add.l d3,d0
        move.w d0,decay_fraction
        swap d0
        movem.l (sp)+,d2-d3
        sub.w d0,$1bc62.l
        rts

lap_clock:
        tst.b active
        beq.s lap_advance
        tst.b legacy_due
        beq.s lap_done
lap_advance:
        move.b #$13,d0
        movea.l #$1c938,a0
        jmp $5df38.l
lap_done:
        rts

wheel_phase:
        add.b d0,$1bbe3.l
        rts

contact_reload:
        move.b #5,$620b6.l
        tst.b active
        beq.s contact_done
        move.b #30,$620b6.l
contact_done:
        rts
collision_reload:
        move.b #5,$63ee0.l
        tst.b active
        beq.s collision_done
        move.b #30,$63ee0.l
collision_done:
        rts

respawn_tick:
        tst.b active
        beq.s respawn_advance
        tst.b legacy_due
        bne.s respawn_advance
        tst.b $1bb41.l         ; caller tests sign
        rts
respawn_advance:
        subq.b #1,$1bb41.l
        rts

race_exit:
        clr.b active
        move.b #6,$616d8.l
        move.w #$20,$69ede.l
        rts

; Detect externally replaced coordinates/velocities before reusing their
; fractional remainder. Helpers preserve the whole caller register/CCR state.
SYNC macro
        move.w sr,-(sp)
        movem.l d0-d3/a0-a2,-(sp)
        moveq #\1,d1
        moveq #\2,d2
        moveq #\3,d3
        bsr.w sync_state
        movem.l (sp)+,d0-d3/a0-a2
        move.w (sp)+,ccr
        rts
        endm
detect_linear:  SYNC 0,2,0
remember_linear: SYNC 0,2,1
detect_angular: SYNC 3,2,0
remember_angular: SYNC 3,2,1
detect_pose: SYNC 6,5,0
remember_pose: SYNC 6,5,1
sync_state:
        lea channel_addresses(pc),a0
        lea previous_values(pc),a1
        lea remainders(pc),a2
sync_loop:
        move.w d1,d0
        lsl.w #2,d0
        move.l a0,-(sp)
        movea.l (0,a0,d0.w),a0
        cmpi.w #6,d1
        bcs.s sync_word
        cmpi.w #9,d1
        bcc.s sync_word
        move.l (a0),a0
        bra.s sync_loaded
sync_word:
        move.w (a0),a0        ; sign-extended MOVEA.W; compare same format
sync_loaded:
        tst.b d3
        bne.s sync_remember
        cmpa.l (0,a1,d0.w),a0
        beq.s sync_next
        move.w d1,d0
        add.w d0,d0
        clr.w (0,a2,d0.w)
        bra.s sync_next
sync_remember:
        move.l a0,(0,a1,d0.w)
sync_next:
        movea.l (sp)+,a0
        addq.w #1,d1
        dbra d2,sync_loop
        rts

active: dc.b 0
legacy_due: dc.b 0
phase: dc.b 5
next_gate: dc.b 0
        even
decay_fraction: dc.w 0
channel_addresses:
        dc.l $1bcea,$1bcec,$1bcee,$1bcf0,$1bcf2,$1bcf4
        dc.l $1bcd8,$1bcdc,$1bce0,$1bce4,$1bce6,$1bce8
previous_values: dcb.l 12,0
display_swap:
        jsr $1b7b6.l
        move.w sr,-(sp)
        tst.b active
        nop
wait_publication:
        tst.b $1b816.l
        bne.s wait_publication
display_done:
        move.w (sp)+,ccr
        rts
        include "src/SCR_Opponent20ms.s"
        include "src/SCR_ObjectSetup060.s"
        include "src/SCR_TransformPoints060.s"
        include "src/SCR_TrackPoints060.s"
        include "src/SCR_FillSpans060.s"
        include "src/SCR_CoefficientsTail060.s"
        include "src/SCR_Angles060.s"
        include "src/SCR_Colors060.s"
runtime_end:
