; Bypass automatic yaw correction during manual steering.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Manual steering bypasses fractional yaw correction.
        bcs.w yaw_damping20
