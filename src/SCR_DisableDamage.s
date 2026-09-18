; Suppress new player damage only. Contact forces, impact events and sound
; remain original. Existing damage is neither cleared nor repaired.
        machine 68000
speed_damage_front_left:
        tst.b disable_damage_enabled
        bne.s .disabled
        move.b d0,$1bb4f.l
        jmp $61cc8.l
.disabled:
        tst.b d0                 ; same NZVC/X as the displaced MOVE.B
        jmp $61cc8.l

speed_damage_front_right:
        tst.b disable_damage_enabled
        bne.s .disabled
        move.b d0,$1bb50.l
        jmp $61df0.l
.disabled:
        tst.b d0
        jmp $61df0.l

speed_damage_rear:
        tst.b disable_damage_enabled
        bne.s .disabled
        move.b d0,$1bb51.l
        jmp $61f18.l
.disabled:
        tst.b d0
        jmp $61f18.l

; Called by the existing JSR. No tail-calls the untouched crack renderer;
; Yes returns without advancing the crack, its RNG or retirement threshold.
speed_damage_crack:
        tst.b disable_damage_enabled
        bne.s .disabled
        jmp $66106.l
.disabled:
        rts

; The existing severity threshold and cooldown have already been checked.
; Yes takes the ordinary impact-sound path without consuming a damage slot.
speed_damage_severe:
        tst.b disable_damage_enabled
        bne.s .disabled
        move.b $1c9cf.l,d2
        jmp $5e034.l
.disabled:
        jmp $5e05c.l
