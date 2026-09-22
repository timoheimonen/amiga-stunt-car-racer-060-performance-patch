; Load the editor module and allocate its Chip and Fast memory.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Called with A3=first-load allocation, A2=trackdisk request, OS still alive.
; Preserve registers and CCR. The module is owned until emulator reset/exit.
bootstrap_start:
        move.w ccr,-(sp)
        movem.l d0-d7/a0-a6,-(sp)
        move.l 4.w,a6
        moveq #1,d7             ; Chip allocation failure / unsafe address range
chip_allocate:
        move.l #CHIP_BYTES,d0
        move.l #$50002,d1       ; MEMF_REVERSE | MEMF_CLEAR | MEMF_CHIP
        jsr -198(a6)
chip_allocated:
        tst.l d0
        beq done
        move.l d0,a4
        cmpi.l #$190000,d0     ; above fixed game + performance Chip areas
        blo chip_rejected
        addi.l #CHIP_BYTES,d0
        cmpi.l #$200000,d0
        bhi chip_rejected
        move.l sp,a5
        movea.l a4,sp
        adda.l #CHIP_BYTES,sp   ; private stack beyond the DMA buffer
        move.l 28(a2),-(sp)
        move.l 32(a2),-(sp)
        move.l 36(a2),-(sp)
        move.l 40(a2),-(sp)
        move.l 44(a2),-(sp)
        move.l a4,40(a2)
        move.l #READ_BYTES,36(a2)
        move.l #DISK_OFFSET,44(a2)
        move.w #2,28(a2)
        move.l a2,a1
        jsr -456(a6)
read_complete:
        moveq #2,d7             ; I/O error or short read
        tst.b 31(a2)
        bne restore_io
        cmpi.l #READ_BYTES,32(a2)
        bne restore_io
        moveq #3,d7             ; malformed or corrupt package
        move.l a4,a0
        moveq #0,d0
        move.l #READ_BYTES/4,d1
sum_loop:
        add.l (a0)+,d0
        subq.l #1,d1
        bne.s sum_loop
        cmpi.l #PAYLOAD_SUM,d0
        bne restore_io
        cmpi.l #$53434945,4(a4)  ; SCIE
        bne restore_io
        cmpi.l #$00010020,8(a4)  ; ABI 1, header 32
        bne restore_io
        cmpi.l #FAST_BYTES,20(a4)
        bne restore_io
        cmpi.l #MODULE_BYTES,24(a4)
        bne restore_io
        moveq #5,d7             ; incompatible continuation: publish nothing
        cmpi.w #$207c,$124(a3)
        bne restore_io
        cmpi.l #$e700,$126(a3)
        bne restore_io
        moveq #4,d7             ; persistent Fast allocation failure
fast_allocate:
        move.l #FAST_BYTES,d0
        move.l #$10004,d1       ; MEMF_CLEAR | MEMF_FAST, never Chip fallback
        jsr -198(a6)
fast_allocated:
        tst.l d0
        beq restore_io
        move.l d0,d6
        move.l d0,a0
        move.l a4,a1
        move.l #READ_BYTES/4,d1
copy_loop:
        move.l (a1)+,(a0)+
        subq.l #1,d1
        bne.s copy_loop
        move.l d6,a0
        move.l #1,12(a0)
        move.l d6,16(a0)
        move.l a4,28(a0)        ; persistent Chip MFM + decoded sector buffers
        ; Single publication point after all validation and allocation.
        ; Game loader is not executing concurrently.
publish:
        move.w #$4eb9,$124(a3)
        move.l d6,$126(a3)
        jsr -636(a6)            ; CacheClearU, before any Fast code executes
        moveq #6,d7
restore_io:
        move.w #9,28(a2)        ; synchronous motor off, then restore request
        clr.l 36(a2)
        move.l a2,a1
        jsr -456(a6)
        move.l (sp)+,44(a2)
        move.l (sp)+,40(a2)
        move.l (sp)+,36(a2)
        move.l (sp)+,32(a2)
        move.l (sp)+,28(a2)
        move.l a5,sp
        cmpi.l #6,d7
        beq.s done             ; successful module owns Chip until reset
        move.l a4,a1
        move.l #CHIP_BYTES,d0
        jsr -210(a6)
        bra.s done
chip_rejected:
        move.l a4,a1
        move.l #CHIP_BYTES,d0
        jsr -210(a6)
done:
        lea boot_status(pc),a0
        move.l d7,(a0)
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,ccr
        rts
boot_status: dc.l 0

; Called from first-load+$34 after OS interrupts have been disabled. Disarm
; sprite data left by Intuition before displaying the original loading screen.
; Clearing DMA alone does not clear the hardware's armed data registers.
loader_clear_sprites:
        move.w #$7c7f,$dff096
        movem.l d0/a0,-(sp)
        lea $dff140.l,a0
        moveq #15,d0
.clear_sprite:
        clr.l (a0)+
        dbra d0,.clear_sprite
        movem.l (sp)+,d0/a0
        move.w #$7c7f,$dff096    ; displaced MOVE's CCR, including preserved X
        rts
