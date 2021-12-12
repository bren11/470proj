/*
	TEST PROGRAM #4: compute first 16 multiples of 8 (embarrassingly parallel)


	long output[16];
	
	void
	main(void)
	{
	  long i;
	  for (i=0; i < 16; i++,a++,b++,c++)
	    output[i] = ((i + i) + (i + i)) + ((i + i) + (i + i));
	}
*/
	data = 0x1000
    li  x17, 48
	li	x3, 100000
    li	x12, 101000
    li	x13, 102000
	li	x14, 3000
	li	x4, data
loop:	add	x6,	x3,	x3 #
	add	x9,	x3,	x3 #
	add	x8,	x3,	x3 #
	mulhsu x5,	x3,	x3 #
	mul x7,	x5,	x6 #
	mulh x10,	x8,	x9 #
	mulhu x11,	x7,	x10 #
	sw	x11, 0(x4)
    add	x3,	x3,	x14

    add	x6,	x12,	x12 #
	add	x9,	x12,	x12 #
	add	x8,	x12,	x12 #
	mulhsu x5,	x12,	x12 #
	mul x7,	x5,	x6 #
	mulh x10,	x8,	x9 #
	mulhu x11,	x7,	x10 #
	sw	x11, 8(x4)
    add    x12,	x12,	x14

    add	x6,	x13,	x13 #
	add	x9,	x13,	x13 #
	add	x8,	x13,	x13 #
	mulhsu x5,	x13,	x13 #
	mul x7,	x5,	x6 #
	mulh x10,	x8,	x9 #
	mulhu x11,	x7,	x10 #
	sw	x11, 16(x4)
	addi	x4,	x4,	0x18 #
	addi	x17,	x17,	-3 #
    add    x13,    x13,	x14
	bne	x17,	x0,	loop #
	wfi

