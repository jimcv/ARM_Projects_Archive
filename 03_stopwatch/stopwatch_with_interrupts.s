// initialize exception vector table
.section .vectors, "ax"
B _start
B SERVICE_UND       // undefined instruction vector
B SERVICE_SVC       // software interrupt vector
B SERVICE_ABT_INST  // aborted prefetch vector
B SERVICE_ABT_DATA  // aborted data vector
.word 0 // unused vector
B SERVICE_IRQ       // IRQ interrupt vector
B SERVICE_FIQ       // FIQ interrupt vector

.text
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

TIMER_LOAD:     .word 2000000       @ Make timer count down from 2M (at 200MHz this will take 0.01 second)
PB_int_flag:    .word 0x0
tim_int_flag:   .word 0x0

_start:
    /* Set up stack pointers for IRQ and SVC processor modes */
    MOV        R1, #0b11010010      // interrupts masked, MODE = IRQ
    MSR        CPSR_c, R1           // change to IRQ mode
    LDR        SP, =0xFFFFFFFF - 3  // set IRQ stack to A9 onchip memory
    /* Change to SVC (supervisor) mode with interrupts disabled */
    MOV        R1, #0b11010011      // interrupts masked, MODE = SVC
    MSR        CPSR, R1             // change to supervisor mode
    LDR        SP, =0x3FFFFFFF - 3  // set SVC stack to top of DDR3 memory
    BL     CONFIG_GIC           // configure the ARM GIC
    // enable PB interrupt
    MOV     R0, #0xF
    BL      enable_PB_INT_ASM
    // enable interrupt for ARM A9 private timer
    LDR     R0, TIMER_LOAD
    MOV     R1, #0b110
    BL      ARM_TIM_config_ASM
    // enable IRQ interrupts in the processor
    MOV        R0, #0b01010011      // IRQ unmasked, MODE = SVC
    MSR        CPSR_c, R0
IDLE:
    // init
    MOV     R4, #0                  @ R4 <- 1/100th of second
    MOV     R5, #0                  @ R5 <- 1/10th of second
    MOV     R6, #0                  @ R6 <- second
    MOV     R7, #0                  @ R7 <- second ^ 10
    MOV     R8, #0                  @ R8 <- minute
    MOV     R9, #0                  @ R9 <- minute ^ 10
    BL      refresh_display
timer_loop:
    // check and PB
    LDR     R0, =PB_int_flag
    LDR     R1, [R0]                @ R1 <- edgecp written by ISR
    MOV     R2, #0
    STR     R2, [R0]                @ clear PB_int_flag
    // PB2: reset
    TST     R1, #0b0100
    BNE     reset_timer
    // PB1: stop
    TST     R1, #0b0010
    BNE     stop_timer
    // PB0: start
    TST     R1, #0b0001
    BNE     start_timer
    // check timer
    LDR     R0, =tim_int_flag
    LDR     R1, [R0]                @ R1 <- F written by ISR
    TST     R1, #1
    BEQ     timer_loop
    // when F is asserted, clear it, then do increment logic
    MOV     R2, #0
    STR     R2, [R0]                @ clear F
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
    BLEQ    IDLE
    // refresh HEX display with new digits
    BL      refresh_display
    B       timer_loop

start_timer:
    // utility function to start the timer
    LDR     R0, TIMER_LOAD
    MOV     R1, #0b111
    BL      ARM_TIM_config_ASM
    B       timer_loop

stop_timer:
    // utility function to stop the timer
    LDR     R0, TIMER_LOAD
    MOV     R1, #0b110
    BL      ARM_TIM_config_ASM
    B       timer_loop

reset_timer:
    // utility function to stop and reset the timer
    LDR     R0, TIMER_LOAD
    MOV     R1, #0b110
    BL      ARM_TIM_config_ASM
    B       IDLE

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


/*--- Undefined instructions ---------------------------------------- */
SERVICE_UND:
    B SERVICE_UND
/*--- Software interrupts ------------------------------------------- */
SERVICE_SVC:
    B SERVICE_SVC
/*--- Aborted data reads -------------------------------------------- */
SERVICE_ABT_DATA:
    B SERVICE_ABT_DATA
/*--- Aborted instruction fetch ------------------------------------- */
SERVICE_ABT_INST:
    B SERVICE_ABT_INST
/*--- IRQ ----------------------------------------------------------- */
SERVICE_IRQ:
    PUSH {R0-R7, LR}
