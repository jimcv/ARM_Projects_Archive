/*

    Tic-Tac-toe game

 */

.global _start
.equ    PIX_BUF, 0xC8000000         @ Base addr of pixel buffer
.equ    CHAR_BUF, 0xC9000000        @ Base addr of character buffer
.equ    PS_DAT, 0xFF200100          @ Addr of PS2_Data

TURN: .word 1                       @ 1 if player-1 turn, 0 if player-2 turn
CENTER_X_POS: .word 90, 159, 228    @ x coords of square centers
CENTER_Y_POS: .word 51, 120, 189    @ y coords of square centers

LAST_KEY: .word 0                   @ store the output of reading PS2_Data

P1_TXT: .word 80, 108, 97, 121, 101, 114, 45, 49, 32, 84, 117, 114, 110
P2_TXT: .word 80, 108, 97, 121, 101, 114, 45, 50, 32, 84, 117, 114, 110
TXT_LENGTH: .word 13

P1_MARKS: .word 0                   @ store marks P1 placed using one-hot
P2_MARKS: .word 0                   @ store marks P2 placed using one-hot

P1_WIN: .word 80, 108, 97, 121, 101, 114, 45, 49, 32, 87, 105, 110, 115
P2_WIN: .word 80, 108, 97, 121, 101, 114, 45, 50, 32, 87, 105, 110, 115
WIN_LENGTH: .word   13

DRAW_TXT: .word 68, 114, 97, 119
DRAW_LENGTH: .word  4

_start:
    BL      VGA_clear_charbuff_ASM
    BL      VGA_fill_ASM
    BL      draw_grid_ASM
    B       wait_for_start

// display draw message
disp_draw:
    PUSH    {R4-R6}
    LDR     R4, =DRAW_TXT
    LDR     R5, DRAW_LENGTH
    MOV     R6, #0
disp_draw_loop:
    // check stop condition
    CMP     R6, R5
    BGE     disp_draw_loop_end
    // display
    ADD     R0, R6, #38             @ text left margin 38px
    MOV     R1, #1
    LDR     R2, [R4], #4            @ post-increment array pointer
    BL      VGA_write_char_ASM
    // increment
    ADD     R6, R6, #1
    B       disp_draw_loop
disp_draw_loop_end:
    POP     {R4-R6}
    B       wait_for_start

// display win message for the player of the current turn
disp_win:
    PUSH    {R4-R6}
    LDR     R0, TURN
    CMP     R0, #1
    LDREQ   R4, =P1_WIN
    LDRNE   R4, =P2_WIN
    LDR     R5, WIN_LENGTH
    MOV     R6, #0
disp_win_loop:
    // check stop condition
    CMP     R6, R5
    BGE     disp_win_loop_end
    // display
    ADD     R0, R6, #33             @ text left margin 33px
    MOV     R1, #1
    LDR     R2, [R4], #4            @ post-increment array pointer
    BL      VGA_write_char_ASM
    // increment
    ADD     R6, R6, #1
    B       disp_win_loop
disp_win_loop_end:
    POP     {R4-R6}
    B       wait_for_start

// check winning condition, if no condition is met, change turns
check_win:
    LDR     R0, TURN
    CMP     R0, #1
    LDREQ   R0, P1_MARKS
    LDRNE   R0, P2_MARKS
    BL      check_win_pattern
    CMP     R0, #1
    BEQ     check_win_true
    // no win pattern, check for draw
    LDR     R0, P1_MARKS
    LDR     R1, P2_MARKS
    ORR     R0, R0, R1
    LDR     R1, =#0b111111111
    CMP     R0, R1
    BEQ     check_win_draw
    // no win nor draw, change turns
    LDR     R0, =TURN
    LDR     R1, [R0]
    EOR     R1, R1, #1              @ bit flip
    STR     R1, [R0]
    BL      VGA_clear_charbuff_ASM
    BL      disp_turn
    B       wait_for_key
check_win_true:
    BL      VGA_clear_charbuff_ASM
    B       disp_win
check_win_draw:
    BL    VGA_clear_charbuff_ASM
    B     disp_draw

