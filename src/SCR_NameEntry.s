; Player-name call sites only: shared filename entry is left unchanged.
name_prompt_fire:
        movem.l d0/a2,-(sp)
        lea name_prompt_fire_text(pc),a2
        bsr.w speed_print_label
        movem.l (sp)+,d0/a2
        rts

; The original entry loop waits for release, accepts Fire as CR and pads
; the twelve-character name with spaces. Its last joystick poll remains
; in $1b88e (active-low Fire bit 4). Supply a default only for empty Fire
; confirmation. Typed names and keyboard Return keep their old behavior.
name_entry_fire:
        jsr $5b6de.l
        movem.l d0/a0,-(sp)
        btst #4,$1b88e.l
        bne.s .done
        moveq #0,d0
        move.b $1bbd5.l,d0
        lea $1ecab.l,a0
        adda.w d0,a0
        cmpi.b #' ',(a0)
        bne.s .done
        move.l #'race',(a0)
        move.b #'r',4(a0)
.done:
        movem.l (sp)+,d0/a0
        rts

name_prompt_fire_text:
        dc.b $1f,5,14,'NAME? OR PRESS FIRE TO CONTINUE'
        dc.b $1f,11,20,'PERFORMANCE EDITION'
        dc.b $1f,12,22,'BY TIMO HEIMONEN',0
        even
