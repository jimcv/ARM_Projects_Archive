// Use iteration to compute nth Fibonacci number. (n: any positive int)

.global _start

// data section
N:          .word 6
// allocate space for n + 2 integers
SEQUENCE:   .space 32


_start:
    // save states
    PUSH    {R4-R5}
    // addr of array & n into variable reg
    LDR     R4, =SEQUENCE
    LDR     R5, =N
    LDR     R5, [R5]
    // store values in array
    MOV     R1, #0
    MOV     R2, #1
    STR     R1, [R4]
    STR     R2, [R4, #4]
    // goto loop
    B      compute

compute:
    // set i
    MOV     R0, #2

loop:
    SUB     R1, R0, #1
    LDR     R2, [R4, R1, LSL #2]    @ R2 <- *SEQUENCE[i - 1]
    SUB     R1, R0, #2
    LDR     R3, [R4, R1, LSL #2]    @ R3 <- *SEQUENCE[i - 2]
    ADD     R1, R2, R3
    STR     R1, [R4, R0, LSL #2]    @ *SEQUENCE[i] = R2 + R3

increment_loop:
    ADD     R0, R0, #1
    CMP     R0, R5
    BLE     loop
    // else continue to end_of_loop

end_of_loop:
    // load return value
    LDR     R0, [R4, R5, LSL #2]
    // restore states
    POP     {R4-R5}
    B       end

end:
    B       end