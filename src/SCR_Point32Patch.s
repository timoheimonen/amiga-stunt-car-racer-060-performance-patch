; Place the 32-bit screen-point routine in its fixed instruction slot.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

        machine 68060
screen_point32_start:
        include "src/SCR_Point32.s"
        dcb.w (72-(*-screen_point32_start))/2,$4e71
