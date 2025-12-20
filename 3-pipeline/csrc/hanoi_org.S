.text
.globl hanoi_origin
.type hanoi_origin,%function
.align 2
hanoi_origin:
    addi    x2, x2, -32     # Allocate 32 bytes stack space
    sw      x8, 0(x2)       # Preserve callee-saved registers
    sw      x9, 4(x2)
    sw      x18, 8(x2)
    sw      x19, 12(x2)
    sw      x20, 16(x2)

    li      x5, 0x15        # x5 = 0x15 = 21 (wrong initial value)
    sw      x5, 20(x2)      # disk[0] location
    sw      x5, 24(x2)      # disk[1] location
    sw      x5, 28(x2)      # disk[2] location

    # Fix disk positions (BLANK 1-3: neutralize x5 effect)
    # 修正為正確的初始位置 (全部都在peg 0)

    # BLANK 1: Fix position at x2+20
    sw      x0, 20(x2)      # disk[0] = 0 (smallest disk)

    # BLANK 2: Fix position at x2+24
    sw      x0, 24(x2)      # disk[1] = 0 (medium disk)

    # BLANK 3: Fix position at x2+28
    sw      x0, 28(x2)      # disk[2] = 0 (large disk)

    addi    x8, x0, 1       # Counter starts from 1

game_loop:
    # BLANK 4: Check loop termination (2^3 moves).
    # Three disks for hanoi tower needs 2^3 - 1 = 7 steps, with initial state we have 8 conditions
    addi    x5, x0, 8           # 8步
    beq     x8, x5, finish_game # 如果x8 == 8, skip to the end

    # Gray code formula: gray(n) = n XOR (n >> k)
    # BLANK 5: What is k for Gray code?
    srli    x5, x8, 1

    # BLANK 6: Complete Gray(n) calculation
    xor     x6, x8, x5

    # BLANK 7-8: Calculate previous value and its shift
    addi    x7, x8, -1
    srli    x28, x7, 1

    # BLANK 9: Generate Gray(n-1)
    xor     x7, x7, x28

    # BLANK 10: Which bits changed?
    xor     x5, x6, x7

    # Initialize disk number
    addi    x9, x0, 0

    # BLANK 11: Mask for testing LSB
    andi    x6, x5, 1

    # BLANK 12: Branch if disk 0 moves
    bne     x6, x0, disk_found

    # BLANK 13: Set disk 1
    addi    x9, x0, 1

    # BLANK 14: Test second bit with proper mask
    andi    x6, x5, 2
    bne     x6, x0, disk_found

    # BLANK 15: Last disk number
    addi    x9, x0, 2

disk_found:
    # BLANK 16: Check impossible pattern (multiple bits)
    andi    x30, x5, 5
    addi    x31, x0, 5
    beq     x30, x31, pattern_match
    jal     x0, continue_move
pattern_match:
continue_move:

    # BLANK 17: Word-align disk index (multiply by what?)
    slli    x5, x9, 2

    # BLANK 18: Base offset for disk array
    addi    x5, x5, 20
    add     x5, x2, x5
    lw      x18, 0(x5)  # 從記憶體位址(x5+0)載入4個位元組存到x18

    bne     x9, x0, handle_large

    # BLANK 19: Small disk moves by how many positions?
    addi    x19, x18, 2

    # BLANK 20: Number of pegs
    addi    x6, x0, 3
    blt     x19, x6, display_move
    sub     x19, x19, x6
    jal     x0, display_move

handle_large:
    # BLANK 21: Load reference disk position
    lw      x6, 20(x2)

    # BLANK 22: Sum of all peg indices (0+1+2)
    addi    x19, x0, 3
    sub     x19, x19, x18   # 減去大盤子的位址
    sub     x19, x19, x6    # 再減去小盤子的位址, 就可以得到下一步要移動到哪個柱子

#如果大盤子在 peg 0: x19 = 3 - 0 = 3
#如果大盤子在 peg 1: x19 = 3 - 1 = 2
#如果大盤子在 peg 2: x19 = 3 - 2 = 1

display_move:
    la      x20, obdata     # 將obdata資料區段的位址載入x20
    add     x5, x20, x18    # 計算來源peg的位址
    # 也就表示x5指向obdata陣列中第x18個項目

    # BLANK 23: Load byte from obfuscated data
    lbu     x13, 0(x5)  # 讀取 1 byte

    # BLANK 24: Decode constant (0x6F)
    li      x6, 0x6F        # 載入解碼常數 0x6F
    xor     x13, x13, x6    # 解碼過程。原始obdata被混淆過，需要還原成實際的ascii字母

    # BLANK 25: Final offset adjustment
    addi    x13, x13, -0x12

    add     x7, x20, x19
    lbu     x14, 0(x7)
    xor     x14, x14, x6
    addi    x14, x14, -0x12

    # la      x10, str1
    # addi    x17, x0, 4
    # ecall
    addi a7, x0, 64     # syscall number for write
    addi a0, x0, 1      # stdout
    la a1, str1         # address of string
    li a2, 10           # length of string
    ecall

    # addi    x10, x9, 1  # 印出碟子編號(x9 + 1 , 因為編號是在0-based), x9 is either 0, 1, or 2.
    # addi    x17, x0, 1  # 設為1代表
    # ecall

    addi a7, x9, 1
    la a1, disks
    add a1, a1, a7
    add a7, x0, 0x40
    add a0, x0, 0x1
    li a2, 1
    ecall

    # la      x10, str2
    # addi    x17, x0, 4
    # ecall
    addi a7, x0, 64     # syscall number for write
    addi a0, x0, 1      # stdout
    la a1, str2         # address of string
    li a2, 6           # length of string
    ecall
    
    # addi    x10, x11, 0     # 印出來源peg字母(A or B or C)
    # addi    x17, x0, 11
    # ecall

    add a7, x0, 0x40
    add a0, x0, 0x1
    la a1, pegs
    addi x13, x13, -65
    add a1, a1, x13
    li a2, 1
    ecall
    
    # la      x10, str3
    # addi    x17, x0, 4
    # ecall

    addi a7, x0, 64
    addi a0, x0, 1
    la a1, str3
    li a2, 4
    ecall

    # addi    x10, x12, 0
    # addi    x17, x0, 11
    # ecall

    addi a7, x0, 64
    addi a0, x0, 1
    la a1, pegs
    addi x14, x14, -65
    add a1, a1, x14
    li a2, 1
    ecall

    # addi    x10, x0, 10
    # addi    x17, x0, 11
    # ecall
    addi a7, x0, 64
    addi a0, x0, 1
    la a1, newline
    li a2, 1
    ecall

    # BLANK 26: Calculate storage offset
    slli    x5, x9, 2
    addi    x5, x5, 20
    add     x5, x2, x5

    # BLANK 27: Update disk position
    sw      x19, 0(x5)

    # BLANK 28-29: Increment counter and loop
    addi    x8, x8, 1
    jal     x0, game_loop

finish_game:
    lw      x8, 0(x2)
    lw      x9, 4(x2)
    lw      x18, 8(x2)
    lw      x19, 12(x2)
    lw      x20, 16(x2)
    addi    x2, x2, 32
    
    # addi    x17, x0, 10
    # ecall

    li a0, 0
    jr ra

    .data
obdata:     .byte   0x3c, 0x3b, 0x3a
pegs:       .byte   65, 66, 67
disks:      .byte   48, 49, 50, 51
str1:       .ascii  "Move Disk "
str2:       .ascii  " from "
str3:       .ascii  " to "
newline:    .ascii  "\n"