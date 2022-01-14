/*

    Polling based Stopwatch!

 */

.global _start
.equ    SW_MEMORY, 0xFF200040       @ Addr of slider switches
.equ    LED_MEMORY, 0xFF200000      @ Addr of LEDs
.equ    HEX3_0, 0xFF200020          @ Bits 30 downto 0 are data for HEX3 to HEX0, with 1 bit between each HEX
.equ    HEX5_4, 0xFF200030          @ Bits 14 downto 0 are data for HEX5 to HEX4, with 1 bit between each HEX
.equ    PB_DATA, 0xFF200050         @ One hot data register for pushbuttons 3 downto 0
.equ    PB_MASK, 0xFF200058         @ Interruptmask register 3 downto 0
.equ    PB_EDGE, 0xFF20005C         @ Edgecapture register 3 downto 0
.equ    TIM_LOAD, 0xFFFEC600        @ Addr for private timer load register
.equ    TIM_COUNT, 0xFFFEC604       @ Addr for private timer count register
.equ    TIM_CTRL, 0xFFFEC608        @ Addr for private timer control register (PRESCALER, IAE)
.equ    TIM_INT, 0xFFFEC60C         @ Addr for private timer interrupt status register

TIMER_LOAD: .word 2000000         @ Make timer count down from 2M (at 200MHz this will take 0.01 second)

_start:
    // init
    MOV     R4, #0                  @ R4 <- 1/100th of second
    MOV     R5, #0                  @ R5 <- 1/10th of second
    MOV     R6, #0                  @ R6 <- second
    MOV     R7, #0                  @ R7 <- second ^ 10
    MOV     R8, #0                  @ R8 <- minute
    MOV     R9, #0                  @ R9 <- minute ^ 10
    BL      refresh_display
poll:
    // poll pushbuttons for command
    BL      read_PB_edgecp_ASM
    CMP     R0, #0                  @ avoid simulator warning by only calling clear when there is edgecp
    BLNE    PB_clear_edgecp_ASM     @ PB_clear_edgecp_ASM does not modify R0 so we don't need to save it
    // PB2: reset
    TST     R0, #0b0100
    BNE     reset_timer
    // PB1: stop
    TST     R0, #0b0010
    BNE     stop_timer
    // PB0: start
    TST     R0, #0b0001
    BNE     start_timer
    // poll timer interrupt status register
    BL      ARM_TIM_read_INT_ASM
    TST     R0, #1
    BEQ     poll
    // when F is asserted, do increment logic (base 10 between seconds and base 60 between second and minute)
    BL      ARM_TIM_clear_INT_ASM
    ADD     R4, R4, #1
    CMP     R4, #10
    MOVEQ   R4, #0
    ADDEQ   R5, #1
    CMP     R5, #10
    MOVEQ   R5, #0
    ADDEQ   R6, #1
    CMP     R6, #10
    MOVEQ   R6, #0
    ADDEQ   R7, #1
    CMP     R7, #6
    MOVEQ   R7, #0
    ADDEQ   R8, #1
    CMP     R8, #10
    MOVEQ   R8, #0
    ADDEQ   R9, #1
    CMP     R9, #10
    BLEQ    _start
    // refresh HEX display with new digits
    BL      refresh_display
    B       poll

start_timer:
    // utility function to start the timer
    LDR     R0, TIMER_LOAD
    MOV     R1, #0b011
    BL      ARM_TIM_config_ASM
    B       poll

stop_timer:
    // utility function to stop the timer
    LDR     R0, TIMER_LOAD
    MOV     R1, #0b010
    BL      ARM_TIM_config_ASM
    B       poll

reset_timer:
    // utility function to stop and reset the timer
    LDR     R0, TIMER_LOAD
    MOV     R1, #0b010
    BL      ARM_TIM_config_ASM
    B       _start

refresh_display:
    PUSH    {LR}
    // refresh HEX 0 to 5 with current data
    MOV     R0, #0b000001
    MOV     R1, R4                  @ R4 is displayed on HEX0
    BL      HEX_write_ASM
    MOV     R0, #0b000010
    MOV     R1, R5                  @ R5 is displayed on HEX1
    BL      HEX_write_ASM
    MOV     R0, #0b000100
    MOV     R1, R6                  @ R6 is displayed on HEX2
    BL      HEX_write_ASM
    MOV     R0, #0b001000
    MOV     R1, R7                  @ R7 is displayed on HEX3
    BL      HEX_write_ASM
    MOV     R0, #0b010000
    MOV     R1, R8                  @ R8 is displayed on HEX4
    BL      HEX_write_ASM
    MOV     R0, #0b100000
    MOV     R1, R9                  @ R9 is displayed on HEX5
    BL      HEX_write_ASM
    POP     {LR}
    BX      LR

