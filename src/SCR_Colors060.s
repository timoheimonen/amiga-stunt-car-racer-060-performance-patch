; Select color drawing routines through data pointers and precomputed masks.
        machine 68060
colors_start060:              ; start of color drawing module
word_dispatch060:
        move.w d4,d2
        not.w d2
        jmp ([word_pointer060])
word_pointer060: dc.l $66476
pixel_odd_pointer060: dc.l pixel_variants060+15*34
pixel_previous060: dc.b 8     ; original BSET opcodes initially select color 15
        even
word_routines060:
        dc.l $66476
        dc.l $66486
        dc.l $66496
        dc.l $664a6
        dc.l $664b6
        dc.l $664c6
        dc.l $664d6
        dc.l $664e6
        dc.l $664f6
        dc.l $66506
        dc.l $66516
        dc.l $66526
        dc.l $66536
        dc.l $66546
        dc.l $66556
        dc.l $66566
color_masks060:
        dc.l $00000000,$00000000 ; color 0
        dc.l $ffff0000,$00000000 ; color 1
        dc.l $0000ffff,$00000000 ; color 2
        dc.l $ffffffff,$00000000 ; color 3
        dc.l $00000000,$ffff0000 ; color 4
        dc.l $ffff0000,$ffff0000 ; color 5
        dc.l $0000ffff,$ffff0000 ; color 6
        dc.l $ffffffff,$ffff0000 ; color 7
        dc.l $00000000,$0000ffff ; color 8
        dc.l $ffff0000,$0000ffff ; color 9
        dc.l $0000ffff,$0000ffff ; color 10
        dc.l $ffffffff,$0000ffff ; color 11
        dc.l $00000000,$ffffffff ; color 12
        dc.l $ffff0000,$ffffffff ; color 13
        dc.l $0000ffff,$ffffffff ; color 14
        dc.l $ffffffff,$ffffffff ; color 15
pixel_variants060:
; Color 0: odd byte then even byte, exactly 34 bytes.
        bclr d0,$1(a0)
        bclr d0,$1f41(a0)
        bclr d0,$3e81(a0)
        bclr d0,$5dc1(a0)
        rts
        bclr d0,(a0)
        bclr d0,$1f40(a0)
        bclr d0,$3e80(a0)
        bclr d0,$5dc0(a0)
        rts
; Color 1: odd byte then even byte, exactly 34 bytes.
        bset d0,$1(a0)
        bclr d0,$1f41(a0)
        bclr d0,$3e81(a0)
        bclr d0,$5dc1(a0)
        rts
        bset d0,(a0)
        bclr d0,$1f40(a0)
        bclr d0,$3e80(a0)
        bclr d0,$5dc0(a0)
        rts
; Color 2: odd byte then even byte, exactly 34 bytes.
        bclr d0,$1(a0)
        bset d0,$1f41(a0)
        bclr d0,$3e81(a0)
        bclr d0,$5dc1(a0)
        rts
        bclr d0,(a0)
        bset d0,$1f40(a0)
        bclr d0,$3e80(a0)
        bclr d0,$5dc0(a0)
        rts
; Color 3: odd byte then even byte, exactly 34 bytes.
        bset d0,$1(a0)
        bset d0,$1f41(a0)
        bclr d0,$3e81(a0)
        bclr d0,$5dc1(a0)
        rts
        bset d0,(a0)
        bset d0,$1f40(a0)
        bclr d0,$3e80(a0)
        bclr d0,$5dc0(a0)
        rts
; Color 4: odd byte then even byte, exactly 34 bytes.
        bclr d0,$1(a0)
        bclr d0,$1f41(a0)
        bset d0,$3e81(a0)
        bclr d0,$5dc1(a0)
        rts
        bclr d0,(a0)
        bclr d0,$1f40(a0)
        bset d0,$3e80(a0)
        bclr d0,$5dc0(a0)
        rts
