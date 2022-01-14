// 2D convolution
// Input: fx, image, kernel sizes
// image & kernel are square

.global _start

// data section
FX:     .word 183, 207, 128, 30, 109, 0, 14, 52, 15, 210, 228, 76, 48, 82, 179, 194, 22, 168, 58, 116, 228, 217, 180, 181, 243, 65, 24, 127, 216, 118, 64, 210, 138, 104, 80, 137, 212, 196, 150, 139, 155, 154, 36, 254, 218, 65, 3, 11, 91, 95, 219, 10, 45, 193, 204, 196, 25, 177, 188, 170, 189, 241, 102, 237, 251, 223, 10, 24, 171, 71, 0, 4, 81, 158, 59, 232, 155, 217, 181, 19, 25, 12, 80, 244, 227, 101, 250, 103, 68, 46, 136, 152, 144, 2, 97, 250, 47, 58, 214, 51
KX:     .word 1, 1, 0, -1, -1, 0, 1, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1, 0, 1, 0, -1, -1, 0, 1, 1

// image, kernel dimensions + stride
IW:     .word 10
IH:     .word 10
KW:     .word 5
KH:     .word 5
KSW:    .word 2
KHW:    .word 2

// allocate space = image width * image height * sizeof(int)
GX:     .space 400

// code section
_start:
    // make space for 7 integers on the stack
    // y, x, sum, i, j, temp1, temp2
    SUB     SP, SP, #28

init_loop_1:
    MOV     R0, #0
    STR     R0, [SP, #24]           @ SP+24 <- int y = 0
loop_1:
    LDR     R0, [SP, #24]
    LDR     R1, =IH
    LDR     R1, [R1]
    // stop condition y < *IH
    CMP     R0, R1
    BGE     end_loop_1
    // else continue to init_loop_2

init_loop_2:
    MOV     R0, #0
    STR     R0, [SP, #20]           @ SP+20 <- int x = 0
loop_2:
    LDR     R0, [SP, #20]
    LDR     R1, =IW
    LDR     R1, [R1]
    // stop condition x < *IW
    CMP     R0, R1
    BGE     end_loop_2
    // else
    MOV     R0, #0
    STR     R0, [SP, #16]           @ SP+16 <- int sum = 0
    // continue to init_loop_3

init_loop_3:
    STR     R0, [SP, #12]           @ SP+12 <- int i = 0
loop_3:
    LDR     R0, [SP, #12]
    LDR     R1, =KW
    LDR     R1, [R1]
    // stop condition i < *KW
    CMP     R0, R1
    BGE     end_loop_3
    // else continue to init_loop_4

init_loop_4:
    MOV     R0, #0
    STR     R0, [SP, #8]            @ SP+8 <- int j = 0
loop_4:
    LDR     R0, [SP, #8]
    LDR     R1, =KH
    LDR     R1, [R1]
    // stop condition j < *KH
    CMP     R0, R1
    BGE     end_loop_4
    // else continue to body

body:
    // int temp1 = x + j - ksw
    LDR     R0, [SP, #20]
    LDR     R1, [SP, #8]
    ADD     R0, R0, R1
    LDR     R1, =KSW
    LDR     R1, [R1]
    SUB     R0, R0, R1
    STR     R0, [SP, #4]            @ SP+4 <- int temp1
    // int temp2 = y + i - khw
    LDR     R0, [SP, #24]
    LDR     R1, [SP, #12]
    ADD     R0, R0, R1
    LDR     R1, =KHW
    LDR     R1, [R1]
    SUB     R0, R0, R1
    STR     R0, [SP]                @ SP <- int temp2
    // check 1: temp1 >= 0
    LDR     R0, [SP, #4]
    CMP     R0, #0
    BLT     end_body
    // check 2: temp1 <= 9
    CMP     R0, #9
    BGT     end_body
    // check 3: temp2 >= 0
    LDR     R0, [SP]
    CMP     R0, #0
    BLT     end_body
    // check 4: temp2 <= 9
    CMP     R0, #9
    BGT     end_body
    // else continue to sum

sum:
    // kx[j][i]
    LDR     R1, [SP, #8]            @ R1 <- j
    LDR     R2, =KW
    LDR     R2, [R2]
    MUL     R1, R1, R2              @ R1 <- row j offset in words (j * kw)
    LDR     R2, =KX
    ADD     R1, R2, R1, LSL #2      @ R1 <- KX[j]
    LDR     R2, [SP, #12]           @ R2 <- i
    LDR     R1, [R1, R2, LSL #2]    @ R1 <- *KX[j][i]
    // fx[temp1][temp2]
    LDR     R2, [SP, #4]            @ R2 <- temp1
    LDR     R3, =IW
    LDR     R3, [R3]
    MUL     R2, R2, R3              @ R2 <- row temp1 offset in words
    LDR     R3, =FX
    ADD     R2, R3, R2, LSL #2      @ R2 <- FX[temp1]
    LDR     R3, [SP]                @ R3 <- temp2
    LDR     R2, [R2, R3, LSL #2]    @ R2 <- *FX[temp1][temp2]
    // sum = sum + kx[j][i] * fx[temp1][temp2]
    LDR     R0, [SP, #16]           @ R0 <- sum
    MLA     R3, R1, R2, R0
    STR     R3, [SP, #16]

end_body:
    // continue to increment_loop_4

increment_loop_4:
    LDR     R0, [SP, #8]
    ADD     R0, R0, #1
    STR     R0, [SP, #8]
    B       loop_4

end_loop_4:
    // continue to increment_loop_3

increment_loop_3:
    LDR     R0, [SP, #12]
    ADD     R0, R0, #1
    STR     R0, [SP, #12]
    B       loop_3

end_loop_3:
    LDR     R0, [SP, #16]           @ R0 <- sum
    LDR     R1, [SP, #20]           @ R1 <- x
    LDR     R2, =IW
    LDR     R2, [R2]
    MUL     R1, R1, R2              @ R1 <- row x offset in words
    LDR     R2, =GX
    ADD     R1, R2, R1, LSL #2
    LDR     R2, [SP, #24]           @ R2 <- y
    STR     R0, [R1, R2, LSL #2]    @ gx[x][y] <- sum
    // continue to increment_loop_2

increment_loop_2:
    LDR     R0, [SP, #20]
    ADD     R0, R0, #1
    STR     R0, [SP, #20]
    B       loop_2

end_loop_2:
    // continue to increment_loop_1

increment_loop_1:
    LDR     R0, [SP, #24]
    ADD     R0, R0, #1
    STR     R0, [SP, #24]
    B       loop_1

end_loop_1:
    LDR     R0, =GX                 @ return address of gx
    ADD     SP, SP, #28
    B       end

end:
    B       end

