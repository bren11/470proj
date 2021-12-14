	.file	"min_distance.c"
	.option nopic
	.option norelax
	.attribute arch, "rv32i2p0_m2p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.align	2
	.globl	min
	.type	min, @function
min:
	ble	a0,a2,.L2
	mv	a0,a2
.L2:
	ble	a0,a1,.L3
	mv	a0,a1
.L3:
	ret
	.size	min, .-min
	.align	2
	.globl	strlen
	.type	strlen, @function
strlen:
	lbu	a5,0(a0)
	mv	a4,a0
	li	a0,0
	beq	a5,zero,.L8
.L7:
	addi	a0,a0,1
	add	a5,a4,a0
	lbu	a5,0(a5)
	bne	a5,zero,.L7
	ret
.L8:
	ret
	.size	strlen, .-strlen
	.align	2
	.globl	minDistance
	.type	minDistance, @function
minDistance:
	addi	sp,sp,-16
	sw	s0,12(sp)
	sw	s1,8(sp)
	sw	s2,4(sp)
	addi	s0,sp,16
	lbu	a5,0(a0)
	mv	t3,a0
	beq	a5,zero,.L25
	li	t1,0
.L12:
	mv	a4,t1
	addi	t1,t1,1
	add	a5,t3,t1
	lbu	a5,0(a5)
	bne	a5,zero,.L12
	lbu	a3,0(a1)
	addi	a4,a4,2
	slli	a5,a4,2
	beq	a3,zero,.L26
.L42:
	li	t4,0
.L14:
	mv	a3,t4
	addi	t4,t4,1
	add	a6,a1,t4
	lbu	a5,0(a6)
	bne	a5,zero,.L14
	addi	a3,a3,2
	mul	a4,a4,a3
	slli	a3,a3,2
	srli	t0,a3,2
	slli	a5,a4,2
.L13:
	addi	a5,a5,15
	andi	a5,a5,-16
	sub	sp,sp,a5
	mv	t6,sp
	addi	a3,t1,1
	li	a4,0
.L15:
	mul	a5,a4,t0
	slli	a5,a5,2
	add	a5,t6,a5
	sw	a4,0(a5)
	addi	a4,a4,1
	bne	a4,a3,.L15
	mv	t5,t6
	addi	a3,t4,1
	mv	a4,t6
	li	a5,0
.L16:
	sw	a5,0(a4)
	addi	a5,a5,1
	addi	a4,a4,4
	bne	a5,a3,.L16
	beq	t1,zero,.L17
	beq	t4,zero,.L17
	slli	t2,t0,2
	add	s2,t3,t1
	add	a6,a1,t4
	addi	s1,t2,4
.L19:
	lbu	a7,0(t3)
	mv	a4,a1
	add	a2,s1,t5
	mv	a3,t5
	j	.L24
.L41:
	lw	a5,4(a3)
	ble	a5,a0,.L21
	mv	a5,a0
.L21:
	lw	a0,-4(a2)
	ble	a5,a0,.L22
	mv	a5,a0
.L22:
	addi	a5,a5,1
	sw	a5,0(a2)
	addi	a4,a4,1
	addi	a3,a3,4
	addi	a2,a2,4
	beq	a6,a4,.L40
.L24:
	lbu	a5,0(a4)
	lw	a0,0(a3)
	bne	a5,a7,.L41
	sw	a0,0(a2)
	addi	a4,a4,1
	addi	a3,a3,4
	addi	a2,a2,4
	bne	a6,a4,.L24
.L40:
	addi	t3,t3,1
	add	t5,t5,t2
	bne	t3,s2,.L19
.L17:
	mul	a5,t1,t0
	add	a5,a5,t4
	slli	a5,a5,2
	add	a5,t6,a5
	lw	a0,0(a5)
	addi	sp,s0,-16
	lw	s0,12(sp)
	lw	s1,8(sp)
	lw	s2,4(sp)
	addi	sp,sp,16
	jr	ra
.L25:
	lbu	a3,0(a1)
	li	a5,4
	li	a4,1
	li	t1,0
	bne	a3,zero,.L42
.L26:
	li	t0,1
	li	t4,0
	j	.L13
	.size	minDistance, .-minDistance
	.section	.text.startup,"ax",@progbits
	.align	2
	.globl	main
	.type	main, @function
main:
	li	a0,0
	ret
	.size	main, .-main
	.ident	"GCC: (GNU) 9.2.0"
