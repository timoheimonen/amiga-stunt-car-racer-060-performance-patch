; WHDLoad slave: start the patched game disk from a hard disk.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Starts the patched game disk, installed as Disk.1, from a hard disk.
;
; The slave runs the disk's own boot block with a minimal exec.library and
; trackdisk.device in front of it: the boot block, the performance runtime
; installer and the editor bootstrap allocate their memory and read the disk
; exactly as on floppy. Chip allocations come from BaseMem, Fast allocations
; from ExpMem, and every read goes through resload_DiskLoad. The intro is
; skipped. Before the boot block enters the game's loader, the loader's floppy
; driver is replaced with the same reads; after the loader has read the main
; program, the game's own floppy driver is replaced as well.
;
; The disk areas the game and the track editor write are files in the install
; directory itself (see file_map), as WHDLoad does not create subdirectories:
; each custom track slot, its records, the track index, and the game's own
; save index and saves. A file stands for its sectors in both copies the
; editor keeps on floppy; without the file, the disk's original sectors are
; read. Writes outside these areas are refused as on a write-protected disk,
; so Disk.1 is never written.
;
; Addresses: boot block offsets are relative to the boot block, first-load
; offsets relative to the first-load allocation (A3 in the boot block), game
; addresses are runtime addresses of the main program loaded at $E700.

        include "SCR_WHDLoad.i"

        ifnd BOOT_SUM
        fail "BOOT_SUM (sum of the boot block's long words) must be defined"
        endif
        ifnd FIRST_SUM
        fail "FIRST_SUM (sum of the first-load long words) must be defined"
        endif
        ifnd MAIN_SUM
        fail "MAIN_SUM (sum of the main program's long words) must be defined"
        endif

BASEMEM         equ $200000             ; 2 MiB Chip, as the floppy game needs
ANGLES_BYTES    equ $40000              ; performance runtime's optional tables
EDITOR_BYTES    equ $60000              ; editor module
SERIAL_BYTES    equ $8000               ; Computer Link module
STACK_BYTES     equ $2000               ; slave stack during the boot
EXPMEM_SIZE     equ ANGLES_BYTES+EDITOR_BYTES+SERIAL_BYTES+STACK_BYTES

BOOT_ADDR       equ $8c000              ; boot block, read from disk offset 0
CHIP_LOW        equ $80000              ; first ordinary Chip allocation
CHIP_LOW_END    equ BOOT_ADDR           ; ordinary Chip ends below the boot block
CHIP_TOP_END    equ $190000             ; lowest top-down Chip allocation

FIRST_OFFSET    equ $2c00               ; boot block's first read
FIRST_BYTES     equ $b000
MAIN_ADDR       equ $e700               ; loader's main program read
MAIN_SECTOR     equ $6e
MAIN_SECTORS    equ $325
GAME_DRIVER     equ $62e86              ; game's floppy driver
LOADER_DRIVER   equ $570                ; loader's driver in the first load

; exec.library and trackdisk.device values used by the boot code
LVO_COUNT       equ 106                 ; jump table slots -636..-6
ATTNFLAGS       equ 296                 ; ExecBase->AttnFlags
MEMF_CHIP       equ 1<<1
MEMF_FAST       equ 1<<2
MEMF_CLEAR      equ 1<<16
MEMF_REVERSE    equ 1<<18
IO_COMMAND      equ $1c
IO_ERROR        equ $1f
IO_ACTUAL       equ $20
IO_LENGTH       equ $24
IO_DATA         equ $28
IO_OFFSET       equ $2c
CMD_READ        equ 2
TD_MOTOR        equ 9

;============================================================================

base:
        moveq #-1,d0                    ; ws_Security
        rts
        dc.b "WHDLOADS"                 ; ws_ID
        dc.w 17                         ; ws_Version
        dc.w WHDLF_NoError|WHDLF_EmulTrap|WHDLF_ClearMem
        dc.l BASEMEM                    ; ws_BaseMemSize
        dc.l 0                          ; ws_ExecInstall
        dc.w start-base                 ; ws_GameLoader
        dc.w 0                          ; ws_CurrentDir
        dc.w 0                          ; ws_DontCache
        dc.b 0                          ; ws_keydebug
        dc.b $59                        ; ws_keyexit: F10
