; Transform screen points with full 32-bit intermediate precision.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Shared screen-point kernel. Inputs and output arrays keep their word ABI.
; D4/D5 retain the original input words; D0/D3 are scratch as before.
; Q15 rotation coefficients from the game satisfy |c|+|s| <= 46342.
; Thus even full signed-word inputs and the rounding bias fit signed long.
; Combine full 16x16 products, then round once to the nearest screen pixel
; (halfway toward +infinity). SWAP / ASR.W #1 extracts (sum + 65536) >> 17.
; Four coefficient reads and X-before-Y writes preserve the access ordering.
        move.w (0,a5,d1.w),d5
        move.w (0,a4,d1.w),d4
        move.w $22(a3),d0
        muls.w d5,d0
        move.w $20(a3),d3
        muls.w d4,d3
        add.l d3,d0
        addi.l #$10000,d0
        swap d0
        asr.w #1,d0
        addi.w #128,d0
        move.w d0,(0,a5,d1.w)
        move.w $22(a3),d0
        muls.w d4,d0
        move.w $20(a3),d3
        muls.w d5,d3
        sub.l d3,d0
        addi.l #$10000,d0
        swap d0
        asr.w #1,d0
        addi.w #64,d0
        move.w d0,(0,a4,d1.w)