; Color 5: odd byte then even byte, exactly 34 bytes.
        bset d0,$1(a0)
        bclr d0,$1f41(a0)
        bset d0,$3e81(a0)
        bclr d0,$5dc1(a0)
        rts
        bset d0,(a0)
        bclr d0,$1f40(a0)
        bset d0,$3e80(a0)
        bclr d0,$5dc0(a0)
        rts
; Color 6: odd byte then even byte, exactly 34 bytes.
        bclr d0,$1(a0)
        bset d0,$1f41(a0)
        bset d0,$3e81(a0)
        bclr d0,$5dc1(a0)
        rts
        bclr d0,(a0)
        bset d0,$1f40(a0)
        bset d0,$3e80(a0)
        bclr d0,$5dc0(a0)
        rts
; Color 7: odd byte then even byte, exactly 34 bytes.
        bset d0,$1(a0)
        bset d0,$1f41(a0)
        bset d0,$3e81(a0)
        bclr d0,$5dc1(a0)
        rts
        bset d0,(a0)
        bset d0,$1f40(a0)
        bset d0,$3e80(a0)
        bclr d0,$5dc0(a0)
        rts
; Color 8: odd byte then even byte, exactly 34 bytes.
        bclr d0,$1(a0)
        bclr d0,$1f41(a0)
        bclr d0,$3e81(a0)
        bset d0,$5dc1(a0)
        rts
        bclr d0,(a0)
        bclr d0,$1f40(a0)
        bclr d0,$3e80(a0)
        bset d0,$5dc0(a0)
        rts
; Color 9: odd byte then even byte, exactly 34 bytes.
        bset d0,$1(a0)
        bclr d0,$1f41(a0)
        bclr d0,$3e81(a0)
        bset d0,$5dc1(a0)
        rts
        bset d0,(a0)
        bclr d0,$1f40(a0)
        bclr d0,$3e80(a0)
        bset d0,$5dc0(a0)
        rts
; Color 10: odd byte then even byte, exactly 34 bytes.
        bclr d0,$1(a0)
        bset d0,$1f41(a0)
        bclr d0,$3e81(a0)
        bset d0,$5dc1(a0)
        rts
        bclr d0,(a0)
        bset d0,$1f40(a0)
        bclr d0,$3e80(a0)
        bset d0,$5dc0(a0)
        rts
; Color 11: odd byte then even byte, exactly 34 bytes.
        bset d0,$1(a0)
        bset d0,$1f41(a0)
        bclr d0,$3e81(a0)
        bset d0,$5dc1(a0)
        rts
        bset d0,(a0)
        bset d0,$1f40(a0)
        bclr d0,$3e80(a0)
        bset d0,$5dc0(a0)
        rts
; Color 12: odd byte then even byte, exactly 34 bytes.
        bclr d0,$1(a0)
        bclr d0,$1f41(a0)
        bset d0,$3e81(a0)
        bset d0,$5dc1(a0)
        rts
        bclr d0,(a0)
        bclr d0,$1f40(a0)
        bset d0,$3e80(a0)
        bset d0,$5dc0(a0)
        rts
; Color 13: odd byte then even byte, exactly 34 bytes.
        bset d0,$1(a0)
        bclr d0,$1f41(a0)
        bset d0,$3e81(a0)
        bset d0,$5dc1(a0)
        rts
        bset d0,(a0)
        bclr d0,$1f40(a0)
        bset d0,$3e80(a0)
        bset d0,$5dc0(a0)
        rts
; Color 14: odd byte then even byte, exactly 34 bytes.
        bclr d0,$1(a0)
        bset d0,$1f41(a0)
        bset d0,$3e81(a0)
        bset d0,$5dc1(a0)
        rts
        bclr d0,(a0)
        bset d0,$1f40(a0)
        bset d0,$3e80(a0)
        bset d0,$5dc0(a0)
        rts
; Color 15: odd byte then even byte, exactly 34 bytes.
        bset d0,$1(a0)
        bset d0,$1f41(a0)
        bset d0,$3e81(a0)
        bset d0,$5dc1(a0)
        rts
        bset d0,(a0)
        bset d0,$1f40(a0)
        bset d0,$3e80(a0)
        bset d0,$5dc0(a0)
        rts
