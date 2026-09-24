; Link frame parser: 32-byte frames with CRC.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Link framing core.
; 68000 instructions; caller-owned, even-aligned 66-byte context:
;   +0 word collected count, +2 32-byte window, +34 complete frame.
; Initialize count to zero. Exactly one execution context owns the parser.
; The completion buffer is valid only after push returns 1. Consume its
; event metadata before feeding another byte; it is not a concurrent mailbox.
SCR25_SIZE       equ 32
SCR25_BODY       equ 28
SCR25_MAGIC      equ $d391
SCR25_COUNT      equ 0
SCR25_WINDOW     equ 2
SCR25_COMPLETE   equ 34
SCR25_CONTEXT   equ 66

; a1=data, d0.w=length (0..65535). Returns zero-extended CRC in d0.
; CRC-16/CCITT-FALSE: init ffff, polynomial 1021, no reflection/xorout.
; Preserves every register except d0; CCR undefined.
scr25_crc:
        movem.l d1-d3/a1,-(sp)
        move.w d0,d3
        move.w #$ffff,d1
        tst.w d3
        beq.s scr25_crc_done
scr25_crc_byte:
        moveq #0,d0
        move.b (a1)+,d0
        lsl.w #8,d0
        eor.w d0,d1
        moveq #7,d2
scr25_crc_bit:
        add.w d1,d1
        bcc.s scr25_crc_next
        eori.w #$1021,d1
scr25_crc_next:
        dbra d2,scr25_crc_bit
        subq.w #1,d3
        bne.s scr25_crc_byte
scr25_crc_done:
        moveq #0,d0
        move.w d1,d0
        movem.l (sp)+,d1-d3/a1
        rts

; a0=context, d0.b=one received byte. Returns d0.l=1 for a whole,
; checked frame copied to +34; otherwise 0 and leaves +34 untouched.
; All other registers preserved. No I/O, polling, allocation or game writes.
; At most one 30-byte CRC and one 32-byte copy per call. Invalid frames
; advance by ONE byte, preserving embedded headers for resynchronization.
scr25_push:
        movem.l d1-d3/a1-a2,-(sp)
        move.w SCR25_COUNT(a0),d1
        lea SCR25_WINDOW(a0),a1
        move.b d0,(0,a1,d1.w)
        addq.w #1,d1
        move.w d1,SCR25_COUNT(a0)
        cmpi.w #SCR25_SIZE,d1
        bne.s scr25_incomplete
        cmpi.w #SCR25_MAGIC,(a1)
        bne.s scr25_slide
        moveq #SCR25_SIZE-2,d0
        bsr.w scr25_crc
        cmp.w SCR25_SIZE-2(a1),d0
        bne.s scr25_slide
        lea SCR25_COMPLETE(a0),a2
        moveq #SCR25_SIZE/2-1,d1
scr25_copy:
        move.w (a1)+,(a2)+
        dbra d1,scr25_copy
        clr.w SCR25_COUNT(a0)
        moveq #1,d0
        bra.s scr25_return
scr25_slide:
        lea 1(a1),a2
        moveq #SCR25_SIZE-2,d1
scr25_shift:
        move.b (a2)+,(a1)+
        dbra d1,scr25_shift
        move.w #SCR25_SIZE-1,SCR25_COUNT(a0)
scr25_incomplete:
        moveq #0,d0
scr25_return:
        movem.l (sp)+,d1-d3/a1-a2
        rts

; d0.w=candidate, d1.w=last accepted. Caller checks agreed generation
; and live-session timeout FIRST. No comparison to the local game clock.
; Returns d0.l=1 iff modular delta is 1..32767. Equal, old and the
; ambiguous half-range delta 32768 return 0. Preserves other registers.
scr25_newer:
        sub.w d1,d0
        tst.w d0
        ble.s scr25_not_newer
        moveq #1,d0
        rts
scr25_not_newer:
        moveq #0,d0
        rts