expmem:
        dc.l EXPMEM_SIZE                ; ws_ExpMem, replaced by its address
        dc.w name-base                  ; ws_name
        dc.w copy-base                  ; ws_copy
        dc.w info-base                  ; ws_info
        dc.w 0                          ; ws_kickname: no kickstart image
        dc.l 0                          ; ws_kicksize
        dc.w 0                          ; ws_kickcrc
        dc.w 0                          ; ws_config

name:   dc.b "Stunt Car Racer",0
copy:   dc.b "1989 Geoff Crammond, MicroStyle",0
info:   dc.b "Performance Patch",10
        dc.b "by Timo Heimonen",0
exec_name:
        dc.b "exec.library",0
trackdisk_name:
        dc.b "trackdisk.device",0
        even

resload:
        dc.l 0
fast_next:
        dc.l 0                          ; next ExpMem allocation
fast_end:
        dc.l 0                          ; start of the slave stack
chip_next:
        dc.l CHIP_LOW
chip_top:
        dc.l BASEMEM

attn_tags:
        dc.l WHDLTAG_ATTNFLAGS_GET
attn_flags:
        dc.l 0
        dc.l 0                          ; TAG_DONE

io_request:
        ds.b 48

;============================================================================
; Entry from WHDLoad in supervisor mode. A0: resload base.

start:
        lea resload(pc),a1
        move.l a0,(a1)
        movea.l a0,a5

        ; The boot code allocates Chip memory at the top of BaseMem, where
        ; WHDLoad's stack is: run the boot on a stack at the end of ExpMem.
        move.l expmem(pc),d0
        lea fast_next(pc),a0
        move.l d0,(a0)
        add.l #EXPMEM_SIZE-STACK_BYTES,d0
        lea fast_end(pc),a0
        move.l d0,(a0)
        add.l #STACK_BYTES,d0
        movea.l d0,sp

        lea attn_tags(pc),a0
        jsr resload_Control(a5)
        lea exec_base(pc),a6
        move.w attn_flags+2(pc),ATTNFLAGS(a6)
        move.l a6,($4).w

        ; Read and check the boot block.
        moveq #0,d0
        move.l #$400,d1
        moveq #1,d2
        lea (BOOT_ADDR).l,a0
        jsr resload_DiskLoad(a5)
        lea (BOOT_ADDR).l,a0
        move.l #$400,d1
        bsr checksum
        cmp.l #BOOT_SUM,d0
        bne wrong_version

        ; Skip the intro: the trampoline at $340 calls the runtime installer
        ; ($24C) instead of the intro ($286), then the editor bootstrap.
        lea (BOOT_ADDR).l,a0
        cmpi.l #$6100ff44,$340(a0)
        bne wrong_version
        move.w #$ff0a,$342(a0)
        ; Enter the game through the slave: "LEA $200(boot),SP / JMP (A3)".
        cmpi.l #$4ffa0182,$7c(a0)
        bne wrong_version
        cmpi.w #$4ed3,$80(a0)
        bne wrong_version
        lea enter_loader(pc),a1
        move.w #$4ef9,$7c(a0)
        move.l a1,$7e(a0)
        jsr resload_FlushCache(a5)

        ; Start the boot block as the system would: A1 the trackdisk request,
        ; A6 ExecBase. It does not return.
        lea io_request(pc),a1
        jmp $c(a0)

; Called from the boot block in place of its jump into the first load, after
; the runtime and the editor have been installed. A3: first-load allocation.
; The loader is still in the first load; its driver is replaced before the
; first load copies the loader to $4000.

enter_loader:
        cmpi.l #$48e77ffc,LOADER_DRIVER(a3)
        bne wrong_version
        cmpi.l #$4e56ffdc,LOADER_DRIVER+4(a3)
        bne wrong_version
        lea loader_driver(pc),a0
        move.w #$4ef9,LOADER_DRIVER(a3)
        move.l a0,LOADER_DRIVER+2(a3)
        movea.l resload(pc),a0
        jsr resload_FlushCache(a0)
        lea (BOOT_ADDR+$200).l,sp
        jmp (a3)

wrong_version:
        pea TDREASON_WRONGVER
        move.l resload(pc),-(sp)
        addq.l #resload_Abort,(sp)
        rts

; D0 = sum of the D1 bytes (a multiple of 4) at A0. Destroys D1 and A0.
checksum:
        moveq #0,d0
        lsr.l #2,d1
.loop:  add.l (a0)+,d0
        subq.l #1,d1
        bne.s .loop
        rts

