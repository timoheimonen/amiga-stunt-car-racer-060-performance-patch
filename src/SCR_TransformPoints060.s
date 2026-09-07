; Batch the sole TransformScreenPoint caller at $69604..$6960f.
; Target: FS-UAE / 68060. Integer operations remain 68000-compatible.
; A3=$1c230, A4=$1c0f0, A5=$1bfb0; D1.w is the last point byte offset.
; Preserve the original per-point arithmetic and register/CCR result at $69610.
; No extra register spills or coefficient-hoisting assumptions are needed.
; D1 byte decrement (including its upper bits and final X flag) is unchanged.
        machine 68060       ; Select 68060 ASL encodings; base runtime uses 68000.
transform_points060:
.point:
        move.w (0,a5,d1.w),d5
        move.w (0,a4,d1.w),d4
        move.w $22(a3),d0
        muls.w d5,d0
        asl.l #1,d0
        swap d0
        move.w $20(a3),d3
        muls.w d4,d3
        asl.l #1,d3
        swap d3
        add.w d3,d0
        asr.w #2,d0
        addi.w #128,d0
        move.w d0,(0,a5,d1.w)
        move.w $22(a3),d0
        muls.w d4,d0
        asl.l #1,d0
        swap d0
        move.w $20(a3),d3
        muls.w d5,d3
        asl.l #1,d3
        swap d3
        sub.w d3,d0
        asr.w #2,d0
        addi.w #64,d0
        move.w d0,(0,a4,d1.w)
        subq.b #2,d1
        bpl.s .point
        jmp $69610.l
transform_points060_end:
