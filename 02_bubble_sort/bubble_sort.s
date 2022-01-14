// Bubble sort array in ascending order
// Input is array ARR of size SIZE

.global _start

// data section
ARR:    .word -1, 23, 0, 12, -7
SIZE:   .word 5

_start:
    // save states
    PUSH    {R4-R6}

init_loop_1:
    MOV     R4, #0                  @ R4 <- int step = 0
loop_1:
    LDR     R0, =SIZE
    LDR     R0, [R0]                @ R0 <- *SIZE
    // check stop condition
    SUB     R0, R0, #1
    CMP     R4, R0
    BGE     end_loop_1
    // else continue to init_loop_2

init_loop_2:
    MOV     R5, #0                  @ R5 <- int i = 0
loop_2:
    LDR     R0, =SIZE
    LDR     R0, [R0]                @ R0 <- *SIZE
    MOV     R1, R4
    // check stop condition
    MVN     R1, R1                  @ R1 <- (- step - 1)
    ADD     R0, R0, R1
    CMP     R5, R0
    BGE     end_loop_2
    // else continue to swap_check

swap_check:
    LDR     R0, =ARR                @ R0 <- ARR
    MOV     R1, R5
    LDR     R1, [R0, R1, LSL #2]!   @ R1 <- *(ptr + i) & post increment R0
    LDR     R0, [R0, #4]            @ R0 <- *(ptr + i + 1)
    CMP     R1, R0
    // change conditions here to sort in descending instead (LE to GE)
    BLE     end_swap_check
    // else do the swap

swap:
    // int tmp = *(ptr + i)
    LDR     R0, =ARR
    LDR     R1, [R0, R5, LSL #2]    @ R1 <- *(ptr + i)
    MOV     R6, R1                  @ R6 <- int tmp = *(ptr + i)
    // *(ptr + i) = *(ptr + i + 1)
    ADD     R1, R0, R5, LSL #2      @ R1 <- ARR[i]
    LDR     R1, [R1, #4]            @ R1 <- *(ptr + i + 1)
    STR     R1, [R0, R5, LSL #2]
    // *(ptr + i + 1) = tmp
    ADD     R0, R0, R5, LSL #2      @ R0 <- ARR[i]
    STR     R6, [R0, #4]

end_swap_check:
    // continue to increment_loop_2

increment_loop_2:
    ADD     R5, R5, #1
    B       loop_2

end_loop_2:
    // continue to increment_loop_1

increment_loop_1:
    ADD     R4, R4, #1
    B       loop_1

end_loop_1:
    LDR     R0, =ARR                @ return address of array
    // restore states
    POP     {R4-R6}
    B       end

end:
    B       end