;============================================================================
; Replacement for the floppy driver of the loader and of the game, with the
; same interface: D0 drive (bits 0-1) and format (bit 15), D1 first sector,
; D2 sector count, D3 0 to read or 1 to write, A0 data. Returns D0 = 0 or the
; driver's error code with the flags set from it; preserves the other
; registers. Only the game disk in the standard format exists (DF1 has no
; disk). Reads and writes of the file_map areas go to their files, other
; reads to Disk.1; other writes are refused as on a write-protected disk.

ERR_RANGE       equ 30                  ; the driver's errors
ERR_NO_DISK     equ 29
ERR_PROTECTED   equ 28

disk_driver:
        movem.l d1-d7/a0-a6,-(sp)
        andi.w #$8003,d0
        bne .no_disk
        moveq #0,d6
        move.w d1,d6                    ; D6: current sector
        moveq #0,d7
        move.w d2,d7                    ; D7: sectors left
        movea.l a0,a4                   ; A4: data
        movea.l resload(pc),a5
        moveq #ERR_RANGE,d0
        tst.l d7
        beq .done
        move.l d6,d1
        add.l d7,d1
        cmp.l #1760,d1
        bhi .done
        tst.w d3
        bne .write

.read:  move.l d6,d0
        bsr map_sector
        bne.s .read_file
        moveq #1,d5                     ; unmapped: read up to the next file
.extent:
        cmp.l d7,d5
        bhs.s .read_disk
        move.l d6,d0
        add.l d5,d0
        bsr map_sector
        bne.s .read_disk
        addq.l #1,d5
        bra.s .extent
.read_disk:
        move.l d6,d0
        bsr disk_read                   ; D5 sectors from sector D0 to A4
        bra.s .read_next
.read_file:
        bsr chunk                       ; D5 sectors of this file
        bsr file_size
        beq.s .read_original
        bmi .bad_file
        move.l d5,d0
        lsl.l #8,d0
        add.l d0,d0                     ; size
        move.l d3,d1
        lsl.l #8,d1
        add.l d1,d1                     ; offset in the file
        lea file_name(pc),a0
        movea.l a4,a1
        jsr resload_LoadFileOffset(a5)
        bra.s .read_next
.read_original:
        move.w file_blank(pc),d0
        bne.s .read_blank
        move.l a3,d0
        add.l d3,d0
        bsr disk_read
        bra.s .read_next
.read_blank:
        move.l d5,d0                    ; a new save disk: empty sectors
        lsl.l #7,d0
        movea.l a4,a0
.clear: clr.l (a0)+
        subq.l #1,d0
        bne.s .clear
.read_next:
        move.l d5,d0
        lsl.l #8,d0
        add.l d0,d0
        adda.l d0,a4
        add.l d5,d6
        sub.l d5,d7
        bne .read
        moveq #0,d0
        bra .done

        ; Writes: every sector must be in a file, then each file is written
        ; once with the new sectors over its current contents.
.write: move.l d6,d4
        move.l d7,d5
.check: move.l d4,d0
        bsr map_sector
        beq .protected
        addq.l #1,d4
        subq.l #1,d5
        bne.s .check
.write_file:
        move.l d6,d0
        bsr map_sector
        bsr chunk
        bsr file_size
        bgt.s .load_file
        moveq #0,d4                     ; D4: the file exists
        lea file_buffer(pc),a0          ; no file (or a damaged one): the
        move.w file_blank(pc),d0        ; disk's sectors, or empty ones
        bne.s .blank
        move.l a3,d0
        move.l d2,d1
        lsl.l #8,d1
        add.l d1,d1
        lsl.l #8,d0
        add.l d0,d0
        moveq #1,d2
        jsr resload_DiskLoad(a5)
        bra.s .merge
.blank: move.w #3*512/4-1,d0
.empty: clr.l (a0)+
        dbra d0,.empty
        bra.s .merge
.load_file:
        moveq #1,d4
        lea file_name(pc),a0
        lea file_buffer(pc),a1
        jsr resload_LoadFile(a5)
        ; Each write of an existing file shows the system for a moment, so
        ; an unchanged file is not written again (the editor writes the
        ; index of both of its copies, which is one file here).
.merge: lea file_buffer(pc),a1
        move.l d3,d0
        lsl.l #8,d0
        add.l d0,d0
        adda.l d0,a1
        move.l d5,d0
        lsl.l #7,d0                     ; long words
