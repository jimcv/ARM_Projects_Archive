// Use recursion to compute nth Fibonacci number. (n: any positive int)
// Input is N = n

.global _start

// data section
N:      .word 3

_start:
    // load parameter n
    LDR     R0, =N
    LDR     R0, [R0]                    @ R0 <- n
    // go to recursion
    PUSH    {LR}
    BL      Fib
    // restore LR and end
    POP     {LR}
    B       end

Fib:
    // save states
    PUSH    {FP, LR}
    MOV     FP, SP                      @ FP <- SP
    // allocate space on stack
    // n input, n returned, (Fib-1) return
    SUB     SP, SP, #12
    STR     R0, [FP, #-4]               @ FP-4 <- n
    // base case check
    CMP     R0, #1
    BGT     else
    // else continue to return

return:
    LDR     R0, [FP, #-4]
    STR     R0, [FP, #-8]               @ n returned <- n input
    B       end_Fib

else:
    // Fib(n-1)
    LDR     R0, [FP, #-4]
    SUB     R0, R0, #1                  @ R0 <- (n - 1)
    BL      Fib
    STR     R0, [FP, #-12]              @ FP-12 <- Fib(n-1) return
    // Fib(n-2)
    LDR     R0, [FP, #-4]
    SUB     R0, R0, #2                  @ R0 <- (n - 2)
    BL      Fib
    LDR     R1, [FP, #-12]              @ R1 <- Fib(n-1) return
    ADD     R0, R1, R0
    STR     R0, [FP, #-8]               @ FP-8 <- n returned
    B       end_Fib

end_Fib:
    LDR     R0, [FP, #-8]               @ R0 <- n returned
    MOV     SP, FP                      @ SP <- FP
    // restore states
    POP     {FP, LR}
    BX      LR

end:
    B       end