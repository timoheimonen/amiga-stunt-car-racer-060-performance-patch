; Appended after the unchanged render060 boot extension ($286).
; Original boot entered Forbid: balance it only while Intuition runs.
run_intro:
        bsr install_runtime
        movem.l d0-d7/a0-a6,-(sp)
        move.l 4.w,a6
        move.l #16384,d0       ; 8 KiB payload + 8 KiB private call stack, CHIP
        move.l #$10002,d1
        jsr -198(a6)
        tst.l d0
        beq .done
        move.l d0,a4
        move.l sp,a3
        lea 16384(a4),sp
        move.l 36(a2),-(sp)
        move.l 40(a2),-(sp)
        move.l 44(a2),-(sp)
        move.w 28(a2),-(sp)
        move.l a4,40(a2)
        move.l #8192,36(a2)
        move.l #$74000,44(a2)
        move.w #2,28(a2)
        move.l a2,a1
        jsr -456(a6)
        tst.b 31(a2)
        bne.s .restore_io
        move.l a4,a0
        moveq #0,d0
        move.w #2047,d1
.sum:   add.l (a0)+,d0
        dbra d1,.sum
        cmp.l #INTRO_SUM,d0
        bne.s .restore_io
        ; No disk DMA remains while the intro owns its screen.
        move.w #9,28(a2)
        clr.l 36(a2)
        move.l a2,a1
        jsr -456(a6)
        jsr -636(a6)
        jsr -138(a6)           ; Permit balances original boot's Forbid
        jsr (a4)
        move.l 4.w,a6
        jsr -132(a6)           ; restore original boot task nesting
.restore_io:
        move.w (sp)+,28(a2)
        move.l (sp)+,44(a2)
        move.l (sp)+,40(a2)
        move.l (sp)+,36(a2)
        move.l a3,sp
        move.l a4,a1
        move.l #16384,d0
        jsr -210(a6)
.done:  movem.l (sp)+,d0-d7/a0-a6
        rts
