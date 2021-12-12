/*
   GROUP 17
	TEST PROGRAM: insertion sort

	long a[] = { 3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3 };

  int i,j,temp;
  for(i=1;i<16;++i) {
    temp = a[i];
    j = i;
    while(1) {
      if(a[j-1] > temp)
        a[j] = a[j-1];
      else
        break; 
      --j;
      if(j == 0) 
        break;      
    }
    a[j] = temp;
  }  
  
  modified from sort.s
*/

 j	start
 nop 
  .dword 3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3 
  .align 4
start:	
	li	x6, 1
  
	li	x10, 16

	li	x31, 1

iloop:
	lw	x4,  0(x10) 
	mv	x7,	x6 #j = i
	mv	x20,	x10 #index j
	addi	x19,	x20,	-8 #index j-1

jloop:
#unroll-1
	lw	x15,  0(x19) 
	lw	x16,  0(x20) 

	blt	x15,	x4,	ifinish # branch if x15 lt x4
  
	sw	x15,  0(x20) 
  
#unroll-2
	lw	x15,  -8(x19) 
	lw	x16,  -8(x20) 

	blt	x15,	x4,	ifinish # branch if x15 lt x4
  
	sw	x15,  -8(x20) 
  
	addi	x19,	x19,	-16 #index to a[j-1]
	addi	x20,	x20,	-16 #index to a[j]
  
	addi	x7,	x7,	-2 #j-=2
	bge	x31,	x7,	jfinish #

	j jloop

jfinish: #post-loop
	beq	x7,	x0,	ifinish #

	lw	x15,  0(x19) 
	lw	x16,  0(x20) 

	sltu	x12,	x15,	x4 #
	bne	x12,	x0,	jfinish #
  
	sw	x15,  0(x20) 
  
	addi	x19,	x19,	-8 #index to a[j-1]
	addi	x20,	x20,	-8 #index to a[j]
  
	addi	x7,	x7,	-1 #j--

ifinish:
	sw	x4,  0(x20) 
	addi	x10,	x10,	8 #
	addi	x6,	x6,	1 #increment and check i loop
  
	sltu	x11,	x6,	16 #
	bne	x11,	x0,	iloop #

	wfi

  
