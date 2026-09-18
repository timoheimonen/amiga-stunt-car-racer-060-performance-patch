; Render-only angle calculation; physics retains the original $64d66.
; D0/D3 signed input components; D0.w output angle, D7.w exact ratio for
; the following distance calculation. D4/D5 retain original input signs.
; A0 remains the original atan table; D2/D6 and all other registers survive.
; Scratch D0/D3 upper halves and CCR are not results at the three call sites.
        machine 68060
render_angle_precise:
        movea.l #$1cc46,a0
        move.w d0,d4
        bpl.s .positive_x
        neg.w d0
.positive_x:
        move.w d3,d5
        bpl.s .positive_z
        neg.w d3
.positive_z:
        cmp.w d0,d3
        beq.s .equal
        ; Magnitudes are unsigned: abs(-32768) is the valid word $8000.
        bhi.s .z_larger
        swap d3
        clr.w d3
        divu.w d0,d3
        move.w d3,d7
        bsr.s render_atan_interpolate
        move.w d4,d3
        eor.w d5,d3
        bmi.s .x_opposite
        neg.w d0
.x_opposite:
        move.w #$4000,d3
        tst.w d4
        bpl.s .x_positive
        move.w #-$4000,d3
.x_positive:
        add.w d3,d0
        rts
.z_larger:
        swap d0
        clr.w d0
        divu.w d3,d0
        move.w d0,d7
        bsr.s render_atan_interpolate
        bra.s .quadrant
.equal:
        move.w #$ffff,d7
        move.w #$2000,d0
.quadrant:
        move.w d4,d3
        eor.w d5,d3
        bpl.s .same_sign
        neg.w d0
.same_sign:
        tst.w d5
        bpl.s .done
        addi.w #$8000,d0
.done:
        rts

render_atan_interpolate:
        move.l d2,-(sp)
        move.w d7,d3
        lsr.w #4,d3
        andi.w #$ffe,d3
        move.w (a0,d3.w),d0
        move.w #$2000,d2
        cmpi.w #$ffe,d3
        beq.s .endpoint
        move.w 2(a0,d3.w),d2
.endpoint:
        ; The implicit last sample is atan(1)=8192, NOT the following
        ; distance table's first word at $1dc46.
        sub.w d0,d2
        move.w d7,d3
        andi.w #31,d3
        mulu.w d3,d2
        addi.w #16,d2
        lsr.w #5,d2
        add.w d2,d0
        move.l (sp)+,d2
        rts
render_angle_precise_end:
