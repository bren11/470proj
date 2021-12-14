/*
   GROUP 17
	TEST PROGRAM: insertion sort

	long a[] = { 3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 10, 3 };

  int max, k, i;
  max = a[0]
  for(i=1;i<16;++i) {
    if (max <= a[i]) {
      max = a[i];
      k = i
    }
  }  
  mem[data]=max
  mem[data+8]=k
*/

 j	start
 nop 
  .dword 3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 10, 3 
  .align 4
start:
	data = 0x1000
	li	x6, 0
	li	x2, data
	li	x10, 8
	li	x3, 0
loop:
	lw	x5,  0(x10)
	bge x3, x5, skip1
	mv	x3, x5
skip1:

	lw	x5,  8(x10)
	bge x3, x5, skip2
	mv	x3, x5
skip2:

	lw	x5,  16(x10)
	bge x3, x5, skip3
	mv	x3, x5
skip3:
	addi	x10,	x10,	24
	slti	x11,	x6,	12 #
	addi	x6,		x6,	3

	bne	x11,	x0,	loop #

	lw	x5,  0(x10)
	bge x3, x5, skip4
	mv	x3, x5
skip4:

	sw	x3,	0(x2)

	wfi