// Private Timer Driver
// configure the timer with load value in R0, control bits in R1
ARM_TIM_config_ASM:
    LDR     R2, =TIM_LOAD
    STR     R0, [R2]
    LDR     R2, =TIM_CTRL
    STR     R1, [R2]
    BX      LR

// returns interrupt status bit F, surrounded by 0
ARM_TIM_read_INT_ASM:
    LDR     R1, =TIM_INT
    LDR     R1, [R1]
    MOV     R2, #1                  @ bit mask to surround F with 0
    AND     R0, R1, R2
    BX      LR

// clear interrupt status bit F by writting 1 to it
ARM_TIM_clear_INT_ASM:
    LDR     R1, =TIM_INT
    MOV     R2, #1
    STR     R2, [R1]
    BX      LR

// Pushbuttons Driver
// return indices of pressed pushbuttons in one-hot encoding
read_PB_data_ASM:
    LDR     R1, =PB_DATA
    LDR     R0, [R1]
    BX      LR

// return indices of pressed then released pushbottons in one-hot
read_PB_edgecp_ASM:
    LDR     R1, =PB_EDGE
    LDR     R0, [R1]
    BX      LR

// clear pushbuttons Edgecapture register
PB_clear_edgecp_ASM:
    LDR     R1, =PB_EDGE
    LDR     R2, [R1]
    STR     R2, [R1]
    BX      LR

// enable interrupt function for given pushbutton indices
enable_PB_INT_ASM:
    LDR     R1, =PB_MASK
    STR     R0, [R1]
    BX      LR

// disable interrupt function for given pushbutton indices
disable_PB_INT_ASM:
    LDR     R1, =PB_MASK
    LDR     R2, [R1]
    BIC     R2, R2, R0              @ R2 <- R2 AND NOT R0
    STR     R2, [R1]
    BX      LR

// HEX Displays Driver
// turn off all segments of displays passed as indices in R0
HEX_clear_ASM:
    // init loop
    PUSH    {R4}                    @ callee-save
    MOV     R1, #0b0000001          @ R1 <- indice comparator
    MOV     R2, #0xFFFFFF00         @ R2 <- bit clear for a single display
HEX_clear_loop:
    // check comparator indice, stop when reached 7th bit
    CMP     R1, #0b1000000
    POPEQ   {R4}
    BXEQ    LR
    // check comparator indice, load HEX3_0 or HEX5_4 accordingly
    CMP     R1, #0b0010000
    LDRLT   R3, =HEX3_0             @ R3 <- HEX data addr
    LDRGE   R3, =HEX5_4
    LDR     R4, [R3]                @ R4 <- HEX data
    // check if current indice needs to be flooded
    TST     R0, R1
    BEQ     HEX_clear_increment     @ jump to increment if result of AND is 0 (i.e. no need to flood)
    // flood
    AND     R4, R4, R2              @ R4 <- (HEX data) AND (bit flood)
    STR     R4, [R3]
HEX_clear_increment:
    LSL     R1, #1                  @ shift comparator to next indice
    ROR     R2, #24                 @ ROR 24 = ROL 8, use this instead of LSL so it comes back to LSB for HEX5_4
    B       HEX_clear_loop

// turn on all segments of displays passed as indices in R0
HEX_flood_ASM:
    // init loop
    PUSH    {R4}                    @ callee-save
    MOV     R1, #0b0000001          @ R1 <- indice comparator
    MOV     R2, #0x000000FF         @ R2 <- bit flood for a single display
HEX_flood_loop:
    // check comparator indice, stop when reached 7th bit
    CMP     R1, #0b1000000
    POPEQ   {R4}
    BXEQ    LR
    // check comparator indice, load HEX3_0 or HEX5_4 accordingly
    CMP     R1, #0b0010000
    LDRLT   R3, =HEX3_0             @ R3 <- HEX data addr
    LDRGE   R3, =HEX5_4
    LDR     R4, [R3]                @ R4 <- HEX data
    // check if current indice needs to be flooded
    TST     R0, R1
    BEQ     HEX_flood_increment     @ jump to increment if result of AND is 0 (i.e. no need to flood)
    // flood
    ORR     R4, R4, R2              @ R4 <- (HEX data) OR (bit flood)
    STR     R4, [R3]
