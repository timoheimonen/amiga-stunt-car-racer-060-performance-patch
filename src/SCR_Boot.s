; Bootblock extension, linked at boot-relative $200. Exec V37+ / 2 MiB Chip.
; Original boot $2c AllocMem is redirected to reserve_memory.
; Original boot $70 (motor-off DoIO) is redirected to install_runtime.
        org $200
reserve_memory:
        movem.l d1-d7/a0-a6,-(sp)
        move.l #$1000,d0
        movea.l #$181000,a1
        jsr -$cc(a6)           ; Exec AllocAbs(byteSize, location)
        tst.l d0
        beq.s allocation_failed
        move.l #$9800,d0
        move.l #$10002,d1      ; original MEMF_CHIP | MEMF_CLEAR
        jsr -$c6(a6)           ; original AllocMem
        tst.l d0
        beq.s allocation_failed
        movem.l (sp)+,d1-d7/a0-a6
        rts
allocation_failed:
        jsr -$96(a6)           ; SuperState (same as original boot)
        move.w #$2700,sr
        move.w #$7fff,$dff096   ; stop DMA, keep failure visible
        move.w #$0f00,$dff180
.halt:  bra.s .halt
install_runtime:
        jsr -$1c8(a6)          ; original motor-off DoIO
        movem.l d0-d7/a0-a6,-(sp)
        movea.l a3,a0          ; initial-load allocation
        adda.l #$8b20,a0       ; payload beyond original loader copy
        movea.l #$181000,a1
        move.w #1368,d0         ; 2738 bytes / 2 - 1
.copy:  move.w (a0)+,(a1)+
        dbra d0,.copy
        jsr -$27c(a6)          ; CacheClearU before executing copied code
        movem.l (sp)+,d0-d7/a0-a6
        rts
