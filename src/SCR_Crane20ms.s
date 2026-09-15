; Crane controller: 120 ms target increments spread over six 20 ms calls.
; Hooked ADD flags are dead (the next MOVE replaces NZVC); D0/D1 preserved.
; Startup runs on every new lift and clears the fraction before target motion.
        machine 68000
crane_startup20:
        clr.w crane_fraction20
        tst.b active
        beq.s crane_startup_advance20
        tst.b legacy_due
        beq.s crane_startup_done20
crane_startup_advance20:
        subq.b #1,$1bbdf.l
crane_startup_done20:
        rts
crane_target20:
        tst.b active
        beq.s crane_target_original20
        movem.l d0-d1,-(sp)
        ext.l d0
        move.w crane_fraction20(pc),d1
        ext.l d1
        add.l d1,d0
        divs.w #6,d0
        swap d0
        move.w d0,crane_fraction20
        swap d0
        add.w d0,$1bc00.l
        movem.l (sp)+,d0-d1
        rts
crane_target_original20:
        add.w d0,$1bc00.l
        rts
crane_fraction20: dc.w 0
