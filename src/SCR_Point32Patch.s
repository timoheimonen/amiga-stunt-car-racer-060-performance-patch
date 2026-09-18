        machine 68060
screen_point32_start:
        include "src/SCR_Point32.s"
        dcb.w (72-(*-screen_point32_start))/2,$4e71
