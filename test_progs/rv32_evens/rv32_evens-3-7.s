/*
	TEST PROGRAM #2: compute even numbers that are less than 16


	long output[16];
	
	void
	main(void)
	{
	  long i,j;
	
	  for (i=0,j=0; i < 16; i++)
	    {
	      if ((i & 1) == 0)
	        output[j++] = i;
	    }
	}
*/
	data = 0x1000
	li	x3, 0
	li	x5, 1
	li	x6,	2
	li	x4, data
loop1:
	andi x31, x3, 1	
	bne	x31,	x0,	loop2 #
	sw	x3, 0(x4)
	addi	x4,	x4,	0x8 #
loop2:
	addi	x3,	x3,	0x3 #

	andi x31, x5, 1	
	bne	x31,	x0,	loop3 #
	sw	x5, 0(x4)
	addi	x4,	x4,	0x8 #
loop3:
	addi	x5,	x5,	0x3 #

	andi x31, x6, 1	
	bne	x31,	x0,	loop4 #
	sw	x6, 0(x4)
	addi	x4,	x4,	0x8 #
loop4:
	slti	x2,	x6,	14 #
	addi	x6,	x6,	0x3 #

	bne	x2,	x0,	loop1 #

	andi x31, x3, 1	
	bne	x31,	x0,	loop5 #
	sw	x3, 0(x4)
loop5:
	wfi

