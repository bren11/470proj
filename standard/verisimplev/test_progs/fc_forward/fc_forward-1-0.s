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
	addi	a6,a6,1
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
	.section	.text.startup,"ax",@progbits
	.align	2
	.globl	main
	.type	main, @function
main:
	li	a0,0
	ret
	.size	main, .-main
	.globl	n
	.section	.sdata,"aw"
	.align	2
	.type	n, @object
	.size	n, 4
n:
	.word	12
	.ident	"GCC: (GNU) 9.2.0"
