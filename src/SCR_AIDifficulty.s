; AI DIFFICULTY changes the selected target, never the simulation time step.
; Entered with JSR from $63c6c; D0.b is the selected target plus bit 7.
; Return D0.b and $1bb4a with the adjusted target, preserving D0's upper
; 24 bits, all other registers and X. Final NZVC match MOVE.B of the result.
speed_ai_target:
        cmpi.w #20,ai_difficulty_k
        beq.s .original
        tst.b d0
        bmi.s .original           ; flagged special-piece target is unchanged
        movem.l d1,-(sp)
        moveq #0,d1
        move.b d0,d1
        mulu.w ai_difficulty_k(pc),d1
        divu.w #20,d1             ; unsigned floor; neither MULU nor DIVU alters X
        cmpi.w #120,d1
        bls.s .limited
        move.w #120,d1
.limited:
        cmp.b d0,d1
        bls.s .preserve_base      ; max(base, min(120, floor(base*k/20)))
        move.b d1,d0
.preserve_base:
        movem.l (sp)+,d1
.original:
        andi.b #$7f,d0
        move.b d0,$1bb4a.l
        rts

; $63bf0 used ADD.W followed by BPL, turning positive signed overflow into
; zero speed. Raised targets can approach that boundary. Preserve the exact
; original add/CCR at 100%. Above 100%, saturate only positive signed overflow
; at $7fff. V=1,N=1 after ADD identifies two nonnegative signed operands whose
; sum exceeds $7fff; negative braking/negative overflow is not saturated.
; The unchanged BPL at $63bf6 still handles ordinary negative results.
; No data/address register or time-step/remainder state is modified here.
speed_ai_speed_add:
        cmpi.w #20,ai_difficulty_k
        beq.s .original
        add.w d0,$1bbee.l
        bvc.s .done
        bpl.s .done
        move.w #$7fff,$1bbee.l    ; MOVE clears NZVC; X is original ADD carry (0)
.done:
        rts
.original:
        add.w d0,$1bbee.l
        rts
