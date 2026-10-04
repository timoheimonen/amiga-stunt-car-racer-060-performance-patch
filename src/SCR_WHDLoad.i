; WHDLoad interface values used by the slave.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; The parts of the WHDLoad slave interface the slave uses, as described in the
; WHDLoad autodoc and include file: slave flags, termination reasons, the
; offsets of the resload functions from the resload base passed to the slave
; in A0, and the resload_Control tags for the CPU flags, the ButtonWait
; option and the function called on each return from the system.

WHDLF_NoError           equ 1<<1        ; resload errors quit with a requester
WHDLF_EmulTrap          equ 1<<2        ; forward TRAP #n to the program's vectors
WHDLF_ClearMem          equ 1<<12       ; clear BaseMem and ExpMem instead of filling

TDREASON_OK             equ -1
TDREASON_WRONGVER       equ 9
TDREASON_OSEMUFAIL      equ 10

resload_Abort           equ $04
resload_LoadFile        equ $08
resload_SaveFile        equ $0c
resload_FlushCache      equ $20
resload_GetFileSize     equ $24
resload_Control         equ $34
resload_LoadFileOffset  equ $4c
resload_Delay           equ $54

WHDLTAG_ATTNFLAGS_GET   equ $88000000   ; TAG_USER+$8000000: exec AttnFlags
WHDLTAG_BUTTONWAIT_GET  equ $88000006   ; option ButtonWait/S: -1 or 0
WHDLTAG_CBSWITCH_SET    equ $8800000c   ; function called on each return from the system
