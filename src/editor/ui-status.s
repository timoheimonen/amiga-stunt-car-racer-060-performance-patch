; Draw the two status lines of the editor bar.
; Copyright (c) 2026 Timo Heimonen
; SPDX-License-Identifier: MIT
; Licensed under the MIT License; see LICENSE.

; Track Editor bar: L1 and L2. The text routines of a render say what they
; have, the most important text of a pass goes to L2, and ui_status_flush draws
; only a line that changed.
UI_L1_Y equ 184-UI_BAR_TOP
UI_L2_Y equ 192-UI_BAR_TOP
UI_TEXT_X equ 3
UI_L1_WIDTH equ 192
UI_L2_WIDTH equ 264
UI_COUNT_X equ 195
UI_COUNT_WIDTH equ 30
UI_WORD_X equ 231
UI_WORD_WIDTH equ 36
UI_SAY_HINT equ 1
UI_SAY_UNSAVED equ 2
UI_SAY_REASON equ 3
UI_SAY_PROMPT equ 4
UI_SAY_RESULT equ 6
UI_SAY_MS equ 2000
UI_RESULT_MS equ 3000

; A0 text, D0 priority. The same priority replaces: later text is newer. A
; result has its own line, so the text under it is there when its time is up.
ui_status_put:
        cmpi.w #UI_SAY_RESULT,d0
        bne.s .line
        move.w #1,ui_result_put-module_start(a5)
        lea ui_next_result(pc),a1
        bra.s ui_line_copy
.line:  cmp.w ui_status_priority(pc),d0
        blo.s .done
        move.w d0,ui_status_priority-module_start(a5)
        lea ui_next_l2(pc),a1
        bra.s ui_line_copy
.done:  rts

; A0 text of L1.
ui_name_put:
        lea ui_next_l1(pc),a1
ui_line_copy:
        moveq #UI_LINE_CHARS-1,d0
.copy:  move.b (a0)+,(a1)+
        dbeq d0,.copy
        clr.b (a1)
        rts

; After the bar is cleared nothing on it is what the buffers say.
ui_status_reset:
        move.b #1,ui_shown_l1-module_start(a5)
        move.b #1,ui_shown_l2-module_start(a5)
        move.b #1,ui_shown_count-module_start(a5)
        clr.l ui_said-module_start(a5)
        rts

; A0 text: L2 says it for a while, over everything else.
ui_say: move.l a0,ui_said-module_start(a5)
        move.l ui_ms(pc),d0
        addi.l #UI_SAY_MS,d0
        move.l d0,ui_said_end-module_start(a5)
        move.w #1,ui_line_due-module_start(a5)
        rts

; Each main loop: ends what ran out of time and redraws L2 when it should
; change. This is no render: the text under a result is already known.
ui_status_tick:
        move.l ui_said(pc),d0
        beq.s .result
        move.l ui_ms(pc),d0
        sub.l ui_said_end(pc),d0
        bmi.s .result
        clr.l ui_said-module_start(a5)
        move.w #1,ui_line_due-module_start(a5)
.result:
        tst.b ui_next_result-module_start(a5)
        beq.s .due
        tst.w storage_modal-module_start(a5)
        bne.s .due
        tst.w editing_prompt-module_start(a5)
        bne.s .due
        move.l ui_ms(pc),d0
        sub.l ui_result_end(pc),d0
        bmi.s .due
        ; The status goes with its text, and that is no change of the view.
        clr.b ui_next_result-module_start(a5)
        clr.b ui_shown_result-module_start(a5)
        clr.w storage_status-module_start(a5)
        clr.w EDITOR_VIEW_SNAPSHOT+VIEW_SNAPSHOT_STATUS(a5)
        move.w #1,ui_line_due-module_start(a5)
.due:   tst.w ui_line_due-module_start(a5)
        beq.s .done
        bsr ui_l2_show
.done:  rts

; L2: a refused click, a result, what the pointer is on, then the render's text.
ui_l2_show:
        movem.l d0-d5/a0-a1,-(sp)
        clr.w ui_line_due-module_start(a5)
        movea.l ui_said(pc),a0
        move.l a0,d0
        bne.s .text
        lea ui_next_result(pc),a0
        tst.b (a0)
        bne.s .text
        movea.l ui_hover_text(pc),a0
        move.l a0,d0
        bne.s .text
        lea ui_next_l2(pc),a0
.text:  lea ui_shown_l2(pc),a1
        bsr ui_line_update
        beq.s .done
        lea ui_commands(pc),a0
        moveq #UI_TEXT_X,d1
        moveq #UI_L2_Y,d2
        move.w #UI_L2_WIDTH,d3
        moveq #UI_INK,d4
        moveq #UI_LEFT_CLIPPED,d5
        bsr ui_add_text
        bsr ui_run_commands