.copy:  cmpm.l (a4)+,(a1)+
        beq.s .same
        moveq #0,d4                     ; changed: the file is written
        move.l -4(a4),-4(a1)
.same:  subq.l #1,d0
        bne.s .copy
        tst.l d4
        bne.s .written
        move.l file_bytes(pc),d0
        lea file_name(pc),a0
        lea file_buffer(pc),a1
        jsr resload_SaveFile(a5)
.written:
        add.l d5,d6
        sub.l d5,d7
        bne .write_file
        moveq #0,d0
        bra.s .done
.bad_file:
        moveq #ERR_RANGE,d0             ; a file of the wrong size: unreadable
        bra.s .done
.protected:
        moveq #ERR_PROTECTED,d0
        bra.s .done
.no_disk:
        moveq #ERR_NO_DISK,d0
.done:  movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts

; D5 = sectors of the request in the current file: min(D0, D7).
chunk:  move.l d0,d5
        cmp.l d7,d5
        bls.s .done
        move.l d7,d5
.done:  rts

; Size check of file_name against file_bytes: returns D0 = 0 (and Z) if the
; file does not exist, 1 if it has the expected size, -1 if not.
file_size:
        lea file_name(pc),a0
        jsr resload_GetFileSize(a5)
        tst.l d0
        beq.s .done
        cmp.l file_bytes(pc),d0
        beq.s .ok
        moveq #-1,d0
        rts
.ok:    moveq #1,d0
.done:  rts

; Read D5 sectors from sector D0 of Disk.1 to A4.
disk_read:
        lsl.l #8,d0
        add.l d0,d0
        move.l d5,d1
        lsl.l #8,d1
        add.l d1,d1
        moveq #1,d2
        movea.l a4,a0
        jsr resload_DiskLoad(a5)
        rts

; Finds the file of sector D0. Returns D0 = 0 (and Z) if the sector is in no
; file. Otherwise D0 = sectors of the file from D0 on, A3 = the file's first
; sector in its first copy on the disk, D2 = the file's sectors, D3 = the
; sector's index in the file, file_name and file_bytes set.
map_sector:
        movem.l d1/d4-d7/a0-a2,-(sp)
        lea file_map(pc),a2
.entry: move.w (a2),d4                  ; first sector of the first copy
        beq.s .none
        moveq #0,d7
        move.w 8(a2),d7                 ; offset of the second copy
        move.w d4,d5
        bsr.s .copy
        beq.s .found
        tst.w d7
        beq.s .next
        move.w d4,d5
        add.w d7,d5
        bsr.s .copy
        beq.s .found
.next:  lea 16(a2),a2
        bra.s .entry
.none:  moveq #0,d0
        movem.l (sp)+,d1/d4-d7/a0-a2
        rts
        ; D5 copy's first sector. Z set if the sector is in it, with
        ; D1 = file number and D3 = index.
.copy:  move.l d0,d1
        sub.w d5,d1
        bcs.s .miss
        divu 6(a2),d1                   ; stride
        cmp.w 4(a2),d1                  ; files
        bhs.s .miss
        move.l d1,d3
        swap d3
        and.l #$ffff,d3
        cmp.w 2(a2),d3                  ; sectors per file
        bhs.s .miss
        and.l #$ffff,d1
        moveq #0,d6                     ; Z
        rts
.miss:  moveq #1,d6                     ; not Z
        rts
.found: moveq #0,d2
        move.w 2(a2),d2
        move.l d2,d0
        lsl.l #8,d0
        add.l d0,d0
        lea file_bytes(pc),a0
        move.l d0,(a0)
        move.l d1,d0                    ; first sector = first + file * stride
        mulu 6(a2),d0
        add.w d4,d0
        movea.l d0,a3
        lea file_name(pc),a1
        lea file_map(pc),a0
        adda.w 10(a2),a0
.prefix:
        move.b (a0)+,(a1)+
        bne.s .prefix
        subq.l #1,a1
        lea file_blank(pc),a0
        move.w 14(a2),d0
        and.w #FILE_BLANK,d0
        move.w d0,(a0)
        btst #0,15(a2)                  ; FILE_NUMBER
        beq.s .suffix
        addq.w #1,d1                    ; two digits: file number from 1
        divu #10,d1
        add.b #'0',d1
        move.b d1,(a1)+
        swap d1
        add.b #'0',d1
        move.b d1,(a1)+
