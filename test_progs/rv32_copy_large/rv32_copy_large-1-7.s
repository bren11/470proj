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
	li	x2, data
loop:
	sw	x3, -0x800(x2)
	sw	x3, 0(x2)
	addi	x2,	x2,	0x8 #
	slti	x5,	x6,	255 #
	addi	x6,	x6,	0x1 #
	addi	x3, x3, 0x0a
	bne	x5,	x0,	loop #
	wfi