/* Read the ICCIAR from the CPU Interface */
    LDR R4, =0xFFFEC100
    LDR R5, [R4, #0x0C] // read from ICCIAR

/* To Do: Check which interrupt has occurred (check interrupt IDs)
   Then call the corresponding ISR
   If the ID is not recognized, branch to UNEXPECTED
   See the assembly example provided in the De1-SoC Computer_Manual on page 46 */
Pushbutton_check:
    CMP     R5, #73
    BNE     Private_timer_check
    BL      KEY_ISR
    B       EXIT_IRQ
Private_timer_check:
    CMP     R5, #29
UNEXPECTED:
    BNE     UNEXPECTED      // if not recognized, stop here
    BL      ARM_TIM_ISR
EXIT_IRQ:
/* Write to the End of Interrupt Register (ICCEOIR) */
    STR R5, [R4, #0x10] // write to ICCEOIR
    POP {R0-R7, LR}
SUBS PC, LR, #4
/*--- FIQ ----------------------------------------------------------- */
SERVICE_FIQ:
    B SERVICE_FIQ



CONFIG_GIC:
    PUSH {LR}
/* To configure the FPGA KEYS interrupt (ID 73):
* 1. set the target to cpu0 in the ICDIPTRn register
* 2. enable the interrupt in the ICDISERn register */
/* CONFIG_INTERRUPT (int_ID (R0), CPU_target (R1)); */
/* To Do: you can configure different interrupts
   by passing their IDs to R0 and repeating the next 3 lines */
    MOV R0, #73            // KEY port (Interrupt ID = 73)
    MOV R1, #1             // this field is a bit-mask; bit 0 targets cpu0
    BL CONFIG_INTERRUPT

    // config private timer
    MOV     R0, #29
    MOV     R1, #1
    BL      CONFIG_INTERRUPT

/* configure the GIC CPU Interface */
    LDR R0, =0xFFFEC100    // base address of CPU Interface
/* Set Interrupt Priority Mask Register (ICCPMR) */
    LDR R1, =0xFFFF        // enable interrupts of all priorities levels
    STR R1, [R0, #0x04]
/* Set the enable bit in the CPU Interface Control Register (ICCICR).
* This allows interrupts to be forwarded to the CPU(s) */
    MOV R1, #1
    STR R1, [R0]
/* Set the enable bit in the Distributor Control Register (ICDDCR).
* This enables forwarding of interrupts to the CPU Interface(s) */
    LDR R0, =0xFFFED000
    STR R1, [R0]
    POP {PC}

/*
* Configure registers in the GIC for an individual Interrupt ID
* We configure only the Interrupt Set Enable Registers (ICDISERn) and
* Interrupt Processor Target Registers (ICDIPTRn). The default (reset)
* values are used for other registers in the GIC
* Arguments: R0 = Interrupt ID, N
* R1 = CPU target
*/
CONFIG_INTERRUPT:
    PUSH {R4-R5, LR}
/* Configure Interrupt Set-Enable Registers (ICDISERn).
* reg_offset = (integer_div(N / 32) * 4
* value = 1 << (N mod 32) */
    LSR R4, R0, #3    // calculate reg_offset
    BIC R4, R4, #3    // R4 = reg_offset
    LDR R2, =0xFFFED100
    ADD R4, R2, R4    // R4 = address of ICDISER
    AND R2, R0, #0x1F // N mod 32
    MOV R5, #1        // enable
    LSL R2, R5, R2    // R2 = value
/* Using the register address in R4 and the value in R2 set the
* correct bit in the GIC register */
    LDR R3, [R4]      // read current register value
    ORR R3, R3, R2    // set the enable bit
    STR R3, [R4]      // store the new register value
/* Configure Interrupt Processor Targets Register (ICDIPTRn)
* reg_offset = integer_div(N / 4) * 4
* index = N mod 4 */
    BIC R4, R0, #3    // R4 = reg_offset
    LDR R2, =0xFFFED800
    ADD R4, R2, R4    // R4 = word address of ICDIPTR
    AND R2, R0, #0x3  // N mod 4
    ADD R4, R2, R4    // R4 = byte address in ICDIPTR
/* Using register address in R4 and the value in R2 write to
* (only) the appropriate byte */
    STRB R1, [R4]
    POP {R4-R5, PC}



KEY_ISR:
    PUSH    {LR}
    // read command, clear interrupt signal then go back
    BL      read_PB_edgecp_ASM
    LDR     R1, =PB_int_flag
    STR     R0, [R1]
    BL      PB_clear_edgecp_ASM
    POP     {LR}
    BX      LR

ARM_TIM_ISR:
    PUSH    {LR}
    // set tim_int_flag to 1, clear interrupt signal then go back
    LDR     R0, =tim_int_flag
    MOV     R1, #1
    STR     R1, [R0]
    BL      ARM_TIM_clear_INT_ASM
    POP     {LR}
    BX      LR

/*
    Drivers Section
*/

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
