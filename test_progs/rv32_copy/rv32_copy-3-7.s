/*
	TEST PROGRAM #1: copy memory contents of 16 elements starting at
			 address 0x1000 over to starting address 0x1100. 
	

	long output[16];

	void
	main(void)
	{
	  long i;
	  *a = 0x1000;
          *b = 0x1100;
	 
	  for (i=0; i < 16; i++)
	    {
	      a[i] = i*10; 
	      b[i] = a[i]; 
	    }
	}
*/
	data = 0x1000
	li	x6, 0
	li	x3, 0
	li	x7, 0x0a
	li	x8, 0x14
	li	x2, data
    li  x31, 0x0a
loop:
	sw	x3, 0(x2)
	sw	x3, 0x100(x2)
	addi	x3, x3, 0x1e

	sw	x7, 0x8(x2)
	sw	x7, 0x108(x2)
	addi	x7, x7, 0x1e

	sw	x8, 0x10(x2)
	sw	x8, 0x110(x2)
	addi	x8, x8, 0x1e

	addi	x2,	x2,	0x18 #
	slti	x5,	x6,	12 #
	addi	x6,	x6,	0x3 #

	bne	x5,	x0,	loop #

	sw	x3, 0(x2)
	lw	x4, 0(x2)
	sw	x4, 0x100(x2)

	wfi