.suffix:
        lea file_map(pc),a0
        adda.w 12(a2),a0
.copy_suffix:
        move.b (a0)+,(a1)+
        bne.s .copy_suffix
        move.l d2,d0
        sub.l d3,d0
        movem.l (sp)+,d1/d4-d7/a0-a2
        rts

; The written disk areas and their files. Each entry: first sector of the
; first copy, sectors per file, files, stride, offset of the second copy (0:
; none), name prefix, name suffix and flags: FILE_NUMBER puts the file number
; (01..) between prefix and suffix; FILE_BLANK means the sectors are on a
; separate save disk, so a missing file reads as empty sectors instead of the
; game disk's. The game saves its season on a formatted disk of its own;
; the track editor keeps its slots on the game disk.
FILE_NUMBER     equ 1
FILE_BLANK      equ 2
file_map:
        dc.w 22,1,1,1,0,save_index-file_map,no_suffix-file_map,FILE_BLANK
        dc.w 23,1,30,1,0,save_prefix-file_map,no_suffix-file_map,FILE_BLANK|FILE_NUMBER
        dc.w 1210,2,32,4,132,track_prefix-file_map,track_suffix-file_map,FILE_NUMBER
        dc.w 1212,2,32,4,132,track_prefix-file_map,records_suffix-file_map,FILE_NUMBER
        dc.w 1474,3,1,3,11,track_index-file_map,no_suffix-file_map,0
        dc.w 0
save_index:
        dc.b "SaveIndex",0
save_prefix:
        dc.b "Save",0
track_prefix:
        dc.b "Track",0
track_index:
        dc.b "TrackIndex",0
track_suffix:
        dc.b ".sct",0
records_suffix:
        dc.b ".rec",0
no_suffix:
        dc.b 0
        even
file_name:
        ds.b 32
file_bytes:
        dc.l 0
file_blank:
        dc.w 0
file_buffer:
        ds.b 3*512

; The loader's driver ($44F8 after the copy). After the main program has
; been read, it is checked and the game's driver is replaced.

loader_driver:
        bsr disk_driver
        bne.s .done
        cmp.w #MAIN_SECTOR,d1
        bne.s .done
        cmp.w #MAIN_SECTORS,d2
        bne.s .done
        cmpa.l #MAIN_ADDR,a0
        bne.s .done
        movem.l d0-d1/a0-a1,-(sp)
        move.l #MAIN_SECTORS*512,d1
        bsr checksum
        cmp.l #MAIN_SUM,d0
        bne wrong_version
        lea (GAME_DRIVER).l,a0
        cmpi.l #$48e77ffc,(a0)
        bne wrong_version
        cmpi.l #$4e56ffdc,4(a0)
        bne wrong_version
        lea disk_driver(pc),a1
        move.w #$4ef9,(a0)+
        move.l a1,(a0)
        movea.l resload(pc),a0
        jsr resload_FlushCache(a0)
        movem.l (sp)+,d0-d1/a0-a1
        tst.l d0
.done:  rts

;============================================================================
; exec.library for the boot code. Every jump table slot calls exec_dispatch,
; which finds the slot's handler from exec_handlers and continues there with
; the caller's registers. A call without a handler ends WHDLoad with an
; error naming the function's offset.

exec_table:
        rept LVO_COUNT
        bsr.w exec_dispatch
        dc.w 0
        endr
exec_base:
        ds.b 512

exec_dispatch:
        movem.l d0/a0,-(sp)
        move.l 8(sp),d0                 ; slot + 4
        lea exec_base+4(pc),a0
        sub.l a0,d0                     ; the function's offset
        lea exec_handlers(pc),a0
.find:  tst.w (a0)
        beq.s .unsupported
        cmp.w (a0)+,d0
        beq.s .found
        addq.l #2,a0
        bra.s .find
.found: move.w (a0),d0
        lea exec_handlers(pc),a0
        adda.w d0,a0
        move.l a0,8(sp)                 ; continue in the handler
        movem.l (sp)+,d0/a0
        rts
.unsupported:
        lea exec_name(pc),a0
os_failure:
        move.l d0,-(sp)                 ; secondary: offset or command
        move.l a0,-(sp)                 ; primary: subsystem
        pea TDREASON_OSEMUFAIL
        move.l resload(pc),-(sp)
        addq.l #resload_Abort,(sp)
        rts

