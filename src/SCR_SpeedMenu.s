; Five-row main menu. Number keys highlight; Space/Return/fire confirms.
; The original input loop waits for confirmation release on each redraw.
        machine 68000
speed_menu:
        move.b #1,speed_menu_active
.again:
        moveq #0,d1
        moveq #4,d2
        jsr $5b840.l
        cmpi.b #4,d0
        bne.s .done
        bsr.w speed_next
        moveq #4,d0
        bra.s .again
.done:
        clr.b speed_menu_active
        rts

speed_next:
        addq.w #1,speed_k
        cmpi.w #30,speed_k
        bls.s speed_update
        move.w #20,speed_k
speed_update:
        movem.l d0/a0,-(sp)
        move.w speed_k(pc),d0
        subi.w #20,d0
        mulu.w #6,d0
        lea speed_coefficients(pc),a0
        adda.w d0,a0
        move.w (a0)+,speed_multiplier
        move.w (a0)+,speed_spring
        move.w (a0)+,speed_decay
        movem.l (sp)+,d0/a0
        rts

speed_menu_row:
        move.b $1bb18.l,d2
        tst.b speed_menu_active
        beq.s .original
        cmpi.b #4,d2
        beq.s .speed
.original:
        jmp $5b8e4.l
.speed:
        lea speed_label(pc),a2
.letter:
        move.b (a2)+,d0
        beq.s .percent
        jsr $594c6.l
        bra.s .letter
.percent:
        move.w speed_k(pc),d0
        mulu.w #5,d0
        divu.w #100,d0
        addi.b #'0',d0
        jsr $594c6.l
        swap d0
        andi.l #$ffff,d0
        divu.w #10,d0
        addi.b #'0',d0
        jsr $594c6.l
        swap d0
        addi.b #'0',d0
        jsr $594c6.l
        moveq #'%',d0
        jsr $594c6.l
        jmp $5b914.l

; Original row-position routine continues with MOVE.B (A0,D1.W),D0.
speed_menu_position:
        lea speed_row_positions(pc),a0
        tst.b speed_menu_active
        bne.s .ready
        movea.l #$64af4,a0
.ready:
        jmp $64b3a.l

speed_menu_keys:
        lea speed_number_keys(pc),a2
        tst.b speed_menu_active
        bne.s .ready
        movea.l #$60c8d,a2
.ready:
        jmp $5b9d8.l

; The original font contains fill data at '%'. Supply a private glyph only
; while the speed menu is active; the game's glyph renderer stays in use.
speed_menu_font:
        movea.l #$1fe82,a0
        tst.b speed_menu_active
        beq.s .ready
        cmpi.l #40,d0
        bne.s .ready
        lea speed_percent_glyph-40(pc),a0
.ready:
        jmp $595c8.l
speed_percent_glyph:
        dc.b $00,$62,$64,$08,$10,$26,$46,$00

speed_label: dc.b 'SPEED ADJUST ',0
speed_row_positions: dc.b 13,15,17,19,21
speed_number_keys: dc.b 1,2,3,4,5
        even
speed_state_start:
speed_k: dc.w 20
speed_multiplier: dc.w 2380
speed_spring: dc.w 1656
speed_decay: dc.w 3068
speed_menu_active: dc.b 0
        even
speed_state_end:
; round(33120/k), round(65536*(1-(1-3068/65536)^(k/20))).
speed_coefficients:
        dc.w 2380,1656,3068
        dc.w 2499,1577,3218
        dc.w 2618,1505,3367
        dc.w 2737,1440,3516
        dc.w 2856,1380,3664
        dc.w 2975,1325,3812
        dc.w 3094,1274,3960
        dc.w 3213,1227,4108
        dc.w 3332,1183,4255
        dc.w 3451,1142,4401
        dc.w 3570,1104,4548