// takes a player's mark pattern in R0, return 1 if they won
check_win_pattern:
    // horizontal 3
    MOV     R1, #0b111
    AND     R2, R1, R0              @ extract the 3 bits we're checking
    EOR     R2, R2, R1              @ check bits
    CMP     R2, #0
    MOVEQ   R0, #1
    BXEQ    LR
    LSL     R1, #3                  @ check 2nd row
    AND     R2, R1, R0
    EOR     R2, R2, R1
    CMP     R2, #0
    MOVEQ   R0, #1
    BXEQ    LR
    LSL     R1, #3                  @ check 3rd row
    AND     R2, R1, R0
    EOR     R2, R2, R1
    CMP     R2, #0
    MOVEQ   R0, #1
    BXEQ    LR
    // vertical 3
    MOV     R1, #0b1001001          @ check 1st column
    AND     R2, R1, R0
    EOR     R2, R2, R1
    CMP     R2, #0
    MOVEQ   R0, #1
    BXEQ    LR
    LSL     R1, #1                  @ check 2nd column
    AND     R2, R1, R0
    EOR     R2, R2, R1
    CMP     R2, #0
    MOVEQ   R0, #1
    BXEQ    LR
    LSL     R1, #1                  @ check 3rd column
    AND     R2, R1, R0
    EOR     R2, R2, R1
    CMP     R2, #0
    MOVEQ   R0, #1
    BXEQ    LR
    // front slash "\"
    LDR     R1, =#0b100010001
    AND     R2, R1, R0
    EOR     R2, R2, R1
    CMP     R2, #0
    MOVEQ   R0, #1
    BXEQ    LR
    // back slash "/"
    MOV     R1, #0b1010100
    AND     R2, R1, R0
    EOR     R2, R2, R1
    CMP     R2, #0
    MOVEQ   R0, #1
    BXEQ    LR
    // no winning pattern
    MOV     R0, #0
    BX      LR

// a num-key has been released to place down a mark
// R0 is where the mark should be placed in one-hot
player_action:
    PUSH    {R4-R9}
    // check if there's already a mark placed
    LDR     R4, =P1_MARKS
    LDR     R5, =P2_MARKS
    LDR     R6, [R4]                @ R6 <- P1_MARKS
    LDR     R7, [R5]                @ R7 <- P2_MARKS
    TST     R0, R6
    POPNE   {R4-R9}
    BNE     wait_for_key
    TST     R0, R7
    POPNE   {R4-R9}
    BNE     wait_for_key
    // action is valid
    LDR     R1, TURN
    CMP     R1, #1
    BEQ     player_1_action
    B       player_2_action
player_1_action:
    ORR     R6, R6, R0
    STR     R6, [R4]
    BL      draw_mark_ASM
    POP     {R4-R9}
    B       check_win
player_2_action:
    ORR     R7, R7, R0
    STR     R7, [R5]
    BL      draw_mark_ASM
    POP     {R4-R9}
    B       check_win

// wait for player input, 1-9 num-key to place, 0 num-key to restart
wait_for_key:
    // check if available
    LDR     R0, =LAST_KEY
    BL      read_PS2_data_ASM
    CMP     R0, #1
    BNE     wait_for_key
    // check for break event
    LDR     R0, LAST_KEY
    CMP     R0, #0xF0
    BNE     wait_for_key
wait_for_key_check:
    // check if available
    LDR     R0, =LAST_KEY
    BL      read_PS2_data_ASM
    CMP     R0, #1
    BNE     wait_for_key_check
    LDR     R0, LAST_KEY
    CMP     R0, #0x45               @ if 0 num-key is released
    BEQ     start_game
    CMP     R0, #0x16               @ if 1 num-key is released
    MOVEQ   R0, #0b1
    BEQ     player_action
    CMP     R0, #0x1E               @ if 2 num-key is released
    MOVEQ   R0, #0b10
    BEQ     player_action
    CMP     R0, #0x26               @ if 3 num-key is released
    MOVEQ   R0, #0b100
    BEQ     player_action
    CMP     R0, #0x25               @ if 4 num-key is released
    MOVEQ   R0, #0b1000
    BEQ     player_action
    CMP     R0, #0x2E               @ if 5 num-key is released
    MOVEQ   R0, #0b10000
    BEQ     player_action
    CMP     R0, #0x36               @ if 6 num-key is released
    MOVEQ   R0, #0b100000
    BEQ     player_action
    CMP     R0, #0x3D               @ if 7 num-key is released
    MOVEQ   R0, #0b1000000
    BEQ     player_action
    CMP     R0, #0x3E               @ if 8 num-key is released
    MOVEQ   R0, #0b10000000
    BEQ     player_action
    CMP     R0, #0x46               @ if 9 num-key is released
    MOVEQ   R0, #0b100000000
    BEQ     player_action
    B       wait_for_key

// poll PS2_Data for 0 num-key to start the game
wait_for_start:
    // check if available
    LDR     R0, =LAST_KEY
    BL      read_PS2_data_ASM
    CMP     R0, #1                  @ check if RVALID
    BNE     wait_for_start
    // check for break event
    LDR     R0, LAST_KEY
    CMP     R0, #0xF0
    BNE     wait_for_start
