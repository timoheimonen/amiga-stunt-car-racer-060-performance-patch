; Apply the Infinite Boost setting to turbo reserve consumption.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Entered by JMP at $608cc after the original boost input/inhibit tests.
; Both paths reproduce the displaced MOVE.B exactly, including D0's upper
; bits and NZVC while preserving X, all other registers and the stack.
; NO continues through the original stock gate and BCD consumption.
; YES retains the actual stock/counter and uses the original boost flag and
; force shift at $60900, even with zero stock. It never synthesizes input.
speed_infinite_boost_gate:
        tst.b infinite_boost_enabled
        bne.s .infinite
        move.b $1ca20.l,d0
        jmp $608d2.l
.infinite:
        move.b $1ca20.l,d0
        jmp $60900.l
