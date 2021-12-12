    li  x1, 0x01
    li  x4, 0x01
    li  x2, 0x00
    li  x3, 0x10
loop:   add x1, x1, x1
    add x1, x1, x1
    add x4, x4, x4
    add x1, x1, x1
    add x4, x4, x4
    add x1, x1, x1
    addi    x2, x2, 0x01 
    bne x2, x3, loop
    wfi