.done:  movem.l (sp)+,d0-d5/a0-a1
        rts

; A0 wanted, A1 shown. Z set when they are the same, otherwise A1 takes A0.
ui_line_update:
        movem.l a0-a1,-(sp)
.compare:
        move.b (a0)+,d0
        cmp.b (a1)+,d0
        bne.s .differ
        tst.b d0
        bne.s .compare
        movem.l (sp)+,a0-a1
        rts
.differ:
        movem.l (sp),a0-a1
.copy:  move.b (a0)+,(a1)+
        bne.s .copy
        movem.l (sp)+,a0-a1
        moveq #1,d0
        rts

; Adds "clear the field, write the text" to the list at A0.
; D1 x, D2 y, D3 width, D4 colour role, D5 alignment, A1 text.
ui_add_text:
        move.w #UI_RECT,(a0)+
        move.w d1,(a0)+
        move.w d2,(a0)+
        move.w d3,(a0)+
        move.w #UI_LINE_HEIGHT,(a0)+
        move.w #UI_PANEL,(a0)+
        move.w #UI_TEXT_AT,(a0)+
        move.w d1,(a0)+
        move.w d2,(a0)+
        move.w d3,(a0)+
        move.w d4,(a0)+
        move.w d5,(a0)+
        move.l a1,(a0)+
        rts

ui_run_commands:
        move.w #UI_END,(a0)
        lea ui_commands(pc),a0
        lea ui_bar_target(pc),a1
        moveq #0,d1
        bra ui_service

ui_status_flush:
        movem.l d0-d5/a0-a1,-(sp)
        clr.w ui_status_priority-module_start(a5)
        tst.w ui_result_put-module_start(a5)
        bne.s .result
        clr.b ui_next_result-module_start(a5)
.result:
        clr.w ui_result_put-module_start(a5)
        lea ui_next_result(pc),a0
        lea ui_shown_result(pc),a1
        bsr ui_line_update
        beq.s .l1
        move.l ui_ms(pc),d0
        addi.l #UI_RESULT_MS,d0
        move.l d0,ui_result_end-module_start(a5)
.l1:    lea ui_next_l1(pc),a0
        lea ui_shown_l1(pc),a1
        bsr ui_line_update
        beq.s .l2
        lea ui_commands(pc),a0
        moveq #UI_TEXT_X,d1
        moveq #UI_L1_Y,d2
        move.w #UI_L1_WIDTH,d3
        moveq #UI_INK,d4
        moveq #UI_LEFT_CLIPPED,d5
        bsr ui_add_text
        bsr ui_run_commands
.l2:    bsr ui_l2_show
        lea ui_next_count(pc),a0
        lea ui_shown_count(pc),a1
        bsr ui_line_update
        sne d5
        lea ui_next_word(pc),a0
        lea ui_shown_word(pc),a1
        bsr ui_line_update
        sne d0
        or.b d0,d5
        beq.s .done
        lea ui_commands(pc),a0
        move.w #UI_COUNT_X,d1
        moveq #UI_L1_Y,d2
        moveq #UI_COUNT_WIDTH,d3
        moveq #UI_INK,d4
        moveq #UI_RIGHT,d5
        lea ui_shown_count(pc),a1
        bsr ui_add_text
        move.w #UI_WORD_X,d1
        moveq #UI_WORD_WIDTH,d3
        moveq #UI_WARN,d4
        cmpi.b #'R',ui_shown_word-module_start(a5)
        bne.s .word
        moveq #UI_OK,d4
.word:  moveq #UI_LEFT,d5
        lea ui_shown_word(pc),a1
        bsr ui_add_text
        bsr ui_run_commands
.done:  movem.l (sp)+,d0-d5/a0-a1
        rts

ui_said: dc.l 0
ui_said_end: dc.l 0
ui_result_end: dc.l 0
ui_status_priority: dc.w 0
ui_result_put: dc.w 0
ui_line_due: dc.w 0
ui_commands: dcb.w 60,0
ui_next_l1: dcb.b UI_LINE_CHARS+2,0
ui_next_l2: dcb.b UI_LINE_CHARS+2,0
ui_next_result: dcb.b UI_LINE_CHARS+2,0
ui_shown_result: dcb.b UI_LINE_CHARS+2,0
ui_shown_l1: dcb.b UI_LINE_CHARS+2,0
ui_shown_l2: dcb.b UI_LINE_CHARS+2,0
ui_next_count: dcb.b 8,0
ui_next_word: dcb.b 8,0
ui_shown_count: dcb.b 8,0
ui_shown_word: dcb.b 8,0
        even