exec_handlers:
        dc.w -132,exec_nothing-exec_handlers    ; Forbid
        dc.w -138,exec_nothing-exec_handlers    ; Permit
        dc.w -150,exec_superstate-exec_handlers ; SuperState
        dc.w -198,exec_allocmem-exec_handlers   ; AllocMem
        dc.w -204,exec_allocabs-exec_handlers   ; AllocAbs
        dc.w -210,exec_nothing-exec_handlers    ; FreeMem
        dc.w -456,exec_doio-exec_handlers       ; DoIO
        dc.w -636,exec_cacheclear-exec_handlers ; CacheClearU
        dc.w 0

exec_nothing:
        rts

; Already in supervisor mode: return the stack pointer as the old SSP.
exec_superstate:
        move.l sp,d0
        rts

; AllocMem(D0 size, D1 requirements): Fast from ExpMem, Chip from BaseMem,
; MEMF_REVERSE from the top. Returns 0 when the area is exhausted. Ordinary
; Chip stays below the running boot block. WHDLF_ClearMem has cleared both
; areas and nothing is reused, so only MEMF_CLEAR clears again.
exec_allocmem:
        movem.l d1-d2/a0-a1,-(sp)
        addq.l #7,d0
        and.w #-8,d0
        btst #1,d1                      ; MEMF_CHIP
        bne.s .chip
        lea fast_next(pc),a0
        move.l (a0),d2
        add.l d0,d2
        cmp.l fast_end(pc),d2
        bhi.s .fail
        move.l (a0),a1
        move.l d2,(a0)
        bra.s .clear
.chip:  btst #18,d1                     ; MEMF_REVERSE
        bne.s .top
        lea chip_next(pc),a0
        move.l (a0),d2
        add.l d0,d2
        cmp.l #CHIP_LOW_END,d2
        bhi.s .fail
        move.l (a0),a1
        move.l d2,(a0)
        bra.s .clear
.top:   lea chip_top(pc),a0
        move.l (a0),d2
        sub.l d0,d2
        cmp.l #CHIP_TOP_END,d2
        blo.s .fail
        move.l d2,(a0)
        movea.l d2,a1
.clear: move.l a1,d2
        btst #16,d1                     ; MEMF_CLEAR
        beq.s .done
        lsr.l #2,d0
        beq.s .done
.zero:  clr.l (a1)+
        subq.l #1,d0
        bne.s .zero
.done:  move.l d2,d0
        movem.l (sp)+,d1-d2/a0-a1
        rts
.fail:  moveq #0,d0
        movem.l (sp)+,d1-d2/a0-a1
        rts

; AllocAbs(D0 size, A1 location): the boot reserves the runtime's area.
exec_allocabs:
        move.l a1,d0
        rts

; DoIO(A1 request) for trackdisk.device: CMD_READ and TD_MOTOR.
exec_doio:
        movem.l d1-d2/a0-a2,-(sp)
        movea.l a1,a2
        moveq #0,d0
        move.w IO_COMMAND(a2),d0
        cmp.w #TD_MOTOR,d0
        beq.s .ok
        cmp.w #CMD_READ,d0
        bne.s .unsupported
        move.l IO_OFFSET(a2),d0
        move.l IO_LENGTH(a2),d1
        moveq #1,d2
        movea.l IO_DATA(a2),a0
        movea.l resload(pc),a1
        jsr resload_DiskLoad(a1)
        cmpi.l #FIRST_OFFSET,IO_OFFSET(a2)
        bne.s .ok
        cmpi.l #FIRST_BYTES,IO_LENGTH(a2)
        bne wrong_version
        movea.l IO_DATA(a2),a0
        move.l #FIRST_BYTES,d1
        bsr checksum
        cmp.l #FIRST_SUM,d0
        bne wrong_version
.ok:    move.l IO_LENGTH(a2),IO_ACTUAL(a2)
        cmpi.w #CMD_READ,IO_COMMAND(a2)
        beq.s .done
        clr.l IO_ACTUAL(a2)
.done:  clr.b IO_ERROR(a2)
        moveq #0,d0
        movem.l (sp)+,d1-d2/a0-a2
        rts
.unsupported:
        lea trackdisk_name(pc),a0
        bra os_failure

exec_cacheclear:
        move.l a0,-(sp)
        movea.l resload(pc),a0
        jsr resload_FlushCache(a0)
        movea.l (sp)+,a0
        rts