wait_check_0:
    // check if available
    LDR     R0, =LAST_KEY
    BL      read_PS2_data_ASM
    CMP     R0, #1
    BNE     wait_check_0
    // check for 0 num-key
    LDR     R0, LAST_KEY
    CMP     R0, #0x45
    BNE     wait_for_start
start_game:
    BL      VGA_clear_charbuff_ASM
    BL      VGA_fill_ASM
    BL      draw_grid_ASM
    // reset variables
    LDR     R0, =TURN               @ set to Player-1 Turn
    MOV     R1, #1
    STR     R1, [R0]
    BL      disp_turn
    LDR     R0, =P1_MARKS           @ clear MARKS
    MOV     R1, #0
    STR     R1, [R0]
    LDR     R0, =P2_MARKS           @ clear MARKS
    STR     R1, [R0]
    B       wait_for_key

// display the text for player turn info
disp_turn:
    PUSH    {R4-R7, LR}
    LDR     R0, TURN
    CMP     R0, #1
    LDREQ   R4, =P1_TXT
    LDRNE   R4, =P2_TXT
    LDR     R5, TXT_LENGTH
    MOV     R6, #0
disp_turn_loop:
    // check stop condition
    CMP     R6, R5
    BGE     disp_turn_loop_end
    // display
    ADD     R0, R6, #33             @ text left margin 33px
    MOV     R1, #1
    LDR     R2, [R4], #4            @ post-increment character array pointer
    BL      VGA_write_char_ASM
    // increment
    ADD     R6, R6, #1
    B       disp_turn_loop
disp_turn_loop_end:
    POP     {R4-R7, LR}
    BX      LR