HEX_flood_increment:
    LSL     R1, #1                  @ shift comparator to next indice
    ROR     R2, #24                 @ ROR 24 = ROL 8, use this instead of LSL so it comes back to LSB for HEX5_4
    B       HEX_flood_loop

// display hexadecimal digit in R1 at HEX indices in R0
HEX_write_ASM:
    // init loop
    PUSH    {R4-R5}                 @ callee-save
    MOV     R2, #0b0000001          @ R2 <- indice comparator
    MOV     R3, #0xFFFFFF00         @ R3 <- bit clear for a single display
    // convert digit to segment data and store in R1
    CMP     R1, #0x0
    MOVEQ   R1, #0b00111111
    BEQ     HEX_write_loop
    CMP     R1, #0x1
    MOVEQ   R1, #0b00000110
    BEQ     HEX_write_loop
    CMP     R1, #0x2
    MOVEQ   R1, #0b01011011
    BEQ     HEX_write_loop
    CMP     R1, #0x3
    MOVEQ   R1, #0b01001111
    BEQ     HEX_write_loop
    CMP     R1, #0x4
    MOVEQ   R1, #0b01100110
    BEQ     HEX_write_loop
    CMP     R1, #0x5
    MOVEQ   R1, #0b01101101
    BEQ     HEX_write_loop
    CMP     R1, #0x6
    MOVEQ   R1, #0b01111101
    BEQ     HEX_write_loop
    CMP     R1, #0x7
    MOVEQ   R1, #0b00000111
    BEQ     HEX_write_loop
    CMP     R1, #0x8
    MOVEQ   R1, #0b01111111
    BEQ     HEX_write_loop
    CMP     R1, #0x9
    MOVEQ   R1, #0b01100111
    BEQ     HEX_write_loop
    CMP     R1, #0xA
    MOVEQ   R1, #0b01110111
    BEQ     HEX_write_loop
    CMP     R1, #0xB
    MOVEQ   R1, #0b01111100
    BEQ     HEX_write_loop
    CMP     R1, #0xC
    MOVEQ   R1, #0b00111001
    BEQ     HEX_write_loop
    CMP     R1, #0xD
    MOVEQ   R1, #0b01011110
    BEQ     HEX_write_loop
    CMP     R1, #0xE
    MOVEQ   R1, #0b01111001
    BEQ     HEX_write_loop
    CMP     R1, #0xF
    MOVEQ   R1, #0b01110001
    BEQ     HEX_write_loop
    // R1 has out of range value then turn off display
    MOV     R1, #0x0
HEX_write_loop:
    // check comparator indice, stop when reached 7th bit
    CMP     R2, #0b1000000
    POPEQ   {R4-R5}
    BXEQ    LR
    // check comparator indice, load HEX3_0 or HEX5_4 accordingly
    CMP     R2, #0b0010000
    LDRLT   R4, =HEX3_0             @ R4 <- HEX data addr
    LDRGE   R4, =HEX5_4
    LDR     R5, [R4]                @ R5 <- HEX data
    // check if current indice needs to be written
    TST     R0, R2
    BEQ     HEX_write_increment     @ jump to increment if result of AND is 0 (i.e. no need to flood)
    // write
    AND     R5, R5, R3              @ clear current display segment data
    ORR     R5, R5, R1              @ put new segment data
    STR     R5, [R4]
HEX_write_increment:
    ROR     R1, #24                 @ ROR 24 = ROL 8 for segment data
    LSL     R2, #1                  @ shift comparator to next indice
    ROR     R3, #24                 @ ROR 24 = ROL 8 for bit clear on single display
    B       HEX_write_loop

// Sider Switches Driver
// returns the state of slider switches in R0
read_slider_switches_ASM:
    LDR     R1, =SW_MEMORY
    LDR     R0, [R1]
    BX      LR

// LEDs Driver
// writes the state of LEDs (On/Off state) in R0 to the LEDs memory location
write_LEDs_ASM:
    LDR     R1, =LED_MEMORY
    STR     R0, [R1]
    BX      LR

