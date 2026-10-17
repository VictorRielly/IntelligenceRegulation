	.file	"isolated.f4c85602b064d7c4-cgu.0"
	.section	.text._RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_,"ax",@progbits
	.p2align	4
	.type	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_,@function
_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_:
	.cfi_startproc
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%r13
	.cfi_def_cfa_offset 32
	pushq	%r12
	.cfi_def_cfa_offset 40
	pushq	%rbx
	.cfi_def_cfa_offset 48
	.cfi_offset %rbx, -48
	.cfi_offset %r12, -40
	.cfi_offset %r13, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rdi, %r14
	movq	8(%rdi), %rbx
	movq	16(%rdi), %r15
	testq	%r15, %r15
	je	.LBB0_5
	leaq	8(%rbx), %r12
	movq	_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip), %r13
	jmp	.LBB0_2
	.p2align	4
.LBB0_4:
	addq	$40, %r12
	decq	%r15
	je	.LBB0_5
.LBB0_2:
	movq	-8(%r12), %rsi
	testq	%rsi, %rsi
	je	.LBB0_4
	movq	(%r12), %rdi
	shlq	$4, %rsi
	movl	$8, %edx
	callq	*%r13
	jmp	.LBB0_4
.LBB0_5:
	movq	(%r14), %rax
	testq	%rax, %rax
	je	.LBB0_6
	shlq	$3, %rax
	leaq	(%rax,%rax,4), %rsi
	movl	$8, %edx
	movq	%rbx, %rdi
	popq	%rbx
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	jmpq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB0_6:
	.cfi_def_cfa_offset 48
	popq	%rbx
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end0:
	.size	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_, .Lfunc_end0-_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_
	.cfi_endproc

	.section	.text._RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_,"ax",@progbits
	.p2align	4
	.type	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_,@function
_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_:
	.cfi_startproc
	testq	%rdi, %rdi
	je	.LBB1_1
	shlq	$4, %rdi
	movl	$8, %edx
	movq	%rdi, %rax
	movq	%rsi, %rdi
	movq	%rax, %rsi
	jmpq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB1_1:
	retq
.Lfunc_end1:
	.size	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_, .Lfunc_end1-_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_
	.cfi_endproc

	.section	.text._RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc5boxed3BoxDG_INtNtNtB4_3ops8function2FnTRL0_SNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEp6OutputB1J_EL_EEB1N_,"ax",@progbits
	.p2align	4
	.type	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc5boxed3BoxDG_INtNtNtB4_3ops8function2FnTRL0_SNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEp6OutputB1J_EL_EEB1N_,@function
_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc5boxed3BoxDG_INtNtNtB4_3ops8function2FnTRL0_SNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEp6OutputB1J_EL_EEB1N_:
.Lfunc_begin0:
	.cfi_startproc
	.cfi_personality 155, DW.ref.rust_eh_personality
	.cfi_lsda 27, .Lexception0
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset %rbx, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rsi, %r14
	movq	%rdi, %rbx
	movq	(%rsi), %rax
	testq	%rax, %rax
	je	.LBB2_2
.Ltmp0:
	movq	%rbx, %rdi
	callq	*%rax
.Ltmp1:
.LBB2_2:
	movq	8(%r14), %rsi
	testq	%rsi, %rsi
	je	.LBB2_3
	movq	16(%r14), %rdx
	movq	%rbx, %rdi
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	jmpq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB2_3:
	.cfi_def_cfa_offset 32
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.LBB2_4:
	.cfi_def_cfa_offset 32
.Ltmp2:
	movq	%rax, %r15
	movq	8(%r14), %rsi
	testq	%rsi, %rsi
	je	.LBB2_6
	movq	16(%r14), %rdx
	movq	%rbx, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB2_6:
	movq	%r15, %rdi
	callq	_Unwind_Resume@PLT
.Lfunc_end2:
	.size	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc5boxed3BoxDG_INtNtNtB4_3ops8function2FnTRL0_SNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEp6OutputB1J_EL_EEB1N_, .Lfunc_end2-_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc5boxed3BoxDG_INtNtNtB4_3ops8function2FnTRL0_SNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEp6OutputB1J_EL_EEB1N_
	.cfi_endproc
	.section	.gcc_except_table._RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc5boxed3BoxDG_INtNtNtB4_3ops8function2FnTRL0_SNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEp6OutputB1J_EL_EEB1N_,"a",@progbits
	.p2align	2, 0x0
GCC_except_table2:
.Lexception0:
	.byte	255
	.byte	255
	.byte	1
	.uleb128 .Lcst_end0-.Lcst_begin0
.Lcst_begin0:
	.uleb128 .Ltmp0-.Lfunc_begin0
	.uleb128 .Ltmp1-.Ltmp0
	.uleb128 .Ltmp2-.Lfunc_begin0
	.byte	0
	.uleb128 .Ltmp1-.Lfunc_begin0
	.uleb128 .Lfunc_end2-.Ltmp1
	.byte	0
	.byte	0
.Lcst_end0:
	.p2align	2, 0x0

	.section	.text._RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_,"ax",@progbits
	.p2align	4
	.type	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_,@function
_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_:
	.cfi_startproc
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%r13
	.cfi_def_cfa_offset 32
	pushq	%r12
	.cfi_def_cfa_offset 40
	pushq	%rbx
	.cfi_def_cfa_offset 48
	.cfi_offset %rbx, -48
	.cfi_offset %r12, -40
	.cfi_offset %r13, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rdi, %rbx
	movq	16(%rdi), %rsi
	testq	%rsi, %rsi
	je	.LBB3_2
	movq	24(%rbx), %rdi
	shlq	$3, %rsi
	movl	$8, %edx
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB3_2:
	movq	48(%rbx), %r14
	movq	56(%rbx), %r15
	testq	%r15, %r15
	je	.LBB3_7
	leaq	8(%r14), %r12
	movq	_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip), %r13
	jmp	.LBB3_4
	.p2align	4
.LBB3_6:
	addq	$40, %r12
	decq	%r15
	je	.LBB3_7
.LBB3_4:
	movq	-8(%r12), %rsi
	testq	%rsi, %rsi
	je	.LBB3_6
	movq	(%r12), %rdi
	shlq	$4, %rsi
	movl	$8, %edx
	callq	*%r13
	jmp	.LBB3_6
.LBB3_7:
	movq	40(%rbx), %rax
	testq	%rax, %rax
	je	.LBB3_9
	shlq	$3, %rax
	leaq	(%rax,%rax,4), %rsi
	movl	$8, %edx
	movq	%r14, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB3_9:
	movq	64(%rbx), %rsi
	testq	%rsi, %rsi
	je	.LBB3_11
	movq	72(%rbx), %rdi
	shlq	$4, %rsi
	movl	$8, %edx
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB3_11:
	movq	96(%rbx), %r14
	movq	104(%rbx), %r15
	testq	%r15, %r15
	je	.LBB3_16
	leaq	16(%r14), %r12
	movq	_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip), %r13
	jmp	.LBB3_13
	.p2align	4
.LBB3_15:
	addq	$32, %r12
	decq	%r15
	je	.LBB3_16
.LBB3_13:
	movq	-8(%r12), %rax
	testq	%rax, %rax
	je	.LBB3_15
	movq	(%r12), %rdi
	shlq	$3, %rax
	leaq	(%rax,%rax,2), %rsi
	movl	$8, %edx
	callq	*%r13
	jmp	.LBB3_15
.LBB3_16:
	movq	88(%rbx), %rsi
	testq	%rsi, %rsi
	je	.LBB3_18
	shlq	$5, %rsi
	movl	$8, %edx
	movq	%r14, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB3_18:
	movq	128(%rbx), %rsi
	testq	%rsi, %rsi
	je	.LBB3_19
	movq	136(%rbx), %rdi
	shlq	$4, %rsi
	movl	$8, %edx
	popq	%rbx
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	jmpq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB3_19:
	.cfi_def_cfa_offset 48
	popq	%rbx
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end3:
	.size	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_, .Lfunc_end3-_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_
	.cfi_endproc

	.section	.text._RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_,"ax",@progbits
	.p2align	4
	.type	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_,@function
_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_:
	.cfi_startproc
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%r13
	.cfi_def_cfa_offset 32
	pushq	%r12
	.cfi_def_cfa_offset 40
	pushq	%rbx
	.cfi_def_cfa_offset 48
	.cfi_offset %rbx, -48
	.cfi_offset %r12, -40
	.cfi_offset %r13, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rdi, %rbx
	movq	16(%rdi), %rsi
	testq	%rsi, %rsi
	je	.LBB4_2
	movq	24(%rbx), %rdi
	shlq	$3, %rsi
	movl	$8, %edx
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB4_2:
	movq	48(%rbx), %r14
	movq	56(%rbx), %r15
	testq	%r15, %r15
	je	.LBB4_7
	leaq	8(%r14), %r12
	movq	_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip), %r13
	jmp	.LBB4_4
	.p2align	4
.LBB4_6:
	addq	$40, %r12
	decq	%r15
	je	.LBB4_7
.LBB4_4:
	movq	-8(%r12), %rsi
	testq	%rsi, %rsi
	je	.LBB4_6
	movq	(%r12), %rdi
	shlq	$4, %rsi
	movl	$8, %edx
	callq	*%r13
	jmp	.LBB4_6
.LBB4_7:
	movq	40(%rbx), %rax
	testq	%rax, %rax
	je	.LBB4_9
	shlq	$3, %rax
	leaq	(%rax,%rax,4), %rsi
	movl	$8, %edx
	movq	%r14, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB4_9:
	movq	64(%rbx), %rsi
	testq	%rsi, %rsi
	je	.LBB4_11
	movq	72(%rbx), %rdi
	shlq	$4, %rsi
	movl	$8, %edx
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB4_11:
	movq	96(%rbx), %r14
	movq	104(%rbx), %r15
	testq	%r15, %r15
	je	.LBB4_16
	leaq	16(%r14), %r12
	movq	_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip), %r13
	jmp	.LBB4_13
	.p2align	4
.LBB4_15:
	addq	$32, %r12
	decq	%r15
	je	.LBB4_16
.LBB4_13:
	movq	-8(%r12), %rax
	testq	%rax, %rax
	je	.LBB4_15
	movq	(%r12), %rdi
	shlq	$3, %rax
	leaq	(%rax,%rax,2), %rsi
	movl	$8, %edx
	callq	*%r13
	jmp	.LBB4_15
.LBB4_16:
	movq	88(%rbx), %rsi
	testq	%rsi, %rsi
	je	.LBB4_18
	shlq	$5, %rsi
	movl	$8, %edx
	movq	%r14, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB4_18:
	movq	128(%rbx), %rsi
	testq	%rsi, %rsi
	je	.LBB4_19
	movq	136(%rbx), %rdi
	shlq	$4, %rsi
	movl	$8, %edx
	popq	%rbx
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	jmpq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB4_19:
	.cfi_def_cfa_offset 48
	popq	%rbx
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end4:
	.size	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_, .Lfunc_end4-_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_
	.cfi_endproc

	.section	.text._RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_,"ax",@progbits
	.p2align	4
	.type	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_,@function
_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_:
	.cfi_startproc
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%r13
	.cfi_def_cfa_offset 32
	pushq	%r12
	.cfi_def_cfa_offset 40
	pushq	%rbx
	.cfi_def_cfa_offset 48
	.cfi_offset %rbx, -48
	.cfi_offset %r12, -40
	.cfi_offset %r13, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rdi, %r14
	movq	8(%rdi), %rbx
	movq	16(%rdi), %r15
	testq	%r15, %r15
	je	.LBB5_5
	leaq	16(%rbx), %r12
	movq	_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip), %r13
	jmp	.LBB5_2
	.p2align	4
.LBB5_4:
	addq	$32, %r12
	decq	%r15
	je	.LBB5_5
.LBB5_2:
	movq	-8(%r12), %rax
	testq	%rax, %rax
	je	.LBB5_4
	movq	(%r12), %rdi
	shlq	$3, %rax
	leaq	(%rax,%rax,2), %rsi
	movl	$8, %edx
	callq	*%r13
	jmp	.LBB5_4
.LBB5_5:
	movq	(%r14), %rsi
	testq	%rsi, %rsi
	je	.LBB5_6
	shlq	$5, %rsi
	movl	$8, %edx
	movq	%rbx, %rdi
	popq	%rbx
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	jmpq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB5_6:
	.cfi_def_cfa_offset 48
	popq	%rbx
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end5:
	.size	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_, .Lfunc_end5-_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_
	.cfi_endproc

	.section	.text._RNCNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0s_0B5_,"ax",@progbits
	.p2align	4
	.type	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0s_0B5_,@function
_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0s_0B5_:
	.cfi_startproc
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset %rbx, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rdi, %rcx
	movq	16(%rdi), %rdi
	movq	16(%rdi), %rax
	cmpq	%rax, %rdx
	jae	.LBB6_5
	movq	8(%rdi), %r10
	movq	(%r10,%rdx,8), %rdi
	movq	8(%rcx), %r8
	cmpq	%r8, %rdi
	jae	.LBB6_6
	leaq	1(%rdx), %r9
	cmpq	%rax, %r9
	jae	.LBB6_7
	movq	8(%r10,%rdx,8), %rax
	cmpq	%r8, %rax
	jae	.LBB6_4
	movq	(%rcx), %rbx
	shlq	$4, %rdi
	shlq	$4, %rax
	movq	(%rbx,%rax), %r10
	movq	8(%rbx,%rax), %r15
	movq	(%rsi), %r8
	movq	%r8, %rax
	mulq	%r10
	movq	%rax, %r11
	movq	%rdx, %rax
	shrq	$32, %rax
	movl	%edx, %ecx
	subq	%rax, %r11
	movabsq	$-4294967296, %r14
	leaq	1(%r11,%r14), %rax
	cmovbq	%rax, %r11
	shlq	$32, %rdx
	subq	%rcx, %rdx
	addq	%rdx, %r11
	movl	$4294967295, %ecx
	leaq	(%r11,%rcx), %rax
	cmovbq	%rax, %r11
	leaq	(%r11,%rcx), %rax
	cmpq	%r14, %r11
	cmovaq	%rax, %r11
	movq	8(%rsi), %rsi
	movq	%rsi, %rax
	mulq	%r15
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r14), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rdx, %r9
	leaq	(%r9,%rcx), %rax
	cmovbq	%rax, %r9
	leaq	(%r9,%rcx), %rax
	cmpq	%r14, %r9
	cmovaq	%rax, %r9
	movq	%rsi, %rax
	mulq	%r10
	movq	%rdx, %r10
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r14), %rdx
	cmovaeq	%rax, %rdx
	movl	%r10d, %eax
	shlq	$32, %r10
	subq	%rax, %r10
	addq	%rdx, %r10
	leaq	(%r10,%rcx), %rax
	cmovbq	%rax, %r10
	leaq	(%r10,%rcx), %rax
	cmpq	%r14, %r10
	cmovaq	%rax, %r10
	movq	%r8, %rax
	mulq	%r15
	movq	%rdx, %rsi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r14), %rdx
	cmovaeq	%rax, %rdx
	movl	%esi, %eax
	shlq	$32, %rsi
	subq	%rax, %rsi
	addq	%rdx, %rsi
	leaq	(%rsi,%rcx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rcx), %rax
	cmpq	%r14, %rsi
	cmovaq	%rax, %rsi
	movl	$7, %edx
	movq	%r9, %rax
	mulq	%rdx
	movq	%rdx, %r8
	shlq	$32, %r8
	subq	%rdx, %r8
	addq	%r8, %rax
	leaq	(%rax,%rcx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rcx), %rdx
	cmpq	%r14, %rax
	cmovaq	%rdx, %rax
	addq	%r11, %rax
	leaq	(%rax,%rcx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rcx), %rdx
	cmpq	%r14, %rax
	cmovaq	%rdx, %rax
	addq	%r10, %rsi
	leaq	(%rsi,%rcx), %rdx
	cmovaeq	%rsi, %rdx
	leaq	(%rdx,%rcx), %rsi
	cmpq	%r14, %rdx
	cmovbeq	%rdx, %rsi
	addq	(%rbx,%rdi), %rax
	leaq	(%rax,%rcx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rcx), %rdx
	cmpq	%r14, %rax
	cmovaq	%rdx, %rax
	addq	8(%rbx,%rdi), %rsi
	leaq	(%rsi,%rcx), %rdx
	cmovaeq	%rsi, %rdx
	addq	%rdx, %rcx
	cmpq	%r14, %rdx
	cmovbeq	%rdx, %rcx
	movq	%rcx, %rdx
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.LBB6_5:
	.cfi_def_cfa_offset 32
	leaq	.Lalloc_14e9b0f3c1e82842e326b949d03d992d(%rip), %rcx
	movq	%rdx, %rdi
	movq	%rax, %rsi
	movq	%rcx, %rdx
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB6_6:
	leaq	.Lalloc_eca36810f664faabadbd931684be3603(%rip), %rdx
	movq	%r8, %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB6_7:
	leaq	.Lalloc_14e9b0f3c1e82842e326b949d03d992d(%rip), %rdx
	movq	%r9, %rdi
	movq	%rax, %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB6_4:
	leaq	.Lalloc_eca36810f664faabadbd931684be3603(%rip), %rdx
	movq	%rax, %rdi
	movq	%r8, %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Lfunc_end6:
	.size	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0s_0B5_, .Lfunc_end6-_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0s_0B5_
	.cfi_endproc

	.section	.text._RNCNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0s_0B5_,"ax",@progbits
	.p2align	4
	.type	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0s_0B5_,@function
_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0s_0B5_:
	.cfi_startproc
	pushq	%rax
	.cfi_def_cfa_offset 16
	movq	%rdi, %rcx
	movq	16(%rdi), %rdi
	movq	16(%rdi), %rax
	cmpq	%rax, %rdx
	jae	.LBB7_5
	movq	8(%rdi), %r10
	movq	(%r10,%rdx,8), %rdi
	movq	8(%rcx), %r8
	cmpq	%r8, %rdi
	jae	.LBB7_6
	leaq	1(%rdx), %r9
	cmpq	%rax, %r9
	jae	.LBB7_7
	movq	8(%r10,%rdx,8), %r9
	cmpq	%r8, %r9
	jae	.LBB7_4
	movq	(%rcx), %r10
	shlq	$4, %r9
	movq	(%rsi), %r8
	movq	%r8, %rax
	mulq	(%r10,%r9)
	movq	%rax, %rcx
	shlq	$4, %rdi
	movq	%rdx, %rax
	shrq	$32, %rax
	movl	%edx, %r11d
	subq	%rax, %rcx
	movabsq	$-4294967296, %rsi
	leaq	1(%rcx,%rsi), %rax
	cmovbq	%rax, %rcx
	shlq	$32, %rdx
	subq	%r11, %rdx
	addq	%rdx, %rcx
	movl	$4294967295, %r11d
	leaq	(%rcx,%r11), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%r11), %rax
	cmpq	%rsi, %rcx
	cmovaq	%rax, %rcx
	movq	%r8, %rax
	mulq	8(%r10,%r9)
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%rsi), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%r8, %rdx
	leaq	(%rdx,%r11), %rax
	cmovbq	%rax, %rdx
	leaq	(%rdx,%r11), %rax
	cmpq	%rsi, %rdx
	cmovaq	%rax, %rdx
	addq	(%r10,%rdi), %rcx
	leaq	(%rcx,%r11), %r8
	cmovaeq	%rcx, %r8
	leaq	(%r8,%r11), %rax
	cmpq	%rsi, %r8
	cmovbeq	%r8, %rax
	addq	8(%r10,%rdi), %rdx
	leaq	(%rdx,%r11), %rcx
	cmovbq	%rcx, %rdx
	addq	%rdx, %r11
	cmpq	%rsi, %rdx
	cmovaq	%r11, %rdx
	popq	%rcx
	.cfi_def_cfa_offset 8
	retq
.LBB7_5:
	.cfi_def_cfa_offset 16
	leaq	.Lalloc_826b68913cf630c35a865efbea8045e3(%rip), %rcx
	movq	%rdx, %rdi
	movq	%rax, %rsi
	movq	%rcx, %rdx
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB7_6:
	leaq	.Lalloc_11ff538006900e8109ee309b459a2f83(%rip), %rdx
	movq	%r8, %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB7_7:
	leaq	.Lalloc_826b68913cf630c35a865efbea8045e3(%rip), %rdx
	movq	%r9, %rdi
	movq	%rax, %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB7_4:
	leaq	.Lalloc_11ff538006900e8109ee309b459a2f83(%rip), %rdx
	movq	%r9, %rdi
	movq	%r8, %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Lfunc_end7:
	.size	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0s_0B5_, .Lfunc_end7-_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0s_0B5_
	.cfi_endproc

	.section	.text._RNCNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0s_0B5_,"ax",@progbits
	.p2align	4
	.type	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0s_0B5_,@function
_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0s_0B5_:
	.cfi_startproc
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset %rbx, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rdi, %rcx
	movq	16(%rdi), %rdi
	movq	16(%rdi), %rax
	cmpq	%rax, %rdx
	jae	.LBB8_5
	movq	8(%rdi), %r10
	movq	(%r10,%rdx,8), %rdi
	movq	8(%rcx), %r8
	cmpq	%r8, %rdi
	jae	.LBB8_6
	leaq	1(%rdx), %r9
	cmpq	%rax, %r9
	jae	.LBB8_7
	movq	8(%r10,%rdx,8), %rax
	cmpq	%r8, %rax
	jae	.LBB8_4
	movq	(%rcx), %rbx
	shlq	$4, %rdi
	shlq	$4, %rax
	movq	(%rbx,%rax), %r10
	movq	8(%rbx,%rax), %r15
	movq	(%rsi), %r8
	movq	%r8, %rax
	mulq	%r10
	movq	%rax, %r11
	movq	%rdx, %rax
	shrq	$32, %rax
	movl	%edx, %ecx
	subq	%rax, %r11
	movabsq	$-4294967296, %r14
	leaq	1(%r11,%r14), %rax
	cmovbq	%rax, %r11
	shlq	$32, %rdx
	subq	%rcx, %rdx
	addq	%rdx, %r11
	movl	$4294967295, %ecx
	leaq	(%r11,%rcx), %rax
	cmovbq	%rax, %r11
	leaq	(%r11,%rcx), %rax
	cmpq	%r14, %r11
	cmovaq	%rax, %r11
	movq	8(%rsi), %rsi
	movq	%rsi, %rax
	mulq	%r15
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r14), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rdx, %r9
	leaq	(%r9,%rcx), %rax
	cmovbq	%rax, %r9
	leaq	(%r9,%rcx), %rax
	cmpq	%r14, %r9
	cmovaq	%rax, %r9
	movq	%rsi, %rax
	mulq	%r10
	movq	%rdx, %r10
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r14), %rdx
	cmovaeq	%rax, %rdx
	movl	%r10d, %eax
	shlq	$32, %r10
	subq	%rax, %r10
	addq	%rdx, %r10
	leaq	(%r10,%rcx), %rax
	cmovbq	%rax, %r10
	leaq	(%r10,%rcx), %rax
	cmpq	%r14, %r10
	cmovaq	%rax, %r10
	movq	%r8, %rax
	mulq	%r15
	movq	%rdx, %rsi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r14), %rdx
	cmovaeq	%rax, %rdx
	movl	%esi, %eax
	shlq	$32, %rsi
	subq	%rax, %rsi
	addq	%rdx, %rsi
	leaq	(%rsi,%rcx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rcx), %rax
	cmpq	%r14, %rsi
	cmovaq	%rax, %rsi
	movl	$7, %edx
	movq	%r9, %rax
	mulq	%rdx
	movq	%rdx, %r8
	shlq	$32, %r8
	subq	%rdx, %r8
	addq	%r8, %rax
	leaq	(%rax,%rcx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rcx), %rdx
	cmpq	%r14, %rax
	cmovaq	%rdx, %rax
	addq	%r11, %rax
	leaq	(%rax,%rcx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rcx), %rdx
	cmpq	%r14, %rax
	cmovaq	%rdx, %rax
	addq	%r10, %rsi
	leaq	(%rsi,%rcx), %rdx
	cmovaeq	%rsi, %rdx
	leaq	(%rdx,%rcx), %rsi
	cmpq	%r14, %rdx
	cmovbeq	%rdx, %rsi
	addq	(%rbx,%rdi), %rax
	leaq	(%rax,%rcx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rcx), %rdx
	cmpq	%r14, %rax
	cmovaq	%rdx, %rax
	addq	8(%rbx,%rdi), %rsi
	leaq	(%rsi,%rcx), %rdx
	cmovaeq	%rsi, %rdx
	addq	%rdx, %rcx
	cmpq	%r14, %rdx
	cmovbeq	%rdx, %rcx
	movq	%rcx, %rdx
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.LBB8_5:
	.cfi_def_cfa_offset 32
	leaq	.Lalloc_623270749f7c2c7eb7abf12a5ce81bec(%rip), %rcx
	movq	%rdx, %rdi
	movq	%rax, %rsi
	movq	%rcx, %rdx
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB8_6:
	leaq	.Lalloc_23cbb2e7863b02fb8b64518d13a27720(%rip), %rdx
	movq	%r8, %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB8_7:
	leaq	.Lalloc_623270749f7c2c7eb7abf12a5ce81bec(%rip), %rdx
	movq	%r9, %rdi
	movq	%rax, %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB8_4:
	leaq	.Lalloc_23cbb2e7863b02fb8b64518d13a27720(%rip), %rdx
	movq	%rax, %rdi
	movq	%r8, %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Lfunc_end8:
	.size	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0s_0B5_, .Lfunc_end8-_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0s_0B5_
	.cfi_endproc

	.section	.text._RNCNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0s_0B5_,"ax",@progbits
	.p2align	4
	.type	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0s_0B5_,@function
_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0s_0B5_:
	.cfi_startproc
	pushq	%rax
	.cfi_def_cfa_offset 16
	movq	%rdi, %rcx
	movq	16(%rdi), %rdi
	movq	16(%rdi), %rax
	cmpq	%rax, %rdx
	jae	.LBB9_5
	movq	8(%rdi), %r10
	movq	(%r10,%rdx,8), %rdi
	movq	8(%rcx), %r8
	cmpq	%r8, %rdi
	jae	.LBB9_6
	leaq	1(%rdx), %r9
	cmpq	%rax, %r9
	jae	.LBB9_7
	movq	8(%r10,%rdx,8), %r9
	cmpq	%r8, %r9
	jae	.LBB9_4
	movq	(%rcx), %r10
	shlq	$4, %r9
	movq	(%rsi), %r8
	movq	%r8, %rax
	mulq	(%r10,%r9)
	movq	%rax, %rcx
	shlq	$4, %rdi
	movq	%rdx, %rax
	shrq	$32, %rax
	movl	%edx, %r11d
	subq	%rax, %rcx
	movabsq	$-4294967296, %rsi
	leaq	1(%rcx,%rsi), %rax
	cmovbq	%rax, %rcx
	shlq	$32, %rdx
	subq	%r11, %rdx
	addq	%rdx, %rcx
	movl	$4294967295, %r11d
	leaq	(%rcx,%r11), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%r11), %rax
	cmpq	%rsi, %rcx
	cmovaq	%rax, %rcx
	movq	%r8, %rax
	mulq	8(%r10,%r9)
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%rsi), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%r8, %rdx
	leaq	(%rdx,%r11), %rax
	cmovbq	%rax, %rdx
	leaq	(%rdx,%r11), %rax
	cmpq	%rsi, %rdx
	cmovaq	%rax, %rdx
	addq	(%r10,%rdi), %rcx
	leaq	(%rcx,%r11), %r8
	cmovaeq	%rcx, %r8
	leaq	(%r8,%r11), %rax
	cmpq	%rsi, %r8
	cmovbeq	%r8, %rax
	addq	8(%r10,%rdi), %rdx
	leaq	(%rdx,%r11), %rcx
	cmovbq	%rcx, %rdx
	addq	%rdx, %r11
	cmpq	%rsi, %rdx
	cmovaq	%r11, %rdx
	popq	%rcx
	.cfi_def_cfa_offset 8
	retq
.LBB9_5:
	.cfi_def_cfa_offset 16
	leaq	.Lalloc_3473ff63602946e5bae196369fb1e157(%rip), %rcx
	movq	%rdx, %rdi
	movq	%rax, %rsi
	movq	%rcx, %rdx
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB9_6:
	leaq	.Lalloc_8bedb038257b840dda514362a0f0e6d8(%rip), %rdx
	movq	%r8, %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB9_7:
	leaq	.Lalloc_3473ff63602946e5bae196369fb1e157(%rip), %rdx
	movq	%r9, %rdi
	movq	%rax, %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB9_4:
	leaq	.Lalloc_8bedb038257b840dda514362a0f0e6d8(%rip), %rdx
	movq	%r9, %rdi
	movq	%r8, %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Lfunc_end9:
	.size	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0s_0B5_, .Lfunc_end9-_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0s_0B5_
	.cfi_endproc

	.section	.text._RNCNvCsl0YfJI2rrfI_8isolated10helper_sum0B3_,"ax",@progbits
	.p2align	4
	.type	_RNCNvCsl0YfJI2rrfI_8isolated10helper_sum0B3_,@function
_RNCNvCsl0YfJI2rrfI_8isolated10helper_sum0B3_:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	pushq	%rax
	.cfi_def_cfa_offset 64
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movabsq	$-4294967296, %r8
	movq	(%rdi), %rax
	movq	(%rax), %r10
	movq	8(%rax), %r9
	movq	16(%rsi), %r14
	movq	24(%rsi), %rbx
	movq	32(%rsi), %r11
	testq	%r14, %r14
	je	.LBB10_4
	movq	8(%rdi), %r15
	movq	8(%rsi), %r12
	movq	16(%rdi), %rsi
	movl	$4294967295, %r13d
	addq	$8, %r12
	.p2align	4
.LBB10_2:
	movq	-8(%r12), %rdi
	cmpq	%rsi, %rdi
	jae	.LBB10_5
	movq	(%r12), %rcx
	shlq	$4, %rdi
	movq	%rcx, %rax
	mulq	(%r15,%rdi)
	movl	%edx, %ebp
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r8), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r13, %rbp
	addq	%rdx, %rbp
	leaq	(%rbp,%r13), %rax
	cmovaeq	%rbp, %rax
	leaq	(%rax,%r13), %rbp
	cmpq	%r8, %rax
	cmovbeq	%rax, %rbp
	movq	%rcx, %rax
	mulq	8(%r15,%rdi)
	movl	%edx, %ecx
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r8), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r13, %rcx
	addq	%rdx, %rcx
	leaq	(%rcx,%r13), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%r13), %rcx
	cmpq	%r8, %rax
	cmovbeq	%rax, %rcx
	addq	%rbx, %rbp
	leaq	(%rbp,%r13), %rax
	cmovaeq	%rbp, %rax
	leaq	(%rax,%r13), %rbx
	cmpq	%r8, %rax
	cmovbeq	%rax, %rbx
	addq	%r11, %rcx
	leaq	(%rcx,%r13), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%r13), %r11
	cmpq	%r8, %rax
	cmovbeq	%rax, %r11
	addq	$16, %r12
	decq	%r14
	jne	.LBB10_2
.LBB10_4:
	subq	%rbx, %r10
	leaq	1(%r10,%r8), %rax
	cmovaeq	%r10, %rax
	subq	%r11, %r9
	leaq	1(%r9,%r8), %rdx
	cmovaeq	%r9, %rdx
	addq	$8, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%r12
	.cfi_def_cfa_offset 40
	popq	%r13
	.cfi_def_cfa_offset 32
	popq	%r14
	.cfi_def_cfa_offset 24
	popq	%r15
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	retq
.LBB10_5:
	.cfi_def_cfa_offset 64
	leaq	.Lalloc_239c1709703ec0aea80b5578885ba055(%rip), %rdx
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Lfunc_end10:
	.size	_RNCNvCsl0YfJI2rrfI_8isolated10helper_sum0B3_, .Lfunc_end10-_RNCNvCsl0YfJI2rrfI_8isolated10helper_sum0B3_
	.cfi_endproc

	.section	.text._RNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0B3_,"ax",@progbits
	.p2align	4
	.type	_RNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0B3_,@function
_RNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0B3_:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	subq	$312, %rsp
	.cfi_def_cfa_offset 368
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%rsi, %r12
	leaq	16(%rdi), %rax
	movq	%rsi, 192(%rsp)
	movq	%rdx, 200(%rsp)
	movq	%rax, 208(%rsp)
	movq	32(%rdi), %rsi
	cmpq	$68, %rsi
	jb	.LBB11_31
	movq	%rdi, %r11
	movq	24(%rdi), %rcx
	movq	536(%rcx), %rdi
	cmpq	%rdx, %rdi
	jae	.LBB11_32
	cmpq	$69, %rsi
	jbe	.LBB11_33
	movq	552(%rcx), %rax
	cmpq	%rdx, %rax
	jae	.LBB11_34
	cmpq	$70, %rsi
	je	.LBB11_35
	movq	560(%rcx), %r8
	cmpq	%rdx, %r8
	jae	.LBB11_36
	cmpq	$73, %rsi
	jbe	.LBB11_37
	movq	%rcx, 88(%rsp)
	movq	584(%rcx), %rcx
	cmpq	%rdx, %rcx
	movq	%rdx, 16(%rsp)
	jae	.LBB11_38
	shlq	$4, %rdi
	shlq	$4, %rax
	movq	(%r12,%rax), %r10
	movq	8(%r12,%rax), %r14
	shlq	$4, %r8
	movq	(%r12,%r8), %r15
	movabsq	$-4294967296, %r13
	movl	$4294967295, %ebx
	shlq	$4, %rcx
	movq	$0, 40(%rsp)
	movq	%r15, %rax
	movq	%r15, 120(%rsp)
	mulq	%r10
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%r13), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rsi, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r9
	cmpq	%r13, %rax
	cmovbeq	%rax, %r9
	movq	8(%r12,%r8), %r8
	movq	%r8, %rax
	movq	%r8, 112(%rsp)
	mulq	%r14
	movq	%rax, %rsi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rsi
	leaq	1(%rsi,%r13), %rax
	cmovbq	%rax, %rsi
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rdx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r13, %rsi
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	movq	%r10, 48(%rsp)
	mulq	%r10
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r13), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%r8, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%r13, %rax
	cmovbeq	%rax, %r8
	movq	%r15, %rax
	movq	%r14, 56(%rsp)
	mulq	%r14
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%r13), %r10
	cmovaeq	%rax, %r10
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%r10, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r10
	cmpq	%r13, %rax
	cmovbeq	%rax, %r10
	movl	$7, %r14d
	movq	%rsi, %rax
	mulq	%r14
	movq	%rdx, %rsi
	shlq	$32, %rsi
	subq	%rdx, %rsi
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovaeq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r13, %rax
	cmovbeq	%rax, %rdx
	addq	%r9, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r9
	cmpq	%r13, %rax
	cmovbeq	%rax, %r9
	movq	(%r12,%rcx), %r15
	addq	%r8, %r10
	leaq	(%r10,%rbx), %rax
	cmovaeq	%r10, %rax
	leaq	(%rax,%rbx), %r10
	cmpq	%r13, %rax
	cmovbeq	%rax, %r10
	movq	168(%r11), %rsi
	movq	%rsi, %rax
	mulq	%r15
	movq	%r15, 24(%rsp)
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r13), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%r8, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r13, %rax
	movq	%r11, 8(%rsp)
	leaq	(%rax,%rbx), %r11
	cmovbeq	%rax, %r11
	movq	8(%r12,%rcx), %rbp
	movq	8(%rsp), %rax
	movq	176(%rax), %r8
	movq	%r8, %rax
	mulq	%rbp
	movq	%rbp, 32(%rsp)
	movq	%rax, %rcx
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rcx
	leaq	1(%rcx,%r13), %rax
	cmovbq	%rax, %rcx
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rdx, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	cmpq	%r13, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaq	%rax, %rcx
	movq	%rsi, %rax
	mulq	%rbp
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%r13), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rsi, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r13, %rax
	leaq	(%rax,%rbx), %rsi
	cmovbeq	%rax, %rsi
	movq	%r8, %rax
	mulq	%r15
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r13), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%r8, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r13, %rax
	leaq	(%rax,%rbx), %r8
	cmovbeq	%rax, %r8
	movq	%rcx, %rax
	mulq	%r14
	movq	%rdx, %rcx
	shlq	$32, %rcx
	subq	%rdx, %rcx
	addq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	cmpq	%r13, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbeq	%rax, %rcx
	addq	%r11, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	cmpq	%r13, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbeq	%rax, %rcx
	addq	%rsi, %r8
	leaq	(%r8,%rbx), %rax
	cmovaeq	%r8, %rax
	cmpq	%r13, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	subq	%rcx, %r9
	leaq	1(%r9,%r13), %r14
	cmovaeq	%r9, %r14
	movq	8(%rsp), %rax
	leaq	152(%rax), %rbp
	subq	%rdx, %r10
	leaq	1(%r10,%r13), %r15
	cmovaeq	%r10, %r15
	movq	(%r12,%rdi), %rax
	movq	%rax, 104(%rsp)
	movq	8(%r12,%rdi), %rax
	movq	%rax, 96(%rsp)
	leaq	192(%rsp), %rdi
	movl	$76, %edx
	movq	%rbp, %rsi
	callq	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0s_0B5_
	subq	%rax, %r14
	leaq	1(%r14,%r13), %rax
	cmovaeq	%r14, %rax
	subq	%rdx, %r15
	leaq	1(%r15,%r13), %rcx
	cmovaeq	%r15, %rcx
	movq	8(%rsp), %rdx
	addq	184(%rdx), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmpq	%r13, %rdx
	cmovbeq	%rdx, %rax
	movq	%rax, 72(%rsp)
	movq	8(%rsp), %rax
	addq	192(%rax), %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r13, %rax
	cmovbeq	%rax, %rcx
	movq	%rcx, 80(%rsp)
	movq	%r12, 64(%rsp)
	leaq	32768(%rbx), %rdx
	movq	120(%rsp), %rcx
	cmpq	$-32768, %rcx
	movl	$32768, %eax
	cmovaeq	%rdx, %rax
	movl	$32768, %r14d
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %r12
	cmpq	%r13, %rax
	cmovbeq	%rax, %r12
	movq	112(%rsp), %rax
	leaq	(%rax,%rbx), %r15
	cmpq	%r13, %rax
	cmovbeq	%rax, %r15
	movl	$71, %edx
	leaq	192(%rsp), %rdi
	movq	%rbp, %rsi
	callq	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0s_0B5_
	subq	%rax, %r12
	leaq	1(%r12,%r13), %rax
	cmovaeq	%r12, %rax
	movq	%rax, 184(%rsp)
	subq	%rdx, %r15
	leaq	1(%r15,%r13), %rax
	cmovaeq	%r15, %rax
	movq	%rax, 176(%rsp)
	movq	24(%rsp), %rax
	cmpq	$-32768, %rax
	leaq	32768(%rbx), %rcx
	cmovaeq	%rcx, %r14
	addq	%rax, %r14
	leaq	(%r14,%rbx), %r15
	cmpq	%r13, %r14
	cmovbeq	%r14, %r15
	movq	32(%rsp), %rcx
	leaq	(%rcx,%rbx), %r14
	cmpq	%rcx, %r13
	movq	40(%rsp), %rax
	sbbq	%rax, %rax
	cmovaeq	%rcx, %r14
	movl	$74, %edx
	leaq	192(%rsp), %rdi
	movq	%rbp, %rsi
	callq	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0s_0B5_
	movq	8(%rsp), %rsi
	subq	%rax, %r15
	leaq	1(%r15,%r13), %rbp
	cmovaeq	%r15, %rbp
	subq	%rdx, %r14
	leaq	1(%r14,%r13), %rax
	cmovaeq	%r14, %rax
	movq	%rax, 40(%rsp)
	movq	200(%rsi), %rdi
	cmpq	16(%rsp), %rdi
	jae	.LBB11_11
	shlq	$4, %rdi
	leaq	128(%rbx), %rax
	movq	104(%rsp), %rdx
	cmpq	$-128, %rdx
	movl	$128, %ecx
	cmovaeq	%rax, %rcx
	addq	%rdx, %rcx
	leaq	(%rcx,%rbx), %r10
	cmpq	%r13, %rcx
	cmovbeq	%rcx, %r10
	movq	96(%rsp), %rax
	leaq	(%rax,%rbx), %r9
	cmpq	%r13, %rax
	cmovbeq	%rax, %r9
	movq	224(%rsi), %rsi
	movq	%rsi, %rax
	movq	48(%rsp), %r14
	mulq	%r14
	movl	%edx, %ecx
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r13), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rbx, %rcx
	addq	%rdx, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %r11
	cmpq	%r13, %rax
	cmovbeq	%rax, %r11
	movq	8(%rsp), %rax
	movq	232(%rax), %r8
	movq	%r8, %rax
	movq	56(%rsp), %r15
	mulq	%r15
	movq	%rax, %rcx
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rcx
	leaq	1(%rcx,%r13), %rax
	cmovbq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmpq	%r13, %rcx
	cmovaq	%rax, %rcx
	movq	%rsi, %rax
	mulq	%r15
	movl	%edx, %esi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r13), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rbx, %rsi
	addq	%rdx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovaeq	%rsi, %rax
	leaq	(%rax,%rbx), %rsi
	cmpq	%r13, %rax
	cmovbeq	%rax, %rsi
	movq	%r8, %rax
	mulq	%r14
	movl	%edx, %r8d
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r13), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rbx, %r8
	addq	%rdx, %r8
	leaq	(%r8,%rbx), %rax
	cmovaeq	%r8, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%r13, %rax
	cmovbeq	%rax, %r8
	movq	%rcx, %rax
	movl	$7, %ecx
	mulq	%rcx
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r13, %rax
	cmovbeq	%rax, %rcx
	addq	%r11, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r13, %rax
	cmovbeq	%rax, %rcx
	addq	%rsi, %r8
	leaq	(%r8,%rbx), %rax
	cmovaeq	%r8, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r13, %rax
	cmovbeq	%rax, %rdx
	addq	%r10, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r13, %rax
	cmovbeq	%rax, %rcx
	addq	%r9, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r13, %rax
	cmovbeq	%rax, %rdx
	movq	8(%rsp), %rax
	addq	240(%rax), %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r13, %rax
	cmovbeq	%rax, %rcx
	movq	8(%rsp), %rax
	addq	248(%rax), %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r13, %rax
	cmovbeq	%rax, %rdx
	movq	8(%rsp), %rax
	movq	208(%rax), %r9
	movq	8(%rsp), %rax
	movq	216(%rax), %r10
	movq	%r9, %rax
	subq	%rcx, %rax
	leaq	1(%rax,%r13), %rcx
	cmovaeq	%rax, %rcx
	movq	%r10, %rax
	subq	%rdx, %rax
	leaq	1(%rax,%r13), %r8
	cmovaeq	%rax, %r8
	movq	64(%rsp), %r12
	movq	(%r12,%rdi), %r14
	movq	%rcx, %rax
	mulq	%r14
	movl	%edx, %esi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r13), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rbx, %rsi
	addq	%rdx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovaeq	%rsi, %rax
	leaq	(%rax,%rbx), %r11
	cmpq	%r13, %rax
	cmovbeq	%rax, %r11
	movq	8(%r12,%rdi), %r15
	movq	%r8, %rax
	mulq	%r15
	movq	%rax, %rsi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rsi
	leaq	1(%rsi,%r13), %rax
	cmovbq	%rax, %rsi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r13, %rsi
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	mulq	%r14
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r13), %rdi
	cmovaeq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rdi
	cmpq	%r13, %rdx
	cmovbeq	%rdx, %rdi
	movq	%rcx, %rax
	mulq	%r15
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r13), %rcx
	cmovaeq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rcx
	cmpq	%r13, %rdx
	cmovbeq	%rdx, %rcx
	movq	%rsi, %rax
	movl	$7, %edx
	mulq	%rdx
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r13, %rax
	cmovbeq	%rax, %rdx
	addq	%r11, %rdx
	movq	8(%rsp), %rsi
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r13, %rax
	cmovbeq	%rax, %rdx
	addq	%rdi, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r13, %rax
	cmovbeq	%rax, %rcx
	subq	$1, %rdx
	cmovbq	%r13, %rdx
	cmpb	$0, (%rsi)
	movq	%r12, %r14
	je	.LBB11_10
	movq	8(%rsi), %rdi
	cmpq	16(%rsp), %rdi
	jae	.LBB11_23
	shlq	$4, %rdi
	movq	(%r14,%rdi), %rax
	movq	%rax, 32(%rsp)
	movq	8(%r14,%rdi), %rax
	movq	%rax, 24(%rsp)
	jmp	.LBB11_13
.LBB11_10:
	movl	$1, %eax
	movq	%rax, 32(%rsp)
	movq	$0, 24(%rsp)
.LBB11_13:
	movq	80(%rsi), %r13
	cmpq	$4, %r13
	jb	.LBB11_24
	movq	72(%rsi), %r12
	movq	256(%rsi), %r8
	movq	%rdx, 136(%rsp)
	movq	48(%rsi), %rdx
	movq	%rcx, 152(%rsp)
	movq	56(%rsi), %rcx
	leaq	-4(%r13), %rax
	movq	%rbp, 56(%rsp)
	movq	%rsi, %rbp
	leaq	64(%r12), %r11
	subq	$8, %rsp
	.cfi_adjust_cfa_offset 8
	movq	%r14, %rdi
	movq	24(%rsp), %r15
	movq	%r15, %rsi
	pushq	%rax
	.cfi_adjust_cfa_offset 8
	pushq	%r11
	.cfi_adjust_cfa_offset 8
	pushq	%r10
	.cfi_adjust_cfa_offset 8
	callq	_RNvCsl0YfJI2rrfI_8isolated10helper_sum
	addq	$32, %rsp
	.cfi_adjust_cfa_offset -32
	movq	%rax, 168(%rsp)
	movq	%rdx, 160(%rsp)
	movq	48(%r12), %rax
	movq	%rax, 144(%rsp)
	movq	56(%r12), %rax
	movq	%rax, 128(%rsp)
	leaq	88(%rbp), %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	callq	_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm4eval
	movq	%rax, %rcx
	movq	%rdx, %rsi
	shlq	$4, %r13
	movq	%r12, 48(%rsp)
	addq	%r12, %r13
	movq	128(%rsp), %r15
	movq	%r15, %rax
	movq	136(%rsp), %r10
	mulq	%r10
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	movabsq	$-4294967296, %r9
	leaq	1(%rax,%r9), %rdi
	cmovaeq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r9, %rdx
	leaq	(%rdx,%rbx), %rdi
	cmovbeq	%rdx, %rdi
	movq	144(%rsp), %r11
	movq	%r11, %rax
	movq	152(%rsp), %r14
	mulq	%r14
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r9), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r8, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r9, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r9, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	160(%rsp), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmpq	%r9, %rdx
	cmovbeq	%rdx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %r8
	cmpq	%r9, %rdx
	cmovbeq	%rdx, %r8
	movq	%r15, %rax
	mulq	%r14
	movl	%edx, %esi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r9), %rdx
	cmovbq	%rdx, %rax
	imulq	%rbx, %rsi
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r9, %rax
	cmovaq	%rdx, %rax
	movl	$7, %edx
	mulq	%rdx
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rsi
	cmpq	%r9, %rax
	cmovbeq	%rax, %rsi
	xorps	%xmm0, %xmm0
	movups	%xmm0, 296(%rsp)
	movq	72(%rsp), %rax
	movq	%rax, 248(%rsp)
	movq	%r11, %rax
	mulq	%r10
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r9), %rdi
	cmovaeq	%rax, %rdi
	movq	80(%rsp), %rax
	movq	%rax, 256(%rsp)
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmpq	%r9, %rdx
	cmovbeq	%rdx, %rax
	movq	184(%rsp), %rdx
	movq	%rdx, 264(%rsp)
	movq	176(%rsp), %rdx
	movq	%rdx, 272(%rsp)
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmpq	%r9, %rdx
	cmovbeq	%rdx, %rax
	addq	168(%rsp), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmpq	%r9, %rdx
	cmovbeq	%rdx, %rax
	movq	56(%rsp), %rdx
	movq	%rdx, 280(%rsp)
	movq	40(%rsp), %rdx
	movq	%rdx, 288(%rsp)
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	leaq	(%rcx,%rbx), %r12
	cmpq	%r9, %rcx
	cmovbeq	%rcx, %r12
	xorl	%r10d, %r10d
	movabsq	$-4294967296, %rbp
	.p2align	4
.LBB11_15:
	leaq	16(%r10), %r15
	cmpq	$64, %r15
	je	.LBB11_16
	movq	48(%rsp), %rax
	leaq	(%rax,%r10), %r11
	movq	(%r11), %rdi
	movq	%rdi, %rax
	movq	32(%rsp), %r14
	mulq	%r14
	movq	%rax, %rcx
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rcx
	leaq	1(%rcx,%rbp), %rdx
	cmovbq	%rdx, %rcx
	imulq	%rbx, %rax
	addq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmpq	%rbp, %rcx
	cmovaq	%rax, %rcx
	movq	%r8, 40(%rsp)
	movq	8(%r11), %r8
	movq	%r8, %rax
	movq	24(%rsp), %r9
	mulq	%r9
	movq	%rax, %rsi
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rsi
	leaq	1(%rsi,%rbp), %rdx
	cmovbq	%rdx, %rsi
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%rbp, %rsi
	cmovaq	%rax, %rsi
	movq	%rdi, %rax
	mulq	%r9
	movq	%rax, %rdi
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rdi
	leaq	1(%rdi,%rbp), %rdx
	cmovbq	%rdx, %rdi
	imulq	%rbx, %rax
	addq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%rbp, %rdi
	cmovaq	%rax, %rdi
	movq	%r8, %rax
	mulq	%r14
	movq	%rax, %r8
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %r8
	leaq	1(%r8,%rbp), %rdx
	cmovbq	%rdx, %r8
	imulq	%rbx, %rax
	addq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmpq	%rbp, %r8
	cmovaq	%rax, %r8
	movq	%rsi, %rax
	movl	$7, %r9d
	mulq	%r9
	movq	%rax, %rsi
	imulq	%rbx, %rdx
	addq	%rdx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%rbp, %rsi
	cmovaq	%rax, %rsi
	addq	%rcx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%rbp, %rsi
	cmovaq	%rax, %rsi
	addq	%rdi, %r8
	leaq	(%r8,%rbx), %rax
	cmovaeq	%r8, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%rbp, %rax
	cmovbeq	%rax, %rcx
	movq	248(%rsp,%r10), %r14
	movq	%rsi, %rax
	mulq	%r14
	movl	%edx, %edi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%rbp), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rbx, %rdi
	addq	%rdx, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovaeq	%rdi, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%rbp, %rax
	cmovbeq	%rax, %r8
	movq	256(%rsp,%r10), %r10
	movq	%rcx, %rax
	mulq	%r10
	movq	%rax, %rdi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rdi
	leaq	1(%rdi,%rbp), %rax
	cmovbq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%rbp, %rdi
	cmovaq	%rax, %rdi
	movq	%rsi, %rax
	mulq	%r10
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%rbp), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rsi
	cmpq	%rbp, %rdx
	cmovbeq	%rdx, %rsi
	movq	%rcx, %rax
	mulq	%r14
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%rbp), %rcx
	cmovaeq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rcx
	cmpq	%rbp, %rdx
	cmovbeq	%rdx, %rcx
	movq	%rdi, %rax
	mulq	%r9
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%rbp, %rax
	cmovbeq	%rax, %rdx
	addq	%r8, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%rbp, %rax
	cmovbeq	%rax, %rdx
	addq	%rsi, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%rbp, %rax
	cmovbeq	%rax, %rcx
	addq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r12
	cmpq	%rbp, %rax
	cmovbeq	%rax, %r12
	addq	40(%rsp), %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%rbp, %rax
	cmovbeq	%rax, %r8
	addq	$16, %r11
	movq	%r15, %r10
	cmpq	%r13, %r11
	jne	.LBB11_15
.LBB11_16:
	movq	88(%rsp), %rax
	movq	544(%rax), %rdi
	movq	16(%rsp), %rsi
	cmpq	%rsi, %rdi
	jae	.LBB11_25
	movq	8(%rsp), %rbp
	movq	144(%rbp), %rax
	testq	%rax, %rax
	movabsq	$-4294967296, %r13
	je	.LBB11_26
	cmpq	$1, %rsi
	jbe	.LBB11_27
	cmpq	$1, %rax
	je	.LBB11_28
	cmpq	$2, %rsi
	je	.LBB11_29
	shlq	$4, %rdi
	movq	%rdi, 48(%rsp)
	movq	64(%rsp), %rdi
	movq	(%rdi), %rax
	movq	%rax, 56(%rsp)
	mulq	%r8
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r13), %rcx
	cmovaeq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r13, %rdx
	leaq	(%rdx,%rbx), %rcx
	cmovbeq	%rdx, %rcx
	movq	8(%rdi), %rax
	movq	%rax, 88(%rsp)
	mulq	%r12
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%r13), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r13, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r13, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	movq	%rax, 80(%rsp)
	movq	136(%rbp), %rsi
	movq	(%rsi), %rcx
	movq	%rsi, 16(%rsp)
	movq	%r8, 40(%rsp)
	movq	16(%rdi), %r8
	movq	%r8, %rax
	mulq	%rcx
	movq	%rax, %r11
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r11
	leaq	1(%r11,%r13), %rax
	cmovbq	%rax, %r11
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r11
	leaq	(%r11,%rbx), %rax
	cmovbq	%rax, %r11
	cmpq	%r13, %r11
	leaq	(%r11,%rbx), %rax
	cmovaq	%rax, %r11
	movq	8(%rsi), %r15
	movq	24(%rdi), %r10
	movq	%r10, %rax
	mulq	%r15
	movq	%rdx, %r9
	shrq	$32, %r9
	subq	%r9, %rax
	leaq	1(%rax,%r13), %r9
	cmovbq	%r9, %rax
	movl	%edx, %edx
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	cmpq	%r13, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaq	%rdx, %rax
	movl	$7, %edx
	mulq	%rdx
	movl	$7, %esi
	movq	%rax, %r9
	imulq	%rbx, %rdx
	addq	%rdx, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	cmpq	%r13, %r9
	leaq	(%r9,%rbx), %rax
	cmovaq	%rax, %r9
	addq	%r11, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	cmpq	%r13, %r9
	leaq	(%r9,%rbx), %rax
	cmovaq	%rax, %r9
	movq	%r9, %rax
	mulq	32(%rsp)
	movq	%rax, %r11
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r11
	leaq	1(%r11,%r13), %rax
	cmovbq	%rax, %r11
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r11
	leaq	(%r11,%rbx), %rax
	cmovbq	%rax, %r11
	cmpq	%r13, %r11
	leaq	(%r11,%rbx), %rax
	cmovaq	%rax, %r11
	movq	%r10, %rax
	mulq	%rcx
	movq	%rax, %r14
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r14
	leaq	1(%r14,%r13), %rax
	cmovbq	%rax, %r14
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r14
	leaq	(%r14,%rbx), %rax
	cmovbq	%rax, %r14
	cmpq	%r13, %r14
	leaq	(%r14,%rbx), %rax
	cmovaq	%rax, %r14
	movq	%r8, %rax
	mulq	%r15
	movq	%rax, %r10
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r10
	leaq	1(%r10,%r13), %rax
	cmovbq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmovbq	%rax, %r10
	cmpq	%r13, %r10
	leaq	(%r10,%rbx), %rax
	cmovaq	%rax, %r10
	addq	%r14, %r10
	leaq	(%r10,%rbx), %rax
	cmovbq	%rax, %r10
	cmpq	%r13, %r10
	leaq	(%r10,%rbx), %rax
	cmovaq	%rax, %r10
	movq	%r10, %rax
	movq	24(%rsp), %rdi
	mulq	%rdi
	movq	%rdi, 24(%rsp)
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r13), %rcx
	cmovbq	%rcx, %rax
	movl	%edx, %ecx
	imulq	%rbx, %rcx
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbq	%rcx, %rax
	cmpq	%r13, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaq	%rcx, %rax
	mulq	%rsi
	movq	%rax, %r8
	imulq	%rbx, %rdx
	addq	%rdx, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	cmpq	%r13, %r8
	leaq	(%r8,%rbx), %rax
	cmovaq	%rax, %r8
	addq	%r11, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	cmpq	%r13, %r8
	leaq	(%r8,%rbx), %rax
	cmovaq	%rax, %r8
	movq	264(%rbp), %r11
	movq	%r11, %rax
	mulq	96(%rsp)
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r13), %rcx
	cmovaeq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r13, %rdx
	leaq	(%rdx,%rbx), %rcx
	cmovbeq	%rdx, %rcx
	movq	272(%rbp), %r14
	movq	%r14, %rax
	movq	104(%rsp), %rsi
	mulq	%rsi
	movq	%rdx, %r15
	shrq	$32, %r15
	subq	%r15, %rax
	leaq	1(%rax,%r13), %r15
	cmovaeq	%rax, %r15
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r15, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r13, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r13, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	movq	48(%rsp), %rcx
	movq	64(%rsp), %rdx
	addq	8(%rdx,%rcx), %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r13, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	subq	288(%rbp), %rax
	leaq	1(%rax,%r13), %rcx
	cmovaeq	%rax, %rcx
	movq	%rcx, 72(%rsp)
	movq	%r8, %rax
	mulq	%rcx
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r13), %rcx
	cmovaeq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r13, %rdx
	leaq	(%rdx,%rbx), %rcx
	cmovbeq	%rdx, %rcx
	movq	%r9, %rax
	mulq	%rdi
	movq	%rax, %r15
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r15
	leaq	1(%r15,%r13), %rax
	cmovbq	%rax, %r15
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r15
	leaq	(%r15,%rbx), %rax
	cmovbq	%rax, %r15
	cmpq	%r13, %r15
	leaq	(%r15,%rbx), %rax
	cmovaq	%rax, %r15
	movq	%r10, %rax
	mulq	32(%rsp)
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r13), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	cmpq	%r13, %r9
	leaq	(%r9,%rbx), %rax
	cmovaq	%rax, %r9
	addq	%r15, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	cmpq	%r13, %r9
	leaq	(%r9,%rbx), %rax
	cmovaq	%rax, %r9
	movq	%r11, %rax
	mulq	%rsi
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%r13), %r10
	cmovaeq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r10, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r13, %rdx
	leaq	(%rdx,%rbx), %r10
	cmovbeq	%rdx, %r10
	movq	%r14, %rax
	mulq	96(%rsp)
	movq	%rdx, %r11
	shrq	$32, %r11
	subq	%r11, %rax
	leaq	1(%rax,%r13), %r11
	cmovbq	%r11, %rax
	movl	%edx, %edx
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	cmpq	%r13, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaq	%rdx, %rax
	movl	$7, %edx
	mulq	%rdx
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r13, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	addq	%r10, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r13, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	movq	64(%rsp), %r15
	movq	48(%rsp), %rax
	addq	(%r15,%rax), %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r13, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	subq	280(%rbp), %rdx
	leaq	1(%rdx,%r13), %rdi
	cmovaeq	%rdx, %rdi
	movq	%r9, %rax
	mulq	%rdi
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%r13), %r10
	cmovaeq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r10, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r13, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r13, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	addq	80(%rsp), %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r13, %rcx
	leaq	(%rcx,%rbx), %r11
	cmovbeq	%rcx, %r11
	movq	56(%rsp), %rax
	mulq	%r12
	movq	%rax, %rcx
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rcx
	leaq	1(%rcx,%r13), %rax
	cmovbq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	cmpq	%r13, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaq	%rax, %rcx
	movq	88(%rsp), %rax
	mulq	40(%rsp)
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%r13), %rsi
	cmovbq	%rsi, %rax
	movl	%edx, %edx
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	cmpq	%r13, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaq	%rdx, %rax
	movl	$7, %r10d
	mulq	%r10
	movq	%rax, %rsi
	imulq	%rbx, %rdx
	addq	%rdx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	cmpq	%r13, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovaq	%rax, %rsi
	addq	%rcx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	cmpq	%r13, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	mulq	%rdi
	movq	%rax, %rdi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rdi
	leaq	1(%rdi,%r13), %rax
	cmovbq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r13, %rdi
	cmovaq	%rax, %rdi
	movq	%r9, %rax
	mulq	72(%rsp)
	movl	%edx, %ecx
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r13), %rdx
	cmovbq	%rdx, %rax
	imulq	%rbx, %rcx
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r13, %rax
	cmovaq	%rcx, %rax
	mulq	%r10
	movl	$7, %r12d
	movq	%rax, %rcx
	imulq	%rbx, %rdx
	addq	%rdx, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmpq	%r13, %rcx
	cmovaq	%rax, %rcx
	addq	%rdi, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmpq	%r13, %rcx
	cmovaq	%rax, %rcx
	addq	%rsi, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmpq	%r13, %rcx
	cmovaq	%rax, %rcx
	movq	16(%rsp), %r8
	movq	16(%r8), %r14
	movq	32(%r15), %rdi
	movq	%rdi, %rax
	mulq	%r14
	movq	%rax, %rsi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rsi
	leaq	1(%rsi,%r13), %rax
	cmovbq	%rax, %rsi
	movl	%edx, %eax
	movq	24(%r8), %r10
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r13, %rsi
	cmovaq	%rax, %rsi
	movq	40(%r15), %r9
	movq	%r9, %rax
	mulq	%r10
	movq	%rax, %r8
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r8
	leaq	1(%r8,%r13), %rax
	cmovbq	%rax, %r8
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	cmpq	%r13, %r8
	leaq	(%r8,%rbx), %rax
	cmovaq	%rax, %r8
	movq	%r9, %rax
	mulq	%r14
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r13), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmpq	%r13, %r9
	cmovaq	%rax, %r9
	movq	%rdi, %rax
	mulq	%r10
	movq	%rax, %r10
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %r10
	leaq	1(%r10,%r13), %rdx
	cmovbq	%rdx, %r10
	imulq	%rbx, %rax
	addq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmovbq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmpq	%r13, %r10
	cmovaq	%rax, %r10
	movq	%r8, %rax
	mulq	%r12
	movq	%rax, %rdi
	imulq	%rbx, %rdx
	addq	%rdx, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r13, %rdi
	cmovaq	%rax, %rdi
	addq	%rsi, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r13, %rdi
	cmovaq	%rax, %rdi
	addq	%r9, %r10
	leaq	(%r10,%rbx), %rax
	cmovaeq	%r10, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%r13, %rax
	cmovbeq	%rax, %r8
	movq	%rdi, %rax
	movq	32(%rsp), %r14
	mulq	%r14
	movq	%rax, %rsi
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rsi
	leaq	1(%rsi,%r13), %rdx
	cmovbq	%rdx, %rsi
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r13, %rsi
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	movq	24(%rsp), %r10
	mulq	%r10
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r13), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmpq	%r13, %r9
	cmovaq	%rax, %r9
	movq	%rdi, %rax
	mulq	%r10
	movq	%rax, %r10
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r10
	leaq	1(%r10,%r13), %rax
	cmovbq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmovbq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmpq	%r13, %r10
	cmovaq	%rax, %r10
	movq	%r8, %rax
	mulq	%r14
	movq	%rax, %r8
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %r8
	leaq	1(%r8,%r13), %rdx
	cmovbq	%rdx, %r8
	imulq	%rbx, %rax
	addq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmpq	%r13, %r8
	cmovaq	%rax, %r8
	movq	%r9, %rax
	mulq	%r12
	movq	%rax, %rdi
	imulq	%rbx, %rdx
	addq	%rdx, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r13, %rdi
	cmovaq	%rax, %rdi
	addq	%rsi, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r13, %rdi
	cmovaq	%rax, %rdi
	addq	%r10, %r8
	leaq	(%r8,%rbx), %rax
	cmovaeq	%r8, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%r13, %rax
	cmovbeq	%rax, %r8
	movq	%rdi, %rax
	movq	120(%rsp), %r10
	mulq	%r10
	movq	%rax, %rsi
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rsi
	leaq	1(%rsi,%r13), %rdx
	cmovbq	%rdx, %rsi
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r13, %rsi
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	movq	112(%rsp), %r14
	mulq	%r14
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r13), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmpq	%r13, %r9
	cmovaq	%rax, %r9
	movq	%rdi, %rax
	mulq	%r14
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r13), %rdi
	cmovaeq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rdi
	cmpq	%r13, %rdx
	cmovbeq	%rdx, %rdi
	movq	%r8, %rax
	mulq	%r10
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r13), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r8, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %r8
	cmpq	%r13, %rdx
	cmovbeq	%rdx, %r8
	movq	%r9, %rax
	mulq	%r12
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r13, %rax
	cmovaq	%rdx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r13, %rax
	cmovaq	%rdx, %rax
	addq	%rdi, %r8
	leaq	(%r8,%rbx), %rdx
	cmovaeq	%r8, %rdx
	leaq	(%rdx,%rbx), %rsi
	cmpq	%r13, %rdx
	cmovbeq	%rdx, %rsi
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r13, %rax
	cmovaq	%rcx, %rax
	addq	%r11, %rsi
	leaq	(%rsi,%rbx), %rcx
	cmovaeq	%rsi, %rcx
	addq	%rcx, %rbx
	cmpq	%r13, %rcx
	cmovbeq	%rcx, %rbx
	movq	%rbx, %rdx
	addq	$312, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%r12
	.cfi_def_cfa_offset 40
	popq	%r13
	.cfi_def_cfa_offset 32
	popq	%r14
	.cfi_def_cfa_offset 24
	popq	%r15
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	retq
.LBB11_24:
	.cfi_def_cfa_offset 368
	leaq	.Lalloc_85ee655d0ee76a931ab97ae7956c61fa(%rip), %rcx
	movl	$4, %edi
	movq	%r13, %rsi
	movq	%r13, %rdx
	callq	*_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail@GOTPCREL(%rip)
.LBB11_31:
	leaq	.Lalloc_14e9b0f3c1e82842e326b949d03d992d(%rip), %rdx
	movl	$67, %edi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB11_32:
	movq	%rdx, %rsi
	leaq	.Lalloc_eca36810f664faabadbd931684be3603(%rip), %rdx
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB11_33:
	leaq	.Lalloc_14e9b0f3c1e82842e326b949d03d992d(%rip), %rdx
	movl	$69, %edi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB11_34:
	movq	%rdx, %rsi
	leaq	.Lalloc_eca36810f664faabadbd931684be3603(%rip), %rdx
	movq	%rax, %rdi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB11_35:
	leaq	.Lalloc_14e9b0f3c1e82842e326b949d03d992d(%rip), %rdx
	movl	$70, %edi
	movl	$70, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB11_36:
	movq	%rdx, %rsi
	leaq	.Lalloc_eca36810f664faabadbd931684be3603(%rip), %rdx
	movq	%r8, %rdi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB11_37:
	leaq	.Lalloc_14e9b0f3c1e82842e326b949d03d992d(%rip), %rdx
	movl	$73, %edi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB11_38:
	leaq	.Lalloc_eca36810f664faabadbd931684be3603(%rip), %rdx
	movq	%rcx, %rdi
	movq	16(%rsp), %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB11_11:
	leaq	.Lalloc_251b78bda4aeb9a619eb192d691b2e6c(%rip), %rdx
	movq	16(%rsp), %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB11_25:
	leaq	.Lalloc_eca36810f664faabadbd931684be3603(%rip), %rdx
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB11_26:
	leaq	.Lalloc_60764c2be1deec61362b17f60211fd40(%rip), %rdx
	xorl	%edi, %edi
	xorl	%esi, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB11_27:
	leaq	.Lalloc_0115ca0cf6aba2d7c2ca2e69392e3726(%rip), %rdx
	movl	$1, %edi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB11_28:
	leaq	.Lalloc_7672b3fd58eaeff1a7f945549344b36b(%rip), %rdx
	movl	$1, %edi
	movl	$1, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB11_29:
	leaq	.Lalloc_0d7c3282f4d1b6d0ea38e377caef0ba7(%rip), %rdx
	movl	$2, %edi
	movl	$2, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB11_23:
	leaq	.Lalloc_03bbe1d0fcdbd86f2216092eb0f02e36(%rip), %rdx
	movq	16(%rsp), %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Lfunc_end11:
	.size	_RNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0B3_, .Lfunc_end11-_RNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0B3_
	.cfi_endproc

	.section	.text._RNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0B3_,"ax",@progbits
	.p2align	4
	.type	_RNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0B3_,@function
_RNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0B3_:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	subq	$312, %rsp
	.cfi_def_cfa_offset 368
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%rdx, %r9
	movq	%rsi, %rdx
	leaq	16(%rdi), %rax
	movq	%rsi, 192(%rsp)
	movq	%r9, 200(%rsp)
	movq	%rax, 208(%rsp)
	movq	32(%rdi), %rsi
	cmpq	$68, %rsi
	jb	.LBB12_31
	movq	%rdi, %rcx
	movq	24(%rdi), %r10
	movq	536(%r10), %rbp
	cmpq	%r9, %rbp
	jae	.LBB12_32
	cmpq	$69, %rsi
	jbe	.LBB12_33
	movq	552(%r10), %rax
	cmpq	%r9, %rax
	jae	.LBB12_34
	cmpq	$70, %rsi
	je	.LBB12_35
	movq	560(%r10), %r8
	cmpq	%r9, %r8
	jae	.LBB12_36
	cmpq	$73, %rsi
	jbe	.LBB12_37
	movq	%rcx, 64(%rsp)
	movq	%r10, 184(%rsp)
	movq	584(%r10), %rcx
	cmpq	%r9, %rcx
	movq	%r9, 8(%rsp)
	jae	.LBB12_38
	shlq	$4, %rbp
	shlq	$4, %rax
	movq	(%rdx,%rax), %r10
	movq	8(%rdx,%rax), %r11
	shlq	$4, %r8
	movq	%rdx, %rdi
	movq	(%rdx,%r8), %r14
	movabsq	$-4294967296, %r12
	movl	$4294967295, %ebx
	shlq	$4, %rcx
	movq	$0, 40(%rsp)
	movq	%r14, %rax
	movq	%r14, 104(%rsp)
	mulq	%r10
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%r12), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rsi, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r9
	cmpq	%r12, %rax
	cmovbeq	%rax, %r9
	movq	8(%rdi,%r8), %r8
	movq	%r8, %rax
	movq	%r8, 96(%rsp)
	mulq	%r11
	movq	%rax, %rsi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rsi
	leaq	1(%rsi,%r12), %rax
	cmovbq	%rax, %rsi
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rdx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r12, %rsi
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	movq	%r10, 56(%rsp)
	mulq	%r10
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r12), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%r8, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r10
	cmpq	%r12, %rax
	cmovbeq	%rax, %r10
	movq	%r14, %rax
	movq	%r11, 48(%rsp)
	mulq	%r11
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r12), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%r8, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r11
	cmpq	%r12, %rax
	cmovbeq	%rax, %r11
	movl	$7, %edx
	movq	%rsi, %rax
	mulq	%rdx
	movq	%rdx, %rsi
	shlq	$32, %rsi
	subq	%rdx, %rsi
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovaeq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rdx
	movq	(%rdi,%rcx), %r14
	movq	%r14, 32(%rsp)
	addq	%r9, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%r12, %rax
	cmovbeq	%rax, %r8
	addq	%r10, %r11
	leaq	(%r11,%rbx), %rax
	cmovaeq	%r11, %rax
	leaq	(%rax,%rbx), %r9
	cmpq	%r12, %rax
	cmovbeq	%rax, %r9
	movq	64(%rsp), %r13
	movq	160(%r13), %rsi
	movq	%rsi, %rax
	mulq	%r14
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%r12), %r10
	cmovaeq	%rax, %r10
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%r10, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %r10
	cmovbeq	%rax, %r10
	movq	8(%rdi,%rcx), %rcx
	movq	%rcx, 24(%rsp)
	movq	%rsi, %rax
	mulq	%rcx
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r12), %rcx
	cmovaeq	%rax, %rcx
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rcx, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbeq	%rax, %rcx
	subq	%r10, %r8
	leaq	1(%r8,%r12), %r14
	cmovaeq	%r8, %r14
	leaq	152(%r13), %rsi
	movq	%rsi, 16(%rsp)
	subq	%rcx, %r9
	leaq	1(%r9,%r12), %r15
	cmovaeq	%r9, %r15
	movq	(%rdi,%rbp), %rax
	movq	%rax, 88(%rsp)
	movq	%rdi, 72(%rsp)
	movq	8(%rdi,%rbp), %rax
	movq	%rax, 80(%rsp)
	leaq	192(%rsp), %rdi
	movl	$76, %edx
	callq	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0s_0B5_
	subq	%rax, %r14
	leaq	1(%r14,%r12), %rax
	cmovaeq	%r14, %rax
	subq	%rdx, %r15
	leaq	1(%r15,%r12), %rcx
	cmovaeq	%r15, %rcx
	addq	168(%r13), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmpq	%r12, %rdx
	cmovbeq	%rdx, %rax
	movq	%rax, 168(%rsp)
	addq	176(%r13), %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rcx
	movq	%rcx, 176(%rsp)
	leaq	32768(%rbx), %rdx
	movq	104(%rsp), %rcx
	cmpq	$-32768, %rcx
	movl	$32768, %eax
	cmovaeq	%rdx, %rax
	movl	$32768, %r14d
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %r15
	cmpq	%r12, %rax
	cmovbeq	%rax, %r15
	movq	96(%rsp), %rax
	leaq	(%rax,%rbx), %rbp
	cmpq	%r12, %rax
	cmovbeq	%rax, %rbp
	movl	$71, %edx
	leaq	192(%rsp), %rdi
	movq	16(%rsp), %r13
	movq	%r13, %rsi
	callq	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0s_0B5_
	subq	%rax, %r15
	leaq	1(%r15,%r12), %rax
	cmovaeq	%r15, %rax
	movq	%rax, 160(%rsp)
	subq	%rdx, %rbp
	leaq	1(%rbp,%r12), %rax
	cmovaeq	%rbp, %rax
	movq	%rax, 152(%rsp)
	movq	64(%rsp), %rbp
	movq	32(%rsp), %rax
	cmpq	$-32768, %rax
	leaq	32768(%rbx), %rcx
	cmovaeq	%rcx, %r14
	addq	%rax, %r14
	leaq	(%r14,%rbx), %r15
	cmpq	%r12, %r14
	cmovbeq	%r14, %r15
	movq	24(%rsp), %rcx
	leaq	(%rcx,%rbx), %r14
	cmpq	%rcx, %r12
	movq	40(%rsp), %rax
	sbbq	%rax, %rax
	cmovaeq	%rcx, %r14
	movl	$74, %edx
	leaq	192(%rsp), %rdi
	movq	%r13, %rsi
	callq	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0s_0B5_
	subq	%rax, %r15
	leaq	1(%r15,%r12), %rax
	cmovaeq	%r15, %rax
	movq	%rax, 40(%rsp)
	subq	%rdx, %r14
	leaq	1(%r14,%r12), %rax
	cmovaeq	%r14, %rax
	movq	%rax, 144(%rsp)
	movq	184(%rbp), %rdi
	cmpq	8(%rsp), %rdi
	jae	.LBB12_11
	shlq	$4, %rdi
	leaq	128(%rbx), %rax
	movq	88(%rsp), %rdx
	cmpq	$-128, %rdx
	movl	$128, %ecx
	cmovaeq	%rax, %rcx
	addq	%rdx, %rcx
	leaq	(%rcx,%rbx), %r10
	cmpq	%r12, %rcx
	cmovbeq	%rcx, %r10
	movq	80(%rsp), %rax
	leaq	(%rax,%rbx), %r9
	cmpq	%r12, %rax
	cmovbeq	%rax, %r9
	movq	208(%rbp), %rsi
	movq	%rsi, %rax
	movq	56(%rsp), %r14
	mulq	%r14
	movl	%edx, %ecx
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rbx, %rcx
	addq	%rdx, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %r11
	cmpq	%r12, %rax
	cmovbeq	%rax, %r11
	movq	216(%rbp), %r8
	movq	%r8, %rax
	movq	48(%rsp), %r15
	mulq	%r15
	movq	%rax, %rcx
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rcx
	leaq	1(%rcx,%r12), %rax
	cmovbq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmpq	%r12, %rcx
	cmovaq	%rax, %rcx
	movq	%rsi, %rax
	mulq	%r15
	movl	%edx, %esi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rbx, %rsi
	addq	%rdx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovaeq	%rsi, %rax
	leaq	(%rax,%rbx), %rsi
	cmpq	%r12, %rax
	cmovbeq	%rax, %rsi
	movq	%r8, %rax
	mulq	%r14
	movl	%edx, %r8d
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rbx, %r8
	addq	%rdx, %r8
	leaq	(%r8,%rbx), %rax
	cmovaeq	%r8, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%r12, %rax
	cmovbeq	%rax, %r8
	movq	%rcx, %rax
	movl	$7, %ecx
	mulq	%rcx
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rcx
	addq	%r11, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rcx
	addq	%rsi, %r8
	leaq	(%r8,%rbx), %rax
	cmovaeq	%r8, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rdx
	addq	%r10, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rcx
	addq	%r9, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rdx
	addq	224(%rbp), %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rcx
	addq	232(%rbp), %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rdx
	movq	192(%rbp), %r9
	movq	200(%rbp), %rsi
	movq	%r9, %rax
	subq	%rcx, %rax
	leaq	1(%rax,%r12), %rcx
	cmovaeq	%rax, %rcx
	movq	%rsi, 16(%rsp)
	movq	%rsi, %rax
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %r8
	cmovaeq	%rax, %r8
	movq	72(%rsp), %r13
	movq	(%r13,%rdi), %r14
	movq	%rcx, %rax
	mulq	%r14
	movl	%edx, %esi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rbx, %rsi
	addq	%rdx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovaeq	%rsi, %rax
	leaq	(%rax,%rbx), %r11
	cmpq	%r12, %rax
	cmovbeq	%rax, %r11
	movq	8(%r13,%rdi), %r15
	movq	%r8, %rax
	mulq	%r15
	movq	%rax, %rsi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rsi
	leaq	1(%rsi,%r12), %rax
	cmovbq	%rax, %rsi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r12, %rsi
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	mulq	%r14
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r12), %rdi
	cmovaeq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rdi
	cmpq	%r12, %rdx
	cmovbeq	%rdx, %rdi
	movq	%rcx, %rax
	mulq	%r15
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r12), %rcx
	cmovaeq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rcx
	cmpq	%r12, %rdx
	cmovbeq	%rdx, %rcx
	movq	%rsi, %rax
	movl	$7, %edx
	mulq	%rdx
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rdx
	addq	%r11, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rdx
	addq	%rdi, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rcx
	subq	$1, %rdx
	cmovbq	%r12, %rdx
	cmpb	$0, (%rbp)
	movq	%r13, %r14
	je	.LBB12_10
	movq	8(%rbp), %rdi
	cmpq	8(%rsp), %rdi
	jae	.LBB12_23
	shlq	$4, %rdi
	movq	(%r14,%rdi), %rax
	movq	%rax, 32(%rsp)
	movq	8(%r14,%rdi), %rax
	movq	%rax, 24(%rsp)
	jmp	.LBB12_13
.LBB12_10:
	movl	$1, %eax
	movq	%rax, 32(%rsp)
	movq	$0, 24(%rsp)
.LBB12_13:
	movq	80(%rbp), %r13
	cmpq	$4, %r13
	jb	.LBB12_24
	movq	72(%rbp), %r15
	movq	240(%rbp), %r8
	movq	%rdx, 120(%rsp)
	movq	48(%rbp), %rdx
	movq	%rcx, 136(%rsp)
	movq	56(%rbp), %rcx
	leaq	-4(%r13), %rax
	leaq	64(%r15), %r11
	subq	$8, %rsp
	.cfi_adjust_cfa_offset 8
	movq	%r14, %rdi
	movq	16(%rsp), %r12
	movq	%r12, %rsi
	pushq	%rax
	.cfi_adjust_cfa_offset 8
	pushq	%r11
	.cfi_adjust_cfa_offset 8
	pushq	40(%rsp)
	.cfi_adjust_cfa_offset 8
	callq	_RNvCsl0YfJI2rrfI_8isolated10helper_sum
	addq	$32, %rsp
	.cfi_adjust_cfa_offset -32
	movq	%rax, 56(%rsp)
	movq	%rdx, 48(%rsp)
	movq	48(%r15), %rax
	movq	%rax, 128(%rsp)
	movq	56(%r15), %rax
	movq	%rax, 112(%rsp)
	leaq	88(%rbp), %rdi
	movq	%r14, %rsi
	movq	%r12, %rdx
	callq	_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm4eval
	movq	%rax, %rcx
	movq	%rdx, %rsi
	shlq	$4, %r13
	movq	%r15, 16(%rsp)
	addq	%r15, %r13
	movq	112(%rsp), %r15
	movq	%r15, %rax
	movq	120(%rsp), %r10
	mulq	%r10
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	movabsq	$-4294967296, %r9
	leaq	1(%rax,%r9), %rdi
	cmovaeq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r9, %rdx
	leaq	(%rdx,%rbx), %rdi
	cmovbeq	%rdx, %rdi
	movq	128(%rsp), %r11
	movq	%r11, %rax
	movq	136(%rsp), %r14
	mulq	%r14
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r9), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r8, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	movq	%r9, %r8
	cmpq	%r9, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r9, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	48(%rsp), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmpq	%r9, %rdx
	cmovbeq	%rdx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %r9
	cmpq	%r8, %rdx
	cmovbeq	%rdx, %r9
	movq	%r15, %rax
	mulq	%r14
	movl	%edx, %esi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r8), %rdx
	cmovbq	%rdx, %rax
	imulq	%rbx, %rsi
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r8, %rax
	cmovaq	%rdx, %rax
	movl	$7, %edx
	mulq	%rdx
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rsi
	cmpq	%r8, %rax
	cmovbeq	%rax, %rsi
	xorps	%xmm0, %xmm0
	movups	%xmm0, 296(%rsp)
	movq	168(%rsp), %rax
	movq	%rax, 248(%rsp)
	movq	%r11, %rax
	mulq	%r10
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r8), %rdi
	cmovaeq	%rax, %rdi
	movq	176(%rsp), %rax
	movq	%rax, 256(%rsp)
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmpq	%r8, %rdx
	cmovbeq	%rdx, %rax
	movq	160(%rsp), %rdx
	movq	%rdx, 264(%rsp)
	movq	152(%rsp), %rdx
	movq	%rdx, 272(%rsp)
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmpq	%r8, %rdx
	cmovbeq	%rdx, %rax
	addq	56(%rsp), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmpq	%r8, %rdx
	cmovbeq	%rdx, %rax
	movq	40(%rsp), %rdx
	movq	%rdx, 280(%rsp)
	movq	144(%rsp), %rdx
	movq	%rdx, 288(%rsp)
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	leaq	(%rcx,%rbx), %r15
	cmpq	%r8, %rcx
	cmovbeq	%rcx, %r15
	xorl	%r10d, %r10d
	movabsq	$-4294967296, %rbp
	.p2align	4
.LBB12_15:
	leaq	16(%r10), %r12
	cmpq	$64, %r12
	je	.LBB12_16
	movq	16(%rsp), %rax
	leaq	(%rax,%r10), %r11
	movq	(%r11), %rdi
	movq	%rdi, %rax
	movq	32(%rsp), %r14
	mulq	%r14
	movq	%rax, %rcx
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rcx
	leaq	1(%rcx,%rbp), %rdx
	cmovbq	%rdx, %rcx
	imulq	%rbx, %rax
	addq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmpq	%rbp, %rcx
	cmovaq	%rax, %rcx
	movq	8(%r11), %r8
	movq	%r8, %rax
	movq	24(%rsp), %rdx
	movq	%r9, 40(%rsp)
	movq	%rdx, %r9
	mulq	%rdx
	movq	%rax, %rsi
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rsi
	leaq	1(%rsi,%rbp), %rdx
	cmovbq	%rdx, %rsi
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%rbp, %rsi
	cmovaq	%rax, %rsi
	movq	%rdi, %rax
	mulq	%r9
	movq	%rax, %rdi
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rdi
	leaq	1(%rdi,%rbp), %rdx
	cmovbq	%rdx, %rdi
	imulq	%rbx, %rax
	addq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%rbp, %rdi
	cmovaq	%rax, %rdi
	movq	%r8, %rax
	mulq	%r14
	movq	%rax, %r8
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %r8
	leaq	1(%r8,%rbp), %rdx
	cmovbq	%rdx, %r8
	imulq	%rbx, %rax
	addq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmpq	%rbp, %r8
	cmovaq	%rax, %r8
	movq	%rsi, %rax
	movl	$7, %r9d
	mulq	%r9
	movq	%rax, %rsi
	imulq	%rbx, %rdx
	addq	%rdx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%rbp, %rsi
	cmovaq	%rax, %rsi
	addq	%rcx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%rbp, %rsi
	cmovaq	%rax, %rsi
	addq	%rdi, %r8
	leaq	(%r8,%rbx), %rax
	cmovaeq	%r8, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%rbp, %rax
	cmovbeq	%rax, %rcx
	movq	248(%rsp,%r10), %r14
	movq	%rsi, %rax
	mulq	%r14
	movl	%edx, %edi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%rbp), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rbx, %rdi
	addq	%rdx, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovaeq	%rdi, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%rbp, %rax
	cmovbeq	%rax, %r8
	movq	256(%rsp,%r10), %r10
	movq	%rcx, %rax
	mulq	%r10
	movq	%rax, %rdi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rdi
	leaq	1(%rdi,%rbp), %rax
	cmovbq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%rbp, %rdi
	cmovaq	%rax, %rdi
	movq	%rsi, %rax
	mulq	%r10
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%rbp), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rsi
	cmpq	%rbp, %rdx
	cmovbeq	%rdx, %rsi
	movq	%rcx, %rax
	mulq	%r14
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%rbp), %rcx
	cmovaeq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rcx
	cmpq	%rbp, %rdx
	cmovbeq	%rdx, %rcx
	movq	%rdi, %rax
	mulq	%r9
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%rbp, %rax
	cmovbeq	%rax, %rdx
	addq	%r8, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%rbp, %rax
	cmovbeq	%rax, %rdx
	addq	%rsi, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%rbp, %rax
	cmovbeq	%rax, %rcx
	addq	%r15, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r15
	cmpq	%rbp, %rax
	cmovbeq	%rax, %r15
	addq	40(%rsp), %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %r9
	cmpq	%rbp, %rax
	cmovbeq	%rax, %r9
	addq	$16, %r11
	movq	%r12, %r10
	cmpq	%r13, %r11
	jne	.LBB12_15
.LBB12_16:
	movq	184(%rsp), %rax
	movq	544(%rax), %rbp
	movq	8(%rsp), %rsi
	cmpq	%rsi, %rbp
	jae	.LBB12_25
	movq	64(%rsp), %rax
	movq	144(%rax), %rax
	testq	%rax, %rax
	movabsq	$-4294967296, %r13
	je	.LBB12_26
	cmpq	$1, %rsi
	jbe	.LBB12_27
	cmpq	$1, %rax
	je	.LBB12_28
	cmpq	$2, %rsi
	je	.LBB12_29
	shlq	$4, %rbp
	movq	72(%rsp), %r8
	movq	(%r8), %rax
	movq	%rax, 56(%rsp)
	mulq	%r9
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r13), %rcx
	cmovaeq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r13, %rdx
	leaq	(%rdx,%rbx), %rcx
	cmovbeq	%rdx, %rcx
	movq	8(%r8), %rax
	movq	%rax, 48(%rsp)
	mulq	%r15
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%r13), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r13, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r13, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	movq	%rax, 16(%rsp)
	movq	64(%rsp), %rdi
	movq	136(%rdi), %rsi
	movq	(%rsi), %rcx
	movq	%rsi, 8(%rsp)
	movq	%r9, 40(%rsp)
	movq	%r8, %r9
	movq	16(%r8), %r8
	movq	%r8, %rax
	mulq	%rcx
	movq	%rax, %r11
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r11
	leaq	1(%r11,%r13), %rax
	cmovbq	%rax, %r11
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r11
	leaq	(%r11,%rbx), %rax
	cmovbq	%rax, %r11
	cmpq	%r13, %r11
	leaq	(%r11,%rbx), %rax
	cmovaq	%rax, %r11
	movq	8(%rsi), %r12
	movq	24(%r9), %r10
	movq	%r10, %rax
	mulq	%r12
	movq	%rdx, %r9
	shrq	$32, %r9
	subq	%r9, %rax
	leaq	1(%rax,%r13), %r9
	cmovbq	%r9, %rax
	movl	%edx, %edx
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	cmpq	%r13, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaq	%rdx, %rax
	movl	$7, %edx
	mulq	%rdx
	movl	$7, %esi
	movq	%rax, %r9
	imulq	%rbx, %rdx
	addq	%rdx, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	cmpq	%r13, %r9
	leaq	(%r9,%rbx), %rax
	cmovaq	%rax, %r9
	addq	%r11, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	cmpq	%r13, %r9
	leaq	(%r9,%rbx), %rax
	cmovaq	%rax, %r9
	movq	%r9, %rax
	mulq	32(%rsp)
	movq	%rax, %r11
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r11
	leaq	1(%r11,%r13), %rax
	cmovbq	%rax, %r11
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r11
	leaq	(%r11,%rbx), %rax
	cmovbq	%rax, %r11
	cmpq	%r13, %r11
	leaq	(%r11,%rbx), %rax
	cmovaq	%rax, %r11
	movq	%r10, %rax
	mulq	%rcx
	movq	%rax, %r14
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r14
	leaq	1(%r14,%r13), %rax
	cmovbq	%rax, %r14
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r14
	leaq	(%r14,%rbx), %rax
	cmovbq	%rax, %r14
	cmpq	%r13, %r14
	leaq	(%r14,%rbx), %rax
	cmovaq	%rax, %r14
	movq	%r8, %rax
	mulq	%r12
	movq	%rax, %r10
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r10
	leaq	1(%r10,%r13), %rax
	cmovbq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmovbq	%rax, %r10
	cmpq	%r13, %r10
	leaq	(%r10,%rbx), %rax
	cmovaq	%rax, %r10
	addq	%r14, %r10
	leaq	(%r10,%rbx), %rax
	cmovbq	%rax, %r10
	cmpq	%r13, %r10
	leaq	(%r10,%rbx), %rax
	cmovaq	%rax, %r10
	movq	%r10, %rax
	movq	24(%rsp), %r14
	mulq	%r14
	movq	%r14, 24(%rsp)
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r13), %rcx
	cmovbq	%rcx, %rax
	movl	%edx, %ecx
	imulq	%rbx, %rcx
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbq	%rcx, %rax
	cmpq	%r13, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaq	%rcx, %rax
	mulq	%rsi
	movq	%rax, %r8
	imulq	%rbx, %rdx
	addq	%rdx, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	cmpq	%r13, %r8
	leaq	(%r8,%rbx), %rax
	cmovaq	%rax, %r8
	addq	%r11, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	cmpq	%r13, %r8
	leaq	(%r8,%rbx), %rax
	cmovaq	%rax, %r8
	movq	248(%rdi), %rsi
	movq	%rsi, %rax
	mulq	80(%rsp)
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r13), %rcx
	cmovaeq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r13, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	movq	72(%rsp), %r11
	addq	8(%r11,%rbp), %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r13, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	subq	264(%rdi), %rax
	leaq	1(%rax,%r13), %r12
	cmovaeq	%rax, %r12
	movq	%r8, %rax
	mulq	%r12
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r13), %rcx
	cmovaeq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r13, %rdx
	leaq	(%rdx,%rbx), %rcx
	cmovbeq	%rdx, %rcx
	movq	%r9, %rax
	mulq	%r14
	movq	%rax, %r14
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r14
	leaq	1(%r14,%r13), %rax
	cmovbq	%rax, %r14
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r14
	leaq	(%r14,%rbx), %rax
	cmovbq	%rax, %r14
	cmpq	%r13, %r14
	leaq	(%r14,%rbx), %rax
	cmovaq	%rax, %r14
	movq	%r10, %rax
	mulq	32(%rsp)
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r13), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	cmpq	%r13, %r9
	leaq	(%r9,%rbx), %rax
	cmovaq	%rax, %r9
	addq	%r14, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	cmpq	%r13, %r9
	leaq	(%r9,%rbx), %rax
	cmovaq	%rax, %r9
	movq	%rsi, %rax
	mulq	88(%rsp)
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%r13), %r10
	cmovaeq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r10, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r13, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	(%r11,%rbp), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r13, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	subq	256(%rdi), %rax
	leaq	1(%rax,%r13), %rdi
	cmovaeq	%rax, %rdi
	movq	%r9, %rax
	mulq	%rdi
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%r13), %r10
	cmovaeq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r10, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r13, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r13, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	addq	16(%rsp), %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r13, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	movq	%rax, 16(%rsp)
	movq	56(%rsp), %rax
	mulq	%r15
	movq	%rax, %rcx
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rcx
	leaq	1(%rcx,%r13), %rax
	cmovbq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	cmpq	%r13, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaq	%rax, %rcx
	movq	48(%rsp), %rax
	mulq	40(%rsp)
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%r13), %rsi
	cmovbq	%rsi, %rax
	movl	%edx, %edx
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	cmpq	%r13, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaq	%rdx, %rax
	movl	$7, %r10d
	mulq	%r10
	movq	%rax, %rsi
	imulq	%rbx, %rdx
	addq	%rdx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	cmpq	%r13, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovaq	%rax, %rsi
	addq	%rcx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	cmpq	%r13, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	mulq	%rdi
	movq	%rax, %rdi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rdi
	leaq	1(%rdi,%r13), %rax
	cmovbq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r13, %rdi
	cmovaq	%rax, %rdi
	movq	%r9, %rax
	mulq	%r12
	movl	%edx, %ecx
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r13), %rdx
	cmovbq	%rdx, %rax
	imulq	%rbx, %rcx
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r13, %rax
	cmovaq	%rcx, %rax
	mulq	%r10
	movl	$7, %r15d
	movq	%rax, %rcx
	imulq	%rbx, %rdx
	addq	%rdx, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmpq	%r13, %rcx
	cmovaq	%rax, %rcx
	addq	%rdi, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmpq	%r13, %rcx
	cmovaq	%rax, %rcx
	addq	%rsi, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmpq	%r13, %rcx
	cmovaq	%rax, %rcx
	movq	8(%rsp), %r8
	movq	16(%r8), %r14
	movq	32(%r11), %rdi
	movq	%rdi, %rax
	mulq	%r14
	movq	%rax, %rsi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rsi
	leaq	1(%rsi,%r13), %rax
	cmovbq	%rax, %rsi
	movl	%edx, %eax
	movq	24(%r8), %r10
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r13, %rsi
	cmovaq	%rax, %rsi
	movq	40(%r11), %r9
	movq	%r9, %rax
	mulq	%r10
	movq	%rax, %r8
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r8
	leaq	1(%r8,%r13), %rax
	cmovbq	%rax, %r8
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	cmpq	%r13, %r8
	leaq	(%r8,%rbx), %rax
	cmovaq	%rax, %r8
	movq	%r9, %rax
	mulq	%r14
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r13), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmpq	%r13, %r9
	cmovaq	%rax, %r9
	movq	%rdi, %rax
	mulq	%r10
	movq	%rax, %r10
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %r10
	leaq	1(%r10,%r13), %rdx
	cmovbq	%rdx, %r10
	imulq	%rbx, %rax
	addq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmovbq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmpq	%r13, %r10
	cmovaq	%rax, %r10
	movq	%r8, %rax
	mulq	%r15
	movq	%rax, %rdi
	imulq	%rbx, %rdx
	addq	%rdx, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r13, %rdi
	cmovaq	%rax, %rdi
	addq	%rsi, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r13, %rdi
	cmovaq	%rax, %rdi
	addq	%r9, %r10
	leaq	(%r10,%rbx), %rax
	cmovaeq	%r10, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%r13, %rax
	cmovbeq	%rax, %r8
	movq	%rdi, %rax
	movq	32(%rsp), %r14
	mulq	%r14
	movq	%rax, %rsi
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rsi
	leaq	1(%rsi,%r13), %rdx
	cmovbq	%rdx, %rsi
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r13, %rsi
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	movq	24(%rsp), %r10
	mulq	%r10
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r13), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmpq	%r13, %r9
	cmovaq	%rax, %r9
	movq	%rdi, %rax
	mulq	%r10
	movq	%rax, %r10
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r10
	leaq	1(%r10,%r13), %rax
	cmovbq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmovbq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmpq	%r13, %r10
	cmovaq	%rax, %r10
	movq	%r8, %rax
	mulq	%r14
	movq	%rax, %r8
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %r8
	leaq	1(%r8,%r13), %rdx
	cmovbq	%rdx, %r8
	imulq	%rbx, %rax
	addq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmpq	%r13, %r8
	cmovaq	%rax, %r8
	movq	%r9, %rax
	mulq	%r15
	movq	%rax, %rdi
	imulq	%rbx, %rdx
	addq	%rdx, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r13, %rdi
	cmovaq	%rax, %rdi
	addq	%rsi, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r13, %rdi
	cmovaq	%rax, %rdi
	addq	%r10, %r8
	leaq	(%r8,%rbx), %rax
	cmovaeq	%r8, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%r13, %rax
	cmovbeq	%rax, %r8
	movq	%rdi, %rax
	movq	104(%rsp), %r10
	mulq	%r10
	movq	%rax, %rsi
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rsi
	leaq	1(%rsi,%r13), %rdx
	cmovbq	%rdx, %rsi
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r13, %rsi
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	movq	96(%rsp), %r14
	mulq	%r14
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r13), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmpq	%r13, %r9
	cmovaq	%rax, %r9
	movq	%rdi, %rax
	mulq	%r14
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r13), %rdi
	cmovaeq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rdi
	cmpq	%r13, %rdx
	cmovbeq	%rdx, %rdi
	movq	%r8, %rax
	mulq	%r10
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r13), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r8, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %r8
	cmpq	%r13, %rdx
	cmovbeq	%rdx, %r8
	movq	%r9, %rax
	mulq	%r15
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r13, %rax
	cmovaq	%rdx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r13, %rax
	cmovaq	%rdx, %rax
	addq	%rdi, %r8
	leaq	(%r8,%rbx), %rdx
	cmovaeq	%r8, %rdx
	leaq	(%rdx,%rbx), %rsi
	cmpq	%r13, %rdx
	cmovbeq	%rdx, %rsi
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r13, %rax
	cmovaq	%rcx, %rax
	addq	16(%rsp), %rsi
	leaq	(%rsi,%rbx), %rcx
	cmovaeq	%rsi, %rcx
	addq	%rcx, %rbx
	cmpq	%r13, %rcx
	cmovbeq	%rcx, %rbx
	movq	%rbx, %rdx
	addq	$312, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%r12
	.cfi_def_cfa_offset 40
	popq	%r13
	.cfi_def_cfa_offset 32
	popq	%r14
	.cfi_def_cfa_offset 24
	popq	%r15
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	retq
.LBB12_24:
	.cfi_def_cfa_offset 368
	leaq	.Lalloc_dd86d8d2da9777486edeb4de51cc3012(%rip), %rcx
	movl	$4, %edi
	movq	%r13, %rsi
	movq	%r13, %rdx
	callq	*_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail@GOTPCREL(%rip)
.LBB12_31:
	leaq	.Lalloc_826b68913cf630c35a865efbea8045e3(%rip), %rdx
	movl	$67, %edi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB12_32:
	leaq	.Lalloc_11ff538006900e8109ee309b459a2f83(%rip), %rdx
	movq	%rbp, %rdi
	movq	%r9, %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB12_33:
	leaq	.Lalloc_826b68913cf630c35a865efbea8045e3(%rip), %rdx
	movl	$69, %edi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB12_34:
	leaq	.Lalloc_11ff538006900e8109ee309b459a2f83(%rip), %rdx
	movq	%rax, %rdi
	movq	%r9, %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB12_35:
	leaq	.Lalloc_826b68913cf630c35a865efbea8045e3(%rip), %rdx
	movl	$70, %edi
	movl	$70, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB12_36:
	leaq	.Lalloc_11ff538006900e8109ee309b459a2f83(%rip), %rdx
	movq	%r8, %rdi
	movq	%r9, %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB12_37:
	leaq	.Lalloc_826b68913cf630c35a865efbea8045e3(%rip), %rdx
	movl	$73, %edi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB12_38:
	leaq	.Lalloc_11ff538006900e8109ee309b459a2f83(%rip), %rdx
	movq	%rcx, %rdi
	movq	8(%rsp), %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB12_11:
	leaq	.Lalloc_8c5249903caae8a4f890768ea185f763(%rip), %rdx
	movq	8(%rsp), %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB12_25:
	leaq	.Lalloc_11ff538006900e8109ee309b459a2f83(%rip), %rdx
	movq	%rbp, %rdi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB12_26:
	leaq	.Lalloc_0f40a973e4ef77172839bcec3485a3cf(%rip), %rdx
	xorl	%edi, %edi
	xorl	%esi, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB12_27:
	leaq	.Lalloc_7893f8279e457884a76b55b3c0e38bce(%rip), %rdx
	movl	$1, %edi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB12_28:
	leaq	.Lalloc_01d88d31381230f5daa9de4874523a4f(%rip), %rdx
	movl	$1, %edi
	movl	$1, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB12_29:
	leaq	.Lalloc_89fc8f3b37234d0552cb47d22f5f3be5(%rip), %rdx
	movl	$2, %edi
	movl	$2, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB12_23:
	leaq	.Lalloc_03bbe1d0fcdbd86f2216092eb0f02e36(%rip), %rdx
	movq	8(%rsp), %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Lfunc_end12:
	.size	_RNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0B3_, .Lfunc_end12-_RNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0B3_
	.cfi_endproc

	.section	.text._RNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0B3_,"ax",@progbits
	.p2align	4
	.type	_RNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0B3_,@function
_RNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0B3_:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	subq	$392, %rsp
	.cfi_def_cfa_offset 448
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%rsi, %r9
	leaq	16(%rdi), %rax
	movq	%rsi, 272(%rsp)
	movq	%rdx, 280(%rsp)
	movq	%rax, 288(%rsp)
	movq	32(%rdi), %rsi
	cmpq	$68, %rsi
	jb	.LBB13_31
	movq	24(%rdi), %rcx
	movq	536(%rcx), %r10
	cmpq	%rdx, %r10
	jae	.LBB13_32
	cmpq	$69, %rsi
	jbe	.LBB13_33
	movq	552(%rcx), %rax
	cmpq	%rdx, %rax
	jae	.LBB13_34
	cmpq	$70, %rsi
	je	.LBB13_35
	movq	560(%rcx), %r8
	cmpq	%rdx, %r8
	jae	.LBB13_36
	cmpq	$73, %rsi
	jbe	.LBB13_37
	movq	%rcx, 80(%rsp)
	movq	584(%rcx), %rcx
	cmpq	%rdx, %rcx
	movq	%rdx, 40(%rsp)
	jae	.LBB13_38
	shlq	$4, %r10
	movq	%r10, 56(%rsp)
	shlq	$4, %rax
	movq	(%r9,%rax), %r11
	movq	8(%r9,%rax), %r10
	shlq	$4, %r8
	movq	(%r9,%r8), %r14
	movabsq	$-4294967296, %r15
	movl	$4294967295, %ebx
	shlq	$4, %rcx
	movq	$0, 32(%rsp)
	movq	%r14, %rax
	movq	%r14, 120(%rsp)
	mulq	%r11
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%r15), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rsi, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	movq	%r9, %rbp
	leaq	(%rax,%rbx), %r9
	cmpq	%r15, %rax
	cmovbeq	%rax, %r9
	movq	8(%rbp,%r8), %r8
	movq	%r8, %rax
	movq	%r8, 112(%rsp)
	mulq	%r10
	movq	%rax, %rsi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rsi
	leaq	1(%rsi,%r15), %rax
	cmovbq	%rax, %rsi
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rdx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r15, %rsi
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	movq	%r11, 232(%rsp)
	mulq	%r11
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r15), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%r8, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%r15, %rax
	cmovbeq	%rax, %r8
	movq	%r14, %rax
	movq	%r10, 240(%rsp)
	mulq	%r10
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%r15), %r10
	cmovaeq	%rax, %r10
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%r10, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r10
	cmpq	%r15, %rax
	cmovbeq	%rax, %r10
	movl	$7, %r11d
	movq	%rsi, %rax
	mulq	%r11
	movq	%rdx, %rsi
	shlq	$32, %rsi
	subq	%rdx, %rsi
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovaeq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r15, %rax
	cmovbeq	%rax, %rdx
	addq	%r9, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r9
	cmpq	%r15, %rax
	cmovbeq	%rax, %r9
	movq	(%rbp,%rcx), %r12
	addq	%r8, %r10
	leaq	(%r10,%rbx), %rax
	cmovaeq	%r10, %rax
	leaq	(%rax,%rbx), %r10
	cmpq	%r15, %rax
	cmovbeq	%rax, %r10
	movq	168(%rdi), %rsi
	movq	%rsi, %rax
	mulq	%r12
	movq	%r12, 16(%rsp)
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r15), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%r8, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r15, %rax
	leaq	(%rax,%rbx), %r14
	cmovbeq	%rax, %r14
	movq	8(%rbp,%rcx), %r13
	movq	176(%rdi), %r8
	movq	%r8, %rax
	mulq	%r13
	movq	%r13, 48(%rsp)
	movq	%rax, %rcx
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rcx
	leaq	1(%rcx,%r15), %rax
	cmovbq	%rax, %rcx
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rdx, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	cmpq	%r15, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaq	%rax, %rcx
	movq	%rsi, %rax
	mulq	%r13
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%r15), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rsi, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r15, %rax
	leaq	(%rax,%rbx), %rsi
	cmovbeq	%rax, %rsi
	movq	%r8, %rax
	mulq	%r12
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r15), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%r8, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r15, %rax
	leaq	(%rax,%rbx), %r8
	cmovbeq	%rax, %r8
	movq	%rcx, %rax
	mulq	%r11
	movq	%rdx, %rcx
	shlq	$32, %rcx
	subq	%rdx, %rcx
	addq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	cmpq	%r15, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbeq	%rax, %rcx
	addq	%r14, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	cmpq	%r15, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbeq	%rax, %rcx
	addq	%rsi, %r8
	leaq	(%r8,%rbx), %rax
	cmovaeq	%r8, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r15, %rax
	cmovbeq	%rax, %rdx
	subq	%rcx, %r9
	leaq	1(%r9,%r15), %r14
	cmovaeq	%r9, %r14
	leaq	152(%rdi), %rsi
	movq	%rsi, 8(%rsp)
	subq	%rdx, %r10
	movq	%rdi, 24(%rsp)
	leaq	1(%r10,%r15), %r12
	movq	%r15, %r13
	cmovaeq	%r10, %r12
	movq	56(%rsp), %rcx
	movq	(%rbp,%rcx), %rax
	movq	%rax, 104(%rsp)
	movq	%rbp, 88(%rsp)
	movq	8(%rbp,%rcx), %rax
	movq	%rax, 56(%rsp)
	leaq	272(%rsp), %r15
	movl	$76, %edx
	movq	%r15, %rdi
	callq	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0s_0B5_
	subq	%rax, %r14
	leaq	1(%r14,%r13), %rax
	cmovaeq	%r14, %rax
	subq	%rdx, %r12
	leaq	1(%r12,%r13), %rcx
	cmovaeq	%r12, %rcx
	movq	24(%rsp), %rdx
	addq	184(%rdx), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmpq	%r13, %rdx
	cmovbeq	%rdx, %rax
	movq	%rax, 72(%rsp)
	movq	24(%rsp), %rax
	addq	192(%rax), %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r13, %rax
	cmovbeq	%rax, %rcx
	movq	%rcx, 64(%rsp)
	leaq	32768(%rbx), %rdx
	movq	120(%rsp), %rcx
	cmpq	$-32768, %rcx
	movl	$32768, %eax
	cmovaeq	%rdx, %rax
	movl	$32768, %r14d
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rbp
	movq	%r13, %r12
	cmpq	%r13, %rax
	cmovbeq	%rax, %rbp
	movq	112(%rsp), %rax
	leaq	(%rax,%rbx), %r13
	cmpq	%r12, %rax
	cmovbeq	%rax, %r13
	movl	$71, %edx
	movq	%r15, %rdi
	movq	8(%rsp), %r15
	movq	%r15, %rsi
	callq	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0s_0B5_
	subq	%rax, %rbp
	movq	%r12, %rcx
	leaq	1(%rbp,%r12), %rax
	cmovaeq	%rbp, %rax
	movq	%rax, 264(%rsp)
	subq	%rdx, %r13
	leaq	1(%r13,%r12), %rbp
	cmovaeq	%r13, %rbp
	movq	16(%rsp), %rax
	cmpq	$-32768, %rax
	leaq	32768(%rbx), %rdx
	cmovaeq	%rdx, %r14
	addq	%rax, %r14
	leaq	(%r14,%rbx), %r12
	cmpq	%rcx, %r14
	cmovbeq	%r14, %r12
	movq	48(%rsp), %rax
	leaq	(%rax,%rbx), %r13
	cmpq	%rax, %rcx
	movq	%rcx, %r14
	movq	%rax, %rcx
	movq	32(%rsp), %rax
	sbbq	%rax, %rax
	cmovaeq	%rcx, %r13
	movl	$74, %edx
	leaq	272(%rsp), %rdi
	movq	%r15, %rsi
	callq	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0s_0B5_
	subq	%rax, %r12
	leaq	1(%r12,%r14), %rcx
	cmovaeq	%r12, %rcx
	movq	24(%rsp), %r11
	subq	%rdx, %r13
	leaq	1(%r13,%r14), %r15
	cmovaeq	%r13, %r15
	movq	200(%r11), %rdi
	movq	40(%rsp), %rsi
	cmpq	%rsi, %rdi
	jae	.LBB13_11
	shlq	$4, %rdi
	movq	88(%rsp), %r9
	movq	(%r9,%rdi), %r8
	movq	8(%r9,%rdi), %rdx
	movq	208(%r11), %rax
	movq	%rax, 16(%rsp)
	movq	216(%r11), %rax
	movq	%rax, 8(%rsp)
	movq	224(%r11), %r12
	movq	232(%r11), %r14
	movq	240(%r11), %r10
	movq	248(%r11), %r13
	cmpb	$0, (%r11)
	movq	%rcx, 256(%rsp)
	movq	%r15, 248(%rsp)
	je	.LBB13_10
	movq	8(%r11), %rdi
	cmpq	%rsi, %rdi
	jae	.LBB13_23
	shlq	$4, %rdi
	movq	(%r9,%rdi), %rax
	movq	8(%r9,%rdi), %rcx
	jmp	.LBB13_13
.LBB13_10:
	movl	$1, %eax
	xorl	%ecx, %ecx
.LBB13_13:
	movq	80(%r11), %r15
	cmpq	$4, %r15
	jb	.LBB13_24
	movq	%r13, 128(%rsp)
	movq	%r12, 136(%rsp)
	movq	%r14, 144(%rsp)
	movq	%r10, 152(%rsp)
	movq	%r8, 160(%rsp)
	movq	%rdx, 168(%rsp)
	movq	%rcx, 96(%rsp)
	movq	%rax, 48(%rsp)
	movq	%rbp, 224(%rsp)
	movq	72(%r11), %rbp
	movq	256(%r11), %r8
	movq	48(%r11), %rdx
	movq	56(%r11), %rcx
	leaq	-4(%r15), %rax
	movq	%rsi, %r14
	leaq	64(%rbp), %r10
	subq	$8, %rsp
	.cfi_adjust_cfa_offset 8
	movq	%r9, %rdi
	movq	%r11, %r13
	movq	%r9, %r12
	movq	24(%rsp), %r9
	pushq	%rax
	.cfi_adjust_cfa_offset 8
	pushq	%r10
	.cfi_adjust_cfa_offset 8
	pushq	32(%rsp)
	.cfi_adjust_cfa_offset 8
	callq	_RNvCsl0YfJI2rrfI_8isolated10helper_sum
	addq	$32, %rsp
	.cfi_adjust_cfa_offset -32
	movq	%rax, 216(%rsp)
	movq	%rdx, 184(%rsp)
	movq	48(%rbp), %rax
	movq	%rax, 192(%rsp)
	movq	56(%rbp), %rax
	movq	%rax, 200(%rsp)
	leaq	88(%r13), %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	callq	_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm4eval
	movq	%rax, 208(%rsp)
	movq	%rdx, 176(%rsp)
	shlq	$4, %r15
	movq	%rbp, 32(%rsp)
	addq	%rbp, %r15
	xorps	%xmm0, %xmm0
	movups	%xmm0, 376(%rsp)
	movq	72(%rsp), %rax
	movq	%rax, 328(%rsp)
	movq	64(%rsp), %rax
	movq	%rax, 336(%rsp)
	movq	264(%rsp), %rax
	movq	%rax, 344(%rsp)
	movq	224(%rsp), %rax
	movq	%rax, 352(%rsp)
	movq	256(%rsp), %rax
	movq	%rax, 360(%rsp)
	movq	248(%rsp), %rax
	movq	%rax, 368(%rsp)
	xorl	%edi, %edi
	xorl	%r8d, %r8d
	xorl	%ecx, %ecx
	movabsq	$-4294967296, %r13
	.p2align	4
.LBB13_15:
	leaq	16(%rdi), %rbp
	cmpq	$64, %rbp
	je	.LBB13_16
	movq	32(%rsp), %rax
	leaq	(%rax,%rdi), %rsi
	movq	328(%rsp,%rdi), %r9
	movq	(%rsi), %r10
	movq	%r10, %rax
	mulq	%r9
	movq	336(%rsp,%rdi), %r12
	movl	%edx, %edi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r13), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rbx, %rdi
	addq	%rdx, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovaeq	%rdi, %rax
	leaq	(%rax,%rbx), %r14
	cmpq	%r13, %rax
	cmovbeq	%rax, %r14
	movq	8(%rsi), %r11
	movq	%r11, %rax
	mulq	%r12
	movq	%rax, %rdi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rdi
	leaq	1(%rdi,%r13), %rax
	cmovbq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r13, %rdi
	cmovaq	%rax, %rdi
	movq	%r10, %rax
	mulq	%r12
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%r13), %r10
	cmovaeq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r10, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %r10
	cmpq	%r13, %rdx
	cmovbeq	%rdx, %r10
	movq	%r11, %rax
	mulq	%r9
	movq	%rdx, %r9
	shrq	$32, %r9
	subq	%r9, %rax
	leaq	1(%rax,%r13), %r9
	cmovaeq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r9, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %r9
	cmpq	%r13, %rdx
	cmovbeq	%rdx, %r9
	movq	%rdi, %rax
	movl	$7, %edx
	mulq	%rdx
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r13, %rax
	cmovbeq	%rax, %rdx
	addq	%r14, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r13, %rax
	cmovbeq	%rax, %rdx
	addq	%r10, %r9
	leaq	(%r9,%rbx), %rax
	cmovaeq	%r9, %rax
	leaq	(%rax,%rbx), %rdi
	cmpq	%r13, %rax
	cmovbeq	%rax, %rdi
	addq	%r8, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%r13, %rax
	cmovbeq	%rax, %r8
	addq	%rcx, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovaeq	%rdi, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r13, %rax
	cmovbeq	%rax, %rcx
	addq	$16, %rsi
	movq	%rbp, %rdi
	cmpq	%r15, %rsi
	jne	.LBB13_15
.LBB13_16:
	movq	80(%rsp), %rax
	movq	544(%rax), %rdi
	movq	40(%rsp), %rsi
	cmpq	%rsi, %rdi
	jae	.LBB13_25
	movq	24(%rsp), %rax
	movq	144(%rax), %rax
	testq	%rax, %rax
	je	.LBB13_26
	cmpq	$1, %rsi
	jbe	.LBB13_27
	cmpq	$1, %rax
	je	.LBB13_28
	cmpq	$2, %rsi
	je	.LBB13_29
	shlq	$4, %rdi
	movq	%rdi, 32(%rsp)
	movabsq	$-4294967296, %r12
	movq	56(%rsp), %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rsi
	cmovbeq	%rax, %rsi
	movq	136(%rsp), %r13
	movq	%r13, %rax
	movq	240(%rsp), %r11
	mulq	%r11
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r12), %rdi
	cmovaeq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rdi
	cmovbeq	%rdx, %rdi
	movq	144(%rsp), %r15
	movq	%r15, %rax
	movq	232(%rsp), %r14
	mulq	%r14
	movq	%rdx, %r9
	shrq	$32, %r9
	subq	%r9, %rax
	leaq	1(%rax,%r12), %r9
	cmovaeq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r9, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	128(%rsp), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	movq	8(%rsp), %rdx
	subq	%rax, %rdx
	leaq	1(%rdx,%r12), %r10
	cmovaeq	%rdx, %r10
	movq	%r10, %rax
	movq	160(%rsp), %rbp
	mulq	%rbp
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%r12), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rsi
	cmovbeq	%rdx, %rsi
	movq	104(%rsp), %rdi
	cmpq	$-128, %rdi
	leaq	128(%rbx), %rax
	movl	$128, %edx
	cmovaeq	%rax, %rdx
	addq	%rdi, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rdi
	cmovbeq	%rdx, %rdi
	movq	%r13, %rax
	mulq	%r14
	movq	%rdx, %r9
	shrq	$32, %r9
	subq	%r9, %rax
	leaq	1(%rax,%r12), %r9
	cmovaeq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r9, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %r9
	cmovbeq	%rdx, %r9
	movq	%r15, %rax
	mulq	%r11
	movq	%rdx, %r11
	shrq	$32, %r11
	subq	%r11, %rax
	leaq	1(%rax,%r12), %r11
	cmovbq	%r11, %rax
	movl	%edx, %edx
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaq	%rdx, %rax
	movl	$7, %edx
	mulq	%rdx
	movl	$7, %r14d
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	addq	%r9, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	addq	%rdi, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	addq	152(%rsp), %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	movq	16(%rsp), %rax
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %r11
	cmovaeq	%rax, %r11
	movq	%r11, %rax
	movq	168(%rsp), %r13
	mulq	%r13
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r12), %rdi
	cmovaeq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rdi
	cmovbeq	%rdx, %rdi
	movq	192(%rsp), %r15
	movq	%r15, %rax
	mulq	%rdi
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%r12), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rsi
	cmovbeq	%rdx, %rsi
	movq	%r11, %rax
	mulq	%rbp
	movq	%rdx, %r9
	shrq	$32, %r9
	subq	%r9, %rax
	leaq	1(%rax,%r12), %r9
	cmovaeq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r9, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %r9
	cmovbeq	%rdx, %r9
	movq	%r10, %rax
	mulq	%r13
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%r12), %r10
	cmovbq	%r10, %rax
	movl	%edx, %edx
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaq	%rdx, %rax
	mulq	%r14
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	addq	%r9, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %r9
	cmovbeq	%rax, %r9
	subq	$1, %r9
	cmovbq	%r12, %r9
	movq	200(%rsp), %r13
	movq	%r13, %rax
	mulq	%r9
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%r12), %r10
	cmovaeq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r10, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	184(%rsp), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	176(%rsp), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rsi
	cmovbeq	%rdx, %rsi
	movq	%rcx, %rax
	movq	48(%rsp), %rbp
	mulq	%rbp
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%r12), %r10
	cmovaeq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r10, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %r10
	cmovbeq	%rdx, %r10
	movq	%r8, %rax
	movq	96(%rsp), %r14
	mulq	%r14
	movq	%rdx, %r11
	shrq	$32, %r11
	subq	%r11, %rax
	leaq	1(%rax,%r12), %r11
	cmovaeq	%rax, %r11
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r11, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%r10, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rsi
	cmovbeq	%rdx, %rsi
	movq	%rsi, 40(%rsp)
	movq	88(%rsp), %r11
	movq	(%r11), %rax
	movq	%rax, 16(%rsp)
	mulq	%rsi
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%r12), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rsi
	cmovbeq	%rdx, %rsi
	movq	%r15, %rax
	mulq	%r9
	movq	%rdx, %r9
	shrq	$32, %r9
	subq	%r9, %rax
	leaq	1(%rax,%r12), %r9
	cmovaeq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r9, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %r9
	cmovbeq	%rdx, %r9
	movq	%r13, %rax
	mulq	%rdi
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r12), %rdi
	cmovbq	%rdi, %rax
	movl	%edx, %edx
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaq	%rdx, %rax
	movl	$7, %r10d
	mulq	%r10
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	addq	%r9, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	addq	216(%rsp), %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	addq	208(%rsp), %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdi
	cmovbeq	%rax, %rdi
	movq	%r8, %rax
	mulq	%rbp
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r12), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r8, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %r8
	cmovbeq	%rdx, %r8
	movq	%rcx, %rax
	mulq	%r14
	movq	%r14, %r9
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r12), %rcx
	cmovbq	%rcx, %rax
	movl	%edx, %ecx
	imulq	%rbx, %rcx
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbq	%rcx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaq	%rcx, %rax
	mulq	%r10
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbeq	%rax, %rcx
	addq	%r8, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbeq	%rax, %rcx
	addq	%rdi, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbeq	%rax, %rcx
	movq	%rcx, 72(%rsp)
	movq	%r11, %r13
	movq	8(%r11), %rax
	movq	%rax, 80(%rsp)
	mulq	%rcx
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r12), %rcx
	cmovaeq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r12, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r12, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	movq	%rax, 64(%rsp)
	movq	24(%rsp), %rax
	movq	136(%rax), %r8
	movq	(%r8), %rcx
	movq	%r8, 8(%rsp)
	movq	16(%r11), %rsi
	movq	%rsi, %rax
	mulq	%rcx
	movq	%rax, %r11
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r11
	leaq	1(%r11,%r12), %rax
	cmovbq	%rax, %r11
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r11
	leaq	(%r11,%rbx), %rax
	cmovbq	%rax, %r11
	cmpq	%r12, %r11
	leaq	(%r11,%rbx), %rax
	cmovaq	%rax, %r11
	movq	8(%r8), %r15
	movq	24(%r13), %r10
	movq	%r10, %rax
	mulq	%r15
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r12), %r8
	cmovbq	%r8, %rax
	movl	%edx, %edx
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaq	%rdx, %rax
	movl	$7, %edi
	mulq	%rdi
	movq	%rax, %r8
	imulq	%rbx, %rdx
	addq	%rdx, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	cmpq	%r12, %r8
	leaq	(%r8,%rbx), %rax
	cmovaq	%rax, %r8
	addq	%r11, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	cmpq	%r12, %r8
	leaq	(%r8,%rbx), %rax
	cmovaq	%rax, %r8
	movq	%r8, %rax
	mulq	%rbp
	movq	%rax, %r11
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r11
	leaq	1(%r11,%r12), %rax
	cmovbq	%rax, %r11
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r11
	leaq	(%r11,%rbx), %rax
	cmovbq	%rax, %r11
	cmpq	%r12, %r11
	leaq	(%r11,%rbx), %rax
	cmovaq	%rax, %r11
	movq	%r10, %rax
	mulq	%rcx
	movq	%rax, %r14
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r14
	leaq	1(%r14,%r12), %rax
	cmovbq	%rax, %r14
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r14
	leaq	(%r14,%rbx), %rax
	cmovbq	%rax, %r14
	cmpq	%r12, %r14
	leaq	(%r14,%rbx), %rax
	cmovaq	%rax, %r14
	movq	%rsi, %rax
	mulq	%r15
	movq	%rax, %r10
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r10
	leaq	1(%r10,%r12), %rax
	cmovbq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmovbq	%rax, %r10
	cmpq	%r12, %r10
	leaq	(%r10,%rbx), %rax
	cmovaq	%rax, %r10
	addq	%r14, %r10
	leaq	(%r10,%rbx), %rax
	cmovbq	%rax, %r10
	cmpq	%r12, %r10
	leaq	(%r10,%rbx), %rax
	cmovaq	%rax, %r10
	movq	%r10, %rax
	mulq	%r9
	movq	%r9, %r14
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r12), %rcx
	cmovbq	%rcx, %rax
	movl	%edx, %ecx
	imulq	%rbx, %rcx
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbq	%rcx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaq	%rcx, %rax
	mulq	%rdi
	movq	%rax, %rsi
	imulq	%rbx, %rdx
	addq	%rdx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	cmpq	%r12, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovaq	%rax, %rsi
	addq	%r11, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	cmpq	%r12, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovaq	%rax, %rsi
	movq	24(%rsp), %rdi
	movq	264(%rdi), %rbp
	movq	%rbp, %rax
	mulq	56(%rsp)
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r12), %rcx
	cmovaeq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rcx
	cmovbeq	%rdx, %rcx
	movq	272(%rdi), %r11
	movq	%r11, %rax
	movq	104(%rsp), %r9
	mulq	%r9
	movq	%rdx, %r15
	shrq	$32, %r15
	subq	%r15, %rax
	leaq	1(%rax,%r12), %r15
	cmovaeq	%rax, %r15
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r15, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r12, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	movq	32(%rsp), %rcx
	addq	8(%r13,%rcx), %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r12, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	subq	288(%rdi), %rax
	leaq	1(%rax,%r12), %rcx
	cmovaeq	%rax, %rcx
	movq	%rsi, %rax
	mulq	%rcx
	movq	%rdx, %r15
	shrq	$32, %r15
	subq	%r15, %rax
	leaq	1(%rax,%r12), %r15
	cmovaeq	%rax, %r15
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r15, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %r13
	cmovbeq	%rdx, %r13
	movq	%r8, %rax
	mulq	%r14
	movq	%rax, %r15
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r15
	leaq	1(%r15,%r12), %rax
	cmovbq	%rax, %r15
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r15
	leaq	(%r15,%rbx), %rax
	cmovbq	%rax, %r15
	cmpq	%r12, %r15
	leaq	(%r15,%rbx), %rax
	cmovaq	%rax, %r15
	movq	%r10, %rax
	mulq	48(%rsp)
	movq	%rax, %r8
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r8
	leaq	1(%r8,%r12), %rax
	cmovbq	%rax, %r8
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	cmpq	%r12, %r8
	leaq	(%r8,%rbx), %rax
	cmovaq	%rax, %r8
	addq	%r15, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	cmpq	%r12, %r8
	leaq	(%r8,%rbx), %rax
	cmovaq	%rax, %r8
	movq	%rbp, %rax
	mulq	%r9
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%r12), %r10
	cmovaeq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r10, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %r10
	cmovbeq	%rdx, %r10
	movq	%r11, %rax
	mulq	56(%rsp)
	movq	%rdx, %r11
	shrq	$32, %r11
	subq	%r11, %rax
	leaq	1(%rax,%r12), %r11
	cmovbq	%r11, %rax
	movl	%edx, %edx
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaq	%rdx, %rax
	movl	$7, %edx
	mulq	%rdx
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	addq	%r10, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	movq	88(%rsp), %r15
	movq	32(%rsp), %rax
	addq	(%r15,%rax), %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	subq	280(%rdi), %rdx
	leaq	1(%rdx,%r12), %r10
	cmovaeq	%rdx, %r10
	movq	%r8, %rax
	mulq	%r10
	movq	%rdx, %r11
	shrq	$32, %r11
	subq	%r11, %rax
	leaq	1(%rax,%r12), %r11
	cmovaeq	%rax, %r11
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r11, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%r13, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	64(%rsp), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %r11
	cmovbeq	%rdx, %r11
	movq	16(%rsp), %rax
	mulq	72(%rsp)
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r12), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	cmpq	%r12, %r9
	leaq	(%r9,%rbx), %rax
	cmovaq	%rax, %r9
	movq	80(%rsp), %rax
	mulq	40(%rsp)
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r12), %rdi
	cmovbq	%rdi, %rax
	movl	%edx, %edx
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaq	%rdx, %rax
	movl	$7, %r14d
	mulq	%r14
	movq	%rax, %rdi
	imulq	%rbx, %rdx
	addq	%rdx, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	cmpq	%r12, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovaq	%rax, %rdi
	addq	%r9, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	cmpq	%r12, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovaq	%rax, %rdi
	movq	%rsi, %rax
	mulq	%r10
	movq	%rax, %rsi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rsi
	leaq	1(%rsi,%r12), %rax
	cmovbq	%rax, %rsi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r12, %rsi
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	mulq	%rcx
	movl	%edx, %ecx
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %rdx
	cmovbq	%rdx, %rax
	imulq	%rbx, %rcx
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r12, %rax
	cmovaq	%rcx, %rax
	mulq	%r14
	movl	$7, %r13d
	movq	%rax, %rcx
	imulq	%rbx, %rdx
	addq	%rdx, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmpq	%r12, %rcx
	cmovaq	%rax, %rcx
	addq	%rsi, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmpq	%r12, %rcx
	cmovaq	%rax, %rcx
	addq	%rdi, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmpq	%r12, %rcx
	cmovaq	%rax, %rcx
	movq	8(%rsp), %r8
	movq	16(%r8), %r14
	movq	32(%r15), %rdi
	movq	%rdi, %rax
	mulq	%r14
	movq	%rax, %rsi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rsi
	leaq	1(%rsi,%r12), %rax
	cmovbq	%rax, %rsi
	movl	%edx, %eax
	movq	24(%r8), %r10
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r12, %rsi
	cmovaq	%rax, %rsi
	movq	40(%r15), %r9
	movq	%r9, %rax
	mulq	%r10
	movq	%rax, %r8
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r8
	leaq	1(%r8,%r12), %rax
	cmovbq	%rax, %r8
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	cmpq	%r12, %r8
	leaq	(%r8,%rbx), %rax
	cmovaq	%rax, %r8
	movq	%r9, %rax
	mulq	%r14
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r12), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmpq	%r12, %r9
	cmovaq	%rax, %r9
	movq	%rdi, %rax
	mulq	%r10
	movq	%rax, %r10
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %r10
	leaq	1(%r10,%r12), %rdx
	cmovbq	%rdx, %r10
	imulq	%rbx, %rax
	addq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmovbq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmpq	%r12, %r10
	cmovaq	%rax, %r10
	movq	%r8, %rax
	mulq	%r13
	movq	%rax, %rdi
	imulq	%rbx, %rdx
	addq	%rdx, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r12, %rdi
	cmovaq	%rax, %rdi
	addq	%rsi, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r12, %rdi
	cmovaq	%rax, %rdi
	addq	%r9, %r10
	leaq	(%r10,%rbx), %rax
	cmovaeq	%r10, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%r12, %rax
	cmovbeq	%rax, %r8
	movq	%rdi, %rax
	movq	48(%rsp), %r14
	mulq	%r14
	movq	%rax, %rsi
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rsi
	leaq	1(%rsi,%r12), %rdx
	cmovbq	%rdx, %rsi
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r12, %rsi
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	movq	96(%rsp), %r10
	mulq	%r10
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r12), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmpq	%r12, %r9
	cmovaq	%rax, %r9
	movq	%rdi, %rax
	mulq	%r10
	movq	%rax, %r10
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r10
	leaq	1(%r10,%r12), %rax
	cmovbq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmovbq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmpq	%r12, %r10
	cmovaq	%rax, %r10
	movq	%r8, %rax
	mulq	%r14
	movq	%rax, %r8
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %r8
	leaq	1(%r8,%r12), %rdx
	cmovbq	%rdx, %r8
	imulq	%rbx, %rax
	addq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmpq	%r12, %r8
	cmovaq	%rax, %r8
	movq	%r9, %rax
	mulq	%r13
	movq	%rax, %rdi
	imulq	%rbx, %rdx
	addq	%rdx, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r12, %rdi
	cmovaq	%rax, %rdi
	addq	%rsi, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r12, %rdi
	cmovaq	%rax, %rdi
	addq	%r10, %r8
	leaq	(%r8,%rbx), %rax
	cmovaeq	%r8, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%r12, %rax
	cmovbeq	%rax, %r8
	movq	%rdi, %rax
	movq	120(%rsp), %r10
	mulq	%r10
	movq	%rax, %rsi
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rsi
	leaq	1(%rsi,%r12), %rdx
	cmovbq	%rdx, %rsi
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r12, %rsi
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	movq	112(%rsp), %r14
	mulq	%r14
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r12), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmpq	%r12, %r9
	cmovaq	%rax, %r9
	movq	%rdi, %rax
	mulq	%r14
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r12), %rdi
	cmovaeq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rdi
	cmpq	%r12, %rdx
	cmovbeq	%rdx, %rdi
	movq	%r8, %rax
	mulq	%r10
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r12), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r8, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %r8
	cmpq	%r12, %rdx
	cmovbeq	%rdx, %r8
	movq	%r9, %rax
	mulq	%r13
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r12, %rax
	cmovaq	%rdx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r12, %rax
	cmovaq	%rdx, %rax
	addq	%rdi, %r8
	leaq	(%r8,%rbx), %rdx
	cmovaeq	%r8, %rdx
	leaq	(%rdx,%rbx), %rsi
	cmpq	%r12, %rdx
	cmovbeq	%rdx, %rsi
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r12, %rax
	cmovaq	%rcx, %rax
	addq	%r11, %rsi
	leaq	(%rsi,%rbx), %rcx
	cmovaeq	%rsi, %rcx
	addq	%rcx, %rbx
	cmpq	%r12, %rcx
	cmovbeq	%rcx, %rbx
	movq	%rbx, %rdx
	addq	$392, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%r12
	.cfi_def_cfa_offset 40
	popq	%r13
	.cfi_def_cfa_offset 32
	popq	%r14
	.cfi_def_cfa_offset 24
	popq	%r15
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	retq
.LBB13_24:
	.cfi_def_cfa_offset 448
	leaq	.Lalloc_783adf84c4437dc3f5e730641bb4655a(%rip), %rcx
	movl	$4, %edi
	movq	%r15, %rsi
	movq	%r15, %rdx
	callq	*_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail@GOTPCREL(%rip)
.LBB13_31:
	leaq	.Lalloc_623270749f7c2c7eb7abf12a5ce81bec(%rip), %rdx
	movl	$67, %edi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB13_32:
	movq	%rdx, %rsi
	leaq	.Lalloc_23cbb2e7863b02fb8b64518d13a27720(%rip), %rdx
	movq	%r10, %rdi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB13_33:
	leaq	.Lalloc_623270749f7c2c7eb7abf12a5ce81bec(%rip), %rdx
	movl	$69, %edi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB13_34:
	movq	%rdx, %rsi
	leaq	.Lalloc_23cbb2e7863b02fb8b64518d13a27720(%rip), %rdx
	movq	%rax, %rdi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB13_35:
	leaq	.Lalloc_623270749f7c2c7eb7abf12a5ce81bec(%rip), %rdx
	movl	$70, %edi
	movl	$70, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB13_36:
	movq	%rdx, %rsi
	leaq	.Lalloc_23cbb2e7863b02fb8b64518d13a27720(%rip), %rdx
	movq	%r8, %rdi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB13_37:
	leaq	.Lalloc_623270749f7c2c7eb7abf12a5ce81bec(%rip), %rdx
	movl	$73, %edi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB13_38:
	leaq	.Lalloc_23cbb2e7863b02fb8b64518d13a27720(%rip), %rdx
	movq	%rcx, %rdi
	movq	40(%rsp), %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB13_11:
	leaq	.Lalloc_33f4d218739df51bc601f47114eed12f(%rip), %rdx
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB13_25:
	leaq	.Lalloc_23cbb2e7863b02fb8b64518d13a27720(%rip), %rdx
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB13_26:
	leaq	.Lalloc_80ab1297b78c18879967432c54c1e54e(%rip), %rdx
	xorl	%edi, %edi
	xorl	%esi, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB13_27:
	leaq	.Lalloc_f604f896c68dd8f0a4007dacc23397d5(%rip), %rdx
	movl	$1, %edi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB13_28:
	leaq	.Lalloc_18a70e0bda0ee5b1c3fd14bc973a5c99(%rip), %rdx
	movl	$1, %edi
	movl	$1, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB13_29:
	leaq	.Lalloc_f3da9c566178cc480d49fd92cad34aad(%rip), %rdx
	movl	$2, %edi
	movl	$2, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB13_23:
	leaq	.Lalloc_03bbe1d0fcdbd86f2216092eb0f02e36(%rip), %rdx
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Lfunc_end13:
	.size	_RNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0B3_, .Lfunc_end13-_RNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0B3_
	.cfi_endproc

	.section	.text._RNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0B3_,"ax",@progbits
	.p2align	4
	.type	_RNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0B3_,@function
_RNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0B3_:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	subq	$392, %rsp
	.cfi_def_cfa_offset 448
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%rsi, %r9
	leaq	16(%rdi), %rax
	movq	%rsi, 272(%rsp)
	movq	%rdx, 280(%rsp)
	movq	%rax, 288(%rsp)
	movq	32(%rdi), %rsi
	cmpq	$68, %rsi
	jb	.LBB14_31
	movq	%rdi, %r12
	movq	24(%rdi), %rcx
	movq	536(%rcx), %rdi
	cmpq	%rdx, %rdi
	jae	.LBB14_32
	cmpq	$69, %rsi
	jbe	.LBB14_33
	movq	552(%rcx), %rax
	cmpq	%rdx, %rax
	jae	.LBB14_34
	cmpq	$70, %rsi
	je	.LBB14_35
	movq	560(%rcx), %r8
	cmpq	%rdx, %r8
	jae	.LBB14_36
	cmpq	$73, %rsi
	jbe	.LBB14_37
	movq	%rcx, 72(%rsp)
	movq	584(%rcx), %rcx
	cmpq	%rdx, %rcx
	movq	%rdx, 24(%rsp)
	jae	.LBB14_38
	shlq	$4, %rdi
	shlq	$4, %rax
	movq	(%r9,%rax), %r10
	movq	8(%r9,%rax), %r11
	shlq	$4, %r8
	movq	(%r9,%r8), %r14
	movabsq	$-4294967296, %rbp
	movl	$4294967295, %ebx
	shlq	$4, %rcx
	movq	$0, 48(%rsp)
	movq	%r14, %rax
	mulq	%r10
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%rbp), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rsi, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	movq	%r9, %r13
	leaq	(%rax,%rbx), %r9
	cmpq	%rbp, %rax
	cmovbeq	%rax, %r9
	movq	8(%r13,%r8), %r8
	movq	%r8, %rax
	movq	%r8, 112(%rsp)
	mulq	%r11
	movq	%rax, %rsi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rsi
	leaq	1(%rsi,%rbp), %rax
	cmovbq	%rax, %rsi
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rdx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%rbp, %rsi
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	movq	%r10, 224(%rsp)
	mulq	%r10
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%rbp), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%r8, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r10
	cmpq	%rbp, %rax
	cmovbeq	%rax, %r10
	movq	%r14, %rax
	movq	%r11, 232(%rsp)
	mulq	%r11
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%rbp), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%r8, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r11
	cmpq	%rbp, %rax
	cmovbeq	%rax, %r11
	movl	$7, %edx
	movq	%rsi, %rax
	mulq	%rdx
	movq	%rdx, %rsi
	shlq	$32, %rsi
	subq	%rdx, %rsi
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovaeq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%rbp, %rax
	cmovbeq	%rax, %rdx
	movq	(%r13,%rcx), %r15
	movq	%r15, 32(%rsp)
	addq	%r9, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%rbp, %rax
	cmovbeq	%rax, %r8
	addq	%r10, %r11
	leaq	(%r11,%rbx), %rax
	cmovaeq	%r11, %rax
	leaq	(%rax,%rbx), %r9
	cmpq	%rbp, %rax
	cmovbeq	%rax, %r9
	movq	160(%r12), %rsi
	movq	%rsi, %rax
	mulq	%r15
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%rbp), %r10
	cmovaeq	%rax, %r10
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%r10, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r10
	cmpq	%rbp, %rax
	cmovbeq	%rax, %r10
	movq	8(%r13,%rcx), %rcx
	movq	%rcx, 16(%rsp)
	movq	%rsi, %rax
	mulq	%rcx
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%rbp), %rcx
	cmovaeq	%rax, %rcx
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rcx, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%rbp, %rax
	cmovbeq	%rax, %rcx
	subq	%r10, %r8
	leaq	1(%r8,%rbp), %r15
	cmovaeq	%r8, %r15
	leaq	152(%r12), %rsi
	movq	%rsi, 8(%rsp)
	subq	%rcx, %r9
	movq	%r12, 40(%rsp)
	leaq	1(%r9,%rbp), %r12
	cmovaeq	%r9, %r12
	movq	(%r13,%rdi), %rax
	movq	%rax, 104(%rsp)
	movq	%r13, 80(%rsp)
	movq	8(%r13,%rdi), %rax
	movq	%rax, 96(%rsp)
	leaq	272(%rsp), %rdi
	movl	$76, %edx
	callq	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0s_0B5_
	subq	%rax, %r15
	leaq	1(%r15,%rbp), %rax
	cmovaeq	%r15, %rax
	subq	%rdx, %r12
	leaq	1(%r12,%rbp), %rcx
	cmovaeq	%r12, %rcx
	movq	40(%rsp), %rdx
	addq	168(%rdx), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmpq	%rbp, %rdx
	cmovbeq	%rdx, %rax
	movq	%rax, 64(%rsp)
	movq	40(%rsp), %rax
	addq	176(%rax), %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%rbp, %rax
	cmovbeq	%rax, %rcx
	movq	%rcx, 56(%rsp)
	leaq	32768(%rbx), %rcx
	cmpq	$-32768, %r14
	movl	$32768, %eax
	cmovaeq	%rcx, %rax
	movl	$32768, %r15d
	movq	%r14, 240(%rsp)
	addq	%r14, %rax
	leaq	(%rax,%rbx), %r13
	movq	%rbp, %r12
	cmpq	%rbp, %rax
	cmovbeq	%rax, %r13
	movq	112(%rsp), %rax
	leaq	(%rax,%rbx), %r14
	cmpq	%rbp, %rax
	cmovbeq	%rax, %r14
	movl	$71, %edx
	leaq	272(%rsp), %rdi
	movq	8(%rsp), %rbp
	movq	%rbp, %rsi
	callq	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0s_0B5_
	subq	%rax, %r13
	movq	%r12, %rcx
	leaq	1(%r13,%r12), %rax
	cmovaeq	%r13, %rax
	movq	%rax, 264(%rsp)
	subq	%rdx, %r14
	leaq	1(%r14,%r12), %r13
	cmovaeq	%r14, %r13
	movq	32(%rsp), %rax
	cmpq	$-32768, %rax
	leaq	32768(%rbx), %rdx
	cmovaeq	%rdx, %r15
	addq	%rax, %r15
	leaq	(%r15,%rbx), %r14
	cmpq	%r12, %r15
	cmovbeq	%r15, %r14
	movq	16(%rsp), %rax
	leaq	(%rax,%rbx), %r12
	cmpq	%rax, %rcx
	movq	%rcx, %r15
	movq	%rax, %rcx
	movq	48(%rsp), %rax
	sbbq	%rax, %rax
	cmovaeq	%rcx, %r12
	movl	$74, %edx
	leaq	272(%rsp), %rdi
	movq	%rbp, %rsi
	callq	_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0s_0B5_
	subq	%rax, %r14
	leaq	1(%r14,%r15), %rcx
	cmovaeq	%r14, %rcx
	subq	%rdx, %r12
	leaq	1(%r12,%r15), %r14
	cmovaeq	%r12, %r14
	movq	40(%rsp), %r11
	movq	184(%r11), %rdi
	movq	24(%rsp), %rsi
	cmpq	%rsi, %rdi
	jae	.LBB14_11
	shlq	$4, %rdi
	movq	80(%rsp), %r9
	movq	(%r9,%rdi), %r8
	movq	8(%r9,%rdi), %rdx
	movq	192(%r11), %rax
	movq	%rax, 16(%rsp)
	movq	200(%r11), %rax
	movq	%rax, 8(%rsp)
	movq	208(%r11), %r12
	movq	216(%r11), %r15
	movq	224(%r11), %r10
	movq	232(%r11), %rbp
	cmpb	$0, (%r11)
	movq	%rcx, 256(%rsp)
	movq	%r14, 248(%rsp)
	je	.LBB14_10
	movq	8(%r11), %rdi
	cmpq	%rsi, %rdi
	jae	.LBB14_23
	shlq	$4, %rdi
	movq	(%r9,%rdi), %rax
	movq	8(%r9,%rdi), %rcx
	jmp	.LBB14_13
.LBB14_10:
	movl	$1, %eax
	xorl	%ecx, %ecx
.LBB14_13:
	movq	80(%r11), %r14
	cmpq	$4, %r14
	jb	.LBB14_24
	movq	%rbp, 208(%rsp)
	movq	%r12, 120(%rsp)
	movq	%r15, 128(%rsp)
	movq	%r10, 136(%rsp)
	movq	%r8, 144(%rsp)
	movq	%rdx, 152(%rsp)
	movq	%rcx, 88(%rsp)
	movq	%rax, 32(%rsp)
	movq	%r13, 216(%rsp)
	movq	72(%r11), %r13
	movq	240(%r11), %r8
	movq	48(%r11), %rdx
	movq	56(%r11), %rcx
	leaq	-4(%r14), %rax
	movq	%rsi, %r15
	leaq	64(%r13), %r10
	subq	$8, %rsp
	.cfi_adjust_cfa_offset 8
	movq	%r9, %rdi
	movq	%r11, %rbp
	movq	%r9, %r12
	movq	24(%rsp), %r9
	pushq	%rax
	.cfi_adjust_cfa_offset 8
	pushq	%r10
	.cfi_adjust_cfa_offset 8
	pushq	32(%rsp)
	.cfi_adjust_cfa_offset 8
	callq	_RNvCsl0YfJI2rrfI_8isolated10helper_sum
	addq	$32, %rsp
	.cfi_adjust_cfa_offset -32
	movq	%rax, 200(%rsp)
	movq	%rdx, 168(%rsp)
	movq	48(%r13), %rax
	movq	%rax, 176(%rsp)
	movq	56(%r13), %rax
	movq	%rax, 184(%rsp)
	leaq	88(%rbp), %rdi
	movq	%r12, %rsi
	movq	%r15, %rdx
	callq	_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm4eval
	movq	%rax, 192(%rsp)
	movq	%rdx, 160(%rsp)
	shlq	$4, %r14
	movq	%r13, 48(%rsp)
	addq	%r13, %r14
	xorps	%xmm0, %xmm0
	movups	%xmm0, 376(%rsp)
	movq	64(%rsp), %rax
	movq	%rax, 328(%rsp)
	movq	56(%rsp), %rax
	movq	%rax, 336(%rsp)
	movq	264(%rsp), %rax
	movq	%rax, 344(%rsp)
	movq	216(%rsp), %rax
	movq	%rax, 352(%rsp)
	movq	256(%rsp), %rax
	movq	%rax, 360(%rsp)
	movq	248(%rsp), %rax
	movq	%rax, 368(%rsp)
	xorl	%edi, %edi
	xorl	%r8d, %r8d
	xorl	%ecx, %ecx
	movabsq	$-4294967296, %rbp
	.p2align	4
.LBB14_15:
	leaq	16(%rdi), %rsi
	cmpq	$64, %rsi
	je	.LBB14_16
	movq	48(%rsp), %rax
	leaq	(%rax,%rdi), %r13
	movq	328(%rsp,%rdi), %r9
	movq	(%r13), %r10
	movq	%r10, %rax
	mulq	%r9
	movq	336(%rsp,%rdi), %r12
	movl	%edx, %edi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%rbp), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rbx, %rdi
	addq	%rdx, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovaeq	%rdi, %rax
	leaq	(%rax,%rbx), %r15
	cmpq	%rbp, %rax
	cmovbeq	%rax, %r15
	movq	8(%r13), %r11
	movq	%r11, %rax
	mulq	%r12
	movq	%rax, %rdi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rdi
	leaq	1(%rdi,%rbp), %rax
	cmovbq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%rbp, %rdi
	cmovaq	%rax, %rdi
	movq	%r10, %rax
	mulq	%r12
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%rbp), %r10
	cmovaeq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r10, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %r10
	cmpq	%rbp, %rdx
	cmovbeq	%rdx, %r10
	movq	%r11, %rax
	mulq	%r9
	movq	%rdx, %r9
	shrq	$32, %r9
	subq	%r9, %rax
	leaq	1(%rax,%rbp), %r9
	cmovaeq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r9, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %r9
	cmpq	%rbp, %rdx
	cmovbeq	%rdx, %r9
	movq	%rdi, %rax
	movl	$7, %edx
	mulq	%rdx
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%rbp, %rax
	cmovbeq	%rax, %rdx
	addq	%r15, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%rbp, %rax
	cmovbeq	%rax, %rdx
	addq	%r10, %r9
	leaq	(%r9,%rbx), %rax
	cmovaeq	%r9, %rax
	leaq	(%rax,%rbx), %rdi
	cmpq	%rbp, %rax
	cmovbeq	%rax, %rdi
	addq	%r8, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%rbp, %rax
	cmovbeq	%rax, %r8
	addq	%rcx, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovaeq	%rdi, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%rbp, %rax
	cmovbeq	%rax, %rcx
	addq	$16, %r13
	movq	%rsi, %rdi
	cmpq	%r14, %r13
	jne	.LBB14_15
.LBB14_16:
	movq	72(%rsp), %rax
	movq	544(%rax), %rdi
	movq	24(%rsp), %rsi
	cmpq	%rsi, %rdi
	jae	.LBB14_25
	movq	40(%rsp), %rax
	movq	144(%rax), %rax
	testq	%rax, %rax
	movq	208(%rsp), %r10
	je	.LBB14_26
	cmpq	$1, %rsi
	jbe	.LBB14_27
	cmpq	$1, %rax
	je	.LBB14_28
	cmpq	$2, %rsi
	je	.LBB14_29
	shlq	$4, %rdi
	movq	%rdi, 48(%rsp)
	movabsq	$-4294967296, %r12
	movq	96(%rsp), %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rsi
	cmovbeq	%rax, %rsi
	movq	120(%rsp), %r13
	movq	%r13, %rax
	movq	232(%rsp), %r11
	mulq	%r11
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r12), %rdi
	cmovaeq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rdi
	cmovbeq	%rdx, %rdi
	movq	128(%rsp), %r15
	movq	%r15, %rax
	movq	224(%rsp), %r14
	mulq	%r14
	movq	%rdx, %r9
	shrq	$32, %r9
	subq	%r9, %rax
	leaq	1(%rax,%r12), %r9
	cmovaeq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r9, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%r10, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	movq	8(%rsp), %rdx
	subq	%rax, %rdx
	leaq	1(%rdx,%r12), %r10
	cmovaeq	%rdx, %r10
	movq	%r10, %rax
	movq	144(%rsp), %rbp
	mulq	%rbp
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%r12), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rsi
	cmovbeq	%rdx, %rsi
	movq	104(%rsp), %rdi
	cmpq	$-128, %rdi
	leaq	128(%rbx), %rax
	movl	$128, %edx
	cmovaeq	%rax, %rdx
	addq	%rdi, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rdi
	cmovbeq	%rdx, %rdi
	movq	%r13, %rax
	mulq	%r14
	movq	%rdx, %r9
	shrq	$32, %r9
	subq	%r9, %rax
	leaq	1(%rax,%r12), %r9
	cmovaeq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r9, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %r9
	cmovbeq	%rdx, %r9
	movq	%r15, %rax
	mulq	%r11
	movq	%rdx, %r11
	shrq	$32, %r11
	subq	%r11, %rax
	leaq	1(%rax,%r12), %r11
	cmovbq	%r11, %rax
	movl	%edx, %edx
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaq	%rdx, %rax
	movl	$7, %edx
	mulq	%rdx
	movl	$7, %r14d
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	addq	%r9, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	addq	%rdi, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	addq	136(%rsp), %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	movq	16(%rsp), %rax
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %r11
	cmovaeq	%rax, %r11
	movq	%r11, %rax
	movq	152(%rsp), %r15
	mulq	%r15
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r12), %rdi
	cmovaeq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rdi
	cmovbeq	%rdx, %rdi
	movq	176(%rsp), %r13
	movq	%r13, %rax
	mulq	%rdi
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%r12), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rsi
	cmovbeq	%rdx, %rsi
	movq	%r11, %rax
	mulq	%rbp
	movq	%rdx, %r9
	shrq	$32, %r9
	subq	%r9, %rax
	leaq	1(%rax,%r12), %r9
	cmovaeq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r9, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %r9
	cmovbeq	%rdx, %r9
	movq	%r10, %rax
	mulq	%r15
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%r12), %r10
	cmovbq	%r10, %rax
	movl	%edx, %edx
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaq	%rdx, %rax
	mulq	%r14
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	addq	%r9, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %r9
	cmovbeq	%rax, %r9
	subq	$1, %r9
	cmovbq	%r12, %r9
	movq	184(%rsp), %r15
	movq	%r15, %rax
	mulq	%r9
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%r12), %r10
	cmovaeq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r10, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	168(%rsp), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	160(%rsp), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rsi
	cmovbeq	%rdx, %rsi
	movq	%rcx, %rax
	movq	32(%rsp), %r14
	mulq	%r14
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%r12), %r10
	cmovaeq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r10, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %r10
	cmovbeq	%rdx, %r10
	movq	%r8, %rax
	movq	88(%rsp), %rbp
	mulq	%rbp
	movq	%rdx, %r11
	shrq	$32, %r11
	subq	%r11, %rax
	leaq	1(%rax,%r12), %r11
	cmovaeq	%rax, %r11
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r11, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%r10, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rsi
	cmovbeq	%rdx, %rsi
	movq	%rsi, 24(%rsp)
	movq	80(%rsp), %r11
	movq	(%r11), %rax
	movq	%rax, 16(%rsp)
	mulq	%rsi
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%r12), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rsi
	cmovbeq	%rdx, %rsi
	movq	%r13, %rax
	mulq	%r9
	movq	%rdx, %r9
	shrq	$32, %r9
	subq	%r9, %rax
	leaq	1(%rax,%r12), %r9
	cmovaeq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r9, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %r9
	cmovbeq	%rdx, %r9
	movq	%r15, %rax
	mulq	%rdi
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r12), %rdi
	cmovbq	%rdi, %rax
	movl	%edx, %edx
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaq	%rdx, %rax
	movl	$7, %r10d
	mulq	%r10
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	addq	%r9, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	addq	200(%rsp), %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbeq	%rax, %rdx
	addq	192(%rsp), %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdi
	cmovbeq	%rax, %rdi
	movq	%r8, %rax
	mulq	%r14
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r12), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r8, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %r8
	cmovbeq	%rdx, %r8
	movq	%rcx, %rax
	mulq	%rbp
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r12), %rcx
	cmovbq	%rcx, %rax
	movl	%edx, %ecx
	imulq	%rbx, %rcx
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbq	%rcx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaq	%rcx, %rax
	mulq	%r10
	movl	$7, %r9d
	imulq	%rbx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovaeq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbeq	%rax, %rcx
	addq	%r8, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbeq	%rax, %rcx
	addq	%rdi, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovaeq	%rcx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbeq	%rax, %rcx
	movq	%rcx, 64(%rsp)
	movq	8(%r11), %rax
	movq	%rax, 72(%rsp)
	mulq	%rcx
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r12), %rcx
	cmovaeq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r12, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r12, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	movq	%rax, 56(%rsp)
	movq	40(%rsp), %r15
	movq	136(%r15), %r8
	movq	(%r8), %rcx
	movq	%r8, 8(%rsp)
	movq	16(%r11), %rsi
	movq	%r11, %rdi
	movq	%rsi, %rax
	mulq	%rcx
	movq	%rax, %r11
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r11
	leaq	1(%r11,%r12), %rax
	cmovbq	%rax, %r11
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r11
	leaq	(%r11,%rbx), %rax
	cmovbq	%rax, %r11
	cmpq	%r12, %r11
	leaq	(%r11,%rbx), %rax
	cmovaq	%rax, %r11
	movq	8(%r8), %r13
	movq	24(%rdi), %r10
	movq	%r10, %rax
	mulq	%r13
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r12), %r8
	cmovbq	%r8, %rax
	movl	%edx, %edx
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaq	%rdx, %rax
	mulq	%r9
	movq	%rax, %r8
	imulq	%rbx, %rdx
	addq	%rdx, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	cmpq	%r12, %r8
	leaq	(%r8,%rbx), %rax
	cmovaq	%rax, %r8
	addq	%r11, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	cmpq	%r12, %r8
	leaq	(%r8,%rbx), %rax
	cmovaq	%rax, %r8
	movq	%r8, %rax
	mulq	%r14
	movq	%rax, %r11
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r11
	leaq	1(%r11,%r12), %rax
	cmovbq	%rax, %r11
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r11
	leaq	(%r11,%rbx), %rax
	cmovbq	%rax, %r11
	cmpq	%r12, %r11
	leaq	(%r11,%rbx), %rax
	cmovaq	%rax, %r11
	movq	%r10, %rax
	mulq	%rcx
	movq	%rax, %r14
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r14
	leaq	1(%r14,%r12), %rax
	cmovbq	%rax, %r14
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r14
	leaq	(%r14,%rbx), %rax
	cmovbq	%rax, %r14
	cmpq	%r12, %r14
	leaq	(%r14,%rbx), %rax
	cmovaq	%rax, %r14
	movq	%rsi, %rax
	mulq	%r13
	movq	%rax, %r10
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r10
	leaq	1(%r10,%r12), %rax
	cmovbq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmovbq	%rax, %r10
	cmpq	%r12, %r10
	leaq	(%r10,%rbx), %rax
	cmovaq	%rax, %r10
	addq	%r14, %r10
	leaq	(%r10,%rbx), %rax
	cmovbq	%rax, %r10
	cmpq	%r12, %r10
	leaq	(%r10,%rbx), %rax
	cmovaq	%rax, %r10
	movq	%r10, %rax
	movq	%rbp, %rdi
	mulq	%rbp
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r12), %rcx
	cmovbq	%rcx, %rax
	movl	%edx, %ecx
	imulq	%rbx, %rcx
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbq	%rcx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaq	%rcx, %rax
	mulq	%r9
	movq	%rax, %rsi
	imulq	%rbx, %rdx
	addq	%rdx, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	cmpq	%r12, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovaq	%rax, %rsi
	addq	%r11, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	cmpq	%r12, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovaq	%rax, %rsi
	movq	248(%r15), %r11
	movq	%r11, %rax
	mulq	96(%rsp)
	movq	%rdx, %rcx
	shrq	$32, %rcx
	subq	%rcx, %rax
	leaq	1(%rax,%r12), %rcx
	cmovaeq	%rax, %rcx
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r12, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	movq	48(%rsp), %r9
	movq	80(%rsp), %rbp
	addq	8(%rbp,%r9), %rax
	leaq	(%rax,%rbx), %rcx
	cmovaeq	%rax, %rcx
	cmpq	%r12, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbeq	%rcx, %rax
	subq	264(%r15), %rax
	leaq	1(%rax,%r12), %rcx
	cmovaeq	%rax, %rcx
	movq	%rsi, %rax
	mulq	%rcx
	movq	%rdx, %r14
	shrq	$32, %r14
	subq	%r14, %rax
	leaq	1(%rax,%r12), %r14
	cmovaeq	%rax, %r14
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r14, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %r13
	cmovbeq	%rdx, %r13
	movq	%r8, %rax
	mulq	%rdi
	movq	%rax, %r14
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r14
	leaq	1(%r14,%r12), %rax
	cmovbq	%rax, %r14
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r14
	leaq	(%r14,%rbx), %rax
	cmovbq	%rax, %r14
	cmpq	%r12, %r14
	leaq	(%r14,%rbx), %rax
	cmovaq	%rax, %r14
	movq	%r10, %rax
	mulq	32(%rsp)
	movq	%rax, %r8
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r8
	leaq	1(%r8,%r12), %rax
	cmovbq	%rax, %r8
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	cmpq	%r12, %r8
	leaq	(%r8,%rbx), %rax
	cmovaq	%rax, %r8
	addq	%r14, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	cmpq	%r12, %r8
	leaq	(%r8,%rbx), %rax
	cmovaq	%rax, %r8
	movq	%r11, %rax
	mulq	104(%rsp)
	movq	%rdx, %r10
	shrq	$32, %r10
	subq	%r10, %rax
	leaq	1(%rax,%r12), %r10
	cmovaeq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r10, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	(%rbp,%r9), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	subq	256(%r15), %rax
	leaq	1(%rax,%r12), %r10
	cmovaeq	%rax, %r10
	movq	%r8, %rax
	mulq	%r10
	movq	%rdx, %r11
	shrq	$32, %r11
	subq	%r11, %rax
	leaq	1(%rax,%r12), %r11
	cmovaeq	%rax, %r11
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r11, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	%r13, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %rax
	cmovbeq	%rdx, %rax
	addq	56(%rsp), %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	cmpq	%r12, %rdx
	leaq	(%rdx,%rbx), %r11
	cmovbeq	%rdx, %r11
	movq	16(%rsp), %rax
	mulq	64(%rsp)
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r12), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	cmpq	%r12, %r9
	leaq	(%r9,%rbx), %rax
	cmovaq	%rax, %r9
	movq	72(%rsp), %rax
	mulq	24(%rsp)
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r12), %rdi
	cmovbq	%rdi, %rax
	movl	%edx, %edx
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	cmpq	%r12, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaq	%rdx, %rax
	movl	$7, %r14d
	mulq	%r14
	movq	%rax, %rdi
	imulq	%rbx, %rdx
	addq	%rdx, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	cmpq	%r12, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovaq	%rax, %rdi
	addq	%r9, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	cmpq	%r12, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovaq	%rax, %rdi
	movq	%rsi, %rax
	mulq	%r10
	movq	%rax, %rsi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rsi
	leaq	1(%rsi,%r12), %rax
	cmovbq	%rax, %rsi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r12, %rsi
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	mulq	%rcx
	movl	%edx, %ecx
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %rdx
	cmovbq	%rdx, %rax
	imulq	%rbx, %rcx
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r12, %rax
	cmovaq	%rcx, %rax
	mulq	%r14
	movl	$7, %r13d
	movq	%rax, %rcx
	imulq	%rbx, %rdx
	addq	%rdx, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmpq	%r12, %rcx
	cmovaq	%rax, %rcx
	addq	%rsi, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmpq	%r12, %rcx
	cmovaq	%rax, %rcx
	addq	%rdi, %rcx
	leaq	(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%rbx), %rax
	cmpq	%r12, %rcx
	cmovaq	%rax, %rcx
	movq	8(%rsp), %r8
	movq	16(%r8), %r14
	movq	32(%rbp), %rdi
	movq	%rdi, %rax
	mulq	%r14
	movq	%rax, %rsi
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rsi
	leaq	1(%rsi,%r12), %rax
	cmovbq	%rax, %rsi
	movl	%edx, %eax
	movq	24(%r8), %r10
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r12, %rsi
	cmovaq	%rax, %rsi
	movq	40(%rbp), %r9
	movq	%r9, %rax
	mulq	%r10
	movq	%rax, %r8
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r8
	leaq	1(%r8,%r12), %rax
	cmovbq	%rax, %r8
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	cmpq	%r12, %r8
	leaq	(%r8,%rbx), %rax
	cmovaq	%rax, %r8
	movq	%r9, %rax
	mulq	%r14
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r12), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmpq	%r12, %r9
	cmovaq	%rax, %r9
	movq	%rdi, %rax
	mulq	%r10
	movq	%rax, %r10
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %r10
	leaq	1(%r10,%r12), %rdx
	cmovbq	%rdx, %r10
	imulq	%rbx, %rax
	addq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmovbq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmpq	%r12, %r10
	cmovaq	%rax, %r10
	movq	%r8, %rax
	mulq	%r13
	movq	%rax, %rdi
	imulq	%rbx, %rdx
	addq	%rdx, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r12, %rdi
	cmovaq	%rax, %rdi
	addq	%rsi, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r12, %rdi
	cmovaq	%rax, %rdi
	addq	%r9, %r10
	leaq	(%r10,%rbx), %rax
	cmovaeq	%r10, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%r12, %rax
	cmovbeq	%rax, %r8
	movq	%rdi, %rax
	movq	32(%rsp), %r14
	mulq	%r14
	movq	%rax, %rsi
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rsi
	leaq	1(%rsi,%r12), %rdx
	cmovbq	%rdx, %rsi
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r12, %rsi
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	movq	88(%rsp), %r10
	mulq	%r10
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r12), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmpq	%r12, %r9
	cmovaq	%rax, %r9
	movq	%rdi, %rax
	mulq	%r10
	movq	%rax, %r10
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r10
	leaq	1(%r10,%r12), %rax
	cmovbq	%rax, %r10
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmovbq	%rax, %r10
	leaq	(%r10,%rbx), %rax
	cmpq	%r12, %r10
	cmovaq	%rax, %r10
	movq	%r8, %rax
	mulq	%r14
	movq	%rax, %r8
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %r8
	leaq	1(%r8,%r12), %rdx
	cmovbq	%rdx, %r8
	imulq	%rbx, %rax
	addq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmovbq	%rax, %r8
	leaq	(%r8,%rbx), %rax
	cmpq	%r12, %r8
	cmovaq	%rax, %r8
	movq	%r9, %rax
	mulq	%r13
	movq	%rax, %rdi
	imulq	%rbx, %rdx
	addq	%rdx, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r12, %rdi
	cmovaq	%rax, %rdi
	addq	%rsi, %rdi
	leaq	(%rdi,%rbx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rbx), %rax
	cmpq	%r12, %rdi
	cmovaq	%rax, %rdi
	addq	%r10, %r8
	leaq	(%r8,%rbx), %rax
	cmovaeq	%r8, %rax
	leaq	(%rax,%rbx), %r8
	cmpq	%r12, %rax
	cmovbeq	%rax, %r8
	movq	%rdi, %rax
	movq	240(%rsp), %r10
	mulq	%r10
	movq	%rax, %rsi
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rsi
	leaq	1(%rsi,%r12), %rdx
	cmovbq	%rdx, %rsi
	imulq	%rbx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rbx), %rax
	cmpq	%r12, %rsi
	cmovaq	%rax, %rsi
	movq	%r8, %rax
	movq	112(%rsp), %r14
	mulq	%r14
	movq	%rax, %r9
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r9
	leaq	1(%r9,%r12), %rax
	cmovbq	%rax, %r9
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmovbq	%rax, %r9
	leaq	(%r9,%rbx), %rax
	cmpq	%r12, %r9
	cmovaq	%rax, %r9
	movq	%rdi, %rax
	mulq	%r14
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r12), %rdi
	cmovaeq	%rax, %rdi
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%rdi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %rdi
	cmpq	%r12, %rdx
	cmovbeq	%rdx, %rdi
	movq	%r8, %rax
	mulq	%r10
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r12), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	imulq	%rbx, %rax
	addq	%r8, %rax
	leaq	(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rbx), %r8
	cmpq	%r12, %rdx
	cmovbeq	%rdx, %r8
	movq	%r9, %rax
	mulq	%r13
	imulq	%rbx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r12, %rax
	cmovaq	%rdx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rbx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rbx), %rdx
	cmpq	%r12, %rax
	cmovaq	%rdx, %rax
	addq	%rdi, %r8
	leaq	(%r8,%rbx), %rdx
	cmovaeq	%r8, %rdx
	leaq	(%rdx,%rbx), %rsi
	cmpq	%r12, %rdx
	cmovbeq	%rdx, %rsi
	addq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmovbq	%rcx, %rax
	leaq	(%rax,%rbx), %rcx
	cmpq	%r12, %rax
	cmovaq	%rcx, %rax
	addq	%r11, %rsi
	leaq	(%rsi,%rbx), %rcx
	cmovaeq	%rsi, %rcx
	addq	%rcx, %rbx
	cmpq	%r12, %rcx
	cmovbeq	%rcx, %rbx
	movq	%rbx, %rdx
	addq	$392, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%r12
	.cfi_def_cfa_offset 40
	popq	%r13
	.cfi_def_cfa_offset 32
	popq	%r14
	.cfi_def_cfa_offset 24
	popq	%r15
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	retq
.LBB14_24:
	.cfi_def_cfa_offset 448
	leaq	.Lalloc_354dc1959db4c84bf13af6f86d635aee(%rip), %rcx
	movl	$4, %edi
	movq	%r14, %rsi
	movq	%r14, %rdx
	callq	*_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail@GOTPCREL(%rip)
.LBB14_31:
	leaq	.Lalloc_3473ff63602946e5bae196369fb1e157(%rip), %rdx
	movl	$67, %edi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB14_32:
	movq	%rdx, %rsi
	leaq	.Lalloc_8bedb038257b840dda514362a0f0e6d8(%rip), %rdx
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB14_33:
	leaq	.Lalloc_3473ff63602946e5bae196369fb1e157(%rip), %rdx
	movl	$69, %edi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB14_34:
	movq	%rdx, %rsi
	leaq	.Lalloc_8bedb038257b840dda514362a0f0e6d8(%rip), %rdx
	movq	%rax, %rdi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB14_35:
	leaq	.Lalloc_3473ff63602946e5bae196369fb1e157(%rip), %rdx
	movl	$70, %edi
	movl	$70, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB14_36:
	movq	%rdx, %rsi
	leaq	.Lalloc_8bedb038257b840dda514362a0f0e6d8(%rip), %rdx
	movq	%r8, %rdi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB14_37:
	leaq	.Lalloc_3473ff63602946e5bae196369fb1e157(%rip), %rdx
	movl	$73, %edi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB14_38:
	leaq	.Lalloc_8bedb038257b840dda514362a0f0e6d8(%rip), %rdx
	movq	%rcx, %rdi
	movq	24(%rsp), %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB14_11:
	leaq	.Lalloc_d0a18ec8c4590cc3d9111a1a11b11099(%rip), %rdx
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB14_25:
	leaq	.Lalloc_8bedb038257b840dda514362a0f0e6d8(%rip), %rdx
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB14_26:
	leaq	.Lalloc_38b3a9f276003767a8ae4525b00c9940(%rip), %rdx
	xorl	%edi, %edi
	xorl	%esi, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB14_27:
	leaq	.Lalloc_95c9a529b9c6675768dc03a5e4eb87b8(%rip), %rdx
	movl	$1, %edi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB14_28:
	leaq	.Lalloc_f1afeffee25b8cbad41bb5872529e5be(%rip), %rdx
	movl	$1, %edi
	movl	$1, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB14_29:
	leaq	.Lalloc_e7192de98d175da682c169f6595d4522(%rip), %rdx
	movl	$2, %edi
	movl	$2, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB14_23:
	leaq	.Lalloc_03bbe1d0fcdbd86f2216092eb0f02e36(%rip), %rdx
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Lfunc_end14:
	.size	_RNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0B3_, .Lfunc_end14-_RNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0B3_
	.cfi_endproc

	.section	.text._RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_,"ax",@progbits
	.p2align	4
	.type	_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_,@function
_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_:
.Lfunc_begin1:
	.cfi_startproc
	.cfi_personality 155, DW.ref.rust_eh_personality
	.cfi_lsda 27, .Lexception1
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset %rbx, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rdi, %rbx
.Ltmp3:
	callq	_RNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0B3_
.Ltmp4:
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	%rbx, %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_
	movq	%r14, %rax
	movq	%r15, %rdx
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.LBB15_2:
	.cfi_def_cfa_offset 32
.Ltmp5:
	movq	%rax, %r14
	movq	%rbx, %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_
	movq	%r14, %rdi
	callq	_Unwind_Resume@PLT
.Lfunc_end15:
	.size	_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_, .Lfunc_end15-_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_
	.cfi_endproc
	.section	.gcc_except_table._RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_,"a",@progbits
	.p2align	2, 0x0
GCC_except_table15:
.Lexception1:
	.byte	255
	.byte	255
	.byte	1
	.uleb128 .Lcst_end1-.Lcst_begin1
.Lcst_begin1:
	.uleb128 .Ltmp3-.Lfunc_begin1
	.uleb128 .Ltmp4-.Ltmp3
	.uleb128 .Ltmp5-.Lfunc_begin1
	.byte	0
	.uleb128 .Ltmp4-.Lfunc_begin1
	.uleb128 .Lfunc_end15-.Ltmp4
	.byte	0
	.byte	0
.Lcst_end1:
	.p2align	2, 0x0

	.section	.text._RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_,"ax",@progbits
	.p2align	4
	.type	_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_,@function
_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_:
.Lfunc_begin2:
	.cfi_startproc
	.cfi_personality 155, DW.ref.rust_eh_personality
	.cfi_lsda 27, .Lexception2
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset %rbx, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rdi, %rbx
.Ltmp6:
	callq	_RNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0B3_
.Ltmp7:
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	%rbx, %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_
	movq	%r14, %rax
	movq	%r15, %rdx
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.LBB16_2:
	.cfi_def_cfa_offset 32
.Ltmp8:
	movq	%rax, %r14
	movq	%rbx, %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_
	movq	%r14, %rdi
	callq	_Unwind_Resume@PLT
.Lfunc_end16:
	.size	_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_, .Lfunc_end16-_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_
	.cfi_endproc
	.section	.gcc_except_table._RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_,"a",@progbits
	.p2align	2, 0x0
GCC_except_table16:
.Lexception2:
	.byte	255
	.byte	255
	.byte	1
	.uleb128 .Lcst_end2-.Lcst_begin2
.Lcst_begin2:
	.uleb128 .Ltmp6-.Lfunc_begin2
	.uleb128 .Ltmp7-.Ltmp6
	.uleb128 .Ltmp8-.Lfunc_begin2
	.byte	0
	.uleb128 .Ltmp7-.Lfunc_begin2
	.uleb128 .Lfunc_end16-.Ltmp7
	.byte	0
	.byte	0
.Lcst_end2:
	.p2align	2, 0x0

	.section	.text._RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_,"ax",@progbits
	.p2align	4
	.type	_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_,@function
_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_:
.Lfunc_begin3:
	.cfi_startproc
	.cfi_personality 155, DW.ref.rust_eh_personality
	.cfi_lsda 27, .Lexception3
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset %rbx, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rdi, %rbx
.Ltmp9:
	callq	_RNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0B3_
.Ltmp10:
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	%rbx, %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_
	movq	%r14, %rax
	movq	%r15, %rdx
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.LBB17_2:
	.cfi_def_cfa_offset 32
.Ltmp11:
	movq	%rax, %r14
	movq	%rbx, %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_
	movq	%r14, %rdi
	callq	_Unwind_Resume@PLT
.Lfunc_end17:
	.size	_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_, .Lfunc_end17-_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_
	.cfi_endproc
	.section	.gcc_except_table._RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_,"a",@progbits
	.p2align	2, 0x0
GCC_except_table17:
.Lexception3:
	.byte	255
	.byte	255
	.byte	1
	.uleb128 .Lcst_end3-.Lcst_begin3
.Lcst_begin3:
	.uleb128 .Ltmp9-.Lfunc_begin3
	.uleb128 .Ltmp10-.Ltmp9
	.uleb128 .Ltmp11-.Lfunc_begin3
	.byte	0
	.uleb128 .Ltmp10-.Lfunc_begin3
	.uleb128 .Lfunc_end17-.Ltmp10
	.byte	0
	.byte	0
.Lcst_end3:
	.p2align	2, 0x0

	.section	.text._RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_,"ax",@progbits
	.p2align	4
	.type	_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_,@function
_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_:
.Lfunc_begin4:
	.cfi_startproc
	.cfi_personality 155, DW.ref.rust_eh_personality
	.cfi_lsda 27, .Lexception4
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset %rbx, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rdi, %rbx
.Ltmp12:
	callq	_RNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0B3_
.Ltmp13:
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	%rbx, %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_
	movq	%r14, %rax
	movq	%r15, %rdx
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.LBB18_2:
	.cfi_def_cfa_offset 32
.Ltmp14:
	movq	%rax, %r14
	movq	%rbx, %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_
	movq	%r14, %rdi
	callq	_Unwind_Resume@PLT
.Lfunc_end18:
	.size	_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_, .Lfunc_end18-_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_
	.cfi_endproc
	.section	.gcc_except_table._RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_,"a",@progbits
	.p2align	2, 0x0
GCC_except_table18:
.Lexception4:
	.byte	255
	.byte	255
	.byte	1
	.uleb128 .Lcst_end4-.Lcst_begin4
.Lcst_begin4:
	.uleb128 .Ltmp12-.Lfunc_begin4
	.uleb128 .Ltmp13-.Ltmp12
	.uleb128 .Ltmp14-.Lfunc_begin4
	.byte	0
	.uleb128 .Ltmp13-.Lfunc_begin4
	.uleb128 .Lfunc_end18-.Ltmp13
	.byte	0
	.byte	0
.Lcst_end4:
	.p2align	2, 0x0

	.section	.text._RNvCsl0YfJI2rrfI_8isolated10helper_sum,"ax",@progbits
	.p2align	4
	.type	_RNvCsl0YfJI2rrfI_8isolated10helper_sum,@function
_RNvCsl0YfJI2rrfI_8isolated10helper_sum:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	subq	$136, %rsp
	.cfi_def_cfa_offset 192
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	192(%rsp), %rax
	movq	%r9, 120(%rsp)
	movq	%rax, 128(%rsp)
	leaq	120(%rsp), %rax
	movq	%rax, 24(%rsp)
	movq	%rdi, 32(%rsp)
	movq	%rsi, 16(%rsp)
	movq	%rsi, 40(%rsp)
	testq	%rcx, %rcx
	je	.LBB19_1
	movq	%rdx, %r10
	movq	208(%rsp), %rsi
	movabsq	$-4294967296, %r12
	movl	$4294967295, %r14d
	movq	%rcx, %rax
	shrq	%rax
	movq	%rcx, %r11
	subq	%rax, %r11
	movq	%rcx, 8(%rsp)
	leaq	1(%rcx), %rax
	cmpq	$1, %r11
	adcq	$0, %r11
	leaq	(%rsi,%rsi), %rcx
	movq	%rcx, 64(%rsp)
	andq	$-2, %rax
	movq	%rax, 72(%rsp)
	movq	%r8, %rax
	shlq	$4, %rax
	addq	%rdi, %rax
	addq	$8, %rax
	movq	%rax, 56(%rsp)
	xorl	%ebp, %ebp
	leaq	24(%rsp), %r13
	movq	$0, (%rsp)
	xorl	%edx, %edx
	.p2align	4
.LBB19_4:
	cmpq	16(%rsp), %r8
	jae	.LBB19_12
	movq	%rdx, 96(%rsp)
	movq	%r11, 112(%rsp)
	movq	%r8, 104(%rsp)
	cmpq	%rbp, 72(%rsp)
	je	.LBB19_13
	movq	56(%rsp), %rax
	movq	-8(%rax,%rbp,8), %r15
	movq	(%rax,%rbp,8), %rbx
	movq	%r13, %rdi
	movq	%r10, %rsi
	movq	%r10, %r13
	callq	_RNCNvCsl0YfJI2rrfI_8isolated10helper_sum0B3_
	movq	%rax, %r8
	movq	%rdx, %rdi
	movq	%rbp, 88(%rsp)
	leaq	1(%rbp), %rax
	cmpq	8(%rsp), %rax
	movq	%r13, 80(%rsp)
	jae	.LBB19_7
	leaq	40(%r13), %rsi
	leaq	24(%rsp), %r13
	movq	%rdi, %rbp
	movq	%r13, %rdi
	movq	%r8, %r13
	callq	_RNCNvCsl0YfJI2rrfI_8isolated10helper_sum0B3_
	movq	%rax, %rsi
	movq	%rdx, %rcx
	movq	%r13, %rax
	mulq	%r15
	movl	%edx, %edi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r14, %rdi
	addq	%rdx, %rdi
	leaq	(%rdi,%r14), %rax
	cmovaeq	%rdi, %rax
	leaq	(%rax,%r14), %r8
	cmpq	%r12, %rax
	cmovbeq	%rax, %r8
	movq	%rbp, 48(%rsp)
	movq	%rbp, %rax
	mulq	%rbx
	movq	%rax, %rdi
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rdi
	leaq	1(%rdi,%r12), %rdx
	cmovbq	%rdx, %rdi
	imulq	%r14, %rax
	addq	%rax, %rdi
	leaq	(%rdi,%r14), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%r14), %rax
	cmpq	%r12, %rdi
	cmovaq	%rax, %rdi
	movq	%rbp, %rax
	mulq	%r15
	movl	%edx, %r9d
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r14, %r9
	addq	%rdx, %r9
	leaq	(%r9,%r14), %rax
	cmovaeq	%r9, %rax
	leaq	(%rax,%r14), %r9
	cmpq	%r12, %rax
	cmovbeq	%rax, %r9
	movq	%r13, %rax
	mulq	%rbx
	movl	%edx, %r10d
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r14, %r10
	addq	%rdx, %r10
	leaq	(%r10,%r14), %rax
	cmovaeq	%r10, %rax
	leaq	(%rax,%r14), %r11
	cmpq	%r12, %rax
	cmovbeq	%rax, %r11
	movq	%rdi, %rax
	movl	$7, %ebx
	mulq	%rbx
	imulq	%r14, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%r14), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%r14), %rdx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rdx
	addq	%r8, %rdx
	leaq	(%rdx,%r14), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%r14), %r10
	cmpq	%r12, %rax
	cmovbeq	%rax, %r10
	addq	%r9, %r11
	leaq	(%r11,%r14), %rax
	cmovaeq	%r11, %rax
	leaq	(%rax,%r14), %r9
	cmpq	%r12, %rax
	cmovbeq	%rax, %r9
	movq	%rsi, %rax
	mulq	%r10
	movl	%edx, %edi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r14, %rdi
	addq	%rdx, %rdi
	leaq	(%rdi,%r14), %rax
	cmovaeq	%rdi, %rax
	leaq	(%rax,%r14), %r8
	cmpq	%r12, %rax
	cmovbeq	%rax, %r8
	movq	%rcx, %rax
	mulq	%r9
	movq	%rax, %rdi
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rdi
	leaq	1(%rdi,%r12), %rdx
	cmovbq	%rdx, %rdi
	imulq	%r14, %rax
	addq	%rax, %rdi
	leaq	(%rdi,%r14), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%r14), %rax
	cmpq	%r12, %rdi
	cmovaq	%rax, %rdi
	movq	%rcx, %rax
	mulq	%r10
	movl	%edx, %r10d
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r14, %r10
	addq	%rdx, %r10
	leaq	(%r10,%r14), %rax
	cmovaeq	%r10, %rax
	leaq	(%rax,%r14), %r10
	cmpq	%r12, %rax
	cmovbeq	%rax, %r10
	movq	%rsi, %rax
	mulq	%r9
	movl	%edx, %r9d
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r14, %r9
	addq	%rdx, %r9
	leaq	(%r9,%r14), %rax
	cmovaeq	%r9, %rax
	leaq	(%rax,%r14), %r9
	cmpq	%r12, %rax
	cmovbeq	%rax, %r9
	movq	%rdi, %rax
	mulq	%rbx
	imulq	%r14, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%r14), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%r14), %rdx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rdx
	addq	%r8, %rdx
	leaq	(%rdx,%r14), %rdi
	cmovaeq	%rdx, %rdi
	leaq	(%rdi,%r14), %rax
	cmpq	%r12, %rdi
	cmovbeq	%rdi, %rax
	addq	%r10, %r9
	leaq	(%r9,%r14), %rdi
	cmovaeq	%r9, %rdi
	leaq	(%rdi,%r14), %rdx
	cmpq	%r12, %rdi
	cmovbeq	%rdi, %rdx
	addq	%rsi, %r13
	leaq	(%r13,%r14), %rsi
	cmovaeq	%r13, %rsi
	leaq	(%rsi,%r14), %rdi
	cmpq	%r12, %rsi
	cmovbeq	%rsi, %rdi
	movq	48(%rsp), %rsi
	addq	%rcx, %rsi
	leaq	(%rsi,%r14), %rcx
	cmovaeq	%rsi, %rcx
	leaq	(%rcx,%r14), %rsi
	cmpq	%r12, %rcx
	cmovbeq	%rcx, %rsi
	subq	%rdi, %rax
	leaq	1(%rax,%r12), %r8
	cmovaeq	%rax, %r8
	subq	%rsi, %rdx
	leaq	1(%rdx,%r12), %r10
	cmovaeq	%rdx, %r10
	jmp	.LBB19_9
	.p2align	4
.LBB19_7:
	movq	%r8, %rax
	mulq	%r15
	movl	%edx, %ecx
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r14, %rcx
	addq	%rdx, %rcx
	leaq	(%rcx,%r14), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%r14), %rsi
	cmpq	%r12, %rax
	cmovbeq	%rax, %rsi
	movq	%rdi, %rax
	mulq	%rbx
	movq	%rax, %rcx
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rcx
	leaq	1(%rcx,%r12), %rdx
	cmovbq	%rdx, %rcx
	imulq	%r14, %rax
	addq	%rax, %rcx
	leaq	(%rcx,%r14), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%r14), %rax
	cmpq	%r12, %rcx
	cmovaq	%rax, %rcx
	movq	%rdi, %rax
	mulq	%r15
	movl	%edx, %edi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r14, %rdi
	addq	%rdx, %rdi
	leaq	(%rdi,%r14), %rax
	cmovaeq	%rdi, %rax
	leaq	(%rax,%r14), %rdi
	cmpq	%r12, %rax
	cmovbeq	%rax, %rdi
	movq	%r8, %rax
	mulq	%rbx
	movl	%edx, %r8d
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r14, %r8
	addq	%rdx, %r8
	leaq	(%r8,%r14), %rax
	cmovaeq	%r8, %rax
	leaq	(%rax,%r14), %r9
	cmpq	%r12, %rax
	cmovbeq	%rax, %r9
	movq	%rcx, %rax
	movl	$7, %ebx
	mulq	%rbx
	imulq	%r14, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%r14), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%r14), %rcx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rcx
	addq	%rsi, %rcx
	leaq	(%rcx,%r14), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%r14), %r8
	cmpq	%r12, %rax
	cmovbeq	%rax, %r8
	addq	%rdi, %r9
	leaq	(%r9,%r14), %rax
	cmovaeq	%r9, %rax
	leaq	(%rax,%r14), %r10
	cmpq	%r12, %rax
	cmovbeq	%rax, %r10
	subq	$1, %r8
	cmovbq	%r12, %r8
.LBB19_9:
	leaq	24(%rsp), %r13
	movq	88(%rsp), %rbp
	cmpq	%rbp, 64(%rsp)
	movq	112(%rsp), %r11
	je	.LBB19_11
	movq	200(%rsp), %rdi
	movq	(%rdi,%rbp,8), %rsi
	movq	%rsi, %rax
	mulq	%r8
	movl	%edx, %ecx
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r12), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r14, %rcx
	addq	%rdx, %rcx
	leaq	(%rcx,%r14), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%r14), %r9
	cmpq	%r12, %rax
	cmovbeq	%rax, %r9
	movq	8(%rdi,%rbp,8), %rdi
	movq	%rdi, %rax
	mulq	%r10
	movq	%rax, %rcx
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rcx
	leaq	1(%rcx,%r12), %rax
	cmovbq	%rax, %rcx
	movl	%edx, %eax
	imulq	%r14, %rax
	addq	%rax, %rcx
	leaq	(%rcx,%r14), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%r14), %rax
	cmpq	%r12, %rcx
	cmovaq	%rax, %rcx
	movq	%rsi, %rax
	mulq	%r10
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%r12), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	imulq	%r14, %rax
	addq	%rsi, %rax
	leaq	(%rax,%r14), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%r14), %rsi
	cmpq	%r12, %rdx
	cmovbeq	%rdx, %rsi
	movq	%rdi, %rax
	mulq	%r8
	movq	%rdx, %rdi
	shrq	$32, %rdi
	subq	%rdi, %rax
	leaq	1(%rax,%r12), %rdi
	cmovaeq	%rax, %rdi
	movl	%edx, %eax
	imulq	%r14, %rax
	addq	%rdi, %rax
	leaq	(%rax,%r14), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%r14), %rdi
	cmpq	%r12, %rdx
	cmovbeq	%rdx, %rdi
	movq	%rcx, %rax
	mulq	%rbx
	imulq	%r14, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%r14), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%r14), %rcx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rcx
	addq	%r9, %rcx
	leaq	(%rcx,%r14), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%r14), %rcx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rcx
	addq	%rsi, %rdi
	leaq	(%rdi,%r14), %rax
	cmovaeq	%rdi, %rax
	leaq	(%rax,%r14), %rdx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rdx
	addq	(%rsp), %rcx
	leaq	(%rcx,%r14), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%r14), %rcx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rcx
	movq	%rcx, (%rsp)
	addq	96(%rsp), %rdx
	leaq	(%rdx,%r14), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%r14), %rdx
	cmpq	%r12, %rax
	cmovbeq	%rax, %rdx
	addq	$2, %rbp
	movq	80(%rsp), %r10
	addq	$80, %r10
	movq	104(%rsp), %r8
	incq	%r8
	decq	%r11
	jne	.LBB19_4
	jmp	.LBB19_2
.LBB19_1:
	xorl	%edx, %edx
	movq	$0, (%rsp)
.LBB19_2:
	movq	(%rsp), %rax
	addq	$136, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%r12
	.cfi_def_cfa_offset 40
	popq	%r13
	.cfi_def_cfa_offset 32
	popq	%r14
	.cfi_def_cfa_offset 24
	popq	%r15
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	retq
.LBB19_13:
	.cfi_def_cfa_offset 192
	leaq	.Lalloc_976e0beddddec32ff42087070bcd77a5(%rip), %rdx
	movq	%rbp, %rdi
	movq	8(%rsp), %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB19_11:
	leaq	.Lalloc_96d987a87d97c3b145ef68c6e71dd047(%rip), %rdx
	movq	208(%rsp), %rdi
	movq	%rdi, %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB19_12:
	leaq	.Lalloc_10b6528b98bd905c6309b430b77c3a07(%rip), %rdx
	movq	%r8, %rdi
	movq	16(%rsp), %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Lfunc_end19:
	.size	_RNvCsl0YfJI2rrfI_8isolated10helper_sum, .Lfunc_end19-_RNvCsl0YfJI2rrfI_8isolated10helper_sum
	.cfi_endproc

	.section	.text._RNvCsl0YfJI2rrfI_8isolated9factory_0,"ax",@progbits
	.p2align	4
	.type	_RNvCsl0YfJI2rrfI_8isolated9factory_0,@function
_RNvCsl0YfJI2rrfI_8isolated9factory_0:
.Lfunc_begin5:
	.cfi_startproc
	.cfi_personality 155, DW.ref.rust_eh_personality
	.cfi_lsda 27, .Lexception5
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	subq	$664, %rsp
	.cfi_def_cfa_offset 720
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%r9, 40(%rsp)
	movl	%r8d, %r15d
	movl	%ecx, %r12d
	movl	%edx, %r14d
	movq	%rsi, %rbp
	movq	%rdi, %r13
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$624, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB20_51
	movq	%rax, %rbx
	movl	$624, %edx
	movq	%rax, %rdi
	movl	$255, %esi
	callq	*memset@GOTPCREL(%rip)
	movl	$67, %eax
	.p2align	4
.LBB20_2:
	movq	%rax, %rcx
	incq	%rax
	leaq	-64(%rcx), %rdx
	movq	%rdx, (%rbx,%rcx,8)
	cmpq	$77, %rcx
	cmoveq	%rcx, %rax
	je	.LBB20_4
	cmpq	$77, %rax
	jbe	.LBB20_2
.LBB20_4:
	cmpq	$34, %rbp
	jbe	.LBB20_5
	movl	%r15d, 28(%rsp)
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$160, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB20_7
	movq	%rax, %r15
	leaq	400(%r13), %rsi
	movl	$160, %edx
	movq	%rax, %rdi
	callq	*memcpy@GOTPCREL(%rip)
	cmpq	$36, %rbp
	jbe	.LBB20_10
	movq	%r13, 32(%rsp)
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$32, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB20_12
	movq	%rax, %r13
	movl	%r14d, %ecx
	andl	$63, %ecx
	movl	$1, %r8d
	shlq	%cl, %r8
	cmpl	$63, %ecx
	movabsq	$9223372032559808513, %rax
	cmoveq	%rax, %r8
	movq	32(%rsp), %rsi
	movups	560(%rsi), %xmm0
	movl	%r12d, %ecx
	andl	$63, %ecx
	movl	$1, %edi
	shlq	%cl, %rdi
	movups	576(%rsi), %xmm1
	cmpl	$63, %ecx
	cmoveq	%rax, %rdi
	movups	%xmm1, 16(%r13)
	leal	-1(%r14), %ecx
	movl	$1, %r10d
	shlq	%cl, %r10
	xorl	%edx, %edx
	testl	%r14d, %r14d
	cmoveq	%rdx, %r10
	testq	%r10, %r10
	cmovsq	%rax, %r10
	leal	-1(%r12), %ecx
	movl	$1, %r9d
	shlq	%cl, %r9
	movups	%xmm0, (%r13)
	testl	%r12d, %r12d
	cmoveq	%rdx, %r9
	movups	336(%rsi), %xmm0
	testq	%r9, %r9
	cmovsq	%rax, %r9
	movups	352(%rsi), %xmm1
	movb	$8, %cl
	subb	%r12b, %cl
	movl	$1, %eax
	shlq	%cl, %rax
	movups	368(%rsi), %xmm2
	movl	$1, %edx
	movb	$16, %cl
	subb	%r14b, %cl
	shlq	%cl, %rdx
	movups	384(%rsi), %xmm3
	movaps	%xmm3, 640(%rsp)
	movq	$68, 448(%rsp)
	movq	$1, 456(%rsp)
	movq	$68, 464(%rsp)
	movq	%rax, 472(%rsp)
	movq	$71, 480(%rsp)
	movq	$1, 488(%rsp)
	movq	$72, 496(%rsp)
	movq	$1, 504(%rsp)
	movq	$74, 512(%rsp)
	movq	$1, 520(%rsp)
	movq	$75, 528(%rsp)
	movq	$1, 536(%rsp)
	movq	$76, 544(%rsp)
	movq	$1, 552(%rsp)
	movq	$77, 560(%rsp)
	movq	$1, 568(%rsp)
	movq	$77, 576(%rsp)
	movq	%rdx, 584(%rsp)
	movq	40(%rsp), %r12
	cmpq	$10, %r12
	jae	.LBB20_15
	movaps	%xmm2, 592(%rsp)
	movaps	%xmm1, 608(%rsp)
	movaps	%xmm0, 624(%rsp)
	movq	%r10, 80(%rsp)
	movq	%r9, 88(%rsp)
	movq	%r8, 96(%rsp)
	movq	%rdi, 104(%rsp)
	testq	%r12, %r12
	movq	%rbx, (%rsp)
	movq	%r15, 8(%rsp)
	movq	%r13, 16(%rsp)
	movq	%rbp, 72(%rsp)
	je	.LBB20_17
	leaq	(,%r12,8), %rax
	leaq	(%rax,%rax,4), %r15
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$8, %esi
	movq	%r15, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB20_19
	movq	%rax, %r14
	movq	%r12, 152(%rsp)
	movq	%rax, 160(%rsp)
	addq	$24, %r14
	leaq	456(%rsp), %rbx
	xorl	%r13d, %r13d
	.p2align	4
.LBB20_23:
	movq	-8(%rbx), %r15
	movq	(%rbx), %rbp
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$16, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB20_24
	movq	%rax, %r12
	cmpq	$78, %r15
	jae	.LBB20_26
	movq	(%rsp), %rax
	movq	(%rax,%r15,8), %rax
	movabsq	$-4294967295, %rdx
	leaq	(%rdx,%rbp), %rcx
	decq	%rcx
	cmpq	%rdx, %rcx
	movabsq	$-8589934590, %rcx
	cmovbq	%rdx, %rcx
	movq	%rbp, %rdx
	sarq	$63, %rdx
	andq	%rcx, %rdx
	addq	%rbp, %rdx
	movq	%rax, (%r12)
	movq	%rdx, 8(%r12)
	movq	$1, -24(%r14)
	movq	%r12, -16(%r14)
	movq	$1, -8(%r14)
	movaps	640(%rsp), %xmm0
	movups	%xmm0, (%r14)
	incq	%r13
	addq	$40, %r14
	addq	$16, %rbx
	movq	40(%rsp), %r12
	cmpq	%r13, %r12
	jne	.LBB20_23
	jmp	.LBB20_29
.LBB20_17:
	movq	$0, 152(%rsp)
	movq	$8, 160(%rsp)
.LBB20_29:
	movq	152(%rsp), %rax
	movq	%rax, 48(%rsp)
	movq	160(%rsp), %rax
	movq	%rax, 56(%rsp)
	movq	%r12, 64(%rsp)
	movq	$0, 112(%rsp)
	movq	$8, 120(%rsp)
	leaq	128(%rsp), %rax
	cmpb	$0, 28(%rsp)
	je	.LBB20_30
	movq	%r12, %rcx
	shrq	%rcx
	movq	%r12, %rdx
	subq	%rcx, %rdx
	negq	%rcx
	leaq	(%r12,%rcx), %rdi
	addq	$4, %rdi
	xorps	%xmm0, %xmm0
	movups	%xmm0, (%rax)
	movq	$0, 16(%rax)
	cmpq	$6, %rdx
	movq	(%rsp), %rbx
	movq	8(%rsp), %r14
	movq	16(%rsp), %r13
	jae	.LBB20_36
	shlq	$4, %rdi
	movups	(%r14,%rdi), %xmm0
	movups	%xmm0, 136(%rsp)
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$88, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	movq	%rax, %r12
	testq	%rax, %rax
	movq	72(%rsp), %rax
	movq	32(%rsp), %rdx
	je	.LBB20_34
	movq	$3, (%r12)
	movq	$4, 8(%r12)
	movq	$5, 16(%r12)
	movq	$6, 24(%r12)
	movq	$7, 32(%r12)
	movq	$8, 40(%r12)
	movq	$9, 48(%r12)
	movq	$10, 56(%r12)
	movq	$11, 64(%r12)
	movq	$12, 72(%r12)
	movq	$13, 80(%r12)
	cmpq	$37, %rax
	je	.LBB20_40
	movq	592(%rdx), %rcx
	movq	600(%rdx), %r8
.Ltmp32:
	leaq	112(%rsp), %rdi
	movl	$11, %edx
	movq	%r12, %rsi
	callq	_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm3add
.Ltmp33:
	movl	$88, %esi
	movl	$8, %edx
	movq	%r12, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	movl	$1, %eax
	jmp	.LBB20_31
.LBB20_30:
	xorps	%xmm0, %xmm0
	movups	%xmm0, (%rax)
	movq	$0, 16(%rax)
	xorl	%eax, %eax
	movq	(%rsp), %rbx
	movq	8(%rsp), %r14
	movq	16(%rsp), %r13
.LBB20_31:
	movq	$78, 168(%rsp)
	movq	%rbx, 176(%rsp)
	movq	$78, 184(%rsp)
	movq	$256, 304(%rsp)
	movq	$0, 312(%rsp)
	movq	96(%rsp), %rcx
	movq	%rcx, 320(%rsp)
	movq	$0, 328(%rsp)
	movq	80(%rsp), %rcx
	movq	%rcx, 336(%rsp)
	movq	$0, 344(%rsp)
	movq	$19, 352(%rsp)
	movaps	624(%rsp), %xmm0
	movups	%xmm0, 360(%rsp)
	movaps	608(%rsp), %xmm0
	movups	%xmm0, 376(%rsp)
	movaps	592(%rsp), %xmm0
	movups	%xmm0, 392(%rsp)
	movq	%rax, 152(%rsp)
	movq	$20, 160(%rsp)
	movaps	48(%rsp), %xmm0
	movups	%xmm0, 192(%rsp)
	movq	64(%rsp), %rax
	movq	%rax, 208(%rsp)
	movq	$14, 408(%rsp)
	movq	$10, 216(%rsp)
	movq	%r14, 224(%rsp)
	movq	$10, 232(%rsp)
	movups	112(%rsp), %xmm0
	movups	128(%rsp), %xmm1
	movups	%xmm0, 240(%rsp)
	movups	%xmm1, 256(%rsp)
	movq	144(%rsp), %rax
	movq	%rax, 272(%rsp)
	movq	104(%rsp), %rax
	movq	%rax, 416(%rsp)
	movq	$0, 424(%rsp)
	movq	88(%rsp), %rax
	movq	%rax, 432(%rsp)
	movq	$0, 440(%rsp)
	movq	$2, 280(%rsp)
	movq	%r13, 288(%rsp)
	movq	$2, 296(%rsp)
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$296, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB20_32
	leaq	152(%rsp), %rsi
	movl	$296, %edx
	movq	%rax, %rdi
	movq	%rax, %rbx
	callq	*memcpy@GOTPCREL(%rip)
	leaq	.Lvtable.0(%rip), %rdx
	movq	%rbx, %rax
	addq	$664, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%r12
	.cfi_def_cfa_offset 40
	popq	%r13
	.cfi_def_cfa_offset 32
	popq	%r14
	.cfi_def_cfa_offset 24
	popq	%r15
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	retq
.LBB20_24:
	.cfi_def_cfa_offset 720
.Ltmp24:
	movl	$8, %edi
	movl	$16, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error@GOTPCREL(%rip)
.Ltmp25:
	jmp	.LBB20_6
.LBB20_15:
.Ltmp19:
	leaq	.Lalloc_1343241238dcbe085445d5b11ba0a378(%rip), %rcx
	movl	$9, %edx
	xorl	%edi, %edi
	movq	%r12, %rsi
	callq	*_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail@GOTPCREL(%rip)
.Ltmp20:
	jmp	.LBB20_6
.LBB20_5:
.Ltmp15:
	leaq	.Lalloc_d29c77d346acbe694cb7ba8ee7faff56(%rip), %rcx
	movl	$25, %edi
	movl	$35, %esi
	movq	%rbp, %rdx
	callq	*_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail@GOTPCREL(%rip)
.Ltmp16:
	jmp	.LBB20_6
.LBB20_10:
.Ltmp17:
	leaq	.Lalloc_a51995a9f594fb331ed053838b7be924(%rip), %rcx
	movl	$35, %edi
	movl	$37, %esi
	movq	%rbp, %rdx
	callq	*_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail@GOTPCREL(%rip)
.Ltmp18:
	jmp	.LBB20_6
.LBB20_32:
.Ltmp34:
	movl	$8, %edi
	movl	$296, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error@GOTPCREL(%rip)
.Ltmp35:
	jmp	.LBB20_6
.LBB20_26:
.Ltmp21:
	leaq	.Lalloc_8a0667c067a77bb698bb88e8b54ac9d2(%rip), %rdx
	movl	$78, %esi
	movq	%r15, %rdi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Ltmp22:
	jmp	.LBB20_6
.LBB20_51:
	movl	$8, %edi
	movl	$624, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.LBB20_7:
.Ltmp46:
	movl	$8, %edi
	movl	$160, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp47:
	jmp	.LBB20_6
.LBB20_12:
.Ltmp43:
	movl	$8, %edi
	movl	$32, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp44:
	jmp	.LBB20_6
.LBB20_19:
.Ltmp27:
	movl	$8, %edi
	movq	%r15, %rsi
	movq	(%rsp), %rbx
	movq	8(%rsp), %r15
	movq	16(%rsp), %r13
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp28:
	jmp	.LBB20_6
.LBB20_36:
.Ltmp30:
	leaq	.Lalloc_23b5d640586d465cb57fc69fc0fb3828(%rip), %rdx
	movl	$10, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Ltmp31:
	jmp	.LBB20_6
.LBB20_34:
.Ltmp40:
	movl	$8, %edi
	movl	$88, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp41:
	jmp	.LBB20_6
.LBB20_40:
.Ltmp37:
	leaq	.Lalloc_0e8d56a95944120dff42b51dc5d24e92(%rip), %rdx
	movl	$37, %edi
	movl	$37, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Ltmp38:
.LBB20_6:
	ud2
.LBB20_41:
.Ltmp39:
	movq	%rax, %r14
	movl	$88, %esi
	movl	$8, %edx
	movq	%r12, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	jmp	.LBB20_44
.LBB20_43:
.Ltmp42:
	movq	%rax, %r14
.LBB20_44:
	leaq	112(%rsp), %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_
	leaq	48(%rsp), %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_
	movq	(%rsp), %rbx
	movq	8(%rsp), %r15
	jmp	.LBB20_45
.LBB20_27:
.Ltmp23:
	movq	%rax, %r14
	movl	$16, %esi
	movl	$8, %edx
	movq	%r12, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	jmp	.LBB20_21
.LBB20_47:
.Ltmp36:
	movq	%rax, %r14
	leaq	152(%rsp), %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_
	movq	%r14, %rdi
	callq	_Unwind_Resume@PLT
.LBB20_11:
.Ltmp45:
	movq	%rax, %r14
	jmp	.LBB20_46
.LBB20_49:
.Ltmp48:
	movq	%rax, %r14
	jmp	.LBB20_50
.LBB20_52:
.Ltmp29:
	movq	%rax, %r14
	jmp	.LBB20_45
.LBB20_20:
.Ltmp26:
	movq	%rax, %r14
.LBB20_21:
	movq	(%rsp), %rbx
	movq	8(%rsp), %r15
	movq	%r13, 168(%rsp)
	leaq	152(%rsp), %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_
	movq	16(%rsp), %r13
.LBB20_45:
	movl	$32, %esi
	movl	$8, %edx
	movq	%r13, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB20_46:
	movl	$160, %esi
	movl	$8, %edx
	movq	%r15, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB20_50:
	movl	$624, %esi
	movl	$8, %edx
	movq	%rbx, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	movq	%r14, %rdi
	callq	_Unwind_Resume@PLT
.Lfunc_end20:
	.size	_RNvCsl0YfJI2rrfI_8isolated9factory_0, .Lfunc_end20-_RNvCsl0YfJI2rrfI_8isolated9factory_0
	.cfi_endproc
	.section	.gcc_except_table._RNvCsl0YfJI2rrfI_8isolated9factory_0,"a",@progbits
	.p2align	2, 0x0
GCC_except_table20:
.Lexception5:
	.byte	255
	.byte	255
	.byte	1
	.uleb128 .Lcst_end5-.Lcst_begin5
.Lcst_begin5:
	.uleb128 .Lfunc_begin5-.Lfunc_begin5
	.uleb128 .Ltmp32-.Lfunc_begin5
	.byte	0
	.byte	0
	.uleb128 .Ltmp32-.Lfunc_begin5
	.uleb128 .Ltmp33-.Ltmp32
	.uleb128 .Ltmp39-.Lfunc_begin5
	.byte	0
	.uleb128 .Ltmp33-.Lfunc_begin5
	.uleb128 .Ltmp24-.Ltmp33
	.byte	0
	.byte	0
	.uleb128 .Ltmp24-.Lfunc_begin5
	.uleb128 .Ltmp25-.Ltmp24
	.uleb128 .Ltmp26-.Lfunc_begin5
	.byte	0
	.uleb128 .Ltmp19-.Lfunc_begin5
	.uleb128 .Ltmp20-.Ltmp19
	.uleb128 .Ltmp29-.Lfunc_begin5
	.byte	0
	.uleb128 .Ltmp15-.Lfunc_begin5
	.uleb128 .Ltmp16-.Ltmp15
	.uleb128 .Ltmp48-.Lfunc_begin5
	.byte	0
	.uleb128 .Ltmp17-.Lfunc_begin5
	.uleb128 .Ltmp18-.Ltmp17
	.uleb128 .Ltmp45-.Lfunc_begin5
	.byte	0
	.uleb128 .Ltmp34-.Lfunc_begin5
	.uleb128 .Ltmp35-.Ltmp34
	.uleb128 .Ltmp36-.Lfunc_begin5
	.byte	0
	.uleb128 .Ltmp21-.Lfunc_begin5
	.uleb128 .Ltmp22-.Ltmp21
	.uleb128 .Ltmp23-.Lfunc_begin5
	.byte	0
	.uleb128 .Ltmp22-.Lfunc_begin5
	.uleb128 .Ltmp46-.Ltmp22
	.byte	0
	.byte	0
	.uleb128 .Ltmp46-.Lfunc_begin5
	.uleb128 .Ltmp47-.Ltmp46
	.uleb128 .Ltmp48-.Lfunc_begin5
	.byte	0
	.uleb128 .Ltmp43-.Lfunc_begin5
	.uleb128 .Ltmp44-.Ltmp43
	.uleb128 .Ltmp45-.Lfunc_begin5
	.byte	0
	.uleb128 .Ltmp27-.Lfunc_begin5
	.uleb128 .Ltmp28-.Ltmp27
	.uleb128 .Ltmp29-.Lfunc_begin5
	.byte	0
	.uleb128 .Ltmp30-.Lfunc_begin5
	.uleb128 .Ltmp41-.Ltmp30
	.uleb128 .Ltmp42-.Lfunc_begin5
	.byte	0
	.uleb128 .Ltmp37-.Lfunc_begin5
	.uleb128 .Ltmp38-.Ltmp37
	.uleb128 .Ltmp39-.Lfunc_begin5
	.byte	0
	.uleb128 .Ltmp38-.Lfunc_begin5
	.uleb128 .Lfunc_end20-.Ltmp38
	.byte	0
	.byte	0
.Lcst_end5:
	.p2align	2, 0x0

	.section	.text._RNvCsl0YfJI2rrfI_8isolated9factory_1,"ax",@progbits
	.p2align	4
	.type	_RNvCsl0YfJI2rrfI_8isolated9factory_1,@function
_RNvCsl0YfJI2rrfI_8isolated9factory_1:
.Lfunc_begin6:
	.cfi_startproc
	.cfi_personality 155, DW.ref.rust_eh_personality
	.cfi_lsda 27, .Lexception6
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	subq	$648, %rsp
	.cfi_def_cfa_offset 704
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%r9, 40(%rsp)
	movl	%r8d, %r15d
	movl	%ecx, %r12d
	movl	%edx, %r14d
	movq	%rsi, %rbp
	movq	%rdi, %r13
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$624, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB21_51
	movq	%rax, %rbx
	movl	$624, %edx
	movq	%rax, %rdi
	movl	$255, %esi
	callq	*memset@GOTPCREL(%rip)
	movl	$67, %eax
	.p2align	4
.LBB21_2:
	movq	%rax, %rcx
	incq	%rax
	leaq	-64(%rcx), %rdx
	movq	%rdx, (%rbx,%rcx,8)
	cmpq	$77, %rcx
	cmoveq	%rcx, %rax
	je	.LBB21_4
	cmpq	$77, %rax
	jbe	.LBB21_2
.LBB21_4:
	cmpq	$34, %rbp
	jbe	.LBB21_5
	movl	%r15d, 28(%rsp)
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$160, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB21_7
	movq	%rax, %r15
	leaq	400(%r13), %rsi
	movl	$160, %edx
	movq	%rax, %rdi
	callq	*memcpy@GOTPCREL(%rip)
	cmpq	$36, %rbp
	jbe	.LBB21_10
	movq	%r13, 32(%rsp)
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$32, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB21_12
	movq	%rax, %r13
	movl	%r14d, %eax
	andl	$63, %eax
	movl	$1, %r8d
	movl	%eax, %ecx
	shlq	%cl, %r8
	movq	32(%rsp), %rsi
	movups	560(%rsi), %xmm0
	movl	%r12d, %ecx
	andl	$63, %ecx
	movl	$1, %edi
	shlq	%cl, %rdi
	cmpl	$63, %eax
	movabsq	$9223372032559808513, %rax
	cmoveq	%rax, %r8
	movups	576(%rsi), %xmm1
	cmpl	$63, %ecx
	cmoveq	%rax, %rdi
	movups	%xmm1, 16(%r13)
	leal	-1(%r14), %ecx
	movl	$1, %r10d
	shlq	%cl, %r10
	xorl	%edx, %edx
	testl	%r14d, %r14d
	cmoveq	%rdx, %r10
	testq	%r10, %r10
	cmovsq	%rax, %r10
	leal	-1(%r12), %ecx
	movl	$1, %r9d
	shlq	%cl, %r9
	movups	%xmm0, (%r13)
	testl	%r12d, %r12d
	cmoveq	%rdx, %r9
	movups	336(%rsi), %xmm0
	testq	%r9, %r9
	cmovsq	%rax, %r9
	movups	352(%rsi), %xmm1
	movb	$8, %cl
	subb	%r12b, %cl
	movl	$1, %eax
	shlq	%cl, %rax
	movups	368(%rsi), %xmm2
	movl	$1, %edx
	movb	$16, %cl
	subb	%r14b, %cl
	shlq	%cl, %rdx
	movups	384(%rsi), %xmm3
	movaps	%xmm3, 624(%rsp)
	movq	$68, 432(%rsp)
	movq	$1, 440(%rsp)
	movq	$68, 448(%rsp)
	movq	%rax, 456(%rsp)
	movq	$71, 464(%rsp)
	movq	$1, 472(%rsp)
	movq	$72, 480(%rsp)
	movq	$1, 488(%rsp)
	movq	$74, 496(%rsp)
	movq	$1, 504(%rsp)
	movq	$75, 512(%rsp)
	movq	$1, 520(%rsp)
	movq	$76, 528(%rsp)
	movq	$1, 536(%rsp)
	movq	$77, 544(%rsp)
	movq	$1, 552(%rsp)
	movq	$77, 560(%rsp)
	movq	%rdx, 568(%rsp)
	movq	40(%rsp), %r12
	cmpq	$10, %r12
	jae	.LBB21_15
	movaps	%xmm2, 576(%rsp)
	movaps	%xmm1, 592(%rsp)
	movaps	%xmm0, 608(%rsp)
	movq	%r10, 88(%rsp)
	movq	%r9, 96(%rsp)
	movq	%r8, 104(%rsp)
	movq	%rdi, 112(%rsp)
	testq	%r12, %r12
	movq	%rbx, (%rsp)
	movq	%r15, 8(%rsp)
	movq	%r13, 16(%rsp)
	movq	%rbp, 80(%rsp)
	je	.LBB21_17
	leaq	(,%r12,8), %rax
	leaq	(%rax,%rax,4), %r15
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$8, %esi
	movq	%r15, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB21_19
	movq	%rax, %r14
	movq	%r12, 160(%rsp)
	movq	%rax, 168(%rsp)
	addq	$24, %r14
	leaq	440(%rsp), %rbx
	xorl	%r13d, %r13d
	.p2align	4
.LBB21_23:
	movq	-8(%rbx), %r15
	movq	(%rbx), %rbp
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$16, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB21_24
	movq	%rax, %r12
	cmpq	$78, %r15
	jae	.LBB21_26
	movq	(%rsp), %rax
	movq	(%rax,%r15,8), %rax
	movabsq	$-4294967295, %rdx
	leaq	(%rdx,%rbp), %rcx
	decq	%rcx
	cmpq	%rdx, %rcx
	movabsq	$-8589934590, %rcx
	cmovbq	%rdx, %rcx
	movq	%rbp, %rdx
	sarq	$63, %rdx
	andq	%rcx, %rdx
	addq	%rbp, %rdx
	movq	%rax, (%r12)
	movq	%rdx, 8(%r12)
	movq	$1, -24(%r14)
	movq	%r12, -16(%r14)
	movq	$1, -8(%r14)
	movaps	624(%rsp), %xmm0
	movups	%xmm0, (%r14)
	incq	%r13
	addq	$40, %r14
	addq	$16, %rbx
	movq	40(%rsp), %r12
	cmpq	%r13, %r12
	jne	.LBB21_23
	jmp	.LBB21_29
.LBB21_17:
	movq	$0, 160(%rsp)
	movq	$8, 168(%rsp)
.LBB21_29:
	movq	160(%rsp), %rax
	movq	%rax, 48(%rsp)
	movq	168(%rsp), %rax
	movq	%rax, 56(%rsp)
	movq	%r12, 64(%rsp)
	movq	$0, 120(%rsp)
	movq	$8, 128(%rsp)
	leaq	136(%rsp), %rax
	cmpb	$0, 28(%rsp)
	je	.LBB21_30
	movq	%r12, %rcx
	shrq	%rcx
	movq	%r12, %rdx
	subq	%rcx, %rdx
	negq	%rcx
	leaq	(%r12,%rcx), %rdi
	addq	$4, %rdi
	xorps	%xmm0, %xmm0
	movups	%xmm0, (%rax)
	movq	$0, 16(%rax)
	cmpq	$6, %rdx
	movq	(%rsp), %rbx
	movq	8(%rsp), %r14
	movq	16(%rsp), %r13
	jae	.LBB21_36
	shlq	$4, %rdi
	movups	(%r14,%rdi), %xmm0
	movups	%xmm0, 144(%rsp)
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$88, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	movq	%rax, %r12
	testq	%rax, %rax
	movq	80(%rsp), %rax
	movq	32(%rsp), %rdx
	je	.LBB21_34
	movq	$3, (%r12)
	movq	$4, 8(%r12)
	movq	$5, 16(%r12)
	movq	$6, 24(%r12)
	movq	$7, 32(%r12)
	movq	$8, 40(%r12)
	movq	$9, 48(%r12)
	movq	$10, 56(%r12)
	movq	$11, 64(%r12)
	movq	$12, 72(%r12)
	movq	$13, 80(%r12)
	cmpq	$37, %rax
	je	.LBB21_40
	movq	592(%rdx), %rcx
	movq	600(%rdx), %r8
.Ltmp66:
	leaq	120(%rsp), %rdi
	movl	$11, %edx
	movq	%r12, %rsi
	callq	_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm3add
.Ltmp67:
	movl	$88, %esi
	movl	$8, %edx
	movq	%r12, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	movl	$1, %eax
	jmp	.LBB21_31
.LBB21_30:
	xorps	%xmm0, %xmm0
	movups	%xmm0, (%rax)
	movq	$0, 16(%rax)
	xorl	%eax, %eax
	movq	(%rsp), %rbx
	movq	8(%rsp), %r14
	movq	16(%rsp), %r13
.LBB21_31:
	movq	$78, 176(%rsp)
	movq	%rbx, 184(%rsp)
	movq	$78, 192(%rsp)
	movq	$256, 312(%rsp)
	movq	104(%rsp), %rcx
	movq	%rcx, 320(%rsp)
	movq	88(%rsp), %rcx
	movq	%rcx, 328(%rsp)
	movq	$0, 336(%rsp)
	movq	$19, 344(%rsp)
	movaps	608(%rsp), %xmm0
	movups	%xmm0, 352(%rsp)
	movaps	592(%rsp), %xmm0
	movups	%xmm0, 368(%rsp)
	movaps	576(%rsp), %xmm0
	movups	%xmm0, 384(%rsp)
	movq	%rax, 160(%rsp)
	movq	$20, 168(%rsp)
	movaps	48(%rsp), %xmm0
	movups	%xmm0, 200(%rsp)
	movq	64(%rsp), %rax
	movq	%rax, 216(%rsp)
	movq	$14, 400(%rsp)
	movq	$10, 224(%rsp)
	movq	%r14, 232(%rsp)
	movq	$10, 240(%rsp)
	movq	152(%rsp), %rax
	movq	%rax, 280(%rsp)
	movups	120(%rsp), %xmm0
	movups	136(%rsp), %xmm1
	movups	%xmm1, 264(%rsp)
	movups	%xmm0, 248(%rsp)
	movq	112(%rsp), %rax
	movq	%rax, 408(%rsp)
	movq	96(%rsp), %rax
	movq	%rax, 416(%rsp)
	movq	$0, 424(%rsp)
	movq	$2, 288(%rsp)
	movq	%r13, 296(%rsp)
	movq	$2, 304(%rsp)
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$272, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB21_32
	leaq	160(%rsp), %rsi
	movl	$272, %edx
	movq	%rax, %rdi
	movq	%rax, %rbx
	callq	*memcpy@GOTPCREL(%rip)
	leaq	.Lvtable.1(%rip), %rdx
	movq	%rbx, %rax
	addq	$648, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%r12
	.cfi_def_cfa_offset 40
	popq	%r13
	.cfi_def_cfa_offset 32
	popq	%r14
	.cfi_def_cfa_offset 24
	popq	%r15
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	retq
.LBB21_24:
	.cfi_def_cfa_offset 704
.Ltmp58:
	movl	$8, %edi
	movl	$16, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error@GOTPCREL(%rip)
.Ltmp59:
	jmp	.LBB21_6
.LBB21_15:
.Ltmp53:
	leaq	.Lalloc_9441bbbb1bffb9011b99cd574d638c7a(%rip), %rcx
	movl	$9, %edx
	xorl	%edi, %edi
	movq	%r12, %rsi
	callq	*_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail@GOTPCREL(%rip)
.Ltmp54:
	jmp	.LBB21_6
.LBB21_5:
.Ltmp49:
	leaq	.Lalloc_f0438cd97fee7f47e6788e32f762b012(%rip), %rcx
	movl	$25, %edi
	movl	$35, %esi
	movq	%rbp, %rdx
	callq	*_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail@GOTPCREL(%rip)
.Ltmp50:
	jmp	.LBB21_6
.LBB21_10:
.Ltmp51:
	leaq	.Lalloc_cedfa6dae4663ae34151168cdec22263(%rip), %rcx
	movl	$35, %edi
	movl	$37, %esi
	movq	%rbp, %rdx
	callq	*_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail@GOTPCREL(%rip)
.Ltmp52:
	jmp	.LBB21_6
.LBB21_32:
.Ltmp68:
	movl	$8, %edi
	movl	$272, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error@GOTPCREL(%rip)
.Ltmp69:
	jmp	.LBB21_6
.LBB21_26:
.Ltmp55:
	leaq	.Lalloc_28926e658ad846032cbbfac196c44ac3(%rip), %rdx
	movl	$78, %esi
	movq	%r15, %rdi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Ltmp56:
	jmp	.LBB21_6
.LBB21_51:
	movl	$8, %edi
	movl	$624, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.LBB21_7:
.Ltmp80:
	movl	$8, %edi
	movl	$160, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp81:
	jmp	.LBB21_6
.LBB21_12:
.Ltmp77:
	movl	$8, %edi
	movl	$32, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp78:
	jmp	.LBB21_6
.LBB21_19:
.Ltmp61:
	movl	$8, %edi
	movq	%r15, %rsi
	movq	(%rsp), %rbx
	movq	8(%rsp), %r15
	movq	16(%rsp), %r13
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp62:
	jmp	.LBB21_6
.LBB21_36:
.Ltmp64:
	leaq	.Lalloc_058578575a98bb3429578f82748d5aad(%rip), %rdx
	movl	$10, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Ltmp65:
	jmp	.LBB21_6
.LBB21_34:
.Ltmp74:
	movl	$8, %edi
	movl	$88, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp75:
	jmp	.LBB21_6
.LBB21_40:
.Ltmp71:
	leaq	.Lalloc_7f7b0d1637cd18edc5b90423efa8f2ac(%rip), %rdx
	movl	$37, %edi
	movl	$37, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Ltmp72:
.LBB21_6:
	ud2
.LBB21_41:
.Ltmp73:
	movq	%rax, %r14
	movl	$88, %esi
	movl	$8, %edx
	movq	%r12, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	jmp	.LBB21_44
.LBB21_43:
.Ltmp76:
	movq	%rax, %r14
.LBB21_44:
	leaq	120(%rsp), %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_
	leaq	48(%rsp), %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_
	movq	(%rsp), %rbx
	movq	8(%rsp), %r15
	jmp	.LBB21_45
.LBB21_27:
.Ltmp57:
	movq	%rax, %r14
	movl	$16, %esi
	movl	$8, %edx
	movq	%r12, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	jmp	.LBB21_21
.LBB21_47:
.Ltmp70:
	movq	%rax, %r14
	leaq	160(%rsp), %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_
	movq	%r14, %rdi
	callq	_Unwind_Resume@PLT
.LBB21_11:
.Ltmp79:
	movq	%rax, %r14
	jmp	.LBB21_46
.LBB21_49:
.Ltmp82:
	movq	%rax, %r14
	jmp	.LBB21_50
.LBB21_52:
.Ltmp63:
	movq	%rax, %r14
	jmp	.LBB21_45
.LBB21_20:
.Ltmp60:
	movq	%rax, %r14
.LBB21_21:
	movq	(%rsp), %rbx
	movq	8(%rsp), %r15
	movq	%r13, 176(%rsp)
	leaq	160(%rsp), %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_
	movq	16(%rsp), %r13
.LBB21_45:
	movl	$32, %esi
	movl	$8, %edx
	movq	%r13, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB21_46:
	movl	$160, %esi
	movl	$8, %edx
	movq	%r15, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB21_50:
	movl	$624, %esi
	movl	$8, %edx
	movq	%rbx, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	movq	%r14, %rdi
	callq	_Unwind_Resume@PLT
.Lfunc_end21:
	.size	_RNvCsl0YfJI2rrfI_8isolated9factory_1, .Lfunc_end21-_RNvCsl0YfJI2rrfI_8isolated9factory_1
	.cfi_endproc
	.section	.gcc_except_table._RNvCsl0YfJI2rrfI_8isolated9factory_1,"a",@progbits
	.p2align	2, 0x0
GCC_except_table21:
.Lexception6:
	.byte	255
	.byte	255
	.byte	1
	.uleb128 .Lcst_end6-.Lcst_begin6
.Lcst_begin6:
	.uleb128 .Lfunc_begin6-.Lfunc_begin6
	.uleb128 .Ltmp66-.Lfunc_begin6
	.byte	0
	.byte	0
	.uleb128 .Ltmp66-.Lfunc_begin6
	.uleb128 .Ltmp67-.Ltmp66
	.uleb128 .Ltmp73-.Lfunc_begin6
	.byte	0
	.uleb128 .Ltmp67-.Lfunc_begin6
	.uleb128 .Ltmp58-.Ltmp67
	.byte	0
	.byte	0
	.uleb128 .Ltmp58-.Lfunc_begin6
	.uleb128 .Ltmp59-.Ltmp58
	.uleb128 .Ltmp60-.Lfunc_begin6
	.byte	0
	.uleb128 .Ltmp53-.Lfunc_begin6
	.uleb128 .Ltmp54-.Ltmp53
	.uleb128 .Ltmp63-.Lfunc_begin6
	.byte	0
	.uleb128 .Ltmp49-.Lfunc_begin6
	.uleb128 .Ltmp50-.Ltmp49
	.uleb128 .Ltmp82-.Lfunc_begin6
	.byte	0
	.uleb128 .Ltmp51-.Lfunc_begin6
	.uleb128 .Ltmp52-.Ltmp51
	.uleb128 .Ltmp79-.Lfunc_begin6
	.byte	0
	.uleb128 .Ltmp68-.Lfunc_begin6
	.uleb128 .Ltmp69-.Ltmp68
	.uleb128 .Ltmp70-.Lfunc_begin6
	.byte	0
	.uleb128 .Ltmp55-.Lfunc_begin6
	.uleb128 .Ltmp56-.Ltmp55
	.uleb128 .Ltmp57-.Lfunc_begin6
	.byte	0
	.uleb128 .Ltmp56-.Lfunc_begin6
	.uleb128 .Ltmp80-.Ltmp56
	.byte	0
	.byte	0
	.uleb128 .Ltmp80-.Lfunc_begin6
	.uleb128 .Ltmp81-.Ltmp80
	.uleb128 .Ltmp82-.Lfunc_begin6
	.byte	0
	.uleb128 .Ltmp77-.Lfunc_begin6
	.uleb128 .Ltmp78-.Ltmp77
	.uleb128 .Ltmp79-.Lfunc_begin6
	.byte	0
	.uleb128 .Ltmp61-.Lfunc_begin6
	.uleb128 .Ltmp62-.Ltmp61
	.uleb128 .Ltmp63-.Lfunc_begin6
	.byte	0
	.uleb128 .Ltmp64-.Lfunc_begin6
	.uleb128 .Ltmp75-.Ltmp64
	.uleb128 .Ltmp76-.Lfunc_begin6
	.byte	0
	.uleb128 .Ltmp71-.Lfunc_begin6
	.uleb128 .Ltmp72-.Ltmp71
	.uleb128 .Ltmp73-.Lfunc_begin6
	.byte	0
	.uleb128 .Ltmp72-.Lfunc_begin6
	.uleb128 .Lfunc_end21-.Ltmp72
	.byte	0
	.byte	0
.Lcst_end6:
	.p2align	2, 0x0

	.section	.text._RNvCsl0YfJI2rrfI_8isolated9factory_2,"ax",@progbits
	.p2align	4
	.type	_RNvCsl0YfJI2rrfI_8isolated9factory_2,@function
_RNvCsl0YfJI2rrfI_8isolated9factory_2:
.Lfunc_begin7:
	.cfi_startproc
	.cfi_personality 155, DW.ref.rust_eh_personality
	.cfi_lsda 27, .Lexception7
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	subq	$664, %rsp
	.cfi_def_cfa_offset 720
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%r9, 40(%rsp)
	movl	%r8d, %r15d
	movl	%ecx, %r12d
	movl	%edx, %r14d
	movq	%rsi, %rbp
	movq	%rdi, %r13
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$624, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB22_51
	movq	%rax, %rbx
	movl	$624, %edx
	movq	%rax, %rdi
	movl	$255, %esi
	callq	*memset@GOTPCREL(%rip)
	movl	$67, %eax
	.p2align	4
.LBB22_2:
	movq	%rax, %rcx
	incq	%rax
	leaq	-64(%rcx), %rdx
	movq	%rdx, (%rbx,%rcx,8)
	cmpq	$77, %rcx
	cmoveq	%rcx, %rax
	je	.LBB22_4
	cmpq	$77, %rax
	jbe	.LBB22_2
.LBB22_4:
	cmpq	$34, %rbp
	jbe	.LBB22_5
	movl	%r15d, 28(%rsp)
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$160, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB22_7
	movq	%rax, %r15
	leaq	400(%r13), %rsi
	movl	$160, %edx
	movq	%rax, %rdi
	callq	*memcpy@GOTPCREL(%rip)
	cmpq	$36, %rbp
	jbe	.LBB22_10
	movq	%r13, 32(%rsp)
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$32, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB22_12
	movq	%rax, %r13
	movl	%r14d, %ecx
	andl	$63, %ecx
	movl	$1, %r8d
	shlq	%cl, %r8
	cmpl	$63, %ecx
	movabsq	$9223372032559808513, %rax
	cmoveq	%rax, %r8
	movq	32(%rsp), %rsi
	movups	560(%rsi), %xmm0
	movl	%r12d, %ecx
	andl	$63, %ecx
	movl	$1, %edi
	shlq	%cl, %rdi
	movups	576(%rsi), %xmm1
	cmpl	$63, %ecx
	cmoveq	%rax, %rdi
	movups	%xmm1, 16(%r13)
	leal	-1(%r14), %ecx
	movl	$1, %r10d
	shlq	%cl, %r10
	xorl	%edx, %edx
	testl	%r14d, %r14d
	cmoveq	%rdx, %r10
	testq	%r10, %r10
	cmovsq	%rax, %r10
	leal	-1(%r12), %ecx
	movl	$1, %r9d
	shlq	%cl, %r9
	movups	%xmm0, (%r13)
	testl	%r12d, %r12d
	cmoveq	%rdx, %r9
	movups	336(%rsi), %xmm0
	testq	%r9, %r9
	cmovsq	%rax, %r9
	movups	352(%rsi), %xmm1
	movb	$8, %cl
	subb	%r12b, %cl
	movl	$1, %eax
	shlq	%cl, %rax
	movups	368(%rsi), %xmm2
	movl	$1, %edx
	movb	$16, %cl
	subb	%r14b, %cl
	shlq	%cl, %rdx
	movups	384(%rsi), %xmm3
	movaps	%xmm3, 640(%rsp)
	movq	$68, 448(%rsp)
	movq	$1, 456(%rsp)
	movq	$68, 464(%rsp)
	movq	%rax, 472(%rsp)
	movq	$71, 480(%rsp)
	movq	$1, 488(%rsp)
	movq	$72, 496(%rsp)
	movq	$1, 504(%rsp)
	movq	$74, 512(%rsp)
	movq	$1, 520(%rsp)
	movq	$75, 528(%rsp)
	movq	$1, 536(%rsp)
	movq	$76, 544(%rsp)
	movq	$1, 552(%rsp)
	movq	$77, 560(%rsp)
	movq	$1, 568(%rsp)
	movq	$77, 576(%rsp)
	movq	%rdx, 584(%rsp)
	movq	40(%rsp), %r12
	cmpq	$10, %r12
	jae	.LBB22_15
	movaps	%xmm2, 592(%rsp)
	movaps	%xmm1, 608(%rsp)
	movaps	%xmm0, 624(%rsp)
	movq	%r10, 80(%rsp)
	movq	%r9, 88(%rsp)
	movq	%r8, 96(%rsp)
	movq	%rdi, 104(%rsp)
	testq	%r12, %r12
	movq	%rbx, (%rsp)
	movq	%r15, 8(%rsp)
	movq	%r13, 16(%rsp)
	movq	%rbp, 72(%rsp)
	je	.LBB22_17
	leaq	(,%r12,8), %rax
	leaq	(%rax,%rax,4), %r15
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$8, %esi
	movq	%r15, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB22_19
	movq	%rax, %r14
	movq	%r12, 152(%rsp)
	movq	%rax, 160(%rsp)
	addq	$24, %r14
	leaq	456(%rsp), %rbx
	xorl	%r13d, %r13d
	.p2align	4
.LBB22_23:
	movq	-8(%rbx), %r15
	movq	(%rbx), %rbp
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$16, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB22_24
	movq	%rax, %r12
	cmpq	$78, %r15
	jae	.LBB22_26
	movq	(%rsp), %rax
	movq	(%rax,%r15,8), %rax
	movabsq	$-4294967295, %rdx
	leaq	(%rdx,%rbp), %rcx
	decq	%rcx
	cmpq	%rdx, %rcx
	movabsq	$-8589934590, %rcx
	cmovbq	%rdx, %rcx
	movq	%rbp, %rdx
	sarq	$63, %rdx
	andq	%rcx, %rdx
	addq	%rbp, %rdx
	movq	%rax, (%r12)
	movq	%rdx, 8(%r12)
	movq	$1, -24(%r14)
	movq	%r12, -16(%r14)
	movq	$1, -8(%r14)
	movaps	640(%rsp), %xmm0
	movups	%xmm0, (%r14)
	incq	%r13
	addq	$40, %r14
	addq	$16, %rbx
	movq	40(%rsp), %r12
	cmpq	%r13, %r12
	jne	.LBB22_23
	jmp	.LBB22_29
.LBB22_17:
	movq	$0, 152(%rsp)
	movq	$8, 160(%rsp)
.LBB22_29:
	movq	152(%rsp), %rax
	movq	%rax, 48(%rsp)
	movq	160(%rsp), %rax
	movq	%rax, 56(%rsp)
	movq	%r12, 64(%rsp)
	movq	$0, 112(%rsp)
	movq	$8, 120(%rsp)
	leaq	128(%rsp), %rax
	cmpb	$0, 28(%rsp)
	je	.LBB22_30
	movq	%r12, %rcx
	shrq	%rcx
	movq	%r12, %rdx
	subq	%rcx, %rdx
	negq	%rcx
	leaq	(%r12,%rcx), %rdi
	addq	$4, %rdi
	xorps	%xmm0, %xmm0
	movups	%xmm0, (%rax)
	movq	$0, 16(%rax)
	cmpq	$6, %rdx
	movq	(%rsp), %rbx
	movq	8(%rsp), %r14
	movq	16(%rsp), %r13
	jae	.LBB22_36
	shlq	$4, %rdi
	movups	(%r14,%rdi), %xmm0
	movups	%xmm0, 136(%rsp)
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$88, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	movq	%rax, %r12
	testq	%rax, %rax
	movq	72(%rsp), %rax
	movq	32(%rsp), %rdx
	je	.LBB22_34
	movq	$3, (%r12)
	movq	$4, 8(%r12)
	movq	$5, 16(%r12)
	movq	$6, 24(%r12)
	movq	$7, 32(%r12)
	movq	$8, 40(%r12)
	movq	$9, 48(%r12)
	movq	$10, 56(%r12)
	movq	$11, 64(%r12)
	movq	$12, 72(%r12)
	movq	$13, 80(%r12)
	cmpq	$37, %rax
	je	.LBB22_40
	movq	592(%rdx), %rcx
	movq	600(%rdx), %r8
.Ltmp100:
	leaq	112(%rsp), %rdi
	movl	$11, %edx
	movq	%r12, %rsi
	callq	_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm3add
.Ltmp101:
	movl	$88, %esi
	movl	$8, %edx
	movq	%r12, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	movl	$1, %eax
	jmp	.LBB22_31
.LBB22_30:
	xorps	%xmm0, %xmm0
	movups	%xmm0, (%rax)
	movq	$0, 16(%rax)
	xorl	%eax, %eax
	movq	(%rsp), %rbx
	movq	8(%rsp), %r14
	movq	16(%rsp), %r13
.LBB22_31:
	movq	$78, 168(%rsp)
	movq	%rbx, 176(%rsp)
	movq	$78, 184(%rsp)
	movq	$256, 304(%rsp)
	movq	$0, 312(%rsp)
	movq	96(%rsp), %rcx
	movq	%rcx, 320(%rsp)
	movq	$0, 328(%rsp)
	movq	80(%rsp), %rcx
	movq	%rcx, 336(%rsp)
	movq	$0, 344(%rsp)
	movq	$19, 352(%rsp)
	movaps	624(%rsp), %xmm0
	movups	%xmm0, 360(%rsp)
	movaps	608(%rsp), %xmm0
	movups	%xmm0, 376(%rsp)
	movaps	592(%rsp), %xmm0
	movups	%xmm0, 392(%rsp)
	movq	%rax, 152(%rsp)
	movq	$20, 160(%rsp)
	movaps	48(%rsp), %xmm0
	movups	%xmm0, 192(%rsp)
	movq	64(%rsp), %rax
	movq	%rax, 208(%rsp)
	movq	$14, 408(%rsp)
	movq	$10, 216(%rsp)
	movq	%r14, 224(%rsp)
	movq	$10, 232(%rsp)
	movups	112(%rsp), %xmm0
	movups	128(%rsp), %xmm1
	movups	%xmm0, 240(%rsp)
	movups	%xmm1, 256(%rsp)
	movq	144(%rsp), %rax
	movq	%rax, 272(%rsp)
	movq	104(%rsp), %rax
	movq	%rax, 416(%rsp)
	movq	$0, 424(%rsp)
	movq	88(%rsp), %rax
	movq	%rax, 432(%rsp)
	movq	$0, 440(%rsp)
	movq	$2, 280(%rsp)
	movq	%r13, 288(%rsp)
	movq	$2, 296(%rsp)
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$296, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB22_32
	leaq	152(%rsp), %rsi
	movl	$296, %edx
	movq	%rax, %rdi
	movq	%rax, %rbx
	callq	*memcpy@GOTPCREL(%rip)
	leaq	.Lvtable.2(%rip), %rdx
	movq	%rbx, %rax
	addq	$664, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%r12
	.cfi_def_cfa_offset 40
	popq	%r13
	.cfi_def_cfa_offset 32
	popq	%r14
	.cfi_def_cfa_offset 24
	popq	%r15
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	retq
.LBB22_24:
	.cfi_def_cfa_offset 720
.Ltmp92:
	movl	$8, %edi
	movl	$16, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error@GOTPCREL(%rip)
.Ltmp93:
	jmp	.LBB22_6
.LBB22_15:
.Ltmp87:
	leaq	.Lalloc_16fb6e1cf5412ccbca18445a9781d2ea(%rip), %rcx
	movl	$9, %edx
	xorl	%edi, %edi
	movq	%r12, %rsi
	callq	*_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail@GOTPCREL(%rip)
.Ltmp88:
	jmp	.LBB22_6
.LBB22_5:
.Ltmp83:
	leaq	.Lalloc_4d6b7a825e6461216f128f0802dfe2ec(%rip), %rcx
	movl	$25, %edi
	movl	$35, %esi
	movq	%rbp, %rdx
	callq	*_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail@GOTPCREL(%rip)
.Ltmp84:
	jmp	.LBB22_6
.LBB22_10:
.Ltmp85:
	leaq	.Lalloc_b8ba05bf1ee24e89bc9451481eb89547(%rip), %rcx
	movl	$35, %edi
	movl	$37, %esi
	movq	%rbp, %rdx
	callq	*_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail@GOTPCREL(%rip)
.Ltmp86:
	jmp	.LBB22_6
.LBB22_32:
.Ltmp102:
	movl	$8, %edi
	movl	$296, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error@GOTPCREL(%rip)
.Ltmp103:
	jmp	.LBB22_6
.LBB22_26:
.Ltmp89:
	leaq	.Lalloc_9ff3b8d94994bf8c3f90654c665568fa(%rip), %rdx
	movl	$78, %esi
	movq	%r15, %rdi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Ltmp90:
	jmp	.LBB22_6
.LBB22_51:
	movl	$8, %edi
	movl	$624, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.LBB22_7:
.Ltmp114:
	movl	$8, %edi
	movl	$160, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp115:
	jmp	.LBB22_6
.LBB22_12:
.Ltmp111:
	movl	$8, %edi
	movl	$32, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp112:
	jmp	.LBB22_6
.LBB22_19:
.Ltmp95:
	movl	$8, %edi
	movq	%r15, %rsi
	movq	(%rsp), %rbx
	movq	8(%rsp), %r15
	movq	16(%rsp), %r13
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp96:
	jmp	.LBB22_6
.LBB22_36:
.Ltmp98:
	leaq	.Lalloc_0c9e7887a13d11b191a330181159523c(%rip), %rdx
	movl	$10, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Ltmp99:
	jmp	.LBB22_6
.LBB22_34:
.Ltmp108:
	movl	$8, %edi
	movl	$88, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp109:
	jmp	.LBB22_6
.LBB22_40:
.Ltmp105:
	leaq	.Lalloc_5b806d1bdaa4e2f1b1b427dca973f7a4(%rip), %rdx
	movl	$37, %edi
	movl	$37, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Ltmp106:
.LBB22_6:
	ud2
.LBB22_41:
.Ltmp107:
	movq	%rax, %r14
	movl	$88, %esi
	movl	$8, %edx
	movq	%r12, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	jmp	.LBB22_44
.LBB22_43:
.Ltmp110:
	movq	%rax, %r14
.LBB22_44:
	leaq	112(%rsp), %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_
	leaq	48(%rsp), %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_
	movq	(%rsp), %rbx
	movq	8(%rsp), %r15
	jmp	.LBB22_45
.LBB22_27:
.Ltmp91:
	movq	%rax, %r14
	movl	$16, %esi
	movl	$8, %edx
	movq	%r12, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	jmp	.LBB22_21
.LBB22_47:
.Ltmp104:
	movq	%rax, %r14
	leaq	152(%rsp), %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_
	movq	%r14, %rdi
	callq	_Unwind_Resume@PLT
.LBB22_11:
.Ltmp113:
	movq	%rax, %r14
	jmp	.LBB22_46
.LBB22_49:
.Ltmp116:
	movq	%rax, %r14
	jmp	.LBB22_50
.LBB22_52:
.Ltmp97:
	movq	%rax, %r14
	jmp	.LBB22_45
.LBB22_20:
.Ltmp94:
	movq	%rax, %r14
.LBB22_21:
	movq	(%rsp), %rbx
	movq	8(%rsp), %r15
	movq	%r13, 168(%rsp)
	leaq	152(%rsp), %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_
	movq	16(%rsp), %r13
.LBB22_45:
	movl	$32, %esi
	movl	$8, %edx
	movq	%r13, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB22_46:
	movl	$160, %esi
	movl	$8, %edx
	movq	%r15, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB22_50:
	movl	$624, %esi
	movl	$8, %edx
	movq	%rbx, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	movq	%r14, %rdi
	callq	_Unwind_Resume@PLT
.Lfunc_end22:
	.size	_RNvCsl0YfJI2rrfI_8isolated9factory_2, .Lfunc_end22-_RNvCsl0YfJI2rrfI_8isolated9factory_2
	.cfi_endproc
	.section	.gcc_except_table._RNvCsl0YfJI2rrfI_8isolated9factory_2,"a",@progbits
	.p2align	2, 0x0
GCC_except_table22:
.Lexception7:
	.byte	255
	.byte	255
	.byte	1
	.uleb128 .Lcst_end7-.Lcst_begin7
.Lcst_begin7:
	.uleb128 .Lfunc_begin7-.Lfunc_begin7
	.uleb128 .Ltmp100-.Lfunc_begin7
	.byte	0
	.byte	0
	.uleb128 .Ltmp100-.Lfunc_begin7
	.uleb128 .Ltmp101-.Ltmp100
	.uleb128 .Ltmp107-.Lfunc_begin7
	.byte	0
	.uleb128 .Ltmp101-.Lfunc_begin7
	.uleb128 .Ltmp92-.Ltmp101
	.byte	0
	.byte	0
	.uleb128 .Ltmp92-.Lfunc_begin7
	.uleb128 .Ltmp93-.Ltmp92
	.uleb128 .Ltmp94-.Lfunc_begin7
	.byte	0
	.uleb128 .Ltmp87-.Lfunc_begin7
	.uleb128 .Ltmp88-.Ltmp87
	.uleb128 .Ltmp97-.Lfunc_begin7
	.byte	0
	.uleb128 .Ltmp83-.Lfunc_begin7
	.uleb128 .Ltmp84-.Ltmp83
	.uleb128 .Ltmp116-.Lfunc_begin7
	.byte	0
	.uleb128 .Ltmp85-.Lfunc_begin7
	.uleb128 .Ltmp86-.Ltmp85
	.uleb128 .Ltmp113-.Lfunc_begin7
	.byte	0
	.uleb128 .Ltmp102-.Lfunc_begin7
	.uleb128 .Ltmp103-.Ltmp102
	.uleb128 .Ltmp104-.Lfunc_begin7
	.byte	0
	.uleb128 .Ltmp89-.Lfunc_begin7
	.uleb128 .Ltmp90-.Ltmp89
	.uleb128 .Ltmp91-.Lfunc_begin7
	.byte	0
	.uleb128 .Ltmp90-.Lfunc_begin7
	.uleb128 .Ltmp114-.Ltmp90
	.byte	0
	.byte	0
	.uleb128 .Ltmp114-.Lfunc_begin7
	.uleb128 .Ltmp115-.Ltmp114
	.uleb128 .Ltmp116-.Lfunc_begin7
	.byte	0
	.uleb128 .Ltmp111-.Lfunc_begin7
	.uleb128 .Ltmp112-.Ltmp111
	.uleb128 .Ltmp113-.Lfunc_begin7
	.byte	0
	.uleb128 .Ltmp95-.Lfunc_begin7
	.uleb128 .Ltmp96-.Ltmp95
	.uleb128 .Ltmp97-.Lfunc_begin7
	.byte	0
	.uleb128 .Ltmp98-.Lfunc_begin7
	.uleb128 .Ltmp109-.Ltmp98
	.uleb128 .Ltmp110-.Lfunc_begin7
	.byte	0
	.uleb128 .Ltmp105-.Lfunc_begin7
	.uleb128 .Ltmp106-.Ltmp105
	.uleb128 .Ltmp107-.Lfunc_begin7
	.byte	0
	.uleb128 .Ltmp106-.Lfunc_begin7
	.uleb128 .Lfunc_end22-.Ltmp106
	.byte	0
	.byte	0
.Lcst_end7:
	.p2align	2, 0x0

	.section	.text._RNvCsl0YfJI2rrfI_8isolated9factory_3,"ax",@progbits
	.p2align	4
	.type	_RNvCsl0YfJI2rrfI_8isolated9factory_3,@function
_RNvCsl0YfJI2rrfI_8isolated9factory_3:
.Lfunc_begin8:
	.cfi_startproc
	.cfi_personality 155, DW.ref.rust_eh_personality
	.cfi_lsda 27, .Lexception8
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	subq	$648, %rsp
	.cfi_def_cfa_offset 704
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%r9, 40(%rsp)
	movl	%r8d, %r15d
	movl	%ecx, %r12d
	movl	%edx, %r14d
	movq	%rsi, %rbp
	movq	%rdi, %r13
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$624, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB23_51
	movq	%rax, %rbx
	movl	$624, %edx
	movq	%rax, %rdi
	movl	$255, %esi
	callq	*memset@GOTPCREL(%rip)
	movl	$67, %eax
	.p2align	4
.LBB23_2:
	movq	%rax, %rcx
	incq	%rax
	leaq	-64(%rcx), %rdx
	movq	%rdx, (%rbx,%rcx,8)
	cmpq	$77, %rcx
	cmoveq	%rcx, %rax
	je	.LBB23_4
	cmpq	$77, %rax
	jbe	.LBB23_2
.LBB23_4:
	cmpq	$34, %rbp
	jbe	.LBB23_5
	movl	%r15d, 28(%rsp)
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$160, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB23_7
	movq	%rax, %r15
	leaq	400(%r13), %rsi
	movl	$160, %edx
	movq	%rax, %rdi
	callq	*memcpy@GOTPCREL(%rip)
	cmpq	$36, %rbp
	jbe	.LBB23_10
	movq	%r13, 32(%rsp)
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$32, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB23_12
	movq	%rax, %r13
	movl	%r14d, %eax
	andl	$63, %eax
	movl	$1, %r8d
	movl	%eax, %ecx
	shlq	%cl, %r8
	movq	32(%rsp), %rsi
	movups	560(%rsi), %xmm0
	movl	%r12d, %ecx
	andl	$63, %ecx
	movl	$1, %edi
	shlq	%cl, %rdi
	cmpl	$63, %eax
	movabsq	$9223372032559808513, %rax
	cmoveq	%rax, %r8
	movups	576(%rsi), %xmm1
	cmpl	$63, %ecx
	cmoveq	%rax, %rdi
	movups	%xmm1, 16(%r13)
	leal	-1(%r14), %ecx
	movl	$1, %r10d
	shlq	%cl, %r10
	xorl	%edx, %edx
	testl	%r14d, %r14d
	cmoveq	%rdx, %r10
	testq	%r10, %r10
	cmovsq	%rax, %r10
	leal	-1(%r12), %ecx
	movl	$1, %r9d
	shlq	%cl, %r9
	movups	%xmm0, (%r13)
	testl	%r12d, %r12d
	cmoveq	%rdx, %r9
	movups	336(%rsi), %xmm0
	testq	%r9, %r9
	cmovsq	%rax, %r9
	movups	352(%rsi), %xmm1
	movb	$8, %cl
	subb	%r12b, %cl
	movl	$1, %eax
	shlq	%cl, %rax
	movups	368(%rsi), %xmm2
	movl	$1, %edx
	movb	$16, %cl
	subb	%r14b, %cl
	shlq	%cl, %rdx
	movups	384(%rsi), %xmm3
	movaps	%xmm3, 624(%rsp)
	movq	$68, 432(%rsp)
	movq	$1, 440(%rsp)
	movq	$68, 448(%rsp)
	movq	%rax, 456(%rsp)
	movq	$71, 464(%rsp)
	movq	$1, 472(%rsp)
	movq	$72, 480(%rsp)
	movq	$1, 488(%rsp)
	movq	$74, 496(%rsp)
	movq	$1, 504(%rsp)
	movq	$75, 512(%rsp)
	movq	$1, 520(%rsp)
	movq	$76, 528(%rsp)
	movq	$1, 536(%rsp)
	movq	$77, 544(%rsp)
	movq	$1, 552(%rsp)
	movq	$77, 560(%rsp)
	movq	%rdx, 568(%rsp)
	movq	40(%rsp), %r12
	cmpq	$10, %r12
	jae	.LBB23_15
	movaps	%xmm2, 576(%rsp)
	movaps	%xmm1, 592(%rsp)
	movaps	%xmm0, 608(%rsp)
	movq	%r10, 88(%rsp)
	movq	%r9, 96(%rsp)
	movq	%r8, 104(%rsp)
	movq	%rdi, 112(%rsp)
	testq	%r12, %r12
	movq	%rbx, (%rsp)
	movq	%r15, 8(%rsp)
	movq	%r13, 16(%rsp)
	movq	%rbp, 80(%rsp)
	je	.LBB23_17
	leaq	(,%r12,8), %rax
	leaq	(%rax,%rax,4), %r15
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$8, %esi
	movq	%r15, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB23_19
	movq	%rax, %r14
	movq	%r12, 160(%rsp)
	movq	%rax, 168(%rsp)
	addq	$24, %r14
	leaq	440(%rsp), %rbx
	xorl	%r13d, %r13d
	.p2align	4
.LBB23_23:
	movq	-8(%rbx), %r15
	movq	(%rbx), %rbp
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$16, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB23_24
	movq	%rax, %r12
	cmpq	$78, %r15
	jae	.LBB23_26
	movq	(%rsp), %rax
	movq	(%rax,%r15,8), %rax
	movabsq	$-4294967295, %rdx
	leaq	(%rdx,%rbp), %rcx
	decq	%rcx
	cmpq	%rdx, %rcx
	movabsq	$-8589934590, %rcx
	cmovbq	%rdx, %rcx
	movq	%rbp, %rdx
	sarq	$63, %rdx
	andq	%rcx, %rdx
	addq	%rbp, %rdx
	movq	%rax, (%r12)
	movq	%rdx, 8(%r12)
	movq	$1, -24(%r14)
	movq	%r12, -16(%r14)
	movq	$1, -8(%r14)
	movaps	624(%rsp), %xmm0
	movups	%xmm0, (%r14)
	incq	%r13
	addq	$40, %r14
	addq	$16, %rbx
	movq	40(%rsp), %r12
	cmpq	%r13, %r12
	jne	.LBB23_23
	jmp	.LBB23_29
.LBB23_17:
	movq	$0, 160(%rsp)
	movq	$8, 168(%rsp)
.LBB23_29:
	movq	160(%rsp), %rax
	movq	%rax, 48(%rsp)
	movq	168(%rsp), %rax
	movq	%rax, 56(%rsp)
	movq	%r12, 64(%rsp)
	movq	$0, 120(%rsp)
	movq	$8, 128(%rsp)
	leaq	136(%rsp), %rax
	cmpb	$0, 28(%rsp)
	je	.LBB23_30
	movq	%r12, %rcx
	shrq	%rcx
	movq	%r12, %rdx
	subq	%rcx, %rdx
	negq	%rcx
	leaq	(%r12,%rcx), %rdi
	addq	$4, %rdi
	xorps	%xmm0, %xmm0
	movups	%xmm0, (%rax)
	movq	$0, 16(%rax)
	cmpq	$6, %rdx
	movq	(%rsp), %rbx
	movq	8(%rsp), %r14
	movq	16(%rsp), %r13
	jae	.LBB23_36
	shlq	$4, %rdi
	movups	(%r14,%rdi), %xmm0
	movups	%xmm0, 144(%rsp)
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$88, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	movq	%rax, %r12
	testq	%rax, %rax
	movq	80(%rsp), %rax
	movq	32(%rsp), %rdx
	je	.LBB23_34
	movq	$3, (%r12)
	movq	$4, 8(%r12)
	movq	$5, 16(%r12)
	movq	$6, 24(%r12)
	movq	$7, 32(%r12)
	movq	$8, 40(%r12)
	movq	$9, 48(%r12)
	movq	$10, 56(%r12)
	movq	$11, 64(%r12)
	movq	$12, 72(%r12)
	movq	$13, 80(%r12)
	cmpq	$37, %rax
	je	.LBB23_40
	movq	592(%rdx), %rcx
	movq	600(%rdx), %r8
.Ltmp134:
	leaq	120(%rsp), %rdi
	movl	$11, %edx
	movq	%r12, %rsi
	callq	_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm3add
.Ltmp135:
	movl	$88, %esi
	movl	$8, %edx
	movq	%r12, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	movl	$1, %eax
	jmp	.LBB23_31
.LBB23_30:
	xorps	%xmm0, %xmm0
	movups	%xmm0, (%rax)
	movq	$0, 16(%rax)
	xorl	%eax, %eax
	movq	(%rsp), %rbx
	movq	8(%rsp), %r14
	movq	16(%rsp), %r13
.LBB23_31:
	movq	$78, 176(%rsp)
	movq	%rbx, 184(%rsp)
	movq	$78, 192(%rsp)
	movq	$256, 312(%rsp)
	movq	104(%rsp), %rcx
	movq	%rcx, 320(%rsp)
	movq	88(%rsp), %rcx
	movq	%rcx, 328(%rsp)
	movq	$0, 336(%rsp)
	movq	$19, 344(%rsp)
	movaps	608(%rsp), %xmm0
	movups	%xmm0, 352(%rsp)
	movaps	592(%rsp), %xmm0
	movups	%xmm0, 368(%rsp)
	movaps	576(%rsp), %xmm0
	movups	%xmm0, 384(%rsp)
	movq	%rax, 160(%rsp)
	movq	$20, 168(%rsp)
	movaps	48(%rsp), %xmm0
	movups	%xmm0, 200(%rsp)
	movq	64(%rsp), %rax
	movq	%rax, 216(%rsp)
	movq	$14, 400(%rsp)
	movq	$10, 224(%rsp)
	movq	%r14, 232(%rsp)
	movq	$10, 240(%rsp)
	movq	152(%rsp), %rax
	movq	%rax, 280(%rsp)
	movups	120(%rsp), %xmm0
	movups	136(%rsp), %xmm1
	movups	%xmm1, 264(%rsp)
	movups	%xmm0, 248(%rsp)
	movq	112(%rsp), %rax
	movq	%rax, 408(%rsp)
	movq	96(%rsp), %rax
	movq	%rax, 416(%rsp)
	movq	$0, 424(%rsp)
	movq	$2, 288(%rsp)
	movq	%r13, 296(%rsp)
	movq	$2, 304(%rsp)
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$272, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB23_32
	leaq	160(%rsp), %rsi
	movl	$272, %edx
	movq	%rax, %rdi
	movq	%rax, %rbx
	callq	*memcpy@GOTPCREL(%rip)
	leaq	.Lvtable.3(%rip), %rdx
	movq	%rbx, %rax
	addq	$648, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%r12
	.cfi_def_cfa_offset 40
	popq	%r13
	.cfi_def_cfa_offset 32
	popq	%r14
	.cfi_def_cfa_offset 24
	popq	%r15
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	retq
.LBB23_24:
	.cfi_def_cfa_offset 704
.Ltmp126:
	movl	$8, %edi
	movl	$16, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error@GOTPCREL(%rip)
.Ltmp127:
	jmp	.LBB23_6
.LBB23_15:
.Ltmp121:
	leaq	.Lalloc_36684b31319358aad4985691b5adb1d1(%rip), %rcx
	movl	$9, %edx
	xorl	%edi, %edi
	movq	%r12, %rsi
	callq	*_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail@GOTPCREL(%rip)
.Ltmp122:
	jmp	.LBB23_6
.LBB23_5:
.Ltmp117:
	leaq	.Lalloc_26fc8e81fc819c8a9f630ccd48e47036(%rip), %rcx
	movl	$25, %edi
	movl	$35, %esi
	movq	%rbp, %rdx
	callq	*_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail@GOTPCREL(%rip)
.Ltmp118:
	jmp	.LBB23_6
.LBB23_10:
.Ltmp119:
	leaq	.Lalloc_529870ce56aabb58b099913f27113d23(%rip), %rcx
	movl	$35, %edi
	movl	$37, %esi
	movq	%rbp, %rdx
	callq	*_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail@GOTPCREL(%rip)
.Ltmp120:
	jmp	.LBB23_6
.LBB23_32:
.Ltmp136:
	movl	$8, %edi
	movl	$272, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error@GOTPCREL(%rip)
.Ltmp137:
	jmp	.LBB23_6
.LBB23_26:
.Ltmp123:
	leaq	.Lalloc_413c07112253bea69b9c0ea7f62d2d3b(%rip), %rdx
	movl	$78, %esi
	movq	%r15, %rdi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Ltmp124:
	jmp	.LBB23_6
.LBB23_51:
	movl	$8, %edi
	movl	$624, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.LBB23_7:
.Ltmp148:
	movl	$8, %edi
	movl	$160, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp149:
	jmp	.LBB23_6
.LBB23_12:
.Ltmp145:
	movl	$8, %edi
	movl	$32, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp146:
	jmp	.LBB23_6
.LBB23_19:
.Ltmp129:
	movl	$8, %edi
	movq	%r15, %rsi
	movq	(%rsp), %rbx
	movq	8(%rsp), %r15
	movq	16(%rsp), %r13
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp130:
	jmp	.LBB23_6
.LBB23_36:
.Ltmp132:
	leaq	.Lalloc_f861b8e02d0300dcb721b5d1c9a678c4(%rip), %rdx
	movl	$10, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Ltmp133:
	jmp	.LBB23_6
.LBB23_34:
.Ltmp142:
	movl	$8, %edi
	movl	$88, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp143:
	jmp	.LBB23_6
.LBB23_40:
.Ltmp139:
	leaq	.Lalloc_20064a57f7955b3dc6ee7ae10e9bd5ab(%rip), %rdx
	movl	$37, %edi
	movl	$37, %esi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Ltmp140:
.LBB23_6:
	ud2
.LBB23_41:
.Ltmp141:
	movq	%rax, %r14
	movl	$88, %esi
	movl	$8, %edx
	movq	%r12, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	jmp	.LBB23_44
.LBB23_43:
.Ltmp144:
	movq	%rax, %r14
.LBB23_44:
	leaq	120(%rsp), %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_
	leaq	48(%rsp), %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_
	movq	(%rsp), %rbx
	movq	8(%rsp), %r15
	jmp	.LBB23_45
.LBB23_27:
.Ltmp125:
	movq	%rax, %r14
	movl	$16, %esi
	movl	$8, %edx
	movq	%r12, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	jmp	.LBB23_21
.LBB23_47:
.Ltmp138:
	movq	%rax, %r14
	leaq	160(%rsp), %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_
	movq	%r14, %rdi
	callq	_Unwind_Resume@PLT
.LBB23_11:
.Ltmp147:
	movq	%rax, %r14
	jmp	.LBB23_46
.LBB23_49:
.Ltmp150:
	movq	%rax, %r14
	jmp	.LBB23_50
.LBB23_52:
.Ltmp131:
	movq	%rax, %r14
	jmp	.LBB23_45
.LBB23_20:
.Ltmp128:
	movq	%rax, %r14
.LBB23_21:
	movq	(%rsp), %rbx
	movq	8(%rsp), %r15
	movq	%r13, 176(%rsp)
	leaq	160(%rsp), %rdi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_
	movq	16(%rsp), %r13
.LBB23_45:
	movl	$32, %esi
	movl	$8, %edx
	movq	%r13, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB23_46:
	movl	$160, %esi
	movl	$8, %edx
	movq	%r15, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB23_50:
	movl	$624, %esi
	movl	$8, %edx
	movq	%rbx, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	movq	%r14, %rdi
	callq	_Unwind_Resume@PLT
.Lfunc_end23:
	.size	_RNvCsl0YfJI2rrfI_8isolated9factory_3, .Lfunc_end23-_RNvCsl0YfJI2rrfI_8isolated9factory_3
	.cfi_endproc
	.section	.gcc_except_table._RNvCsl0YfJI2rrfI_8isolated9factory_3,"a",@progbits
	.p2align	2, 0x0
GCC_except_table23:
.Lexception8:
	.byte	255
	.byte	255
	.byte	1
	.uleb128 .Lcst_end8-.Lcst_begin8
.Lcst_begin8:
	.uleb128 .Lfunc_begin8-.Lfunc_begin8
	.uleb128 .Ltmp134-.Lfunc_begin8
	.byte	0
	.byte	0
	.uleb128 .Ltmp134-.Lfunc_begin8
	.uleb128 .Ltmp135-.Ltmp134
	.uleb128 .Ltmp141-.Lfunc_begin8
	.byte	0
	.uleb128 .Ltmp135-.Lfunc_begin8
	.uleb128 .Ltmp126-.Ltmp135
	.byte	0
	.byte	0
	.uleb128 .Ltmp126-.Lfunc_begin8
	.uleb128 .Ltmp127-.Ltmp126
	.uleb128 .Ltmp128-.Lfunc_begin8
	.byte	0
	.uleb128 .Ltmp121-.Lfunc_begin8
	.uleb128 .Ltmp122-.Ltmp121
	.uleb128 .Ltmp131-.Lfunc_begin8
	.byte	0
	.uleb128 .Ltmp117-.Lfunc_begin8
	.uleb128 .Ltmp118-.Ltmp117
	.uleb128 .Ltmp150-.Lfunc_begin8
	.byte	0
	.uleb128 .Ltmp119-.Lfunc_begin8
	.uleb128 .Ltmp120-.Ltmp119
	.uleb128 .Ltmp147-.Lfunc_begin8
	.byte	0
	.uleb128 .Ltmp136-.Lfunc_begin8
	.uleb128 .Ltmp137-.Ltmp136
	.uleb128 .Ltmp138-.Lfunc_begin8
	.byte	0
	.uleb128 .Ltmp123-.Lfunc_begin8
	.uleb128 .Ltmp124-.Ltmp123
	.uleb128 .Ltmp125-.Lfunc_begin8
	.byte	0
	.uleb128 .Ltmp124-.Lfunc_begin8
	.uleb128 .Ltmp148-.Ltmp124
	.byte	0
	.byte	0
	.uleb128 .Ltmp148-.Lfunc_begin8
	.uleb128 .Ltmp149-.Ltmp148
	.uleb128 .Ltmp150-.Lfunc_begin8
	.byte	0
	.uleb128 .Ltmp145-.Lfunc_begin8
	.uleb128 .Ltmp146-.Ltmp145
	.uleb128 .Ltmp147-.Lfunc_begin8
	.byte	0
	.uleb128 .Ltmp129-.Lfunc_begin8
	.uleb128 .Ltmp130-.Ltmp129
	.uleb128 .Ltmp131-.Lfunc_begin8
	.byte	0
	.uleb128 .Ltmp132-.Lfunc_begin8
	.uleb128 .Ltmp143-.Ltmp132
	.uleb128 .Ltmp144-.Lfunc_begin8
	.byte	0
	.uleb128 .Ltmp139-.Lfunc_begin8
	.uleb128 .Ltmp140-.Ltmp139
	.uleb128 .Ltmp141-.Lfunc_begin8
	.byte	0
	.uleb128 .Ltmp140-.Lfunc_begin8
	.uleb128 .Lfunc_end23-.Ltmp140
	.byte	0
	.byte	0
.Lcst_end8:
	.p2align	2, 0x0

	.section	.text._RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm3add,"ax",@progbits
	.p2align	4
	.type	_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm3add,@function
_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm3add:
.Lfunc_begin9:
	.cfi_startproc
	.cfi_personality 155, DW.ref.rust_eh_personality
	.cfi_lsda 27, .Lexception9
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	subq	$88, %rsp
	.cfi_def_cfa_offset 144
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%rsi, 80(%rsp)
	testq	%rdx, %rdx
	je	.LBB24_22
	movq	%r8, %r12
	movabsq	$384307168202282326, %rsi
	movq	16(%rdi), %r10
	movl	$1, %r13d
	testq	%r10, %r10
	movq	%rcx, 40(%rsp)
	movq	%rdi, 56(%rsp)
	movq	%r10, 48(%rsp)
	movq	%rdx, 32(%rsp)
	je	.LBB24_10
	movq	8(%rdi), %r11
	movl	%r10d, %eax
	andl	$3, %eax
	cmpq	$4, %r10
	jae	.LBB24_4
	xorl	%ebx, %ebx
	xorl	%edi, %edi
	jmp	.LBB24_7
.LBB24_4:
	movq	%r10, %r8
	andq	$-4, %r8
	leaq	120(%r11), %r9
	xorl	%ebx, %ebx
	xorl	%edi, %edi
	.p2align	4
.LBB24_5:
	addq	-96(%r9), %rdi
	addq	-64(%r9), %rdi
	addq	-32(%r9), %rdi
	addq	(%r9), %rdi
	addq	$4, %rbx
	subq	$-128, %r9
	cmpq	%rbx, %r8
	jne	.LBB24_5
	testq	%rax, %rax
	je	.LBB24_9
.LBB24_7:
	shlq	$5, %rbx
	leaq	(%rbx,%r11), %r8
	addq	$24, %r8
	shll	$5, %eax
	xorl	%edx, %edx
	.p2align	4
.LBB24_8:
	addq	(%r8,%rdx), %rdi
	addq	$32, %rdx
	cmpq	%rdx, %rax
	jne	.LBB24_8
.LBB24_9:
	testq	%rdi, %rdi
	je	.LBB24_10
	movabsq	$-4294967296, %r8
	movl	$1, %r13d
	movl	$4294967295, %r9d
	xorl	%ebp, %ebp
	movl	$7, %r10d
	.p2align	4
.LBB24_26:
	movq	%r13, %rax
	mulq	%rcx
	movl	%edx, %r11d
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r8), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r9, %r11
	addq	%rdx, %r11
	leaq	(%r11,%r9), %rax
	cmovaeq	%r11, %rax
	leaq	(%rax,%r9), %r11
	cmpq	%r8, %rax
	cmovbeq	%rax, %r11
	movq	%rbp, %rax
	mulq	%r12
	movq	%rax, %r15
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %r15
	leaq	1(%r15,%r8), %rdx
	cmovbq	%rdx, %r15
	imulq	%r9, %rax
	addq	%rax, %r15
	leaq	(%r15,%r9), %rax
	cmovbq	%rax, %r15
	leaq	(%r15,%r9), %rax
	cmpq	%r8, %r15
	cmovaq	%rax, %r15
	movq	%r13, %rax
	mulq	%r12
	movl	%edx, %ebx
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r8), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r9, %rbx
	addq	%rdx, %rbx
	leaq	(%rbx,%r9), %rax
	cmovaeq	%rbx, %rax
	leaq	(%rax,%r9), %rbx
	cmpq	%r8, %rax
	cmovbeq	%rax, %rbx
	movq	%rbp, %rax
	mulq	%rcx
	movl	%edx, %r14d
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r8), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r9, %r14
	addq	%rdx, %r14
	leaq	(%r14,%r9), %rax
	cmovaeq	%r14, %rax
	leaq	(%rax,%r9), %r14
	cmpq	%r8, %rax
	cmovbeq	%rax, %r14
	movq	%r15, %rax
	mulq	%r10
	imulq	%r9, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%r9), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%r9), %rcx
	cmpq	%r8, %rax
	cmovbeq	%rax, %rcx
	addq	%r11, %rcx
	leaq	(%rcx,%r9), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%r9), %r13
	cmpq	%r8, %rax
	cmovbeq	%rax, %r13
	addq	%rbx, %r14
	leaq	(%r14,%r9), %rax
	cmovaeq	%r14, %rax
	movq	40(%rsp), %rcx
	leaq	(%rax,%r9), %rbp
	cmpq	%r8, %rax
	cmovbeq	%rax, %rbp
	decq	%rdi
	jne	.LBB24_26
	jmp	.LBB24_11
.LBB24_10:
	xorl	%ebp, %ebp
.LBB24_11:
	movq	32(%rsp), %r14
	leaq	(,%r14,8), %r15
	leaq	(%r15,%r15,2), %rbx
	decq	%rsi
	cmpq	%rsi, %r14
	jbe	.LBB24_13
	xorl	%edi, %edi
	movq	%rbx, %rsi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.LBB24_13:
	testq	%rbx, %rbx
	movq	%r12, 72(%rsp)
	je	.LBB24_14
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$8, %esi
	movq	%rbx, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	movl	$8, %edi
	testq	%rax, %rax
	jne	.LBB24_15
	movq	%rbx, %rsi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.LBB24_14:
	movl	$8, %eax
	xorl	%r14d, %r14d
.LBB24_15:
	movabsq	$-4294967296, %rbx
	movl	$4294967295, %r12d
	movq	%r14, 8(%rsp)
	movq	%rax, 16(%rsp)
	movq	$0, 24(%rsp)
	xorl	%r14d, %r14d
	movq	%r15, 64(%rsp)
	jmp	.LBB24_16
	.p2align	4
.LBB24_18:
	leaq	(%r15,%r15,2), %rsi
	movq	%r13, %rax
	movq	40(%rsp), %r9
	mulq	%r9
	incq	%r15
	movl	%edx, %ecx
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r12, %rcx
	addq	%rdx, %rcx
	leaq	(%rcx,%r12), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%r12), %rdi
	cmpq	%rbx, %rax
	cmovbeq	%rax, %rdi
	movq	%rbp, %rax
	movq	72(%rsp), %r8
	mulq	%r8
	movq	%rax, %rcx
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rcx
	leaq	1(%rcx,%rbx), %rdx
	cmovbq	%rdx, %rcx
	imulq	%r12, %rax
	addq	%rax, %rcx
	leaq	(%rcx,%r12), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%r12), %rax
	cmpq	%rbx, %rcx
	cmovaq	%rax, %rcx
	movq	%r13, %rax
	mulq	%r8
	movl	%edx, %r8d
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	imulq	%r12, %r8
	addq	%rdx, %r8
	leaq	(%r8,%r12), %rax
	cmovaeq	%r8, %rax
	leaq	(%rax,%r12), %r8
	cmpq	%rbx, %rax
	cmovbeq	%rax, %r8
	movq	%rbp, %rax
	mulq	%r9
	movq	%rdx, %r9
	shrq	$32, %r9
	subq	%r9, %rax
	leaq	1(%rax,%rbx), %r9
	cmovaeq	%rax, %r9
	movl	%edx, %eax
	imulq	%r12, %rax
	addq	%r9, %rax
	leaq	(%rax,%r12), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%r12), %r9
	cmpq	%rbx, %rdx
	cmovbeq	%rdx, %r9
	movq	16(%rsp), %r10
	movq	32(%rsp), %rax
	movq	%rax, (%r10,%rsi,8)
	movq	%rcx, %rax
	movl	$7, %ecx
	mulq	%rcx
	imulq	%r12, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%r12), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%r12), %rcx
	cmpq	%rbx, %rax
	cmovbeq	%rax, %rcx
	movq	%r13, 8(%r10,%rsi,8)
	movq	%rbp, 16(%r10,%rsi,8)
	addq	%rdi, %rcx
	leaq	(%rcx,%r12), %rax
	cmovaeq	%rcx, %rax
	leaq	(%rax,%r12), %r13
	cmpq	%rbx, %rax
	cmovbeq	%rax, %r13
	addq	%r8, %r9
	leaq	(%r9,%r12), %rax
	cmovaeq	%r9, %rax
	leaq	(%rax,%r12), %rbp
	cmpq	%rbx, %rax
	cmovbeq	%rax, %rbp
	movq	%r15, 24(%rsp)
	addq	$8, %r14
	movq	64(%rsp), %r15
	cmpq	%r14, %r15
	je	.LBB24_19
.LBB24_16:
	movq	80(%rsp), %rax
	movq	(%rax,%r14), %rax
	movq	%rax, 32(%rsp)
	movq	24(%rsp), %r15
	cmpq	8(%rsp), %r15
	jne	.LBB24_18
.Ltmp151:
	leaq	8(%rsp), %rdi
	callq	_RNvMs3_NtCs40k4W9msRzi_5alloc7raw_vecINtB5_6RawVecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE8grow_oneBS_
.Ltmp152:
	jmp	.LBB24_18
.LBB24_19:
	movq	8(%rsp), %r15
	movq	16(%rsp), %rbx
	movq	24(%rsp), %r14
	movq	56(%rsp), %r12
	movq	48(%rsp), %r13
	cmpq	(%r12), %r13
	jne	.LBB24_21
.Ltmp154:
	movq	%r12, %rdi
	callq	_RNvMs3_NtCs40k4W9msRzi_5alloc7raw_vecINtB5_6RawVecTjINtNtB7_3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEE8grow_oneB1a_
.Ltmp155:
.LBB24_21:
	movq	8(%r12), %rax
	movq	%r13, %rcx
	shlq	$5, %rcx
	movq	$20, (%rax,%rcx)
	movq	%r15, 8(%rax,%rcx)
	movq	%rbx, 16(%rax,%rcx)
	movq	%r14, 24(%rax,%rcx)
	incq	%r13
	movq	%r13, 16(%r12)
.LBB24_22:
	addq	$88, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%r12
	.cfi_def_cfa_offset 40
	popq	%r13
	.cfi_def_cfa_offset 32
	popq	%r14
	.cfi_def_cfa_offset 24
	popq	%r15
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	retq
.LBB24_27:
	.cfi_def_cfa_offset 144
.Ltmp156:
	movq	%rax, %r14
	testq	%r15, %r15
	jne	.LBB24_28
	jmp	.LBB24_29
.LBB24_30:
.Ltmp153:
	movq	%rax, %r14
	movq	8(%rsp), %r15
	testq	%r15, %r15
	je	.LBB24_29
	movq	16(%rsp), %rbx
.LBB24_28:
	shlq	$3, %r15
	leaq	(%r15,%r15,2), %rsi
	movl	$8, %edx
	movq	%rbx, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB24_29:
	movq	%r14, %rdi
	callq	_Unwind_Resume@PLT
.Lfunc_end24:
	.size	_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm3add, .Lfunc_end24-_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm3add
	.cfi_endproc
	.section	.gcc_except_table._RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm3add,"a",@progbits
	.p2align	2, 0x0
GCC_except_table24:
.Lexception9:
	.byte	255
	.byte	255
	.byte	1
	.uleb128 .Lcst_end9-.Lcst_begin9
.Lcst_begin9:
	.uleb128 .Lfunc_begin9-.Lfunc_begin9
	.uleb128 .Ltmp151-.Lfunc_begin9
	.byte	0
	.byte	0
	.uleb128 .Ltmp151-.Lfunc_begin9
	.uleb128 .Ltmp152-.Ltmp151
	.uleb128 .Ltmp153-.Lfunc_begin9
	.byte	0
	.uleb128 .Ltmp154-.Lfunc_begin9
	.uleb128 .Ltmp155-.Ltmp154
	.uleb128 .Ltmp156-.Lfunc_begin9
	.byte	0
	.uleb128 .Ltmp155-.Lfunc_begin9
	.uleb128 .Lfunc_end24-.Ltmp155
	.byte	0
	.byte	0
.Lcst_end9:
	.p2align	2, 0x0

	.section	.text._RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm4eval,"ax",@progbits
	.p2align	4
	.type	_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm4eval,@function
_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm4eval:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	subq	$72, %rsp
	.cfi_def_cfa_offset 128
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%rdx, (%rsp)
	movabsq	$-4294967296, %r15
	movl	$4294967295, %ecx
	movq	16(%rdi), %rdx
	testq	%rdx, %rdx
	movq	%rdi, 8(%rsp)
	je	.LBB25_1
	movq	8(%rdi), %r14
	shlq	$5, %rdx
	addq	%r14, %rdx
	xorl	%r11d, %r11d
	xorl	%r10d, %r10d
	movq	%rdx, 16(%rsp)
	jmp	.LBB25_3
	.p2align	4
.LBB25_5:
	xorl	%r10d, %r10d
	xorl	%r9d, %r9d
.LBB25_6:
	movq	32(%rsp), %r12
	subq	24(%rsp), %r12
	movq	%r9, %rax
	mulq	%r12
	movq	48(%rsp), %r14
	addq	$32, %r14
	movl	%edx, %edi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r15), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rcx, %rdi
	addq	%rdx, %rdi
	leaq	(%rdi,%rcx), %rax
	cmovaeq	%rdi, %rax
	leaq	(%rax,%rcx), %rbx
	cmpq	%r15, %rax
	cmovbeq	%rax, %rbx
	movq	%r10, %rax
	movq	40(%rsp), %r8
	mulq	%r8
	movq	%rax, %r11
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %r11
	leaq	1(%r11,%r15), %rdx
	cmovbq	%rdx, %r11
	imulq	%rcx, %rax
	addq	%rax, %r11
	leaq	(%r11,%rcx), %rax
	cmovbq	%rax, %r11
	leaq	(%r11,%rcx), %rax
	cmpq	%r15, %r11
	cmovaq	%rax, %r11
	movq	%r10, %rax
	mulq	%r12
	movl	%edx, %edi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r15), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rcx, %rdi
	addq	%rdx, %rdi
	leaq	(%rdi,%rcx), %rax
	cmovaeq	%rdi, %rax
	leaq	(%rax,%rcx), %rdi
	cmpq	%r15, %rax
	cmovbeq	%rax, %rdi
	movq	%r9, %rax
	mulq	%r8
	movl	%edx, %r8d
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r15), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rcx, %r8
	addq	%rdx, %r8
	leaq	(%r8,%rcx), %rax
	cmovaeq	%r8, %rax
	leaq	(%rax,%rcx), %r8
	cmpq	%r15, %rax
	cmovbeq	%rax, %r8
	movq	%r11, %rax
	movl	$7, %edx
	mulq	%rdx
	imulq	%rcx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rcx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rcx), %rdx
	cmpq	%r15, %rax
	cmovbeq	%rax, %rdx
	addq	%rbx, %rdx
	leaq	(%rdx,%rcx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rcx), %rdx
	cmpq	%r15, %rax
	cmovbeq	%rax, %rdx
	addq	%rdi, %r8
	leaq	(%r8,%rcx), %rax
	cmovaeq	%r8, %rax
	leaq	(%rax,%rcx), %rdi
	cmpq	%r15, %rax
	cmovbeq	%rax, %rdi
	addq	64(%rsp), %rdx
	leaq	(%rdx,%rcx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rcx), %r10
	cmpq	%r15, %rax
	cmovbeq	%rax, %r10
	addq	56(%rsp), %rdi
	leaq	(%rdi,%rcx), %rax
	cmovaeq	%rdi, %rax
	leaq	(%rax,%rcx), %r11
	cmpq	%r15, %rax
	cmovbeq	%rax, %r11
	movq	16(%rsp), %rdx
	cmpq	%rdx, %r14
	je	.LBB25_7
.LBB25_3:
	movq	(%r14), %rax
	cmpq	(%rsp), %rax
	jae	.LBB25_8
	movq	%r11, 56(%rsp)
	movq	%r10, 64(%rsp)
	shlq	$4, %rax
	movq	(%rsi,%rax), %rdx
	movq	8(%rsi,%rax), %rax
	movq	%rdx, 24(%rsp)
	cmpq	$2, %rdx
	movl	$1, %edi
	leaq	2(%r15), %rdx
	cmovaeq	%rdx, %rdi
	movq	%rdi, 32(%rsp)
	movq	%r15, %rdx
	subq	%rax, %rdx
	incq	%rdx
	testq	%rax, %rax
	cmoveq	%rax, %rdx
	movq	%rdx, 40(%rsp)
	movq	24(%r14), %rax
	testq	%rax, %rax
	movq	%r14, 48(%rsp)
	je	.LBB25_5
	movq	16(%r14), %rbp
	leaq	(%rax,%rax,2), %rax
	leaq	(,%rax,8), %r13
	addq	%rbp, %r13
	xorl	%r9d, %r9d
	xorl	%r10d, %r10d
	.p2align	4
.LBB25_10:
	movq	(%rbp), %rbx
	cmpq	(%rsp), %rbx
	jae	.LBB25_12
	movq	8(%rbp), %r8
	shlq	$4, %rbx
	movq	(%rsi,%rbx), %r11
	movq	%r11, %rax
	mulq	%r8
	movq	16(%rbp), %r12
	movl	%edx, %edi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r15), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rcx, %rdi
	addq	%rdx, %rdi
	leaq	(%rdi,%rcx), %rax
	cmovaeq	%rdi, %rax
	leaq	(%rax,%rcx), %rdi
	cmpq	%r15, %rax
	cmovbeq	%rax, %rdi
	movq	8(%rsi,%rbx), %r14
	movq	%r14, %rax
	mulq	%r12
	movq	%rax, %rbx
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %rbx
	leaq	1(%rbx,%r15), %rax
	cmovbq	%rax, %rbx
	movl	%edx, %eax
	imulq	%rcx, %rax
	addq	%rax, %rbx
	leaq	(%rbx,%rcx), %rax
	cmovbq	%rax, %rbx
	leaq	(%rbx,%rcx), %rax
	cmpq	%r15, %rbx
	cmovaq	%rax, %rbx
	movq	%r14, %rax
	mulq	%r8
	movq	%rdx, %r8
	shrq	$32, %r8
	subq	%r8, %rax
	leaq	1(%rax,%r15), %r8
	cmovaeq	%rax, %r8
	movl	%edx, %eax
	imulq	%rcx, %rax
	addq	%r8, %rax
	leaq	(%rax,%rcx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rcx), %r8
	cmpq	%r15, %rdx
	cmovbeq	%rdx, %r8
	movq	%r11, %rax
	mulq	%r12
	movq	%rdx, %r11
	shrq	$32, %r11
	subq	%r11, %rax
	leaq	1(%rax,%r15), %r11
	cmovaeq	%rax, %r11
	movl	%edx, %eax
	imulq	%rcx, %rax
	addq	%r11, %rax
	leaq	(%rax,%rcx), %rdx
	cmovaeq	%rax, %rdx
	leaq	(%rdx,%rcx), %r11
	cmpq	%r15, %rdx
	cmovbeq	%rdx, %r11
	movq	%rbx, %rax
	movl	$7, %edx
	mulq	%rdx
	imulq	%rcx, %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rcx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rcx), %rdx
	cmpq	%r15, %rax
	cmovbeq	%rax, %rdx
	addq	%rdi, %rdx
	leaq	(%rdx,%rcx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rcx), %rdx
	cmpq	%r15, %rax
	cmovbeq	%rax, %rdx
	addq	%r8, %r11
	leaq	(%r11,%rcx), %rax
	cmovaeq	%r11, %rax
	leaq	(%rax,%rcx), %rdi
	cmpq	%r15, %rax
	cmovbeq	%rax, %rdi
	addq	%r9, %rdx
	leaq	(%rdx,%rcx), %rax
	cmovaeq	%rdx, %rax
	leaq	(%rax,%rcx), %r9
	cmpq	%r15, %rax
	cmovbeq	%rax, %r9
	addq	%r10, %rdi
	leaq	(%rdi,%rcx), %rax
	cmovaeq	%rdi, %rax
	leaq	(%rax,%rcx), %r10
	cmpq	%r15, %rax
	cmovbeq	%rax, %r10
	addq	$24, %rbp
	cmpq	%r13, %rbp
	jne	.LBB25_10
	jmp	.LBB25_6
.LBB25_1:
	xorl	%r10d, %r10d
	xorl	%r11d, %r11d
.LBB25_7:
	movq	8(%rsp), %rdi
	movq	24(%rdi), %r8
	movq	%r8, %rax
	mulq	%r10
	movq	%rax, %rsi
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rsi
	leaq	1(%rsi,%r15), %rdx
	cmovbq	%rdx, %rsi
	imulq	%rcx, %rax
	addq	%rax, %rsi
	leaq	(%rsi,%rcx), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%rcx), %rax
	cmpq	%r15, %rsi
	cmovaq	%rax, %rsi
	movq	32(%rdi), %r9
	movq	%r9, %rax
	mulq	%r11
	movq	%rax, %rdi
	movl	%edx, %eax
	shrq	$32, %rdx
	subq	%rdx, %rdi
	leaq	1(%rdi,%r15), %rdx
	cmovbq	%rdx, %rdi
	imulq	%rcx, %rax
	addq	%rax, %rdi
	leaq	(%rdi,%rcx), %rax
	cmovbq	%rax, %rdi
	leaq	(%rdi,%rcx), %rax
	cmpq	%r15, %rdi
	cmovaq	%rax, %rdi
	movq	%r8, %rax
	mulq	%r11
	movl	%edx, %r8d
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r15), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rcx, %r8
	addq	%rdx, %r8
	leaq	(%r8,%rcx), %rax
	cmovaeq	%r8, %rax
	leaq	(%rax,%rcx), %r8
	cmpq	%r15, %rax
	cmovbeq	%rax, %r8
	movq	%r9, %rax
	mulq	%r10
	movl	%edx, %r9d
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%r15), %rdx
	cmovaeq	%rax, %rdx
	imulq	%rcx, %r9
	addq	%rdx, %r9
	leaq	(%r9,%rcx), %rax
	cmovaeq	%r9, %rax
	leaq	(%rax,%rcx), %r9
	cmpq	%r15, %rax
	cmovbeq	%rax, %r9
	movl	$7, %edx
	movq	%rdi, %rax
	mulq	%rdx
	imulq	%rcx, %rdx
	addq	%rdx, %rax
	leaq	(%rax,%rcx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rcx), %rdx
	cmpq	%r15, %rax
	cmovaq	%rdx, %rax
	addq	%rsi, %rax
	leaq	(%rax,%rcx), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%rcx), %rdx
	cmpq	%r15, %rax
	cmovaq	%rdx, %rax
	addq	%r8, %r9
	leaq	(%r9,%rcx), %rdx
	cmovaeq	%r9, %rdx
	addq	%rdx, %rcx
	cmpq	%r15, %rdx
	cmovbeq	%rdx, %rcx
	movq	%rcx, %rdx
	addq	$72, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%r12
	.cfi_def_cfa_offset 40
	popq	%r13
	.cfi_def_cfa_offset 32
	popq	%r14
	.cfi_def_cfa_offset 24
	popq	%r15
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	retq
.LBB25_12:
	.cfi_def_cfa_offset 128
	leaq	.Lalloc_953b7a28a8a2723f809dd5bd246c70bc(%rip), %rdx
	movq	%rbx, %rdi
	movq	(%rsp), %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.LBB25_8:
	leaq	.Lalloc_3819371618053aaf30fd9948083359db(%rip), %rdx
	movq	%rax, %rdi
	movq	(%rsp), %rsi
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check@GOTPCREL(%rip)
.Lfunc_end25:
	.size	_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm4eval, .Lfunc_end25-_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm4eval
	.cfi_endproc

	.section	.text.unlikely._RNvMs3_NtCs40k4W9msRzi_5alloc7raw_vecINtB5_6RawVecTjINtNtB7_3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEE8grow_oneB1a_,"ax",@progbits
	.p2align	4
	.type	_RNvMs3_NtCs40k4W9msRzi_5alloc7raw_vecINtB5_6RawVecTjINtNtB7_3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEE8grow_oneB1a_,@function
_RNvMs3_NtCs40k4W9msRzi_5alloc7raw_vecINtB5_6RawVecTjINtNtB7_3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEE8grow_oneB1a_:
	.cfi_startproc
	pushq	%r14
	.cfi_def_cfa_offset 16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	subq	$24, %rsp
	.cfi_def_cfa_offset 48
	.cfi_offset %rbx, -24
	.cfi_offset %r14, -16
	movq	%rdi, %rbx
	movq	(%rdi), %rsi
	leaq	(%rsi,%rsi), %rax
	cmpq	$5, %rax
	movl	$4, %r14d
	cmovaeq	%rax, %r14
	movq	8(%rdi), %rdx
	movq	%rsp, %rdi
	movl	$32, %r8d
	movq	%r14, %rcx
	callq	_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner11finish_growCsl0YfJI2rrfI_8isolated
	cmpl	$1, (%rsp)
	je	.LBB26_2
	movq	8(%rsp), %rax
	movq	%rax, 8(%rbx)
	movq	%r14, (%rbx)
	addq	$24, %rsp
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%r14
	.cfi_def_cfa_offset 8
	retq
.LBB26_2:
	.cfi_def_cfa_offset 48
	movq	8(%rsp), %rdi
	movq	16(%rsp), %rsi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Lfunc_end26:
	.size	_RNvMs3_NtCs40k4W9msRzi_5alloc7raw_vecINtB5_6RawVecTjINtNtB7_3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEE8grow_oneB1a_, .Lfunc_end26-_RNvMs3_NtCs40k4W9msRzi_5alloc7raw_vecINtB5_6RawVecTjINtNtB7_3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEE8grow_oneB1a_
	.cfi_endproc

	.section	.text.unlikely._RNvMs3_NtCs40k4W9msRzi_5alloc7raw_vecINtB5_6RawVecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE8grow_oneBS_,"ax",@progbits
	.p2align	4
	.type	_RNvMs3_NtCs40k4W9msRzi_5alloc7raw_vecINtB5_6RawVecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE8grow_oneBS_,@function
_RNvMs3_NtCs40k4W9msRzi_5alloc7raw_vecINtB5_6RawVecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE8grow_oneBS_:
	.cfi_startproc
	pushq	%r14
	.cfi_def_cfa_offset 16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	subq	$24, %rsp
	.cfi_def_cfa_offset 48
	.cfi_offset %rbx, -24
	.cfi_offset %r14, -16
	movq	%rdi, %rbx
	movq	(%rdi), %rsi
	leaq	(%rsi,%rsi), %rax
	cmpq	$5, %rax
	movl	$4, %r14d
	cmovaeq	%rax, %r14
	movq	8(%rdi), %rdx
	movq	%rsp, %rdi
	movl	$24, %r8d
	movq	%r14, %rcx
	callq	_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner11finish_growCsl0YfJI2rrfI_8isolated
	cmpl	$1, (%rsp)
	je	.LBB27_2
	movq	8(%rsp), %rax
	movq	%rax, 8(%rbx)
	movq	%r14, (%rbx)
	addq	$24, %rsp
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%r14
	.cfi_def_cfa_offset 8
	retq
.LBB27_2:
	.cfi_def_cfa_offset 48
	movq	8(%rsp), %rdi
	movq	16(%rsp), %rsi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Lfunc_end27:
	.size	_RNvMs3_NtCs40k4W9msRzi_5alloc7raw_vecINtB5_6RawVecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE8grow_oneBS_, .Lfunc_end27-_RNvMs3_NtCs40k4W9msRzi_5alloc7raw_vecINtB5_6RawVecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE8grow_oneBS_
	.cfi_endproc

	.section	.text.unlikely._RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner11finish_growCsl0YfJI2rrfI_8isolated,"ax",@progbits
	.p2align	4
	.type	_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner11finish_growCsl0YfJI2rrfI_8isolated,@function
_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner11finish_growCsl0YfJI2rrfI_8isolated:
	.cfi_startproc
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset %rbx, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rdx, %r9
	movq	%rdi, %rbx
	movq	%r8, %rax
	mulq	%rcx
	movq	%rax, %r14
	seto	%al
	movabsq	$9223372036854775800, %rcx
	cmpq	%rcx, %r14
	seta	%cl
	orb	%al, %cl
	movl	$1, %r15d
	je	.LBB28_2
	movl	$8, %eax
	xorl	%r14d, %r14d
	jmp	.LBB28_10
.LBB28_2:
	testq	%rsi, %rsi
	je	.LBB28_4
	imulq	%rsi, %r8
	movl	$8, %edx
	movq	%r9, %rdi
	movq	%r8, %rsi
	movq	%r14, %rcx
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_realloc@GOTPCREL(%rip)
	testq	%rax, %rax
	jne	.LBB28_6
	jmp	.LBB28_9
.LBB28_4:
	testq	%r14, %r14
	je	.LBB28_5
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$8, %esi
	movq	%r14, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	jne	.LBB28_6
.LBB28_9:
	movq	$8, 8(%rbx)
	movl	$16, %eax
	jmp	.LBB28_10
.LBB28_5:
	movl	$8, %eax
.LBB28_6:
	movq	%rax, 8(%rbx)
	movl	$16, %eax
	xorl	%r15d, %r15d
.LBB28_10:
	movq	%r14, (%rbx,%rax)
	movq	%r15, (%rbx)
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end28:
	.size	_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner11finish_growCsl0YfJI2rrfI_8isolated, .Lfunc_end28-_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner11finish_growCsl0YfJI2rrfI_8isolated
	.cfi_endproc

	.section	.text.fzc,"ax",@progbits
	.globl	fzc
	.p2align	4
	.type	fzc,@function
fzc:
.Lfunc_begin10:
	.cfi_startproc
	.cfi_personality 155, DW.ref.rust_eh_personality
	.cfi_lsda 27, .Lexception10
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	subq	$24, %rsp
	.cfi_def_cfa_offset 80
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%r9, 16(%rsp)
	movl	%r8d, %r13d
	movl	%ecx, 12(%rsp)
	movl	%edx, %r12d
	movq	%rsi, %r15
	movq	%rdi, %r14
	movl	80(%rsp), %ebp
	callq	*_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2@GOTPCREL(%rip)
	movl	$608, %edi
	movl	$8, %esi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc@GOTPCREL(%rip)
	testq	%rax, %rax
	je	.LBB29_1
	movq	%rax, %rbx
	movups	(%r15), %xmm0
	movups	%xmm0, (%rax)
	movups	16(%r15), %xmm0
	movups	%xmm0, 16(%rax)
	movups	32(%r15), %xmm0
	movups	%xmm0, 32(%rax)
	movups	48(%r15), %xmm0
	movups	%xmm0, 48(%rax)
	movups	64(%r15), %xmm0
	movups	%xmm0, 64(%rax)
	movups	80(%r15), %xmm0
	movups	%xmm0, 80(%rax)
	movups	96(%r15), %xmm0
	movups	%xmm0, 96(%rax)
	movups	112(%r15), %xmm0
	movups	%xmm0, 112(%rax)
	movups	128(%r15), %xmm0
	movups	%xmm0, 128(%rax)
	movups	144(%r15), %xmm0
	movups	%xmm0, 144(%rax)
	movups	160(%r15), %xmm0
	movups	%xmm0, 160(%rax)
	movups	176(%r15), %xmm0
	movups	%xmm0, 176(%rax)
	movups	192(%r15), %xmm0
	movups	%xmm0, 192(%rax)
	movups	208(%r15), %xmm0
	movups	%xmm0, 208(%rax)
	movups	224(%r15), %xmm0
	movups	%xmm0, 224(%rax)
	movups	240(%r15), %xmm0
	movups	%xmm0, 240(%rax)
	movups	256(%r15), %xmm0
	movups	%xmm0, 256(%rax)
	movups	272(%r15), %xmm0
	movups	%xmm0, 272(%rax)
	movups	288(%r15), %xmm0
	movups	%xmm0, 288(%rax)
	movups	304(%r15), %xmm0
	movups	%xmm0, 304(%rax)
	movups	320(%r15), %xmm0
	movups	%xmm0, 320(%rax)
	movups	336(%r15), %xmm0
	movups	%xmm0, 336(%rax)
	movups	352(%r15), %xmm0
	movups	%xmm0, 352(%rax)
	movups	368(%r15), %xmm0
	movups	%xmm0, 368(%rax)
	movups	384(%r15), %xmm0
	movups	%xmm0, 384(%rax)
	movups	400(%r15), %xmm0
	movups	%xmm0, 400(%rax)
	movups	416(%r15), %xmm0
	movups	%xmm0, 416(%rax)
	movups	432(%r15), %xmm0
	movups	%xmm0, 432(%rax)
	movups	448(%r15), %xmm0
	movups	%xmm0, 448(%rax)
	movups	464(%r15), %xmm0
	movups	%xmm0, 464(%rax)
	movups	480(%r15), %xmm0
	movups	%xmm0, 480(%rax)
	movups	496(%r15), %xmm0
	movups	%xmm0, 496(%rax)
	movups	512(%r15), %xmm0
	movups	%xmm0, 512(%rax)
	movups	528(%r15), %xmm0
	movups	%xmm0, 528(%rax)
	movups	544(%r15), %xmm0
	movups	%xmm0, 544(%rax)
	movups	560(%r15), %xmm0
	movups	%xmm0, 560(%rax)
	movups	576(%r15), %xmm0
	movups	%xmm0, 576(%rax)
	movups	592(%r15), %xmm0
	movups	%xmm0, 592(%rax)
	xorl	%r8d, %r8d
	testl	%ebp, %ebp
	je	.LBB29_14
	cmpl	$1, %ebp
	je	.LBB29_16
	cmpl	$2, %ebp
	jne	.LBB29_6
	testl	%r13d, %r13d
	setne	%r8b
.Ltmp157:
	movl	$38, %esi
	movq	%rbx, %rdi
	movl	%r12d, %edx
	movl	12(%rsp), %ecx
	movq	16(%rsp), %r9
	callq	_RNvCsl0YfJI2rrfI_8isolated9factory_2
.Ltmp158:
	movq	%rax, %r15
	leaq	.Lvtable.2(%rip), %r12
	jmp	.LBB29_8
.LBB29_16:
	testl	%r13d, %r13d
	setne	%r8b
.Ltmp159:
	movl	$38, %esi
	movq	%rbx, %rdi
	movl	%r12d, %edx
	movl	12(%rsp), %ecx
	movq	16(%rsp), %r9
	callq	_RNvCsl0YfJI2rrfI_8isolated9factory_1
.Ltmp160:
	movq	%rax, %r15
	leaq	.Lvtable.1(%rip), %r12
	jmp	.LBB29_8
.LBB29_14:
	testl	%r13d, %r13d
	setne	%r8b
.Ltmp161:
	movl	$38, %esi
	movq	%rbx, %rdi
	movl	%r12d, %edx
	movl	12(%rsp), %ecx
	movq	16(%rsp), %r9
	callq	_RNvCsl0YfJI2rrfI_8isolated9factory_0
.Ltmp162:
	movq	%rax, %r15
	leaq	.Lvtable.0(%rip), %r12
	jmp	.LBB29_8
.LBB29_6:
	testl	%r13d, %r13d
	setne	%r8b
.Ltmp163:
	movl	$38, %esi
	movq	%rbx, %rdi
	movl	%r12d, %edx
	movl	12(%rsp), %ecx
	movq	16(%rsp), %r9
	callq	_RNvCsl0YfJI2rrfI_8isolated9factory_3
.Ltmp164:
	movq	%rax, %r15
	leaq	.Lvtable.3(%rip), %r12
.LBB29_8:
.Ltmp166:
	movl	$21, %edx
	movq	%r15, %rdi
	movq	%rbx, %rsi
	callq	*40(%r12)
.Ltmp167:
	movq	%rax, (%r14)
	movq	%rdx, 8(%r14)
	movq	(%r12), %rax
	testq	%rax, %rax
	je	.LBB29_11
.Ltmp172:
	movq	%r15, %rdi
	callq	*%rax
.Ltmp173:
.LBB29_11:
	movq	8(%r12), %rsi
	testq	%rsi, %rsi
	je	.LBB29_13
	movq	16(%r12), %rdx
	movq	%r15, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB29_13:
	movl	$608, %esi
	movl	$8, %edx
	movq	%rbx, %rdi
	addq	$24, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%r12
	.cfi_def_cfa_offset 40
	popq	%r13
	.cfi_def_cfa_offset 32
	popq	%r14
	.cfi_def_cfa_offset 24
	popq	%r15
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	jmpq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
.LBB29_1:
	.cfi_def_cfa_offset 80
.Ltmp175:
	movl	$8, %edi
	movl	$608, %esi
	callq	*_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error@GOTPCREL(%rip)
.Ltmp176:
	ud2
.LBB29_23:
.Ltmp174:
	movq	8(%r12), %rsi
	testq	%rsi, %rsi
	je	.LBB29_21
	movq	16(%r12), %rdx
	movq	%r15, %rdi
	callq	*_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc@GOTPCREL(%rip)
	movl	$38, %edi
	movq	%rbx, %rsi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking19panic_cannot_unwind@GOTPCREL(%rip)
.LBB29_22:
.Ltmp168:
.Ltmp169:
	movq	%r15, %rdi
	movq	%r12, %rsi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc5boxed3BoxDG_INtNtNtB4_3ops8function2FnTRL0_SNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEp6OutputB1J_EL_EEB1N_
.Ltmp170:
	jmp	.LBB29_21
.LBB29_25:
.Ltmp171:
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking16panic_in_cleanup@GOTPCREL(%rip)
.LBB29_20:
.Ltmp165:
.LBB29_21:
	movl	$38, %edi
	movq	%rbx, %rsi
	callq	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking19panic_cannot_unwind@GOTPCREL(%rip)
.LBB29_26:
.Ltmp177:
	callq	*_RNvNtCscI6d9CVNmLh_4core9panicking19panic_cannot_unwind@GOTPCREL(%rip)
.Lfunc_end29:
	.size	fzc, .Lfunc_end29-fzc
	.cfi_endproc
	.section	.gcc_except_table.fzc,"a",@progbits
	.p2align	2, 0x0
GCC_except_table29:
.Lexception10:
	.byte	255
	.byte	155
	.uleb128 .Lttbase0-.Lttbaseref0
.Lttbaseref0:
	.byte	1
	.uleb128 .Lcst_end10-.Lcst_begin10
.Lcst_begin10:
	.uleb128 .Ltmp157-.Lfunc_begin10
	.uleb128 .Ltmp164-.Ltmp157
	.uleb128 .Ltmp165-.Lfunc_begin10
	.byte	0
	.uleb128 .Ltmp166-.Lfunc_begin10
	.uleb128 .Ltmp167-.Ltmp166
	.uleb128 .Ltmp168-.Lfunc_begin10
	.byte	0
	.uleb128 .Ltmp172-.Lfunc_begin10
	.uleb128 .Ltmp173-.Ltmp172
	.uleb128 .Ltmp174-.Lfunc_begin10
	.byte	0
	.uleb128 .Ltmp175-.Lfunc_begin10
	.uleb128 .Ltmp176-.Ltmp175
	.uleb128 .Ltmp177-.Lfunc_begin10
	.byte	1
	.uleb128 .Ltmp169-.Lfunc_begin10
	.uleb128 .Ltmp170-.Ltmp169
	.uleb128 .Ltmp171-.Lfunc_begin10
	.byte	1
.Lcst_end10:
	.byte	127
	.byte	0
	.p2align	2, 0x0
.Lttbase0:
	.byte	0
	.p2align	2, 0x0

	.type	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93,@object
	.section	.rodata.str1.1,"aMS",@progbits,1
.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93:
	.asciz	"isolated.rs"
	.size	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93, 12

	.type	.Lalloc_239c1709703ec0aea80b5578885ba055,@object
	.section	.data.rel.ro..Lalloc_239c1709703ec0aea80b5578885ba055,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_239c1709703ec0aea80b5578885ba055:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000`\001\000\000P\000\000"
	.size	.Lalloc_239c1709703ec0aea80b5578885ba055, 24

	.type	.Lalloc_14e9b0f3c1e82842e326b949d03d992d,@object
	.section	.data.rel.ro..Lalloc_14e9b0f3c1e82842e326b949d03d992d,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_14e9b0f3c1e82842e326b949d03d992d:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\257\001\000\000*\000\000"
	.size	.Lalloc_14e9b0f3c1e82842e326b949d03d992d, 24

	.type	.Lalloc_eca36810f664faabadbd931684be3603,@object
	.section	.data.rel.ro..Lalloc_eca36810f664faabadbd931684be3603,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_eca36810f664faabadbd931684be3603:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\257\001\000\000%\000\000"
	.size	.Lalloc_eca36810f664faabadbd931684be3603, 24

	.type	.Lalloc_826b68913cf630c35a865efbea8045e3,@object
	.section	.data.rel.ro..Lalloc_826b68913cf630c35a865efbea8045e3,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_826b68913cf630c35a865efbea8045e3:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\316\001\000\000*\000\000"
	.size	.Lalloc_826b68913cf630c35a865efbea8045e3, 24

	.type	.Lalloc_11ff538006900e8109ee309b459a2f83,@object
	.section	.data.rel.ro..Lalloc_11ff538006900e8109ee309b459a2f83,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_11ff538006900e8109ee309b459a2f83:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\316\001\000\000%\000\000"
	.size	.Lalloc_11ff538006900e8109ee309b459a2f83, 24

	.type	.Lalloc_623270749f7c2c7eb7abf12a5ce81bec,@object
	.section	.data.rel.ro..Lalloc_623270749f7c2c7eb7abf12a5ce81bec,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_623270749f7c2c7eb7abf12a5ce81bec:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\355\001\000\000*\000\000"
	.size	.Lalloc_623270749f7c2c7eb7abf12a5ce81bec, 24

	.type	.Lalloc_23cbb2e7863b02fb8b64518d13a27720,@object
	.section	.data.rel.ro..Lalloc_23cbb2e7863b02fb8b64518d13a27720,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_23cbb2e7863b02fb8b64518d13a27720:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\355\001\000\000%\000\000"
	.size	.Lalloc_23cbb2e7863b02fb8b64518d13a27720, 24

	.type	.Lalloc_3473ff63602946e5bae196369fb1e157,@object
	.section	.data.rel.ro..Lalloc_3473ff63602946e5bae196369fb1e157,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_3473ff63602946e5bae196369fb1e157:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\016\002\000\000*\000\000"
	.size	.Lalloc_3473ff63602946e5bae196369fb1e157, 24

	.type	.Lalloc_8bedb038257b840dda514362a0f0e6d8,@object
	.section	.data.rel.ro..Lalloc_8bedb038257b840dda514362a0f0e6d8,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_8bedb038257b840dda514362a0f0e6d8:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\016\002\000\000%\000\000"
	.size	.Lalloc_8bedb038257b840dda514362a0f0e6d8, 24

	.type	.Lalloc_8a0667c067a77bb698bb88e8b54ac9d2,@object
	.section	.data.rel.ro..Lalloc_8a0667c067a77bb698bb88e8b54ac9d2,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_8a0667c067a77bb698bb88e8b54ac9d2:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\253\001\000\000E\000\000"
	.size	.Lalloc_8a0667c067a77bb698bb88e8b54ac9d2, 24

	.type	.Lalloc_251b78bda4aeb9a619eb192d691b2e6c,@object
	.section	.data.rel.ro..Lalloc_251b78bda4aeb9a619eb192d691b2e6c,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_251b78bda4aeb9a619eb192d691b2e6c:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\265\001\000\000\035\000\000"
	.size	.Lalloc_251b78bda4aeb9a619eb192d691b2e6c, 24

	.type	.Lalloc_03bbe1d0fcdbd86f2216092eb0f02e36,@object
	.section	.data.rel.ro..Lalloc_03bbe1d0fcdbd86f2216092eb0f02e36,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_03bbe1d0fcdbd86f2216092eb0f02e36:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\234\001\000\000\030\000\000"
	.size	.Lalloc_03bbe1d0fcdbd86f2216092eb0f02e36, 24

	.type	.Lalloc_60764c2be1deec61362b17f60211fd40,@object
	.section	.data.rel.ro..Lalloc_60764c2be1deec61362b17f60211fd40,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_60764c2be1deec61362b17f60211fd40:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\276\001\000\000$\000\000"
	.size	.Lalloc_60764c2be1deec61362b17f60211fd40, 24

	.type	.Lalloc_0115ca0cf6aba2d7c2ca2e69392e3726,@object
	.section	.data.rel.ro..Lalloc_0115ca0cf6aba2d7c2ca2e69392e3726,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_0115ca0cf6aba2d7c2ca2e69392e3726:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\276\001\000\000,\000\000"
	.size	.Lalloc_0115ca0cf6aba2d7c2ca2e69392e3726, 24

	.type	.Lalloc_7672b3fd58eaeff1a7f945549344b36b,@object
	.section	.data.rel.ro..Lalloc_7672b3fd58eaeff1a7f945549344b36b,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_7672b3fd58eaeff1a7f945549344b36b:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\276\001\000\000L\000\000"
	.size	.Lalloc_7672b3fd58eaeff1a7f945549344b36b, 24

	.type	.Lalloc_0d7c3282f4d1b6d0ea38e377caef0ba7,@object
	.section	.data.rel.ro..Lalloc_0d7c3282f4d1b6d0ea38e377caef0ba7,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_0d7c3282f4d1b6d0ea38e377caef0ba7:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\276\001\000\000T\000\000"
	.size	.Lalloc_0d7c3282f4d1b6d0ea38e377caef0ba7, 24

	.type	.Lalloc_85ee655d0ee76a931ab97ae7956c61fa,@object
	.section	.data.rel.ro..Lalloc_85ee655d0ee76a931ab97ae7956c61fa,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_85ee655d0ee76a931ab97ae7956c61fa:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\267\001\000\000@\000\000"
	.size	.Lalloc_85ee655d0ee76a931ab97ae7956c61fa, 24

	.type	.Lalloc_28926e658ad846032cbbfac196c44ac3,@object
	.section	.data.rel.ro..Lalloc_28926e658ad846032cbbfac196c44ac3,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_28926e658ad846032cbbfac196c44ac3:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\312\001\000\000E\000\000"
	.size	.Lalloc_28926e658ad846032cbbfac196c44ac3, 24

	.type	.Lalloc_8c5249903caae8a4f890768ea185f763,@object
	.section	.data.rel.ro..Lalloc_8c5249903caae8a4f890768ea185f763,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_8c5249903caae8a4f890768ea185f763:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\324\001\000\000\035\000\000"
	.size	.Lalloc_8c5249903caae8a4f890768ea185f763, 24

	.type	.Lalloc_0f40a973e4ef77172839bcec3485a3cf,@object
	.section	.data.rel.ro..Lalloc_0f40a973e4ef77172839bcec3485a3cf,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_0f40a973e4ef77172839bcec3485a3cf:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\335\001\000\000$\000\000"
	.size	.Lalloc_0f40a973e4ef77172839bcec3485a3cf, 24

	.type	.Lalloc_7893f8279e457884a76b55b3c0e38bce,@object
	.section	.data.rel.ro..Lalloc_7893f8279e457884a76b55b3c0e38bce,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_7893f8279e457884a76b55b3c0e38bce:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\335\001\000\000,\000\000"
	.size	.Lalloc_7893f8279e457884a76b55b3c0e38bce, 24

	.type	.Lalloc_01d88d31381230f5daa9de4874523a4f,@object
	.section	.data.rel.ro..Lalloc_01d88d31381230f5daa9de4874523a4f,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_01d88d31381230f5daa9de4874523a4f:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\335\001\000\000L\000\000"
	.size	.Lalloc_01d88d31381230f5daa9de4874523a4f, 24

	.type	.Lalloc_89fc8f3b37234d0552cb47d22f5f3be5,@object
	.section	.data.rel.ro..Lalloc_89fc8f3b37234d0552cb47d22f5f3be5,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_89fc8f3b37234d0552cb47d22f5f3be5:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\335\001\000\000T\000\000"
	.size	.Lalloc_89fc8f3b37234d0552cb47d22f5f3be5, 24

	.type	.Lalloc_dd86d8d2da9777486edeb4de51cc3012,@object
	.section	.data.rel.ro..Lalloc_dd86d8d2da9777486edeb4de51cc3012,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_dd86d8d2da9777486edeb4de51cc3012:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\326\001\000\000@\000\000"
	.size	.Lalloc_dd86d8d2da9777486edeb4de51cc3012, 24

	.type	.Lalloc_9ff3b8d94994bf8c3f90654c665568fa,@object
	.section	.data.rel.ro..Lalloc_9ff3b8d94994bf8c3f90654c665568fa,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_9ff3b8d94994bf8c3f90654c665568fa:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\351\001\000\000E\000\000"
	.size	.Lalloc_9ff3b8d94994bf8c3f90654c665568fa, 24

	.type	.Lalloc_33f4d218739df51bc601f47114eed12f,@object
	.section	.data.rel.ro..Lalloc_33f4d218739df51bc601f47114eed12f,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_33f4d218739df51bc601f47114eed12f:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\363\001\000\000\035\000\000"
	.size	.Lalloc_33f4d218739df51bc601f47114eed12f, 24

	.type	.Lalloc_80ab1297b78c18879967432c54c1e54e,@object
	.section	.data.rel.ro..Lalloc_80ab1297b78c18879967432c54c1e54e,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_80ab1297b78c18879967432c54c1e54e:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\376\001\000\000$\000\000"
	.size	.Lalloc_80ab1297b78c18879967432c54c1e54e, 24

	.type	.Lalloc_f604f896c68dd8f0a4007dacc23397d5,@object
	.section	.data.rel.ro..Lalloc_f604f896c68dd8f0a4007dacc23397d5,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_f604f896c68dd8f0a4007dacc23397d5:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\376\001\000\000,\000\000"
	.size	.Lalloc_f604f896c68dd8f0a4007dacc23397d5, 24

	.type	.Lalloc_18a70e0bda0ee5b1c3fd14bc973a5c99,@object
	.section	.data.rel.ro..Lalloc_18a70e0bda0ee5b1c3fd14bc973a5c99,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_18a70e0bda0ee5b1c3fd14bc973a5c99:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\376\001\000\000L\000\000"
	.size	.Lalloc_18a70e0bda0ee5b1c3fd14bc973a5c99, 24

	.type	.Lalloc_f3da9c566178cc480d49fd92cad34aad,@object
	.section	.data.rel.ro..Lalloc_f3da9c566178cc480d49fd92cad34aad,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_f3da9c566178cc480d49fd92cad34aad:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\376\001\000\000T\000\000"
	.size	.Lalloc_f3da9c566178cc480d49fd92cad34aad, 24

	.type	.Lalloc_783adf84c4437dc3f5e730641bb4655a,@object
	.section	.data.rel.ro..Lalloc_783adf84c4437dc3f5e730641bb4655a,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_783adf84c4437dc3f5e730641bb4655a:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\365\001\000\000@\000\000"
	.size	.Lalloc_783adf84c4437dc3f5e730641bb4655a, 24

	.type	.Lalloc_413c07112253bea69b9c0ea7f62d2d3b,@object
	.section	.data.rel.ro..Lalloc_413c07112253bea69b9c0ea7f62d2d3b,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_413c07112253bea69b9c0ea7f62d2d3b:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\n\002\000\000E\000\000"
	.size	.Lalloc_413c07112253bea69b9c0ea7f62d2d3b, 24

	.type	.Lalloc_d0a18ec8c4590cc3d9111a1a11b11099,@object
	.section	.data.rel.ro..Lalloc_d0a18ec8c4590cc3d9111a1a11b11099,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_d0a18ec8c4590cc3d9111a1a11b11099:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\024\002\000\000\035\000\000"
	.size	.Lalloc_d0a18ec8c4590cc3d9111a1a11b11099, 24

	.type	.Lalloc_38b3a9f276003767a8ae4525b00c9940,@object
	.section	.data.rel.ro..Lalloc_38b3a9f276003767a8ae4525b00c9940,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_38b3a9f276003767a8ae4525b00c9940:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\037\002\000\000$\000\000"
	.size	.Lalloc_38b3a9f276003767a8ae4525b00c9940, 24

	.type	.Lalloc_95c9a529b9c6675768dc03a5e4eb87b8,@object
	.section	.data.rel.ro..Lalloc_95c9a529b9c6675768dc03a5e4eb87b8,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_95c9a529b9c6675768dc03a5e4eb87b8:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\037\002\000\000,\000\000"
	.size	.Lalloc_95c9a529b9c6675768dc03a5e4eb87b8, 24

	.type	.Lalloc_f1afeffee25b8cbad41bb5872529e5be,@object
	.section	.data.rel.ro..Lalloc_f1afeffee25b8cbad41bb5872529e5be,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_f1afeffee25b8cbad41bb5872529e5be:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\037\002\000\000L\000\000"
	.size	.Lalloc_f1afeffee25b8cbad41bb5872529e5be, 24

	.type	.Lalloc_e7192de98d175da682c169f6595d4522,@object
	.section	.data.rel.ro..Lalloc_e7192de98d175da682c169f6595d4522,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_e7192de98d175da682c169f6595d4522:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\037\002\000\000T\000\000"
	.size	.Lalloc_e7192de98d175da682c169f6595d4522, 24

	.type	.Lalloc_354dc1959db4c84bf13af6f86d635aee,@object
	.section	.data.rel.ro..Lalloc_354dc1959db4c84bf13af6f86d635aee,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_354dc1959db4c84bf13af6f86d635aee:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\026\002\000\000@\000\000"
	.size	.Lalloc_354dc1959db4c84bf13af6f86d635aee, 24

	.type	.Lalloc_10b6528b98bd905c6309b430b77c3a07,@object
	.section	.data.rel.ro..Lalloc_10b6528b98bd905c6309b430b77c3a07,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_10b6528b98bd905c6309b430b77c3a07:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000c\001\000\000\021\000\000"
	.size	.Lalloc_10b6528b98bd905c6309b430b77c3a07, 24

	.type	.Lalloc_976e0beddddec32ff42087070bcd77a5,@object
	.section	.data.rel.ro..Lalloc_976e0beddddec32ff42087070bcd77a5,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_976e0beddddec32ff42087070bcd77a5:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000d\001\000\000\027\000\000"
	.size	.Lalloc_976e0beddddec32ff42087070bcd77a5, 24

	.type	.Lalloc_96d987a87d97c3b145ef68c6e71dd047,@object
	.section	.data.rel.ro..Lalloc_96d987a87d97c3b145ef68c6e71dd047,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_96d987a87d97c3b145ef68c6e71dd047:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000l\001\000\000\027\000\000"
	.size	.Lalloc_96d987a87d97c3b145ef68c6e71dd047, 24

	.type	.Lalloc_d29c77d346acbe694cb7ba8ee7faff56,@object
	.section	.data.rel.ro..Lalloc_d29c77d346acbe694cb7ba8ee7faff56,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_d29c77d346acbe694cb7ba8ee7faff56:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\245\001\000\000#\000\000"
	.size	.Lalloc_d29c77d346acbe694cb7ba8ee7faff56, 24

	.type	.Lalloc_a51995a9f594fb331ed053838b7be924,@object
	.section	.data.rel.ro..Lalloc_a51995a9f594fb331ed053838b7be924,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_a51995a9f594fb331ed053838b7be924:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\245\001\000\000>\000\000"
	.size	.Lalloc_a51995a9f594fb331ed053838b7be924, 24

	.type	.Lalloc_23b5d640586d465cb57fc69fc0fb3828,@object
	.section	.data.rel.ro..Lalloc_23b5d640586d465cb57fc69fc0fb3828,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_23b5d640586d465cb57fc69fc0fb3828:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\255\001\000\000\023\000\000"
	.size	.Lalloc_23b5d640586d465cb57fc69fc0fb3828, 24

	.type	.Lalloc_0e8d56a95944120dff42b51dc5d24e92,@object
	.section	.data.rel.ro..Lalloc_0e8d56a95944120dff42b51dc5d24e92,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_0e8d56a95944120dff42b51dc5d24e92:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\255\001\000\000U\000\000"
	.size	.Lalloc_0e8d56a95944120dff42b51dc5d24e92, 24

	.type	.Lvtable.0,@object
	.section	.data.rel.ro..Lvtable.0,"aw",@progbits
	.p2align	3, 0x0
.Lvtable.0:
	.quad	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_
	.asciz	"(\001\000\000\000\000\000\000\b\000\000\000\000\000\000"
	.quad	_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_
	.quad	_RNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0B3_
	.quad	_RNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0B3_
	.size	.Lvtable.0, 48

	.type	.Lalloc_1343241238dcbe085445d5b11ba0a378,@object
	.section	.data.rel.ro..Lalloc_1343241238dcbe085445d5b11ba0a378,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_1343241238dcbe085445d5b11ba0a378:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\253\001\000\000\027\000\000"
	.size	.Lalloc_1343241238dcbe085445d5b11ba0a378, 24

	.type	.Lalloc_f0438cd97fee7f47e6788e32f762b012,@object
	.section	.data.rel.ro..Lalloc_f0438cd97fee7f47e6788e32f762b012,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_f0438cd97fee7f47e6788e32f762b012:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\304\001\000\000#\000\000"
	.size	.Lalloc_f0438cd97fee7f47e6788e32f762b012, 24

	.type	.Lalloc_cedfa6dae4663ae34151168cdec22263,@object
	.section	.data.rel.ro..Lalloc_cedfa6dae4663ae34151168cdec22263,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_cedfa6dae4663ae34151168cdec22263:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\304\001\000\000>\000\000"
	.size	.Lalloc_cedfa6dae4663ae34151168cdec22263, 24

	.type	.Lalloc_058578575a98bb3429578f82748d5aad,@object
	.section	.data.rel.ro..Lalloc_058578575a98bb3429578f82748d5aad,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_058578575a98bb3429578f82748d5aad:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\314\001\000\000\023\000\000"
	.size	.Lalloc_058578575a98bb3429578f82748d5aad, 24

	.type	.Lalloc_7f7b0d1637cd18edc5b90423efa8f2ac,@object
	.section	.data.rel.ro..Lalloc_7f7b0d1637cd18edc5b90423efa8f2ac,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_7f7b0d1637cd18edc5b90423efa8f2ac:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\314\001\000\000U\000\000"
	.size	.Lalloc_7f7b0d1637cd18edc5b90423efa8f2ac, 24

	.type	.Lvtable.1,@object
	.section	.data.rel.ro..Lvtable.1,"aw",@progbits
	.p2align	3, 0x0
.Lvtable.1:
	.quad	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_
	.asciz	"\020\001\000\000\000\000\000\000\b\000\000\000\000\000\000"
	.quad	_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_
	.quad	_RNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0B3_
	.quad	_RNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0B3_
	.size	.Lvtable.1, 48

	.type	.Lalloc_9441bbbb1bffb9011b99cd574d638c7a,@object
	.section	.data.rel.ro..Lalloc_9441bbbb1bffb9011b99cd574d638c7a,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_9441bbbb1bffb9011b99cd574d638c7a:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\312\001\000\000\027\000\000"
	.size	.Lalloc_9441bbbb1bffb9011b99cd574d638c7a, 24

	.type	.Lalloc_4d6b7a825e6461216f128f0802dfe2ec,@object
	.section	.data.rel.ro..Lalloc_4d6b7a825e6461216f128f0802dfe2ec,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_4d6b7a825e6461216f128f0802dfe2ec:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\343\001\000\000#\000\000"
	.size	.Lalloc_4d6b7a825e6461216f128f0802dfe2ec, 24

	.type	.Lalloc_b8ba05bf1ee24e89bc9451481eb89547,@object
	.section	.data.rel.ro..Lalloc_b8ba05bf1ee24e89bc9451481eb89547,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_b8ba05bf1ee24e89bc9451481eb89547:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\343\001\000\000>\000\000"
	.size	.Lalloc_b8ba05bf1ee24e89bc9451481eb89547, 24

	.type	.Lalloc_0c9e7887a13d11b191a330181159523c,@object
	.section	.data.rel.ro..Lalloc_0c9e7887a13d11b191a330181159523c,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_0c9e7887a13d11b191a330181159523c:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\353\001\000\000\023\000\000"
	.size	.Lalloc_0c9e7887a13d11b191a330181159523c, 24

	.type	.Lalloc_5b806d1bdaa4e2f1b1b427dca973f7a4,@object
	.section	.data.rel.ro..Lalloc_5b806d1bdaa4e2f1b1b427dca973f7a4,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_5b806d1bdaa4e2f1b1b427dca973f7a4:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\353\001\000\000U\000\000"
	.size	.Lalloc_5b806d1bdaa4e2f1b1b427dca973f7a4, 24

	.type	.Lvtable.2,@object
	.section	.data.rel.ro..Lvtable.2,"aw",@progbits
	.p2align	3, 0x0
.Lvtable.2:
	.quad	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_
	.asciz	"(\001\000\000\000\000\000\000\b\000\000\000\000\000\000"
	.quad	_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_
	.quad	_RNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0B3_
	.quad	_RNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0B3_
	.size	.Lvtable.2, 48

	.type	.Lalloc_16fb6e1cf5412ccbca18445a9781d2ea,@object
	.section	.data.rel.ro..Lalloc_16fb6e1cf5412ccbca18445a9781d2ea,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_16fb6e1cf5412ccbca18445a9781d2ea:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\351\001\000\000\027\000\000"
	.size	.Lalloc_16fb6e1cf5412ccbca18445a9781d2ea, 24

	.type	.Lalloc_26fc8e81fc819c8a9f630ccd48e47036,@object
	.section	.data.rel.ro..Lalloc_26fc8e81fc819c8a9f630ccd48e47036,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_26fc8e81fc819c8a9f630ccd48e47036:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\004\002\000\000#\000\000"
	.size	.Lalloc_26fc8e81fc819c8a9f630ccd48e47036, 24

	.type	.Lalloc_529870ce56aabb58b099913f27113d23,@object
	.section	.data.rel.ro..Lalloc_529870ce56aabb58b099913f27113d23,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_529870ce56aabb58b099913f27113d23:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\004\002\000\000>\000\000"
	.size	.Lalloc_529870ce56aabb58b099913f27113d23, 24

	.type	.Lalloc_f861b8e02d0300dcb721b5d1c9a678c4,@object
	.section	.data.rel.ro..Lalloc_f861b8e02d0300dcb721b5d1c9a678c4,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_f861b8e02d0300dcb721b5d1c9a678c4:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\f\002\000\000\023\000\000"
	.size	.Lalloc_f861b8e02d0300dcb721b5d1c9a678c4, 24

	.type	.Lalloc_20064a57f7955b3dc6ee7ae10e9bd5ab,@object
	.section	.data.rel.ro..Lalloc_20064a57f7955b3dc6ee7ae10e9bd5ab,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_20064a57f7955b3dc6ee7ae10e9bd5ab:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\f\002\000\000U\000\000"
	.size	.Lalloc_20064a57f7955b3dc6ee7ae10e9bd5ab, 24

	.type	.Lvtable.3,@object
	.section	.data.rel.ro..Lvtable.3,"aw",@progbits
	.p2align	3, 0x0
.Lvtable.3:
	.quad	_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_
	.asciz	"\020\001\000\000\000\000\000\000\b\000\000\000\000\000\000"
	.quad	_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_
	.quad	_RNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0B3_
	.quad	_RNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0B3_
	.size	.Lvtable.3, 48

	.type	.Lalloc_36684b31319358aad4985691b5adb1d1,@object
	.section	.data.rel.ro..Lalloc_36684b31319358aad4985691b5adb1d1,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_36684b31319358aad4985691b5adb1d1:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\n\002\000\000\027\000\000"
	.size	.Lalloc_36684b31319358aad4985691b5adb1d1, 24

	.type	.Lalloc_3819371618053aaf30fd9948083359db,@object
	.section	.data.rel.ro..Lalloc_3819371618053aaf30fd9948083359db,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_3819371618053aaf30fd9948083359db:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\215\001\000\000%\000\000"
	.size	.Lalloc_3819371618053aaf30fd9948083359db, 24

	.type	.Lalloc_953b7a28a8a2723f809dd5bd246c70bc,@object
	.section	.data.rel.ro..Lalloc_953b7a28a8a2723f809dd5bd246c70bc,"aw",@progbits
	.p2align	3, 0x0
.Lalloc_953b7a28a8a2723f809dd5bd246c70bc:
	.quad	.Lalloc_0f470ba9a8dafd09cc9f4992af3b1f93
	.asciz	"\013\000\000\000\000\000\000\000\220\001\000\000)\000\000"
	.size	.Lalloc_953b7a28a8a2723f809dd5bd246c70bc, 24

	.hidden	DW.ref.rust_eh_personality
	.weak	DW.ref.rust_eh_personality
	.section	.data.DW.ref.rust_eh_personality,"awG",@progbits,DW.ref.rust_eh_personality,comdat
	.p2align	3, 0x0
	.type	DW.ref.rust_eh_personality,@object
	.size	DW.ref.rust_eh_personality, 8
DW.ref.rust_eh_personality:
	.quad	rust_eh_personality
	.ident	"rustc version 1.97.0 (2d8144b78 2026-07-07)"
	.section	".note.GNU-stack","",@progbits
