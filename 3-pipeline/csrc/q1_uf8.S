.section .text
clz:
    li   t0, 32                    # n = 32, c = 16
    srli t2, a0, 16                # y = x >> 16
    beqz t2, c_equal_8                # branch if y is equal to zero
    addi t0, t0, -16               # n -= 16
    add   a0, t2, x0                    # x = y
c_equal_8:
    srli t2, a0, 8                 # y = x >> 8
    beqz t2, c_equal_4
    addi t0, t0, -8                # n -= 8
    add   a0, t2, x0                    # x = y
c_equal_4:
    srli t2, a0, 4                 # y = x >> 4
    beqz t2, c_equal_2
    addi t0, t0, -4                # n -= 4
    add   a0, t2, x0                    # x = y
c_equal_2:
    srli t2, a0, 2                 # y = x >> 2
    beqz t2, c_equal_1
    addi t0, t0, -2                # n -= 2
    add   a0, t2, x0                    # x = y
c_equal_1:
    srli t2, a0, 1                 # y = x >> 1
    beqz t2, iter_end
    addi t0, t0, -1                # n -= 1
    add   a0, t2, x0                    # x = y
iter_end:    
    sub  a0, t0, a0                # return n - x
    jr ra    
offset_table:
    .word 0, 16, 48, 112, 240, 496, 1008, 2032, 4080, 8176, 16368, 32752, 65520, 131056, 262128, 524272

.globl uf8_decode
.type uf8_decode,%function
.align 2
uf8_decode:
    andi t0, a0, 0x0F              # mantissa = f1 & 0xF
    srli t1, a0, 4                 # exponent = f1 >> 4
    la t2, offset_table
    slli t3, t1, 2                 # offset << 4
    add t2, t2, t3
    lw t2, 0(t2)
    sll t0, t0, t1                 # mantissa << exponent
    add a0, t0, t2                 # mantissa + offset
    jr ra        
.size uf8_decode,.-uf8_decode

.globl uf8_encode
.type uf8_encode, %function
.align 2
uf8_encode:
    addi sp, sp, -4
    sw ra, 0(sp)                 # will call clz later
    add t5, a0, x0                    # t5 = value
    li t0, 16
    blt t5, t0, ret_value        # branch if value is less than 16
    jal ra, clz                  # call function clz, a0 = lz
    li t0, 31               
    sub t0, t0, a0               # msb = 31 - lz    
    li t1, 0                     # exponent = 0
    li t2, 0                     # overflow = 0
    li t3, 5
    blt t0, t3, find_exact_exp    # branch to find exact exponent if msb is less than 5
    addi t1, t0, -4               # exponent = msb - 4
    li t3, 15
    ble t1, t3, over               # branch to the nearest 1 function if exponent is less than or equal to 15
    li t1, 15                    # exponent = 15
over:
    li t3, 0                     # e (counter)
overflow_loop:
    slli t6, t2, 1             # overflow << 1
    addi t2, t6, 16            # (overflow << 1) + 16
    addi t3, t3, 1             # e++
    blt t3, t1, overflow_loop  # branch to the begining of the loop if e is still less than exponent
adjust_loop:
    blez t1, find_exact_exp        # branch if exponent is less than or equal to zero
    bge t5, t2, find_exact_exp    # branch if overflow is greater than or equal to value (unsigned)
    addi t6, t5, -16               # overflow - 16
    srli t5, t6, 1                 # (overflow - 16) >> 1
    addi t1, t1, -1                # exponent--
    j adjust_loop
find_exact_exp:
    li t6, 15
find_exact_exp_loop:
    bge t1, t6, exact_done             # branch if exponent is greater than or equal to 15
    slli t3, t2, 1                     # overflow << 1
    addi t3, t3, 16                    # next_overflow = (oveflow << 1) + 16
    blt t5, t3, exact_done            # branch if value is less than next_overflow
    add t2, t3, x0                          # overflow = next_overflow
    addi t1, t1, 1                     # exponent++
    j find_exact_exp_loop
exact_done:
    sub t0, t5, t2                     # value - overflow
    srl t0, t0, t1                     # (value - overflow) >> exponent
    slli t3, t1, 4                     # exponent << 4
    or a0, t3, t0                      # (expoment << 4) | mantissa
ret_value:
    lw ra, 0(sp)
    addi sp, sp, 4
    jr ra
.size uf8_encode,.-uf8_encode