// draw a mark in one of the 9 squares, the type of mark depends on TURN
// squares are numbered from left to right, top to bottom, passed in one-hot encoding in R0
draw_mark_ASM:
    // get center position
    PUSH    {R4-R7, LR}
    LDR     R4, =CENTER_X_POS
    LDR     R5, =CENTER_Y_POS
    CMP     R0, #0b1
    LDREQ   R4, [R4]
    LDREQ   R5, [R5]
    BEQ     draw_mark_choose
    CMP     R0, #0b10
    LDREQ   R4, [R4, #4]
    LDREQ   R5, [R5]
    BEQ     draw_mark_choose
    CMP     R0, #0b100
    LDREQ   R4, [R4, #8]
    LDREQ   R5, [R5]
    BEQ     draw_mark_choose
    CMP     R0, #0b1000
    LDREQ   R4, [R4]
    LDREQ   R5, [R5, #4]
    BEQ     draw_mark_choose
    CMP     R0, #0b10000
    LDREQ   R4, [R4, #4]
    LDREQ   R5, [R5, #4]
    BEQ     draw_mark_choose
    CMP     R0, #0b100000
    LDREQ   R4, [R4, #8]
    LDREQ   R5, [R5, #4]
    BEQ     draw_mark_choose
    CMP     R0, #0b1000000
    LDREQ   R4, [R4]
    LDREQ   R5, [R5, #8]
    BEQ     draw_mark_choose
    CMP     R0, #0b10000000
    LDREQ   R4, [R4, #4]
    LDREQ   R5, [R5, #8]
    BEQ     draw_mark_choose
    CMP     R0, #0b100000000
    LDREQ   R4, [R4, #8]
    LDREQ   R5, [R5, #8]
    BEQ     draw_mark_choose
    POP     {R4-R7, LR}
    BX      LR
draw_mark_choose:
    // choose which mark to draw
    LDR     R0, TURN
    CMP     R0, #1
    BEQ     draw_plus
    CMP     R0, #0
    BEQ     draw_rect
    POP     {R4-R7, LR}
    BX      LR
draw_plus:
    // draw vertical line
    SUB     R6, R5, #20             @ y top bound
    ADD     R7, R5, #20             @ y bottom bound
draw_plus_loop_1:
    // check stop condition R6 > R7
    CMP     R6, R7
    BGT     draw_plus_loop_1_end
    // draw
    MOV     R0, R4                  @ x is constant when drawing vertical line
    MOV     R1, R6
    MOV     R2, #0
    BL      VGA_draw_point_ASM
    // increment
    ADD     R6, R6, #1
    B       draw_plus_loop_1
draw_plus_loop_1_end:
    // draw horizontal line
    SUB     R6, R4, #20             @ x left bound
    ADD     R7, R4, #20             @ x right bound
draw_plus_loop_2:
    // check stop condition R6 > R7
    CMP     R6, R7
    BGT     draw_plus_end
    // draw
    MOV     R0, R6
    MOV     R1, R5                  @ y is constant when drawing horizontal line
    MOV     R2, #0
    BL      VGA_draw_point_ASM
    // increment
    ADD     R6, R6, #1
    B       draw_plus_loop_2
draw_plus_end:
    POP     {R4-R7, LR}
    BX      LR
draw_rect:
    // draw the left vertical line
    SUB     R6, R5, #20             @ y top bound
    ADD     R7, R5, #20             @ y bottom bound
    SUB     R4, R4, #20             @ x is shifted 20px left
draw_rect_loop_1:
    // check stop condition
    CMP     R6, R7
    BGT     draw_rect_loop_1_end
    // draw
    MOV     R0, R4
    MOV     R1, R6
    MOV     R2, #0
    BL      VGA_draw_point_ASM
    // increment
    ADD     R6, R6, #1
    B       draw_rect_loop_1
draw_rect_loop_1_end:
    // draw the right vertical line
    SUB     R6, R5, #20             @ y top bound reset
    ADD     R4, R4, #40             @ x is shifted 20px right
draw_rect_loop_2:
    // check stop condition
    CMP     R6, R7
    BGT     draw_rect_loop_2_end
    // draw
    MOV     R0, R4
    MOV     R1, R6
    MOV     R2, #0
    BL      VGA_draw_point_ASM
    // increment
    ADD     R6, R6, #1
    B       draw_rect_loop_2
draw_rect_loop_2_end:
    // draw the upper horizontal line
    SUB     R4, R4, #20             @ x is re-centered
    SUB     R6, R4, #20             @ x left bound
    ADD     R7, R4, #20             @ x right bound
    SUB     R5, R5, #20             @ y is shifted 20px up
draw_rect_loop_3:
    // check stop condition
    CMP     R6, R7
    BGT     draw_rect_loop_3_end
    // draw
    MOV     R0, R6
    MOV     R1, R5
    MOV     R2, #0
    BL      VGA_draw_point_ASM
    // increment
    ADD     R6, R6, #1
    B       draw_rect_loop_3
draw_rect_loop_3_end:
    // draw the lower horizontal line
    SUB     R6, R4, #20             @ x left bound
    ADD     R7, R4, #20             @ x right bound
    ADD     R5, R5, #40             @ y is shifted 20px down
draw_rect_loop_4:
    // check stop condition
    CMP     R6, R7
    BGT     draw_rect_loop_4_end
    // draw
    MOV     R0, R6
    MOV     R1, R5
    MOV     R2, #0
    BL      VGA_draw_point_ASM
    // increment
    ADD     R6, R6, #1
    B       draw_rect_loop_4
draw_rect_loop_4_end:
    POP     {R4-R7, LR}
    BX      LR
    
// draw a 3x3 grid, in a square of 207px by 207px, lines are at increment of 69px from each other
// it's inefficient to loop this way but it was faster to code
draw_grid_ASM:
    PUSH    {R4-R5, LR}
    MOV     R4, #56                  @ x start coord
draw_grid_loop_x:
    // check stop condition: x > 56+207=263
    LDR     R5, =#263
    CMP     R4, R5
    BGT     draw_grid_end
    MOV     R5, #17                  @ y start coord
draw_grid_loop_y:
    // check stop condition: y > 17+207=224
    CMP     R5, #224
    BGT     draw_grid_increment_x
    // check for coordinates for which we want to draw a line
    CMP     R4, #125
    BEQ     draw_grid_do
    CMP     R4, #194
    BEQ     draw_grid_do
    CMP     R5, #86
    BEQ     draw_grid_do
    CMP     R5, #155
    BEQ     draw_grid_do
    B       draw_grid_increment_y
draw_grid_do:
    MOV     R0, R4
    MOV     R1, R5
    MOV     R2, #0
    BL      VGA_draw_point_ASM
draw_grid_increment_y:
    ADD     R5, R5, #1
    B       draw_grid_loop_y
draw_grid_increment_x:
    ADD     R4, R4, #1
    B       draw_grid_loop_x
draw_grid_end:
    POP     {R4-R5, LR}
    BX      LR

// fill the VGA screen with white
VGA_fill_ASM:
    PUSH    {R4-R5, LR}
    MOV     R4, #0                  @ x coord
fill_loop_x:
    // check stop condition: x > 319
    LDR     R5, =#319
    CMP     R4, R5
    BGT     fill_end
    MOV     R5, #0                  @ y coord
fill_loop_y:
    // check stop condition: y > 239
    CMP     R5, #239
    BGT     fill_increment_x
    // loop body
    MOV     R0, R4
    MOV     R1, R5
    LDR     R2, =#0b111111111       @ R2 <- lighter blue
    BL      VGA_draw_point_ASM
    // increment y
    ADD     R5, R5, #1
    B       fill_loop_y
fill_increment_x:
    ADD     R4, R4, #1
    B       fill_loop_x
fill_end:
    POP     {R4-R5, LR}
    BX      LR

end:
    B       end

// VGA drivers
// draws a point at x = R0, y = R1, color = R2, assume valid input
VGA_draw_point_ASM:
    PUSH    {R4}
    LDR     R3, =PIX_BUF
    // simple bit cleaning
    LDR     R4, =#0b111111111       @ x is 9 bits
    AND     R0, R0, R4
    LDR     R4, =#0b11111111        @ y is 8 bits
    AND     R1, R1, R4
    // shift x and y to get the address
    LSL     R0, #1                  @ shift x to correct position
    LSL     R1, #10                 @ shift y to correct position
    ORR     R3, R3, R0
    ORR     R3, R3, R1
    // write
    STRH    R2, [R3]                @ color is a halfword
    POP     {R4}
    BX      LR

// set all valid pixels to 0
VGA_clear_pixelbuff_ASM:
    PUSH    {R4-R5, LR}
    MOV     R4, #0                  @ x coord
clear_pixelbuff_loop_x:
    // check stop condition: x > 319
    LDR     R5, =#319
    CMP     R4, R5
    BGT     clear_pixelbuff_end
    MOV     R5, #0                  @ y coord
clear_pixelbuff_loop_y:
    // check stop condition: y > 239
    CMP     R5, #239
    BGT     clear_pixelbuff_increment_x
    // loop body
    MOV     R0, R4
    MOV     R1, R5
    MOV     R2, #0
    BL      VGA_draw_point_ASM
    // increment y
    ADD     R5, R5, #1
    B       clear_pixelbuff_loop_y
clear_pixelbuff_increment_x:
    ADD     R4, R4, #1
    B       clear_pixelbuff_loop_x
clear_pixelbuff_end:
    POP     {R4-R5, LR}
    BX      LR

// write the ASCII code in R2 to character buffer in x coord R0, y coord R1
VGA_write_char_ASM:
    // check if coords are valid
    CMP     R0, #0
    BXLT    LR
    CMP     R0, #79
    BXGT    LR
    CMP     R1, #0
    BXLT    LR
    CMP     R1, #59
    BXGT    LR
    // prepare addresses to write to char buffer
    LDR     R3, =CHAR_BUF
    LSL     R1, #7
    ORR     R3, R3, R0
    ORR     R3, R3, R1
    // write
    STRB    R2, [R3]                @ ASCII char is a byte
    BX      LR

// set all valid char buffers to 0
VGA_clear_charbuff_ASM:
    PUSH    {R4-R5, LR}
    MOV     R4, #0                  @ x coord
clear_charbuff_loop_x:
    // check stop condition: x > 79
    CMP     R4, #79
    BGT     clear_charbuff_end
    MOV     R5, #0                  @ y coord
clear_charbuff_loop_y:
    // check stop condition: y > 59
    CMP     R5, #59
    BGT     clear_charbuff_increment_x
    // loop body
    MOV     R0, R4
    MOV     R1, R5
    MOV     R2, #0
    BL      VGA_write_char_ASM
    // increment y
    ADD     R5, R5, #1
    B       clear_charbuff_loop_y
clear_charbuff_increment_x:
    ADD     R4, R4, #1
    B       clear_charbuff_loop_x
clear_charbuff_end:
    POP     {R4-R5, LR}
    BX      LR

// PS/2 driver
// if RVALID, store data to address at R0, then return 1, if !RVALID, then return 0
read_PS2_data_ASM:
    PUSH    {R4}
    LDR     R4, =PS_DAT             @ R4 <- addr of PS2_Data
    LDR     R1, [R4]                @ R1, R2 <- PS2_Data
    MOV     R2, R1
    LSR     R1, #15                 @ bit 0 of R1 <- RVALID
    TST     R1, #1
    MOVEQ   R0, #0                  @ return 0 if !RVALID
    POPEQ   {R4}
    BXEQ    LR
    // RVALID, then store the data and return 1
    STRB    R2, [R0]
    MOV     R0, #1
    POP     {R4}
    BX      LR
