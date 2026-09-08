; Draw a pixel using the selected color routine and original bit index.
        machine 68060
pixel060:
        move.b d4,d0
        andi.w #15,d0
        eori.w #15,d0
        cmpi.w #8,d0
        bge.s .even
        jmp ([pixel_odd_pointer060])
.even:  andi.w #7,d0
        jmp ([pixel_odd_pointer060],18)
        dcb.b $6642a-*,0
