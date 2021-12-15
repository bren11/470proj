/*
	TEST PROGRAM #1: copy memory contents of 16 elements starting at
			 address 0x1000 over to starting address 0x1800. 
	

	long output[256];

	void
	main(void)
	{
	  long i;
	  *a = 0x1000;
          *b = 0x1800;
	 
	  for (i=0; i < 256; i++)
	    {
	      a[i] = i*10; 
	      b[i] = a[i]; 
	    }
	}
*/
	data = 0x1800
	li	x6, 0
	li	x3, 0
	li	x7, 0x0a
	li	x8, 0x14
	li	x9, 0x1e
	li	x2, data
loop:
	sw	x3, -0x800(x2)
	sw	x3, 0(x2)
	addi	x3,	x3,	0x28 #

	sw	x7, -0x7F8(x2)
	sw	x7, 0x8(x2)
	addi	x7,	x7,	0x28 #

	sw	x8, -0x7F0(x2)
	sw	x8, 0x10(x2)
	addi	x8,	x8,	0x28 #

	sw	x9, -0x7E8(x2)
	sw	x9, 0x18(x2)
	addi	x9,	x9,	0x28

	addi	x2,	x2,	0x20 #
	slti	x5,	x6,	252 #
	addi	x6,	x6,	0x4 #

	bne	x5,	x0,	loop #
	wfi

