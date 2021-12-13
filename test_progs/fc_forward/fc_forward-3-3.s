	.file	"fc_forward.c"
	.option nopic
	.option norelax
	.attribute arch, "rv32i2p0_m2p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.align	4
	.globl	kernel
	.type	kernel, @function
crt:
	nop
	la ra, exit
	la sp, _sp
	mv s0, sp
	la gp, __global_pointer$
	li tp, 0
	li t0, 0
	li t1, 0
	li t2, 0
	li s1, 0
	li a0, 0
	li a1, 0
	li a2, 0
	li a3, 0
	li a4, 0
	li a5, 0
	li a6, 0
	li a7, 0
	li s2, 0
	li s3, 0
	li s4, 0
	li s5, 0
	li s6, 0
	li s7, 0
	li s8, 0
	li s9, 0
	li s10, 0
	li s11, 0
	li t3, 0
	li t4, 0
	li t5, 0
	li t6, 0
	j main

.global exit
.section .text
.align 4
exit:
	la sp, _sp
	sw a0, -8(sp)
	nop
	wfi
kernel:
	lui	t3,%hi(n)
	lw	a5,%lo(n)(t3)
	ble	a5,zero,.L2
	li	a7,0
	li	a6,0
.L3:
	lw	t1,0(a1)
	lw	a5,0(a0)
	addi	a2,a2,4
	mul	a5,a5,t1
	addi	a0,a0,4
	addi	a1,a1,4
	sw	a5,-4(a2)
	add	a7,a7,a5

    lw	t1,0(a1)
	lw	a5,0(a0)
	addi	a2,a2,4
	mul	a5,a5,t1
	addi	a0,a0,4
	addi	a1,a1,4
	sw	a5,-4(a2)
	add	a7,a7,a5

    lw	t1,0(a1)
	lw	a5,0(a0)
	addi	a2,a2,4
	addi	a6,a6,3
	mul	a5,a5,t1
	addi	a0,a0,4
	addi	a1,a1,4
	sw	a5,-4(a2)
	lw	t1,%lo(n)(t3)
	add	a7,a7,a5
	bgt	t1,a6,.L3
	add	a3,a3,a7
.L2:
	sw	a3,0(a4)
	ret
	.size	kernel, .-kernel
	.align	2
	.globl	myRand
	.type	myRand, @function
myRand:
	lui	a3,%hi(seed)
	lw	a5,%lo(seed)(a3)
	li	a4,16384
	addi	a4,a4,423
	mul	a5,a5,a4
	li	a4,-2147483648
	xori	a4,a4,-1
	rem	a5,a5,a4
	sw	a5,%lo(seed)(a3)
	ret
	.size	myRand, .-myRand
	.align	2
	.globl	main
	.type	main, @function
main:
	addi	sp,sp,-48
	sw	ra,44(sp)
	sw	s0,40(sp)
	sw	s1,36(sp)
	sw	s2,32(sp)
	sw	s3,28(sp)
	sw	s4,24(sp)
	sw	s5,20(sp)
	sw	s6,16(sp)
	sw	s7,12(sp)
	sw	s8,8(sp)
	sw	s9,4(sp)
	addi	s0,sp,48
	lui	a5,%hi(n)
	lw	a4,%lo(n)(a5)
	slli	a5,a4,2
	addi	a5,a5,15
	andi	a5,a5,-16
	sub	sp,sp,a5
	mv	s7,sp
	sub	sp,sp,a5
	mv	s8,sp
	sub	sp,sp,a5
	mv	s9,sp
	ble	a4,zero,.L8
	mv	s4,s7
	mv	s3,s8
	mv	s2,s9
	li	s1,0
	li	s5,65536
	addi	s5,s5,-1
	lui	s6,%hi(n)
.L9:
	call	myRand
	and	a0,a0,s5
	sw	a0,0(s4)
	call	myRand
	and	a0,a0,s5
	sw	a0,0(s3)
	sw	zero,0(s2)
	addi	s1,s1,1
	addi	s4,s4,4
	addi	s3,s3,4
	addi	s2,s2,4
	lw	a5,%lo(n)(s6)
	bgt	a5,s1,.L9
.L8:
	call	myRand
	mv	a3,a0
	lui	s1,%hi(out)
	addi	a4,s1,%lo(out)
	mv	a2,s9
	mv	a1,s8
	mv	a0,s7
	call	kernel
	lw	a0,%lo(out)(s1)
	seqz	a0,a0
	addi	sp,s0,-48
	lw	ra,44(sp)
	lw	s0,40(sp)
	lw	s1,36(sp)
	lw	s2,32(sp)
	lw	s3,28(sp)
	lw	s4,24(sp)
	lw	s5,20(sp)
	lw	s6,16(sp)
	lw	s7,12(sp)
	lw	s8,8(sp)
	lw	s9,4(sp)
	addi	sp,sp,48
	jr	ra
	.size	main, .-main
	.comm	out,4,4
	.globl	seed
	.globl	n
	.section	.sdata,"aw"
	.align	2
	.type	seed, @object
	.size	seed, 4
seed:
	.word	119601316
	.type	n, @object
	.size	n, 4
n:
	.word	12
	.ident	"GCC: (GNU) 9.2.0"
