	.file	"kernels.10eb82e2b480652b-cgu.0"
	.section	.text._RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add,"ax",@progbits
	.p2align	4
	.type	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add,@function
_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add:
	.cfi_startproc
	addq	%rdx, %rdi
	movl	$4294967295, %edx
	leaq	(%rdi,%rdx), %r8
	cmovaeq	%rdi, %r8
	leaq	(%r8,%rdx), %rax
	movabsq	$-4294967296, %rdi
	cmpq	%rdi, %r8
	cmovbeq	%r8, %rax
	addq	%rcx, %rsi
	leaq	(%rsi,%rdx), %rcx
	cmovaeq	%rsi, %rcx
	addq	%rcx, %rdx
	cmpq	%rdi, %rcx
	cmovbeq	%rcx, %rdx
	retq
.Lfunc_end0:
	.size	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add, .Lfunc_end0-_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	.cfi_endproc

	.section	.text._RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul,"ax",@progbits
	.p2align	4
	.type	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul,@function
_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul:
	.cfi_startproc
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset %rbx, -16
	movq	%rcx, %r9
	movq	%rdx, %r8
	movq	%rdx, %rax
	mulq	%rdi
	movq	%rax, %rcx
	movq	%rdx, %rax
	shrq	$32, %rax
	movl	%edx, %r10d
	subq	%rax, %rcx
	movabsq	$-4294967296, %rbx
	leaq	1(%rcx,%rbx), %rax
	cmovbq	%rax, %rcx
	shlq	$32, %rdx
	subq	%r10, %rdx
	addq	%rdx, %rcx
	movl	$4294967295, %r10d
	leaq	(%rcx,%r10), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%r10), %rax
	cmpq	%rbx, %rcx
	cmovaq	%rax, %rcx
	movq	%r9, %rax
	mulq	%rsi
	movq	%rax, %r11
	movq	%rdx, %rax
	shrq	$32, %rax
	subq	%rax, %r11
	leaq	1(%r11,%rbx), %rax
	cmovbq	%rax, %r11
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rdx, %r11
	leaq	(%r11,%r10), %rax
	cmovbq	%rax, %r11
	leaq	(%r11,%r10), %rax
	cmpq	%rbx, %r11
	cmovaq	%rax, %r11
	movq	%r9, %rax
	mulq	%rdi
	movq	%rdx, %r9
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	movl	%r9d, %eax
	shlq	$32, %r9
	subq	%rax, %r9
	addq	%rdx, %r9
	leaq	(%r9,%r10), %rax
	cmovbq	%rax, %r9
	leaq	(%r9,%r10), %rax
	cmpq	%rbx, %r9
	cmovaq	%rax, %r9
	movq	%r8, %rax
	mulq	%rsi
	movq	%rdx, %rsi
	shrq	$32, %rdx
	subq	%rdx, %rax
	leaq	1(%rax,%rbx), %rdx
	cmovaeq	%rax, %rdx
	movl	%esi, %eax
	shlq	$32, %rsi
	subq	%rax, %rsi
	addq	%rdx, %rsi
	leaq	(%rsi,%r10), %rax
	cmovbq	%rax, %rsi
	leaq	(%rsi,%r10), %rax
	cmpq	%rbx, %rsi
	cmovaq	%rax, %rsi
	movl	$7, %edx
	movq	%r11, %rax
	mulq	%rdx
	movq	%rdx, %rdi
	shlq	$32, %rdi
	subq	%rdx, %rdi
	addq	%rdi, %rax
	leaq	(%rax,%r10), %rdx
	cmovbq	%rdx, %rax
	leaq	(%rax,%r10), %rdx
	cmpq	%rbx, %rax
	cmovaq	%rdx, %rax
	addq	%rcx, %rax
	leaq	(%rax,%r10), %rcx
	cmovbq	%rcx, %rax
	leaq	(%rax,%r10), %rcx
	cmpq	%rbx, %rax
	cmovaq	%rcx, %rax
	addq	%r9, %rsi
	leaq	(%rsi,%r10), %rcx
	cmovaeq	%rsi, %rcx
	addq	%rcx, %r10
	cmpq	%rbx, %rcx
	cmovbeq	%rcx, %r10
	movq	%r10, %rdx
	popq	%rbx
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end1:
	.size	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul, .Lfunc_end1-_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	.cfi_endproc

	.section	.text._RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub,"ax",@progbits
	.p2align	4
	.type	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub,@function
_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub:
	.cfi_startproc
	subq	%rdx, %rdi
	movabsq	$-4294967295, %rdx
	leaq	(%rdi,%rdx), %rax
	cmovaeq	%rdi, %rax
	subq	%rcx, %rsi
	leaq	(%rsi,%rdx), %rdx
	cmovaeq	%rsi, %rdx
	retq
.Lfunc_end2:
	.size	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub, .Lfunc_end2-_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	.cfi_endproc

	.section	.text._RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base,"ax",@progbits
	.p2align	4
	.type	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base,@function
_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base:
	.cfi_startproc
	movq	%rdx, %r8
	movq	%rdx, %rax
	mulq	%rdi
	movq	%rax, %rcx
	movq	%rdx, %rax
	shrq	$32, %rax
	movl	%edx, %r9d
	subq	%rax, %rcx
	movabsq	$-4294967296, %rdi
	leaq	1(%rcx,%rdi), %rax
	cmovbq	%rax, %rcx
	shlq	$32, %rdx
	subq	%r9, %rdx
	addq	%rdx, %rcx
	movl	$4294967295, %r9d
	leaq	(%rcx,%r9), %rax
	cmovbq	%rax, %rcx
	leaq	(%rcx,%r9), %rax
	cmpq	%rdi, %rcx
	cmovaq	%rax, %rcx
	movq	%r8, %rax
	mulq	%rsi
	movq	%rdx, %rsi
	shrq	$32, %rsi
	subq	%rsi, %rax
	leaq	1(%rax,%rdi), %rsi
	cmovaeq	%rax, %rsi
	movl	%edx, %eax
	shlq	$32, %rdx
	subq	%rax, %rdx
	addq	%rsi, %rdx
	leaq	(%rdx,%r9), %rax
	cmovbq	%rax, %rdx
	addq	%rdx, %r9
	cmpq	%rdi, %rdx
	cmovaq	%r9, %rdx
	movq	%rcx, %rax
	retq
.Lfunc_end3:
	.size	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base, .Lfunc_end3-_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	.cfi_endproc

	.section	.text.baseline,"ax",@progbits
	.globl	baseline
	.p2align	4
	.type	baseline,@function
baseline:
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
	subq	$1160, %rsp
	.cfi_def_cfa_offset 1216
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%rcx, 1152(%rsp)
	movq	%rdx, 208(%rsp)
	movq	%rdi, %r15
	movq	(%rsi), %rax
	movq	%rax, 120(%rsp)
	movq	8(%rsi), %rax
	movq	%rax, 336(%rsp)
	movq	16(%rsi), %rax
	movq	%rax, 32(%rsp)
	movq	24(%rsi), %rax
	movq	%rax, 56(%rsp)
	movq	%rsi, %r13
	movq	160(%rdi), %rbx
	movq	%rbx, 80(%rsp)
	movq	168(%rdi), %r14
	movq	%r14, 16(%rsp)
	movq	176(%rdi), %rdi
	movq	184(%r15), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rax, 160(%rsp)
	movq	%rdx, 104(%rsp)
	movq	%r13, %rax
	movq	%r13, 40(%rsp)
	movq	32(%r13), %r13
	movq	40(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	104(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	120(%rsp), %rdi
	movq	336(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 120(%rsp)
	movq	%rdx, 336(%rsp)
	movq	32(%rsp), %rdi
	movq	56(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 32(%rsp)
	movq	%rdx, 56(%rsp)
	movq	544(%r15), %rbx
	movq	%rbx, 952(%rsp)
	movq	552(%r15), %r14
	movq	%r14, 1088(%rsp)
	movq	560(%r15), %rdi
	movq	568(%r15), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 624(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 1080(%rsp)
	movq	40(%rsp), %rax
	movq	48(%rax), %r13
	movq	56(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	624(%rsp), %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	120(%rsp), %rdi
	movq	336(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 336(%rsp)
	movq	%rdx, 8(%rsp)
	movq	32(%rsp), %rdi
	movq	56(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	672(%r15), %rbx
	movq	%rbx, 32(%rsp)
	movq	680(%r15), %r14
	movq	%r14, 56(%rsp)
	movq	688(%r15), %rdi
	movq	696(%r15), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 120(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 128(%rsp)
	movq	40(%rsp), %rax
	movq	64(%rax), %r13
	movq	72(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	120(%rsp), %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	336(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 336(%rsp)
	movq	%rdx, 8(%rsp)
	movq	24(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	1088(%r15), %r13
	movq	1096(%r15), %rbp
	movq	1104(%r15), %rdi
	movq	1112(%r15), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 64(%rsp)
	movq	%rdx, %r14
	movq	40(%rsp), %rax
	movq	80(%rax), %rbx
	movq	88(%rax), %r12
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	64(%rsp), %rdi
	movq	%r14, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	336(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 64(%rsp)
	movq	24(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	1056(%r15), %rbx
	movq	%rbx, 1144(%rsp)
	movq	1064(%r15), %r14
	movq	%r14, 1136(%rsp)
	movq	1072(%r15), %rdi
	movq	1080(%r15), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 336(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 1128(%rsp)
	movq	40(%rsp), %rax
	movq	96(%rax), %r13
	movq	104(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	336(%rsp), %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 64(%rsp)
	movq	24(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r15, 88(%rsp)
	movq	1280(%r15), %rbx
	movq	1288(%r15), %r14
	movq	1296(%r15), %rdi
	movq	1304(%r15), %rsi
	movq	%rbx, 608(%rsp)
	movq	%rbx, %rdx
	movq	%r14, 600(%rsp)
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 256(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 352(%rsp)
	movq	40(%rsp), %rax
	movq	112(%rax), %r13
	movq	120(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 64(%rsp)
	movq	24(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	88(%rsp), %rax
	movq	1312(%rax), %rbx
	movq	%rbx, 920(%rsp)
	movq	1320(%rax), %r14
	movq	%r14, 912(%rsp)
	movq	1328(%rax), %rdi
	movq	1336(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rax, 904(%rsp)
	movq	%rdx, %r15
	movq	%rdx, 896(%rsp)
	movq	40(%rsp), %rax
	movq	128(%rax), %r13
	movq	136(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 96(%rsp)
	movq	24(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	88(%rsp), %rax
	movq	192(%rax), %rbx
	movq	%rbx, 24(%rsp)
	movq	200(%rax), %r14
	movq	%r14, 48(%rsp)
	movq	208(%rax), %rdi
	movq	216(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 64(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 72(%rsp)
	movq	40(%rsp), %rax
	movq	144(%rax), %r13
	movq	152(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 192(%rsp)
	movq	112(%rsp), %rdi
	movq	168(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 184(%rsp)
	movq	%rdx, 176(%rsp)
	movq	88(%rsp), %rax
	movq	224(%rax), %rbx
	movq	%rbx, 96(%rsp)
	movq	232(%rax), %r14
	movq	%r14, 112(%rsp)
	movq	240(%rax), %rdi
	movq	248(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 168(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 632(%rsp)
	movq	40(%rsp), %rax
	movq	160(%rax), %r13
	movq	168(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	192(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 192(%rsp)
	movq	184(%rsp), %rdi
	movq	176(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 184(%rsp)
	movq	%rdx, 176(%rsp)
	movq	88(%rsp), %rax
	movq	576(%rax), %rbx
	movq	%rbx, 304(%rsp)
	movq	584(%rax), %r14
	movq	%r14, 368(%rsp)
	movq	592(%rax), %rdi
	movq	600(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 432(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 424(%rsp)
	movq	40(%rsp), %rax
	movq	176(%rax), %r13
	movq	184(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	192(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 192(%rsp)
	movq	184(%rsp), %rdi
	movq	176(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 184(%rsp)
	movq	%rdx, 176(%rsp)
	movq	88(%rsp), %rax
	movq	608(%rax), %rbx
	movq	%rbx, 296(%rsp)
	movq	616(%rax), %r14
	movq	%r14, 360(%rsp)
	movq	624(%rax), %rdi
	movq	632(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 712(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 704(%rsp)
	movq	40(%rsp), %rax
	movq	192(%rax), %r13
	movq	200(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	192(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 192(%rsp)
	movq	184(%rsp), %rdi
	movq	176(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 184(%rsp)
	movq	%rdx, 176(%rsp)
	movq	88(%rsp), %rax
	movq	704(%rax), %rbx
	movq	%rbx, 576(%rsp)
	movq	712(%rax), %r14
	movq	%r14, 568(%rsp)
	movq	720(%rax), %rdi
	movq	728(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 464(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 456(%rsp)
	movq	40(%rsp), %rax
	movq	208(%rax), %r13
	movq	216(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	192(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 192(%rsp)
	movq	184(%rsp), %rdi
	movq	176(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 184(%rsp)
	movq	%rdx, 176(%rsp)
	movq	88(%rsp), %rax
	movq	736(%rax), %rbx
	movq	%rbx, 264(%rsp)
	movq	744(%rax), %r14
	movq	%r14, 312(%rsp)
	movq	752(%rax), %rdi
	movq	760(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 448(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 440(%rsp)
	movq	40(%rsp), %rax
	movq	224(%rax), %r13
	movq	232(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	192(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 192(%rsp)
	movq	184(%rsp), %rdi
	movq	176(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 184(%rsp)
	movq	%rdx, 176(%rsp)
	movq	88(%rsp), %rax
	movq	1120(%rax), %rbx
	movq	%rbx, 776(%rsp)
	movq	1128(%rax), %r14
	movq	%r14, 768(%rsp)
	movq	1136(%rax), %rdi
	movq	1144(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 504(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 496(%rsp)
	movq	40(%rsp), %rax
	movq	240(%rax), %r13
	movq	248(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	192(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 192(%rsp)
	movq	184(%rsp), %rdi
	movq	176(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 184(%rsp)
	movq	%rdx, 176(%rsp)
	movq	88(%rsp), %rax
	movq	1152(%rax), %rbx
	movq	%rbx, 232(%rsp)
	movq	1160(%rax), %r14
	movq	%r14, 320(%rsp)
	movq	1168(%rax), %rdi
	movq	1176(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 936(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 928(%rsp)
	movq	40(%rsp), %rax
	movq	256(%rax), %r13
	movq	264(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	192(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 328(%rsp)
	movq	184(%rsp), %rdi
	movq	176(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 512(%rsp)
	movq	%rdx, 784(%rsp)
	movq	88(%rsp), %rax
	movq	1184(%rax), %rbx
	movq	%rbx, 192(%rsp)
	movq	1192(%rax), %r14
	movq	%r14, 184(%rsp)
	movq	1200(%rax), %rdi
	movq	1208(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 176(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 616(%rsp)
	movq	40(%rsp), %rax
	movq	272(%rax), %r13
	movq	280(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	328(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 152(%rsp)
	movq	512(%rsp), %rdi
	movq	784(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 144(%rsp)
	movq	%rdx, 136(%rsp)
	movq	88(%rsp), %rax
	movq	1216(%rax), %rbx
	movq	%rbx, 328(%rsp)
	movq	1224(%rax), %r14
	movq	%r14, 512(%rsp)
	movq	1232(%rax), %rdi
	movq	1240(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 784(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 944(%rsp)
	movq	40(%rsp), %rax
	movq	288(%rax), %r13
	movq	296(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 152(%rsp)
	movq	144(%rsp), %rdi
	movq	136(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 144(%rsp)
	movq	%rdx, 136(%rsp)
	movq	88(%rsp), %rax
	movq	288(%rax), %rbx
	movq	%rbx, 816(%rsp)
	movq	296(%rax), %r14
	movq	%r14, 808(%rsp)
	movq	304(%rax), %rdi
	movq	312(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 648(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 640(%rsp)
	movq	40(%rsp), %rax
	movq	304(%rax), %r13
	movq	312(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 152(%rsp)
	movq	144(%rsp), %rdi
	movq	136(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 144(%rsp)
	movq	%rdx, 136(%rsp)
	movq	88(%rsp), %rax
	movq	320(%rax), %rbx
	movq	%rbx, 384(%rsp)
	movq	328(%rax), %r14
	movq	%r14, 520(%rsp)
	movq	336(%rax), %rdi
	movq	344(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 968(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 960(%rsp)
	movq	40(%rsp), %rax
	movq	320(%rax), %r13
	movq	328(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 152(%rsp)
	movq	144(%rsp), %rdi
	movq	136(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 144(%rsp)
	movq	%rdx, 136(%rsp)
	movq	88(%rsp), %rax
	movq	352(%rax), %rbx
	movq	%rbx, 832(%rsp)
	movq	360(%rax), %r14
	movq	%r14, 824(%rsp)
	movq	368(%rax), %rdi
	movq	376(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 664(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 656(%rsp)
	movq	40(%rsp), %rax
	movq	336(%rax), %r13
	movq	344(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 152(%rsp)
	movq	144(%rsp), %rdi
	movq	136(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 144(%rsp)
	movq	%rdx, 136(%rsp)
	movq	88(%rsp), %rax
	movq	384(%rax), %rbx
	movq	%rbx, 392(%rsp)
	movq	392(%rax), %r14
	movq	%r14, 528(%rsp)
	movq	400(%rax), %rdi
	movq	408(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 984(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 976(%rsp)
	movq	40(%rsp), %rax
	movq	352(%rax), %r13
	movq	360(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 152(%rsp)
	movq	144(%rsp), %rdi
	movq	136(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 144(%rsp)
	movq	%rdx, 136(%rsp)
	movq	88(%rsp), %rax
	movq	416(%rax), %rbx
	movq	%rbx, 696(%rsp)
	movq	424(%rax), %r14
	movq	%r14, 688(%rsp)
	movq	432(%rax), %rdi
	movq	440(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 680(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 672(%rsp)
	movq	40(%rsp), %rax
	movq	368(%rax), %r13
	movq	376(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 152(%rsp)
	movq	144(%rsp), %rdi
	movq	136(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 144(%rsp)
	movq	%rdx, 136(%rsp)
	movq	88(%rsp), %rax
	movq	448(%rax), %rbx
	movq	%rbx, 400(%rsp)
	movq	456(%rax), %r14
	movq	%r14, 536(%rsp)
	movq	464(%rax), %rdi
	movq	472(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 1000(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 992(%rsp)
	movq	40(%rsp), %rax
	movq	384(%rax), %r13
	movq	392(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 152(%rsp)
	movq	144(%rsp), %rdi
	movq	136(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 144(%rsp)
	movq	%rdx, 136(%rsp)
	movq	88(%rsp), %rax
	movq	480(%rax), %rbx
	movq	%rbx, 552(%rsp)
	movq	488(%rax), %r14
	movq	%r14, 544(%rsp)
	movq	496(%rax), %rdi
	movq	504(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 416(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 408(%rsp)
	movq	40(%rsp), %rax
	movq	400(%rax), %r13
	movq	408(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 152(%rsp)
	movq	144(%rsp), %rdi
	movq	136(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 144(%rsp)
	movq	%rdx, 136(%rsp)
	movq	88(%rsp), %rax
	movq	512(%rax), %rbx
	movq	%rbx, 224(%rsp)
	movq	520(%rax), %r14
	movq	%r14, 288(%rsp)
	movq	528(%rax), %rdi
	movq	536(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 848(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 840(%rsp)
	movq	40(%rsp), %rax
	movq	416(%rax), %r13
	movq	424(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 152(%rsp)
	movq	144(%rsp), %rdi
	movq	136(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 144(%rsp)
	movq	%rdx, 136(%rsp)
	movq	88(%rsp), %rax
	movq	800(%rax), %rbx
	movq	%rbx, 560(%rsp)
	movq	808(%rax), %r14
	movq	%r14, 720(%rsp)
	movq	816(%rax), %rdi
	movq	824(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 1032(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 1024(%rsp)
	movq	40(%rsp), %rax
	movq	432(%rax), %r13
	movq	440(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 152(%rsp)
	movq	144(%rsp), %rdi
	movq	136(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 144(%rsp)
	movq	%rdx, 136(%rsp)
	movq	88(%rsp), %rax
	movq	832(%rax), %rbx
	movq	%rbx, 1016(%rsp)
	movq	840(%rax), %r14
	movq	%r14, 1008(%rsp)
	movq	848(%rax), %rdi
	movq	856(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 1120(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 1112(%rsp)
	movq	40(%rsp), %rax
	movq	448(%rax), %r13
	movq	456(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 152(%rsp)
	movq	144(%rsp), %rdi
	movq	136(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 144(%rsp)
	movq	%rdx, 136(%rsp)
	movq	88(%rsp), %rax
	movq	864(%rax), %rbx
	movq	%rbx, 864(%rsp)
	movq	872(%rax), %r14
	movq	%r14, 856(%rsp)
	movq	880(%rax), %rdi
	movq	888(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 736(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 728(%rsp)
	movq	40(%rsp), %rax
	movq	464(%rax), %r13
	movq	472(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 152(%rsp)
	movq	144(%rsp), %rdi
	movq	136(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 144(%rsp)
	movq	%rdx, 136(%rsp)
	movq	88(%rsp), %rax
	movq	896(%rax), %rbx
	movq	%rbx, 472(%rsp)
	movq	904(%rax), %r14
	movq	%r14, 584(%rsp)
	movq	912(%rax), %rdi
	movq	920(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 1048(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 1040(%rsp)
	movq	40(%rsp), %rax
	movq	480(%rax), %r13
	movq	488(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 152(%rsp)
	movq	144(%rsp), %rdi
	movq	136(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 144(%rsp)
	movq	%rdx, 136(%rsp)
	movq	88(%rsp), %rax
	movq	928(%rax), %rbx
	movq	%rbx, 880(%rsp)
	movq	936(%rax), %r14
	movq	%r14, 872(%rsp)
	movq	944(%rax), %rdi
	movq	952(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 752(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 744(%rsp)
	movq	40(%rsp), %rax
	movq	496(%rax), %r13
	movq	504(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 152(%rsp)
	movq	144(%rsp), %rdi
	movq	136(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 144(%rsp)
	movq	%rdx, 136(%rsp)
	movq	88(%rsp), %rax
	movq	960(%rax), %rbx
	movq	%rbx, 480(%rsp)
	movq	968(%rax), %r14
	movq	%r14, 592(%rsp)
	movq	976(%rax), %rdi
	movq	984(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 1064(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 1056(%rsp)
	movq	40(%rsp), %rax
	movq	512(%rax), %r13
	movq	520(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 376(%rsp)
	movq	144(%rsp), %rdi
	movq	136(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 488(%rsp)
	movq	%rdx, 888(%rsp)
	movq	88(%rsp), %rax
	movq	992(%rax), %rbx
	movq	%rbx, 152(%rsp)
	movq	1000(%rax), %r14
	movq	%r14, 144(%rsp)
	movq	1008(%rax), %rdi
	movq	1016(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 136(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 760(%rsp)
	movq	40(%rsp), %rax
	movq	528(%rax), %r13
	movq	536(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	376(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 280(%rsp)
	movq	488(%rsp), %rdi
	movq	888(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 216(%rsp)
	movq	%rdx, 200(%rsp)
	movq	88(%rsp), %rax
	movq	1024(%rax), %rbx
	movq	%rbx, 376(%rsp)
	movq	1032(%rax), %r14
	movq	%r14, 488(%rsp)
	movq	1040(%rax), %rdi
	movq	1048(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 888(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 1072(%rsp)
	movq	40(%rsp), %rax
	movq	544(%rax), %r13
	movq	552(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 248(%rsp)
	movq	216(%rsp), %rdi
	movq	200(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 216(%rsp)
	movq	%rdx, 200(%rsp)
	movq	88(%rsp), %rax
	movq	96(%rax), %r14
	movq	104(%rax), %rbp
	movq	112(%rax), %rdi
	movq	120(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	80(%rsp), %rdx
	movq	16(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 272(%rsp)
	movq	%rdx, 344(%rsp)
	movq	%rbx, %rdi
	movq	%r15, %rsi
	movq	160(%rsp), %r13
	movq	%r13, %rdx
	movq	104(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 280(%rsp)
	movq	%rdx, 240(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	80(%rsp), %rdi
	movq	16(%rsp), %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	272(%rsp), %rbx
	movq	%rbx, %rdx
	movq	344(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	280(%rsp), %r12
	movq	%r12, %rdx
	movq	240(%rsp), %r13
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 104(%rsp)
	movq	%rdx, 160(%rsp)
	movq	40(%rsp), %rax
	movq	560(%rax), %r15
	movq	568(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 80(%rsp)
	movq	104(%rsp), %rdi
	movq	160(%rsp), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 104(%rsp)
	movq	%rdx, 280(%rsp)
	movq	8(%rsp), %rdi
	movq	248(%rsp), %rsi
	movq	16(%rsp), %rdx
	movq	80(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 248(%rsp)
	movq	%rdx, 240(%rsp)
	movq	216(%rsp), %rdi
	movq	200(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 216(%rsp)
	movq	%rdx, 200(%rsp)
	movq	88(%rsp), %rax
	movq	256(%rax), %rbx
	movq	%rbx, 80(%rsp)
	movq	264(%rax), %r14
	movq	%r14, 16(%rsp)
	movq	272(%rax), %rdi
	movq	280(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	608(%rsp), %r15
	movq	%r15, %rdi
	movq	600(%rsp), %rbp
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 800(%rsp)
	movq	%rdx, 792(%rsp)
	movq	256(%rsp), %rbx
	movq	%rbx, %rdi
	movq	352(%rsp), %r14
	movq	%r14, %rsi
	movq	%r12, %rdx
	movq	%r12, 8(%rsp)
	movq	%r13, 160(%rsp)
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 272(%rsp)
	movq	%rdx, 344(%rsp)
	movq	%r15, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r14
	movq	%rdx, %rbp
	movq	80(%rsp), %rdi
	movq	16(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	800(%rsp), %r14
	movq	%r14, %rdx
	movq	792(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	272(%rsp), %r12
	movq	%r12, %rdx
	movq	344(%rsp), %r13
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 256(%rsp)
	movq	%rdx, 352(%rsp)
	movq	40(%rsp), %rax
	movq	576(%rax), %rbx
	movq	584(%rax), %r15
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 608(%rsp)
	movq	%rdx, 600(%rsp)
	movq	256(%rsp), %rdi
	movq	352(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %rbp
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	248(%rsp), %rdi
	movq	240(%rsp), %rsi
	movq	608(%rsp), %rdx
	movq	600(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 608(%rsp)
	movq	%rdx, 600(%rsp)
	movq	216(%rsp), %rdi
	movq	200(%rsp), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 256(%rsp)
	movq	%rdx, 352(%rsp)
	movq	104(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 104(%rsp)
	movq	%rdx, 280(%rsp)
	movq	88(%rsp), %rax
	movq	128(%rax), %r14
	movq	136(%rax), %r12
	movq	144(%rax), %rdi
	movq	152(%rax), %rsi
	movq	%r14, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rdx, %r13
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	32(%rsp), %rdx
	movq	56(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 200(%rsp)
	movq	%rdx, 240(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	120(%rsp), %rbx
	movq	%rbx, %rdx
	movq	128(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 248(%rsp)
	movq	%rdx, 216(%rsp)
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%r15, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	32(%rsp), %rdi
	movq	56(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	200(%rsp), %r14
	movq	%r14, %rdx
	movq	240(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	248(%rsp), %rbx
	movq	%rbx, %rdx
	movq	216(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 120(%rsp)
	movq	%rdx, 128(%rsp)
	movq	40(%rsp), %rax
	movq	592(%rax), %r12
	movq	600(%rax), %r13
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 32(%rsp)
	movq	%rdx, 56(%rsp)
	movq	120(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	%rbx, %rdi
	movq	%rbp, %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	608(%rsp), %rdi
	movq	600(%rsp), %rsi
	movq	32(%rsp), %rdx
	movq	56(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 608(%rsp)
	movq	%rdx, 600(%rsp)
	movq	256(%rsp), %rdi
	movq	352(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 256(%rsp)
	movq	%rdx, 352(%rsp)
	movq	104(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 104(%rsp)
	movq	%rdx, 280(%rsp)
	movq	88(%rsp), %rax
	movq	768(%rax), %rbx
	movq	%rbx, 56(%rsp)
	movq	776(%rax), %r14
	movq	%r14, 120(%rsp)
	movq	784(%rax), %rdi
	movq	792(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rdx, 32(%rsp)
	movq	920(%rsp), %rbp
	movq	%rbp, %rdi
	movq	912(%rsp), %r12
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 200(%rsp)
	movq	%rdx, 240(%rsp)
	movq	904(%rsp), %r13
	movq	%r13, %rdi
	movq	896(%rsp), %r14
	movq	%r14, %rsi
	movq	%r15, 128(%rsp)
	movq	%r15, %rdx
	movq	32(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 248(%rsp)
	movq	%rdx, 216(%rsp)
	movq	%rbp, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rdi
	movq	120(%rsp), %rsi
	movq	%r15, %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	200(%rsp), %r14
	movq	%r14, %rdx
	movq	240(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	248(%rsp), %r12
	movq	%r12, %rdx
	movq	216(%rsp), %r13
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 904(%rsp)
	movq	%rdx, 896(%rsp)
	movq	40(%rsp), %rax
	movq	608(%rax), %rbx
	movq	616(%rax), %r15
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 920(%rsp)
	movq	%rdx, 912(%rsp)
	movq	904(%rsp), %rdi
	movq	896(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %rbp
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	608(%rsp), %rdi
	movq	600(%rsp), %rsi
	movq	920(%rsp), %rdx
	movq	912(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 920(%rsp)
	movq	%rdx, 912(%rsp)
	movq	256(%rsp), %rdi
	movq	352(%rsp), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 904(%rsp)
	movq	%rdx, 896(%rsp)
	movq	104(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 608(%rsp)
	movq	%rdx, 600(%rsp)
	movq	40(%rsp), %r14
	movq	624(%r14), %rcx
	movq	%rcx, 352(%rsp)
	movq	632(%r14), %rcx
	movq	%rcx, 280(%rsp)
	movq	640(%r14), %rcx
	movq	%rcx, 104(%rsp)
	movq	648(%r14), %rcx
	movq	%rcx, 256(%rsp)
	movq	208(%rsp), %rbx
	movq	(%rbx), %r15
	movq	24(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	64(%rsp), %rdi
	movq	72(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	104(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 64(%rsp)
	movq	%rdx, 72(%rsp)
	movq	656(%r14), %rdi
	movq	664(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	672(%r14), %rax
	movq	%rax, 104(%rsp)
	movq	680(%r14), %rax
	movq	%rax, 256(%rsp)
	movq	8(%rbx), %r15
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	168(%rsp), %rdi
	movq	632(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	104(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 104(%rsp)
	movq	%rdx, 168(%rsp)
	movq	688(%r14), %rdi
	movq	696(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 632(%rsp)
	movq	%rdx, 256(%rsp)
	movq	88(%rsp), %rax
	movq	1344(%rax), %r14
	movq	1352(%rax), %rbp
	movq	1360(%rax), %rdi
	movq	1368(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 216(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 248(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	64(%rsp), %r13
	movq	%r13, %rdx
	movq	72(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 200(%rsp)
	movq	%rdx, 240(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	24(%rsp), %rbx
	movq	%rbx, %rdx
	movq	48(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	216(%rsp), %rdx
	movq	248(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r14
	movq	%rdx, %rbp
	movq	%r13, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	200(%rsp), %rbx
	movq	%rbx, %rdx
	movq	240(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	96(%rsp), %rdx
	movq	112(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 272(%rsp)
	movq	%rdx, 344(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	104(%rsp), %r13
	movq	%r13, %rdx
	movq	168(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 248(%rsp)
	movq	%rdx, 216(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	632(%rsp), %r15
	movq	%r15, %rdx
	movq	256(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 200(%rsp)
	movq	%rdx, 240(%rsp)
	movq	272(%rsp), %rbx
	movq	%rbx, %rdi
	movq	344(%rsp), %r14
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	200(%rsp), %rdi
	movq	240(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 800(%rsp)
	movq	%rdx, 792(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 200(%rsp)
	movq	%rdx, %r12
	movq	96(%rsp), %rbx
	movq	%rbx, %rdi
	movq	112(%rsp), %r13
	movq	%r13, %rsi
	movq	104(%rsp), %rdx
	movq	168(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	200(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 200(%rsp)
	movq	%rdx, 240(%rsp)
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	movq	%rbp, %r12
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 272(%rsp)
	movq	%rdx, 344(%rsp)
	movq	64(%rsp), %rdi
	movq	72(%rsp), %rsi
	movq	104(%rsp), %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r14
	movq	%rdx, %rbp
	movq	24(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	248(%rsp), %rdi
	movq	216(%rsp), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbp
	movq	%rdx, %r15
	movq	800(%rsp), %rdi
	movq	792(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	40(%rsp), %rax
	movq	704(%rax), %rbx
	movq	712(%rax), %r14
	movq	%rbp, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, 96(%rsp)
	movq	200(%rsp), %rdi
	movq	240(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	272(%rsp), %rdi
	movq	344(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 632(%rsp)
	movq	%rdx, 256(%rsp)
	movq	352(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 352(%rsp)
	movq	%rdx, 280(%rsp)
	movq	40(%rsp), %r14
	movq	720(%r14), %rcx
	movq	%rcx, 104(%rsp)
	movq	728(%r14), %rcx
	movq	%rcx, 24(%rsp)
	movq	208(%rsp), %rbx
	movq	16(%rbx), %r15
	movq	80(%rsp), %rdi
	movq	16(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	8(%rsp), %rdi
	movq	160(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	104(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 48(%rsp)
	movq	%rdx, 64(%rsp)
	movq	736(%r14), %rdi
	movq	744(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 104(%rsp)
	movq	%rdx, 24(%rsp)
	movq	752(%r14), %rax
	movq	%rax, 248(%rsp)
	movq	760(%r14), %rax
	movq	%rax, 216(%rsp)
	movq	24(%rbx), %r15
	movq	80(%rsp), %rdi
	movq	16(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	8(%rsp), %rdi
	movq	160(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	248(%rsp), %rdi
	movq	216(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 8(%rsp)
	movq	768(%r14), %rdi
	movq	776(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 248(%rsp)
	movq	%rdx, 216(%rsp)
	movq	88(%rsp), %rax
	movq	1376(%rax), %r14
	movq	1384(%rax), %rbp
	movq	1392(%rax), %rdi
	movq	1400(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 240(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 200(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	48(%rsp), %r13
	movq	%r13, %rdx
	movq	64(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 272(%rsp)
	movq	%rdx, 344(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	104(%rsp), %rbx
	movq	%rbx, %rdx
	movq	24(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 80(%rsp)
	movq	%rdx, 160(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	240(%rsp), %rdx
	movq	200(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r14
	movq	%rdx, %rbp
	movq	%r13, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	272(%rsp), %rbx
	movq	%rbx, %rdx
	movq	344(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	80(%rsp), %rdx
	movq	160(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 1104(%rsp)
	movq	%rdx, 1096(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	16(%rsp), %r13
	movq	%r13, %rdx
	movq	8(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 200(%rsp)
	movq	%rdx, 240(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	248(%rsp), %r15
	movq	%r15, %rdx
	movq	216(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 272(%rsp)
	movq	%rdx, 344(%rsp)
	movq	1104(%rsp), %rbx
	movq	%rbx, %rdi
	movq	1096(%rsp), %r14
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	272(%rsp), %rdi
	movq	344(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 800(%rsp)
	movq	%rdx, 792(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 272(%rsp)
	movq	%rdx, %r12
	movq	80(%rsp), %rbx
	movq	%rbx, %rdi
	movq	160(%rsp), %r13
	movq	%r13, %rsi
	movq	16(%rsp), %rdx
	movq	8(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	272(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 272(%rsp)
	movq	%rdx, 344(%rsp)
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 80(%rsp)
	movq	%rdx, 160(%rsp)
	movq	48(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	16(%rsp), %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r14
	movq	%rdx, %r12
	movq	104(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	200(%rsp), %rdi
	movq	240(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %r15
	movq	800(%rsp), %rdi
	movq	792(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	40(%rsp), %rax
	movq	784(%rax), %rbx
	movq	792(%rax), %r14
	movq	%r12, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r15
	movq	%rdx, 16(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	272(%rsp), %rdi
	movq	344(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 104(%rsp)
	movq	80(%rsp), %rdi
	movq	160(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	352(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r15, %rdx
	movq	16(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 352(%rsp)
	movq	%rdx, 280(%rsp)
	movq	72(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 72(%rsp)
	movq	%rdx, 96(%rsp)
	movq	112(%rsp), %rdi
	movq	168(%rsp), %rsi
	movq	%rbp, %rdx
	movq	104(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	632(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 632(%rsp)
	movq	%rdx, 256(%rsp)
	movq	40(%rsp), %r14
	movq	800(%r14), %rcx
	movq	%rcx, 16(%rsp)
	movq	808(%r14), %rcx
	movq	%rcx, 80(%rsp)
	movq	208(%rsp), %rbx
	movq	32(%rbx), %r15
	movq	816(%rsp), %rdi
	movq	808(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	648(%rsp), %rdi
	movq	640(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	16(%rsp), %rdi
	movq	80(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 8(%rsp)
	movq	816(%r14), %rdi
	movq	824(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 80(%rsp)
	movq	%rdx, 104(%rsp)
	movq	832(%r14), %rax
	movq	%rax, 16(%rsp)
	movq	840(%r14), %rax
	movq	%rax, 24(%rsp)
	movq	40(%rbx), %r15
	movq	384(%rsp), %rdi
	movq	520(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	968(%rsp), %rdi
	movq	960(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	16(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 64(%rsp)
	movq	848(%r14), %rdi
	movq	856(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 816(%rsp)
	movq	%rdx, 808(%rsp)
	movq	88(%rsp), %rax
	movq	1408(%rax), %r14
	movq	1416(%rax), %rbp
	movq	1424(%rax), %rdi
	movq	1432(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 640(%rsp)
	movq	%rdx, %r13
	movq	%rdx, 648(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	160(%rsp), %r12
	movq	%r12, %rdx
	movq	8(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 384(%rsp)
	movq	%rdx, 520(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	80(%rsp), %r13
	movq	%r13, %rdx
	movq	104(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	640(%rsp), %rdx
	movq	648(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbp
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	384(%rsp), %rbx
	movq	%rbx, %rdx
	movq	520(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	24(%rsp), %rdx
	movq	48(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 248(%rsp)
	movq	%rdx, 216(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	16(%rsp), %r13
	movq	%r13, %rdx
	movq	64(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 648(%rsp)
	movq	%rdx, 640(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	816(%rsp), %rbp
	movq	%rbp, %rdx
	movq	808(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 384(%rsp)
	movq	%rdx, 520(%rsp)
	movq	248(%rsp), %r14
	movq	%r14, %rdi
	movq	216(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	384(%rsp), %rdi
	movq	520(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 968(%rsp)
	movq	%rdx, 960(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 384(%rsp)
	movq	%rdx, %r14
	movq	24(%rsp), %r12
	movq	%r12, %rdi
	movq	48(%rsp), %r13
	movq	%r13, %rsi
	movq	16(%rsp), %rdx
	movq	64(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	384(%rsp), %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 384(%rsp)
	movq	%rdx, 520(%rsp)
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	16(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	80(%rsp), %rdi
	movq	104(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	648(%rsp), %rdi
	movq	640(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	968(%rsp), %rdi
	movq	960(%rsp), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	40(%rsp), %rax
	movq	864(%rax), %r14
	movq	872(%rax), %r15
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, 16(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	384(%rsp), %rdi
	movq	520(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 80(%rsp)
	movq	24(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	352(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r13, %rdx
	movq	16(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 816(%rsp)
	movq	%rdx, 808(%rsp)
	movq	72(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 72(%rsp)
	movq	%rdx, 96(%rsp)
	movq	112(%rsp), %rdi
	movq	168(%rsp), %rsi
	movq	%rbp, %rdx
	movq	80(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	632(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 648(%rsp)
	movq	%rdx, 640(%rsp)
	movq	40(%rsp), %r14
	movq	880(%r14), %rcx
	movq	%rcx, 16(%rsp)
	movq	888(%r14), %rcx
	movq	%rcx, 80(%rsp)
	movq	208(%rsp), %rbx
	movq	48(%rbx), %r15
	movq	832(%rsp), %rdi
	movq	824(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	664(%rsp), %rdi
	movq	656(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	16(%rsp), %rdi
	movq	80(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 8(%rsp)
	movq	896(%r14), %rdi
	movq	904(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 80(%rsp)
	movq	%rdx, 104(%rsp)
	movq	912(%r14), %rax
	movq	%rax, 16(%rsp)
	movq	920(%r14), %rax
	movq	%rax, 24(%rsp)
	movq	56(%rbx), %r15
	movq	392(%rsp), %rdi
	movq	528(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	984(%rsp), %rdi
	movq	976(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	16(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 64(%rsp)
	movq	928(%r14), %rdi
	movq	936(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 832(%rsp)
	movq	%rdx, 824(%rsp)
	movq	88(%rsp), %rax
	movq	1440(%rax), %r14
	movq	1448(%rax), %rbp
	movq	1456(%rax), %rdi
	movq	1464(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 656(%rsp)
	movq	%rdx, %r13
	movq	%rdx, 664(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	160(%rsp), %r12
	movq	%r12, %rdx
	movq	8(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 392(%rsp)
	movq	%rdx, 528(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	80(%rsp), %r13
	movq	%r13, %rdx
	movq	104(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	656(%rsp), %rdx
	movq	664(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbp
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	392(%rsp), %rbx
	movq	%rbx, %rdx
	movq	528(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	24(%rsp), %rdx
	movq	48(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 384(%rsp)
	movq	%rdx, 520(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	16(%rsp), %r13
	movq	%r13, %rdx
	movq	64(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 664(%rsp)
	movq	%rdx, 656(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	832(%rsp), %rbp
	movq	%rbp, %rdx
	movq	824(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 392(%rsp)
	movq	%rdx, 528(%rsp)
	movq	384(%rsp), %r14
	movq	%r14, %rdi
	movq	520(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	392(%rsp), %rdi
	movq	528(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 984(%rsp)
	movq	%rdx, 976(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 392(%rsp)
	movq	%rdx, %r14
	movq	24(%rsp), %r12
	movq	%r12, %rdi
	movq	48(%rsp), %r13
	movq	%r13, %rsi
	movq	16(%rsp), %rdx
	movq	64(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	392(%rsp), %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 392(%rsp)
	movq	%rdx, 528(%rsp)
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	16(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	80(%rsp), %rdi
	movq	104(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	664(%rsp), %rdi
	movq	656(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	984(%rsp), %rdi
	movq	976(%rsp), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	40(%rsp), %rax
	movq	944(%rax), %r14
	movq	952(%rax), %r15
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, 16(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	392(%rsp), %rdi
	movq	528(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 80(%rsp)
	movq	24(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	816(%rsp), %rdi
	movq	808(%rsp), %rsi
	movq	%r13, %rdx
	movq	16(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 832(%rsp)
	movq	%rdx, 824(%rsp)
	movq	72(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 72(%rsp)
	movq	%rdx, 96(%rsp)
	movq	112(%rsp), %rdi
	movq	168(%rsp), %rsi
	movq	%rbp, %rdx
	movq	80(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	648(%rsp), %rdi
	movq	640(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 664(%rsp)
	movq	%rdx, 656(%rsp)
	movq	40(%rsp), %r14
	movq	960(%r14), %rcx
	movq	%rcx, 16(%rsp)
	movq	968(%r14), %rcx
	movq	%rcx, 80(%rsp)
	movq	208(%rsp), %rbx
	movq	64(%rbx), %r15
	movq	696(%rsp), %rdi
	movq	688(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	680(%rsp), %rdi
	movq	672(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	16(%rsp), %rdi
	movq	80(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 8(%rsp)
	movq	976(%r14), %rdi
	movq	984(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 80(%rsp)
	movq	%rdx, 104(%rsp)
	movq	992(%r14), %rax
	movq	%rax, 16(%rsp)
	movq	1000(%r14), %rax
	movq	%rax, 24(%rsp)
	movq	72(%rbx), %r15
	movq	400(%rsp), %rdi
	movq	536(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	1000(%rsp), %rdi
	movq	992(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	16(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 64(%rsp)
	movq	1008(%r14), %rdi
	movq	1016(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 696(%rsp)
	movq	%rdx, 688(%rsp)
	movq	88(%rsp), %rax
	movq	1472(%rax), %r14
	movq	1480(%rax), %rbp
	movq	1488(%rax), %rdi
	movq	1496(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 672(%rsp)
	movq	%rdx, %r13
	movq	%rdx, 680(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	160(%rsp), %r12
	movq	%r12, %rdx
	movq	8(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 400(%rsp)
	movq	%rdx, 536(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	80(%rsp), %r13
	movq	%r13, %rdx
	movq	104(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	672(%rsp), %rdx
	movq	680(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbp
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	400(%rsp), %rbx
	movq	%rbx, %rdx
	movq	536(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	24(%rsp), %rdx
	movq	48(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 392(%rsp)
	movq	%rdx, 528(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	16(%rsp), %r13
	movq	%r13, %rdx
	movq	64(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 680(%rsp)
	movq	%rdx, 672(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	696(%rsp), %rbp
	movq	%rbp, %rdx
	movq	688(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 400(%rsp)
	movq	%rdx, 536(%rsp)
	movq	392(%rsp), %r14
	movq	%r14, %rdi
	movq	528(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	400(%rsp), %rdi
	movq	536(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 1000(%rsp)
	movq	%rdx, 992(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 400(%rsp)
	movq	%rdx, %r14
	movq	24(%rsp), %r12
	movq	%r12, %rdi
	movq	48(%rsp), %r13
	movq	%r13, %rsi
	movq	16(%rsp), %rdx
	movq	64(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	400(%rsp), %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 400(%rsp)
	movq	%rdx, 536(%rsp)
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	16(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	80(%rsp), %rdi
	movq	104(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	680(%rsp), %rdi
	movq	672(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	1000(%rsp), %rdi
	movq	992(%rsp), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	40(%rsp), %rax
	movq	1024(%rax), %r14
	movq	1032(%rax), %r15
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, 16(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	400(%rsp), %rdi
	movq	536(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 80(%rsp)
	movq	24(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	832(%rsp), %rdi
	movq	824(%rsp), %rsi
	movq	%r13, %rdx
	movq	16(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 696(%rsp)
	movq	%rdx, 688(%rsp)
	movq	72(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 72(%rsp)
	movq	%rdx, 96(%rsp)
	movq	112(%rsp), %rdi
	movq	168(%rsp), %rsi
	movq	%rbp, %rdx
	movq	80(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	664(%rsp), %rdi
	movq	656(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 680(%rsp)
	movq	%rdx, 672(%rsp)
	movq	40(%rsp), %r14
	movq	1040(%r14), %rcx
	movq	%rcx, 16(%rsp)
	movq	1048(%r14), %rcx
	movq	%rcx, 80(%rsp)
	movq	208(%rsp), %rbx
	movq	80(%rbx), %r15
	movq	552(%rsp), %rdi
	movq	544(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	416(%rsp), %rdi
	movq	408(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	16(%rsp), %rdi
	movq	80(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 8(%rsp)
	movq	1056(%r14), %rdi
	movq	1064(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 80(%rsp)
	movq	%rdx, 104(%rsp)
	movq	1072(%r14), %rax
	movq	%rax, 16(%rsp)
	movq	1080(%r14), %rax
	movq	%rax, 24(%rsp)
	movq	88(%rbx), %r15
	movq	224(%rsp), %rdi
	movq	288(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	848(%rsp), %rdi
	movq	840(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	16(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 64(%rsp)
	movq	1088(%r14), %rdi
	movq	1096(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 552(%rsp)
	movq	%rdx, 544(%rsp)
	movq	88(%rsp), %rax
	movq	1504(%rax), %r14
	movq	1512(%rax), %rbp
	movq	1520(%rax), %rdi
	movq	1528(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 408(%rsp)
	movq	%rdx, %r13
	movq	%rdx, 416(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	160(%rsp), %r12
	movq	%r12, %rdx
	movq	8(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 224(%rsp)
	movq	%rdx, 288(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	80(%rsp), %r13
	movq	%r13, %rdx
	movq	104(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	408(%rsp), %rdx
	movq	416(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbp
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	224(%rsp), %rbx
	movq	%rbx, %rdx
	movq	288(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	24(%rsp), %rdx
	movq	48(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 400(%rsp)
	movq	%rdx, 536(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	16(%rsp), %r13
	movq	%r13, %rdx
	movq	64(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 416(%rsp)
	movq	%rdx, 408(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	552(%rsp), %rbp
	movq	%rbp, %rdx
	movq	544(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 224(%rsp)
	movq	%rdx, 288(%rsp)
	movq	400(%rsp), %r14
	movq	%r14, %rdi
	movq	536(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	224(%rsp), %rdi
	movq	288(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 848(%rsp)
	movq	%rdx, 840(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 224(%rsp)
	movq	%rdx, %r14
	movq	24(%rsp), %r12
	movq	%r12, %rdi
	movq	48(%rsp), %r13
	movq	%r13, %rsi
	movq	16(%rsp), %rdx
	movq	64(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	224(%rsp), %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 224(%rsp)
	movq	%rdx, 288(%rsp)
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	16(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	80(%rsp), %rdi
	movq	104(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	416(%rsp), %rdi
	movq	408(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	848(%rsp), %rdi
	movq	840(%rsp), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	40(%rsp), %rax
	movq	1104(%rax), %r14
	movq	1112(%rax), %r15
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, 16(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	224(%rsp), %rdi
	movq	288(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 80(%rsp)
	movq	24(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	696(%rsp), %rdi
	movq	688(%rsp), %rsi
	movq	%r13, %rdx
	movq	16(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 552(%rsp)
	movq	%rdx, 544(%rsp)
	movq	72(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 72(%rsp)
	movq	%rdx, 96(%rsp)
	movq	112(%rsp), %rdi
	movq	168(%rsp), %rsi
	movq	%rbp, %rdx
	movq	80(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	680(%rsp), %rdi
	movq	672(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 416(%rsp)
	movq	%rdx, 408(%rsp)
	movq	40(%rsp), %r14
	movq	1120(%r14), %rcx
	movq	%rcx, 16(%rsp)
	movq	1128(%r14), %rcx
	movq	%rcx, 80(%rsp)
	movq	208(%rsp), %rbx
	movq	96(%rbx), %r15
	movq	304(%rsp), %rdi
	movq	368(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	432(%rsp), %rdi
	movq	424(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	16(%rsp), %rdi
	movq	80(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 8(%rsp)
	movq	1136(%r14), %rdi
	movq	1144(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 80(%rsp)
	movq	%rdx, 104(%rsp)
	movq	1152(%r14), %rax
	movq	%rax, 16(%rsp)
	movq	1160(%r14), %rax
	movq	%rax, 24(%rsp)
	movq	104(%rbx), %r15
	movq	296(%rsp), %rdi
	movq	360(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	712(%rsp), %rdi
	movq	704(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	16(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 64(%rsp)
	movq	1168(%r14), %rdi
	movq	1176(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 304(%rsp)
	movq	%rdx, 368(%rsp)
	movq	88(%rsp), %rax
	movq	1536(%rax), %r14
	movq	1544(%rax), %rbp
	movq	1552(%rax), %rdi
	movq	1560(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 424(%rsp)
	movq	%rdx, %r13
	movq	%rdx, 432(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	160(%rsp), %r12
	movq	%r12, %rdx
	movq	8(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 296(%rsp)
	movq	%rdx, 360(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	80(%rsp), %r13
	movq	%r13, %rdx
	movq	104(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	424(%rsp), %rdx
	movq	432(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbp
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	296(%rsp), %rbx
	movq	%rbx, %rdx
	movq	360(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	24(%rsp), %rdx
	movq	48(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 224(%rsp)
	movq	%rdx, 288(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	16(%rsp), %r13
	movq	%r13, %rdx
	movq	64(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 432(%rsp)
	movq	%rdx, 424(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	304(%rsp), %rbp
	movq	%rbp, %rdx
	movq	368(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 296(%rsp)
	movq	%rdx, 360(%rsp)
	movq	224(%rsp), %r14
	movq	%r14, %rdi
	movq	288(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	296(%rsp), %rdi
	movq	360(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 712(%rsp)
	movq	%rdx, 704(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 296(%rsp)
	movq	%rdx, %r14
	movq	24(%rsp), %r12
	movq	%r12, %rdi
	movq	48(%rsp), %r13
	movq	%r13, %rsi
	movq	16(%rsp), %rdx
	movq	64(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	296(%rsp), %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 296(%rsp)
	movq	%rdx, 360(%rsp)
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	16(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	80(%rsp), %rdi
	movq	104(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	432(%rsp), %rdi
	movq	424(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	712(%rsp), %rdi
	movq	704(%rsp), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	40(%rsp), %rax
	movq	1184(%rax), %r14
	movq	1192(%rax), %r15
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, 16(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	296(%rsp), %rdi
	movq	360(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 80(%rsp)
	movq	24(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	552(%rsp), %rdi
	movq	544(%rsp), %rsi
	movq	%r13, %rdx
	movq	16(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 304(%rsp)
	movq	%rdx, 368(%rsp)
	movq	72(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 432(%rsp)
	movq	%rdx, 424(%rsp)
	movq	112(%rsp), %rdi
	movq	168(%rsp), %rsi
	movq	%rbp, %rdx
	movq	80(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 296(%rsp)
	movq	%rdx, 360(%rsp)
	movq	416(%rsp), %rdi
	movq	408(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 712(%rsp)
	movq	%rdx, 704(%rsp)
	movq	40(%rsp), %rax
	movq	1200(%rax), %rcx
	movq	%rcx, 16(%rsp)
	movq	1208(%rax), %rax
	movq	%rax, 8(%rsp)
	movq	88(%rsp), %rax
	movq	640(%rax), %r12
	movq	%r12, 104(%rsp)
	movq	648(%rax), %r13
	movq	%r13, 160(%rsp)
	movq	656(%rax), %rdi
	movq	664(%rax), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbp
	movq	%rax, 80(%rsp)
	movq	%rdx, %r14
	movq	208(%rsp), %rbx
	movq	112(%rbx), %r15
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%r14, 168(%rsp)
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	16(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 48(%rsp)
	movq	%rdx, 64(%rsp)
	movq	40(%rsp), %r12
	movq	1216(%r12), %rdi
	movq	1224(%r12), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	1232(%r12), %rax
	movq	%rax, 16(%rsp)
	movq	1240(%r12), %rax
	movq	%rax, 72(%rsp)
	movq	120(%rbx), %r15
	movq	104(%rsp), %rdi
	movq	160(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	80(%rsp), %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	16(%rsp), %rdi
	movq	72(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 112(%rsp)
	movq	40(%rsp), %rax
	movq	1248(%rax), %rdi
	movq	1256(%rax), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 552(%rsp)
	movq	%rdx, 544(%rsp)
	movq	88(%rsp), %rax
	movq	1568(%rax), %r14
	movq	1576(%rax), %rbp
	movq	1584(%rax), %rdi
	movq	1592(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 408(%rsp)
	movq	%rdx, %r13
	movq	%rdx, 416(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	48(%rsp), %r12
	movq	%r12, %rdx
	movq	64(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 224(%rsp)
	movq	%rdx, 288(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	8(%rsp), %r13
	movq	%r13, %rdx
	movq	24(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, 96(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	408(%rsp), %rdx
	movq	416(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbp
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	224(%rsp), %rbx
	movq	%rbx, %rdx
	movq	288(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	72(%rsp), %rdx
	movq	96(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 696(%rsp)
	movq	%rdx, 688(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	16(%rsp), %r13
	movq	%r13, %rdx
	movq	112(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 416(%rsp)
	movq	%rdx, 408(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	552(%rsp), %rbp
	movq	%rbp, %rdx
	movq	544(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 224(%rsp)
	movq	%rdx, 288(%rsp)
	movq	696(%rsp), %r14
	movq	%r14, %rdi
	movq	688(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	224(%rsp), %rdi
	movq	288(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 848(%rsp)
	movq	%rdx, 840(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 224(%rsp)
	movq	%rdx, %r14
	movq	72(%rsp), %r12
	movq	%r12, %rdi
	movq	96(%rsp), %r13
	movq	%r13, %rsi
	movq	16(%rsp), %rdx
	movq	112(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	224(%rsp), %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 224(%rsp)
	movq	%rdx, 288(%rsp)
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, 96(%rsp)
	movq	48(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	16(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	8(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	416(%rsp), %rdi
	movq	408(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	848(%rsp), %rdi
	movq	840(%rsp), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	40(%rsp), %rax
	movq	1264(%rax), %r14
	movq	1272(%rax), %r15
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, 16(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	224(%rsp), %rdi
	movq	288(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 8(%rsp)
	movq	72(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	304(%rsp), %rdi
	movq	368(%rsp), %rsi
	movq	%r13, %rdx
	movq	16(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 304(%rsp)
	movq	%rdx, 368(%rsp)
	movq	432(%rsp), %rdi
	movq	424(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 432(%rsp)
	movq	%rdx, 424(%rsp)
	movq	296(%rsp), %rdi
	movq	360(%rsp), %rsi
	movq	%rbp, %rdx
	movq	8(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 296(%rsp)
	movq	%rdx, 360(%rsp)
	movq	712(%rsp), %rdi
	movq	704(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 712(%rsp)
	movq	%rdx, 704(%rsp)
	movq	40(%rsp), %r14
	movq	1280(%r14), %rcx
	movq	%rcx, 16(%rsp)
	movq	1288(%r14), %rcx
	movq	%rcx, 8(%rsp)
	movq	208(%rsp), %rbx
	movq	128(%rbx), %r15
	movq	576(%rsp), %rdi
	movq	568(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	464(%rsp), %rdi
	movq	456(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	16(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 48(%rsp)
	movq	%rdx, 64(%rsp)
	movq	1296(%r14), %rdi
	movq	1304(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	1312(%r14), %rax
	movq	%rax, 16(%rsp)
	movq	1320(%r14), %rax
	movq	%rax, 72(%rsp)
	movq	136(%rbx), %r15
	movq	264(%rsp), %rdi
	movq	312(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	448(%rsp), %rdi
	movq	440(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	16(%rsp), %rdi
	movq	72(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 112(%rsp)
	movq	1328(%r14), %rdi
	movq	1336(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 576(%rsp)
	movq	%rdx, 568(%rsp)
	movq	88(%rsp), %rax
	movq	1600(%rax), %r14
	movq	1608(%rax), %rbp
	movq	1616(%rax), %rdi
	movq	1624(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 456(%rsp)
	movq	%rdx, %r13
	movq	%rdx, 464(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	48(%rsp), %r12
	movq	%r12, %rdx
	movq	64(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 264(%rsp)
	movq	%rdx, 312(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	8(%rsp), %r13
	movq	%r13, %rdx
	movq	24(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, 96(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	456(%rsp), %rdx
	movq	464(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbp
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	264(%rsp), %rbx
	movq	%rbx, %rdx
	movq	312(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	72(%rsp), %rdx
	movq	96(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 552(%rsp)
	movq	%rdx, 544(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	16(%rsp), %r13
	movq	%r13, %rdx
	movq	112(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 464(%rsp)
	movq	%rdx, 456(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	576(%rsp), %rbp
	movq	%rbp, %rdx
	movq	568(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 264(%rsp)
	movq	%rdx, 312(%rsp)
	movq	552(%rsp), %r14
	movq	%r14, %rdi
	movq	544(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	264(%rsp), %rdi
	movq	312(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 448(%rsp)
	movq	%rdx, 440(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 264(%rsp)
	movq	%rdx, %r14
	movq	72(%rsp), %r12
	movq	%r12, %rdi
	movq	96(%rsp), %r13
	movq	%r13, %rsi
	movq	16(%rsp), %rdx
	movq	112(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	264(%rsp), %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 264(%rsp)
	movq	%rdx, 312(%rsp)
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, 96(%rsp)
	movq	48(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	16(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	8(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	464(%rsp), %rdi
	movq	456(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	448(%rsp), %rdi
	movq	440(%rsp), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	40(%rsp), %rax
	movq	1344(%rax), %r14
	movq	1352(%rax), %r15
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, 16(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	264(%rsp), %rdi
	movq	312(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 8(%rsp)
	movq	72(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	304(%rsp), %rdi
	movq	368(%rsp), %rsi
	movq	%r13, %rdx
	movq	16(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 64(%rsp)
	movq	%rdx, 72(%rsp)
	movq	432(%rsp), %rdi
	movq	424(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	296(%rsp), %rdi
	movq	360(%rsp), %rsi
	movq	%rbp, %rdx
	movq	8(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 576(%rsp)
	movq	%rdx, 568(%rsp)
	movq	712(%rsp), %rdi
	movq	704(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 464(%rsp)
	movq	%rdx, 456(%rsp)
	movq	40(%rsp), %r14
	movq	1360(%r14), %rcx
	movq	%rcx, 16(%rsp)
	movq	1368(%r14), %rcx
	movq	%rcx, 8(%rsp)
	movq	208(%rsp), %rbx
	movq	144(%rbx), %r15
	movq	56(%rsp), %rdi
	movq	120(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	128(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	16(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	1376(%r14), %rdi
	movq	1384(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 8(%rsp)
	movq	1392(%r14), %rax
	movq	%rax, 264(%rsp)
	movq	1400(%r14), %rax
	movq	%rax, 312(%rsp)
	movq	152(%rbx), %r15
	movq	56(%rsp), %rdi
	movq	120(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	128(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	264(%rsp), %rdi
	movq	312(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 32(%rsp)
	movq	%rdx, 128(%rsp)
	movq	1408(%r14), %rdi
	movq	1416(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 264(%rsp)
	movq	%rdx, 312(%rsp)
	movq	88(%rsp), %rax
	movq	1632(%rax), %r14
	movq	1640(%rax), %rbp
	movq	1648(%rax), %rdi
	movq	1656(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 440(%rsp)
	movq	%rdx, %r13
	movq	%rdx, 448(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	24(%rsp), %r12
	movq	%r12, %rdx
	movq	48(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 304(%rsp)
	movq	%rdx, 368(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	16(%rsp), %r13
	movq	%r13, %rdx
	movq	8(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 56(%rsp)
	movq	%rdx, 120(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	440(%rsp), %rdx
	movq	448(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbp
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	304(%rsp), %rbx
	movq	%rbx, %rdx
	movq	368(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	56(%rsp), %rdx
	movq	120(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 296(%rsp)
	movq	%rdx, 360(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	32(%rsp), %r13
	movq	%r13, %rdx
	movq	128(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 448(%rsp)
	movq	%rdx, 440(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	264(%rsp), %rbp
	movq	%rbp, %rdx
	movq	312(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 304(%rsp)
	movq	%rdx, 368(%rsp)
	movq	296(%rsp), %r14
	movq	%r14, %rdi
	movq	360(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	304(%rsp), %rdi
	movq	368(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 432(%rsp)
	movq	%rdx, 424(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 304(%rsp)
	movq	%rdx, %r14
	movq	56(%rsp), %r12
	movq	%r12, %rdi
	movq	120(%rsp), %r13
	movq	%r13, %rsi
	movq	32(%rsp), %rdx
	movq	128(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	304(%rsp), %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 304(%rsp)
	movq	%rdx, 368(%rsp)
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 56(%rsp)
	movq	%rdx, 120(%rsp)
	movq	24(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	32(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	16(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	448(%rsp), %rdi
	movq	440(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	432(%rsp), %rdi
	movq	424(%rsp), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	40(%rsp), %rax
	movq	1424(%rax), %r14
	movq	1432(%rax), %r15
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, 32(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	304(%rsp), %rdi
	movq	368(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 16(%rsp)
	movq	56(%rsp), %rdi
	movq	120(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	64(%rsp), %rdi
	movq	72(%rsp), %rsi
	movq	%r13, %rdx
	movq	32(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 64(%rsp)
	movq	%rdx, 72(%rsp)
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	576(%rsp), %rdi
	movq	568(%rsp), %rsi
	movq	%rbp, %rdx
	movq	16(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 576(%rsp)
	movq	%rdx, 568(%rsp)
	movq	464(%rsp), %rdi
	movq	456(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 464(%rsp)
	movq	%rdx, 456(%rsp)
	movq	40(%rsp), %r14
	movq	1440(%r14), %rcx
	movq	%rcx, 32(%rsp)
	movq	1448(%r14), %rcx
	movq	%rcx, 56(%rsp)
	movq	208(%rsp), %rbx
	movq	160(%rbx), %r15
	movq	560(%rsp), %rdi
	movq	720(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	1032(%rsp), %rdi
	movq	1024(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	32(%rsp), %rdi
	movq	56(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 128(%rsp)
	movq	1456(%r14), %rdi
	movq	1464(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 56(%rsp)
	movq	%rdx, 120(%rsp)
	movq	1472(%r14), %rax
	movq	%rax, 32(%rsp)
	movq	1480(%r14), %rax
	movq	%rax, 8(%rsp)
	movq	168(%rbx), %r15
	movq	1016(%rsp), %rdi
	movq	1008(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	1120(%rsp), %rdi
	movq	1112(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	32(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 32(%rsp)
	movq	%rdx, 48(%rsp)
	movq	1488(%r14), %rdi
	movq	1496(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 264(%rsp)
	movq	%rdx, 312(%rsp)
	movq	88(%rsp), %rax
	movq	1664(%rax), %r14
	movq	1672(%rax), %rbp
	movq	1680(%rax), %rdi
	movq	1688(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 440(%rsp)
	movq	%rdx, %r13
	movq	%rdx, 448(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	16(%rsp), %r12
	movq	%r12, %rdx
	movq	128(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 560(%rsp)
	movq	%rdx, 720(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	56(%rsp), %r13
	movq	%r13, %rdx
	movq	120(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	440(%rsp), %rdx
	movq	448(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbp
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	560(%rsp), %rbx
	movq	%rbx, %rdx
	movq	720(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	8(%rsp), %rdx
	movq	24(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 1016(%rsp)
	movq	%rdx, 1008(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	32(%rsp), %r13
	movq	%r13, %rdx
	movq	48(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 448(%rsp)
	movq	%rdx, 440(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	264(%rsp), %rbp
	movq	%rbp, %rdx
	movq	312(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 560(%rsp)
	movq	%rdx, 720(%rsp)
	movq	1016(%rsp), %r14
	movq	%r14, %rdi
	movq	1008(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	560(%rsp), %rdi
	movq	720(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 1032(%rsp)
	movq	%rdx, 1024(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 560(%rsp)
	movq	%rdx, %r14
	movq	8(%rsp), %r12
	movq	%r12, %rdi
	movq	24(%rsp), %r13
	movq	%r13, %rsi
	movq	32(%rsp), %rdx
	movq	48(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	560(%rsp), %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 560(%rsp)
	movq	%rdx, 720(%rsp)
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	16(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	32(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	56(%rsp), %rdi
	movq	120(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	448(%rsp), %rdi
	movq	440(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	1032(%rsp), %rdi
	movq	1024(%rsp), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	40(%rsp), %rax
	movq	1504(%rax), %r14
	movq	1512(%rax), %r15
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, 32(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	560(%rsp), %rdi
	movq	720(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 56(%rsp)
	movq	8(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	64(%rsp), %rdi
	movq	72(%rsp), %rsi
	movq	%r13, %rdx
	movq	32(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 64(%rsp)
	movq	%rdx, 72(%rsp)
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	576(%rsp), %rdi
	movq	568(%rsp), %rsi
	movq	%rbp, %rdx
	movq	56(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 576(%rsp)
	movq	%rdx, 568(%rsp)
	movq	464(%rsp), %rdi
	movq	456(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 464(%rsp)
	movq	%rdx, 456(%rsp)
	movq	40(%rsp), %r14
	movq	1520(%r14), %rcx
	movq	%rcx, 32(%rsp)
	movq	1528(%r14), %rcx
	movq	%rcx, 56(%rsp)
	movq	208(%rsp), %rbx
	movq	176(%rbx), %r15
	movq	864(%rsp), %rdi
	movq	856(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	736(%rsp), %rdi
	movq	728(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	32(%rsp), %rdi
	movq	56(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 128(%rsp)
	movq	1536(%r14), %rdi
	movq	1544(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 56(%rsp)
	movq	%rdx, 120(%rsp)
	movq	1552(%r14), %rax
	movq	%rax, 32(%rsp)
	movq	1560(%r14), %rax
	movq	%rax, 8(%rsp)
	movq	184(%rbx), %r15
	movq	472(%rsp), %rdi
	movq	584(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	1048(%rsp), %rdi
	movq	1040(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	32(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 32(%rsp)
	movq	%rdx, 48(%rsp)
	movq	1568(%r14), %rdi
	movq	1576(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 864(%rsp)
	movq	%rdx, 856(%rsp)
	movq	88(%rsp), %rax
	movq	1696(%rax), %r14
	movq	1704(%rax), %rbp
	movq	1712(%rax), %rdi
	movq	1720(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 728(%rsp)
	movq	%rdx, %r13
	movq	%rdx, 736(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	16(%rsp), %r12
	movq	%r12, %rdx
	movq	128(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 472(%rsp)
	movq	%rdx, 584(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	56(%rsp), %r13
	movq	%r13, %rdx
	movq	120(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	728(%rsp), %rdx
	movq	736(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbp
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	472(%rsp), %rbx
	movq	%rbx, %rdx
	movq	584(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	8(%rsp), %rdx
	movq	24(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 264(%rsp)
	movq	%rdx, 312(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	32(%rsp), %r13
	movq	%r13, %rdx
	movq	48(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 736(%rsp)
	movq	%rdx, 728(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	864(%rsp), %rbp
	movq	%rbp, %rdx
	movq	856(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 472(%rsp)
	movq	%rdx, 584(%rsp)
	movq	264(%rsp), %r14
	movq	%r14, %rdi
	movq	312(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	472(%rsp), %rdi
	movq	584(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 1048(%rsp)
	movq	%rdx, 1040(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 472(%rsp)
	movq	%rdx, %r14
	movq	8(%rsp), %r12
	movq	%r12, %rdi
	movq	24(%rsp), %r13
	movq	%r13, %rsi
	movq	32(%rsp), %rdx
	movq	48(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	472(%rsp), %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 472(%rsp)
	movq	%rdx, 584(%rsp)
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	16(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	32(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	56(%rsp), %rdi
	movq	120(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	736(%rsp), %rdi
	movq	728(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	1048(%rsp), %rdi
	movq	1040(%rsp), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	40(%rsp), %rax
	movq	1584(%rax), %r14
	movq	1592(%rax), %r15
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, 32(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	472(%rsp), %rdi
	movq	584(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 56(%rsp)
	movq	8(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	64(%rsp), %rdi
	movq	72(%rsp), %rsi
	movq	%r13, %rdx
	movq	32(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 64(%rsp)
	movq	%rdx, 72(%rsp)
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	576(%rsp), %rdi
	movq	568(%rsp), %rsi
	movq	%rbp, %rdx
	movq	56(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 864(%rsp)
	movq	%rdx, 856(%rsp)
	movq	464(%rsp), %rdi
	movq	456(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 736(%rsp)
	movq	%rdx, 728(%rsp)
	movq	40(%rsp), %r14
	movq	1600(%r14), %rcx
	movq	%rcx, 32(%rsp)
	movq	1608(%r14), %rcx
	movq	%rcx, 56(%rsp)
	movq	208(%rsp), %rbx
	movq	192(%rbx), %r15
	movq	880(%rsp), %rdi
	movq	872(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	752(%rsp), %rdi
	movq	744(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	32(%rsp), %rdi
	movq	56(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 128(%rsp)
	movq	1616(%r14), %rdi
	movq	1624(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 56(%rsp)
	movq	%rdx, 120(%rsp)
	movq	1632(%r14), %rax
	movq	%rax, 32(%rsp)
	movq	1640(%r14), %rax
	movq	%rax, 8(%rsp)
	movq	200(%rbx), %r15
	movq	480(%rsp), %rdi
	movq	592(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	1064(%rsp), %rdi
	movq	1056(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	32(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 32(%rsp)
	movq	%rdx, 48(%rsp)
	movq	1648(%r14), %rdi
	movq	1656(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 880(%rsp)
	movq	%rdx, 872(%rsp)
	movq	88(%rsp), %rax
	movq	1728(%rax), %r14
	movq	1736(%rax), %rbp
	movq	1744(%rax), %rdi
	movq	1752(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 744(%rsp)
	movq	%rdx, %r13
	movq	%rdx, 752(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	16(%rsp), %r12
	movq	%r12, %rdx
	movq	128(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 480(%rsp)
	movq	%rdx, 592(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	56(%rsp), %r13
	movq	%r13, %rdx
	movq	120(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	744(%rsp), %rdx
	movq	752(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbp
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	480(%rsp), %rbx
	movq	%rbx, %rdx
	movq	592(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	8(%rsp), %rdx
	movq	24(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 472(%rsp)
	movq	%rdx, 584(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	32(%rsp), %r13
	movq	%r13, %rdx
	movq	48(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 752(%rsp)
	movq	%rdx, 744(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	880(%rsp), %rbp
	movq	%rbp, %rdx
	movq	872(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 480(%rsp)
	movq	%rdx, 592(%rsp)
	movq	472(%rsp), %r14
	movq	%r14, %rdi
	movq	584(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	480(%rsp), %rdi
	movq	592(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 1064(%rsp)
	movq	%rdx, 1056(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 480(%rsp)
	movq	%rdx, %r14
	movq	8(%rsp), %r12
	movq	%r12, %rdi
	movq	24(%rsp), %r13
	movq	%r13, %rsi
	movq	32(%rsp), %rdx
	movq	48(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	480(%rsp), %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 480(%rsp)
	movq	%rdx, 592(%rsp)
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	16(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	32(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	56(%rsp), %rdi
	movq	120(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	752(%rsp), %rdi
	movq	744(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	1064(%rsp), %rdi
	movq	1056(%rsp), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	40(%rsp), %rax
	movq	1664(%rax), %r14
	movq	1672(%rax), %r15
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, 32(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	480(%rsp), %rdi
	movq	592(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 56(%rsp)
	movq	8(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	64(%rsp), %rdi
	movq	72(%rsp), %rsi
	movq	%r13, %rdx
	movq	32(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 64(%rsp)
	movq	%rdx, 72(%rsp)
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	864(%rsp), %rdi
	movq	856(%rsp), %rsi
	movq	%rbp, %rdx
	movq	56(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 880(%rsp)
	movq	%rdx, 872(%rsp)
	movq	736(%rsp), %rdi
	movq	728(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 752(%rsp)
	movq	%rdx, 744(%rsp)
	movq	40(%rsp), %r14
	movq	1680(%r14), %rcx
	movq	%rcx, 32(%rsp)
	movq	1688(%r14), %rcx
	movq	%rcx, 56(%rsp)
	movq	208(%rsp), %rbx
	movq	208(%rbx), %r15
	movq	152(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	136(%rsp), %rdi
	movq	760(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	32(%rsp), %rdi
	movq	56(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 128(%rsp)
	movq	1696(%r14), %rdi
	movq	1704(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 56(%rsp)
	movq	%rdx, 120(%rsp)
	movq	1712(%r14), %rax
	movq	%rax, 32(%rsp)
	movq	1720(%r14), %rax
	movq	%rax, 8(%rsp)
	movq	216(%rbx), %r15
	movq	376(%rsp), %rdi
	movq	488(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	888(%rsp), %rdi
	movq	1072(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	32(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 32(%rsp)
	movq	%rdx, 48(%rsp)
	movq	1728(%r14), %rdi
	movq	1736(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 152(%rsp)
	movq	%rdx, 144(%rsp)
	movq	88(%rsp), %rax
	movq	1760(%rax), %r14
	movq	1768(%rax), %rbp
	movq	1776(%rax), %rdi
	movq	1784(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 760(%rsp)
	movq	%rdx, %r13
	movq	%rdx, 136(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	16(%rsp), %r12
	movq	%r12, %rdx
	movq	128(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 376(%rsp)
	movq	%rdx, 488(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	56(%rsp), %r13
	movq	%r13, %rdx
	movq	120(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	760(%rsp), %rdx
	movq	136(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbp
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	376(%rsp), %rbx
	movq	%rbx, %rdx
	movq	488(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	8(%rsp), %rdx
	movq	24(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 480(%rsp)
	movq	%rdx, 592(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	32(%rsp), %r13
	movq	%r13, %rdx
	movq	48(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 136(%rsp)
	movq	%rdx, 760(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	152(%rsp), %rbp
	movq	%rbp, %rdx
	movq	144(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 376(%rsp)
	movq	%rdx, 488(%rsp)
	movq	480(%rsp), %r14
	movq	%r14, %rdi
	movq	592(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	376(%rsp), %rdi
	movq	488(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 888(%rsp)
	movq	%rdx, 1072(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 376(%rsp)
	movq	%rdx, %r14
	movq	8(%rsp), %r12
	movq	%r12, %rdi
	movq	24(%rsp), %r13
	movq	%r13, %rsi
	movq	32(%rsp), %rdx
	movq	48(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	376(%rsp), %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 376(%rsp)
	movq	%rdx, 488(%rsp)
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	16(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	32(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	56(%rsp), %rdi
	movq	120(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	136(%rsp), %rdi
	movq	760(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	888(%rsp), %rdi
	movq	1072(%rsp), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	40(%rsp), %rax
	movq	1744(%rax), %r14
	movq	1752(%rax), %r15
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, 32(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	376(%rsp), %rdi
	movq	488(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 56(%rsp)
	movq	8(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	64(%rsp), %rdi
	movq	72(%rsp), %rsi
	movq	%r13, %rdx
	movq	32(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 64(%rsp)
	movq	%rdx, 72(%rsp)
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	880(%rsp), %rdi
	movq	872(%rsp), %rsi
	movq	%rbp, %rdx
	movq	56(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 152(%rsp)
	movq	%rdx, 144(%rsp)
	movq	752(%rsp), %rdi
	movq	744(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 136(%rsp)
	movq	%rdx, 760(%rsp)
	movq	40(%rsp), %r14
	movq	1760(%r14), %rcx
	movq	%rcx, 32(%rsp)
	movq	1768(%r14), %rcx
	movq	%rcx, 56(%rsp)
	movq	208(%rsp), %rbx
	movq	224(%rbx), %r15
	movq	776(%rsp), %rdi
	movq	768(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	504(%rsp), %rdi
	movq	496(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	32(%rsp), %rdi
	movq	56(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 128(%rsp)
	movq	1776(%r14), %rdi
	movq	1784(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 56(%rsp)
	movq	%rdx, 120(%rsp)
	movq	1792(%r14), %rax
	movq	%rax, 32(%rsp)
	movq	1800(%r14), %rax
	movq	%rax, 8(%rsp)
	movq	232(%rbx), %r15
	movq	232(%rsp), %rdi
	movq	320(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	936(%rsp), %rdi
	movq	928(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	32(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 32(%rsp)
	movq	%rdx, 48(%rsp)
	movq	1808(%r14), %rdi
	movq	1816(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 776(%rsp)
	movq	%rdx, 768(%rsp)
	movq	88(%rsp), %rax
	movq	1792(%rax), %r14
	movq	1800(%rax), %rbp
	movq	1808(%rax), %rdi
	movq	1816(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 496(%rsp)
	movq	%rdx, %r13
	movq	%rdx, 504(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	16(%rsp), %r12
	movq	%r12, %rdx
	movq	128(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 232(%rsp)
	movq	%rdx, 320(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	56(%rsp), %r13
	movq	%r13, %rdx
	movq	120(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	496(%rsp), %rdx
	movq	504(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbp
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	232(%rsp), %rbx
	movq	%rbx, %rdx
	movq	320(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	8(%rsp), %rdx
	movq	24(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 376(%rsp)
	movq	%rdx, 488(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	32(%rsp), %r13
	movq	%r13, %rdx
	movq	48(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 504(%rsp)
	movq	%rdx, 496(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	776(%rsp), %rbp
	movq	%rbp, %rdx
	movq	768(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 232(%rsp)
	movq	%rdx, 320(%rsp)
	movq	376(%rsp), %r14
	movq	%r14, %rdi
	movq	488(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	232(%rsp), %rdi
	movq	320(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 936(%rsp)
	movq	%rdx, 928(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 232(%rsp)
	movq	%rdx, %r14
	movq	8(%rsp), %r12
	movq	%r12, %rdi
	movq	24(%rsp), %r13
	movq	%r13, %rsi
	movq	32(%rsp), %rdx
	movq	48(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	232(%rsp), %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 232(%rsp)
	movq	%rdx, 320(%rsp)
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	16(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	32(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	56(%rsp), %rdi
	movq	120(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	504(%rsp), %rdi
	movq	496(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	936(%rsp), %rdi
	movq	928(%rsp), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	40(%rsp), %rax
	movq	1824(%rax), %r14
	movq	1832(%rax), %r15
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, 32(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	232(%rsp), %rdi
	movq	320(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 56(%rsp)
	movq	8(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	64(%rsp), %rdi
	movq	72(%rsp), %rsi
	movq	%r13, %rdx
	movq	32(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 64(%rsp)
	movq	%rdx, 72(%rsp)
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	152(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%rbp, %rdx
	movq	56(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 776(%rsp)
	movq	%rdx, 768(%rsp)
	movq	136(%rsp), %rdi
	movq	760(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 504(%rsp)
	movq	%rdx, 496(%rsp)
	movq	40(%rsp), %r14
	movq	1840(%r14), %rcx
	movq	%rcx, 32(%rsp)
	movq	1848(%r14), %rcx
	movq	%rcx, 56(%rsp)
	movq	208(%rsp), %rbx
	movq	240(%rbx), %r15
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	176(%rsp), %rdi
	movq	616(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	32(%rsp), %rdi
	movq	56(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 128(%rsp)
	movq	1856(%r14), %rdi
	movq	1864(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 56(%rsp)
	movq	%rdx, 120(%rsp)
	movq	1872(%r14), %rax
	movq	%rax, 32(%rsp)
	movq	1880(%r14), %rax
	movq	%rax, 8(%rsp)
	movq	248(%rbx), %r15
	movq	328(%rsp), %rdi
	movq	512(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	784(%rsp), %rdi
	movq	944(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	32(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 32(%rsp)
	movq	%rdx, 48(%rsp)
	movq	1888(%r14), %rdi
	movq	1896(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	88(%rsp), %rax
	movq	1824(%rax), %r14
	movq	1832(%rax), %rbp
	movq	1840(%rax), %rdi
	movq	1848(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 616(%rsp)
	movq	%rdx, %r13
	movq	%rdx, 176(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	16(%rsp), %r12
	movq	%r12, %rdx
	movq	128(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 328(%rsp)
	movq	%rdx, 512(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	56(%rsp), %r13
	movq	%r13, %rdx
	movq	120(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	616(%rsp), %rdx
	movq	176(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbp
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	328(%rsp), %rbx
	movq	%rbx, %rdx
	movq	512(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	8(%rsp), %rdx
	movq	24(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 232(%rsp)
	movq	%rdx, 320(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	32(%rsp), %r13
	movq	%r13, %rdx
	movq	48(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 176(%rsp)
	movq	%rdx, 616(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	192(%rsp), %rbp
	movq	%rbp, %rdx
	movq	184(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 328(%rsp)
	movq	%rdx, 512(%rsp)
	movq	232(%rsp), %r14
	movq	%r14, %rdi
	movq	320(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	328(%rsp), %rdi
	movq	512(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 784(%rsp)
	movq	%rdx, 944(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 328(%rsp)
	movq	%rdx, %r14
	movq	8(%rsp), %r12
	movq	%r12, %rdi
	movq	24(%rsp), %r13
	movq	%r13, %rsi
	movq	32(%rsp), %rdx
	movq	48(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	328(%rsp), %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 328(%rsp)
	movq	%rdx, 512(%rsp)
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	16(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	32(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	56(%rsp), %rdi
	movq	120(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	176(%rsp), %rdi
	movq	616(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	784(%rsp), %rdi
	movq	944(%rsp), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	40(%rsp), %rax
	movq	1904(%rax), %r14
	movq	1912(%rax), %r15
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, 32(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	328(%rsp), %rdi
	movq	512(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 56(%rsp)
	movq	8(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	64(%rsp), %rdi
	movq	72(%rsp), %rsi
	movq	%r13, %rdx
	movq	32(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 176(%rsp)
	movq	%rdx, 616(%rsp)
	movq	776(%rsp), %rdi
	movq	768(%rsp), %rsi
	movq	%rbp, %rdx
	movq	56(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 328(%rsp)
	movq	%rdx, 512(%rsp)
	movq	504(%rsp), %rdi
	movq	496(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 784(%rsp)
	movq	%rdx, 944(%rsp)
	movq	40(%rsp), %rax
	movq	1920(%rax), %rcx
	movq	%rcx, 32(%rsp)
	movq	1928(%rax), %rax
	movq	%rax, 128(%rsp)
	movq	88(%rsp), %rax
	movq	1248(%rax), %r12
	movq	%r12, 120(%rsp)
	movq	1256(%rax), %r13
	movq	%r13, 16(%rsp)
	movq	1264(%rax), %rdi
	movq	1272(%rax), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbp
	movq	%rax, 56(%rsp)
	movq	%rdx, %r14
	movq	208(%rsp), %rbx
	movq	256(%rbx), %r15
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%r14, 112(%rsp)
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	32(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 24(%rsp)
	movq	%rdx, 48(%rsp)
	movq	40(%rsp), %r12
	movq	1936(%r12), %rdi
	movq	1944(%r12), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 128(%rsp)
	movq	%rdx, 8(%rsp)
	movq	1952(%r12), %rax
	movq	%rax, 32(%rsp)
	movq	1960(%r12), %rax
	movq	%rax, 64(%rsp)
	movq	264(%rbx), %r15
	movq	120(%rsp), %rdi
	movq	16(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	56(%rsp), %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	32(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 32(%rsp)
	movq	%rdx, 96(%rsp)
	movq	40(%rsp), %rax
	movq	1968(%rax), %rdi
	movq	1976(%rax), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 776(%rsp)
	movq	%rdx, 768(%rsp)
	movq	88(%rsp), %rax
	movq	1856(%rax), %r14
	movq	1864(%rax), %rbp
	movq	1872(%rax), %rdi
	movq	1880(%rax), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 496(%rsp)
	movq	%rdx, %r13
	movq	%rdx, 504(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	24(%rsp), %r12
	movq	%r12, %rdx
	movq	48(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 232(%rsp)
	movq	%rdx, 320(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	128(%rsp), %r13
	movq	%r13, %rdx
	movq	8(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 64(%rsp)
	movq	%rdx, 72(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	496(%rsp), %rdx
	movq	504(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbp
	movq	%rdx, %r14
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	232(%rsp), %rbx
	movq	%rbx, %rdx
	movq	320(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	64(%rsp), %rdx
	movq	72(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 152(%rsp)
	movq	%rdx, 144(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	32(%rsp), %r13
	movq	%r13, %rdx
	movq	96(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 504(%rsp)
	movq	%rdx, 496(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	776(%rsp), %rbp
	movq	%rbp, %rdx
	movq	768(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 232(%rsp)
	movq	%rdx, 320(%rsp)
	movq	152(%rsp), %r14
	movq	%r14, %rdi
	movq	144(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	232(%rsp), %rdi
	movq	320(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 936(%rsp)
	movq	%rdx, 928(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 232(%rsp)
	movq	%rdx, %r14
	movq	64(%rsp), %r12
	movq	%r12, %rdi
	movq	72(%rsp), %r13
	movq	%r13, %rsi
	movq	32(%rsp), %rdx
	movq	96(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	232(%rsp), %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 232(%rsp)
	movq	%rdx, 320(%rsp)
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 64(%rsp)
	movq	%rdx, 72(%rsp)
	movq	24(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	32(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	128(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	504(%rsp), %rdi
	movq	496(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	936(%rsp), %rdi
	movq	928(%rsp), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	40(%rsp), %rax
	movq	1984(%rax), %r14
	movq	1992(%rax), %r15
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, 32(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	232(%rsp), %rdi
	movq	320(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 8(%rsp)
	movq	64(%rsp), %rdi
	movq	72(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%r13, %rdx
	movq	32(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, 72(%rsp)
	movq	176(%rsp), %rdi
	movq	616(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 32(%rsp)
	movq	%rdx, 128(%rsp)
	movq	328(%rsp), %rdi
	movq	512(%rsp), %rsi
	movq	%rbp, %rdx
	movq	8(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 48(%rsp)
	movq	%rdx, 64(%rsp)
	movq	784(%rsp), %rdi
	movq	944(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	88(%rsp), %rax
	movq	(%rax), %rbp
	movq	8(%rax), %r12
	movq	16(%rax), %rdi
	movq	24(%rax), %rsi
	movq	%rbp, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 176(%rsp)
	movq	%rdx, 616(%rsp)
	movq	%r13, %rdi
	movq	72(%rsp), %rsi
	movq	920(%rsp), %rdx
	movq	912(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rax, 72(%rsp)
	movq	%rdx, %rbx
	movq	%rdx, 96(%rsp)
	movq	32(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	904(%rsp), %rdx
	movq	896(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r14
	movq	%rax, 192(%rsp)
	movq	%rdx, %r15
	movq	%rdx, 184(%rsp)
	movq	48(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	608(%rsp), %rdx
	movq	600(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 32(%rsp)
	movq	%rdx, 128(%rsp)
	movq	%rbp, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 48(%rsp)
	movq	%rdx, 64(%rsp)
	movq	%rbp, %rdi
	movq	%rbp, 328(%rsp)
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	176(%rsp), %r13
	movq	%r13, %rdi
	movq	616(%rsp), %rbx
	movq	%rbx, %rsi
	movq	72(%rsp), %rdx
	movq	96(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 72(%rsp)
	movq	%rdx, 96(%rsp)
	movq	%rbp, %rdi
	movq	%r12, %rsi
	movq	32(%rsp), %rdx
	movq	128(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	%r13, %rdi
	movq	%rbx, %rbp
	movq	%rbx, %rsi
	movq	192(%rsp), %rdx
	movq	184(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	328(%rsp), %rdi
	movq	%r12, %rsi
	movq	8(%rsp), %r15
	movq	%r15, %rdx
	movq	24(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	32(%rsp), %rdx
	movq	128(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 32(%rsp)
	movq	%rdx, 128(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	208(%rsp), %rax
	movq	272(%rax), %rbx
	movq	952(%rsp), %rdi
	movq	1088(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	624(%rsp), %rdi
	movq	1080(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	104(%rsp), %rdx
	movq	160(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	80(%rsp), %rdx
	movq	168(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 168(%rsp)
	movq	%rdx, 952(%rsp)
	movq	40(%rsp), %rax
	movq	2000(%rax), %rdx
	movq	2008(%rax), %rcx
	movq	%r14, %rdi
	movq	%r15, %rsi
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 1088(%rsp)
	movq	%rdx, %r15
	movq	%rdx, 1080(%rsp)
	movq	88(%rsp), %rax
	movq	32(%rax), %r14
	movq	40(%rax), %r12
	movq	48(%rax), %rdi
	movq	56(%rax), %rsi
	movq	%r14, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 624(%rsp)
	movq	%rdx, 160(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	168(%rsp), %rbx
	movq	%rbx, %rdx
	movq	952(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 80(%rsp)
	movq	%rdx, 104(%rsp)
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r14
	movq	%rdx, %r12
	movq	1088(%rsp), %rdi
	movq	1080(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	624(%rsp), %rbx
	movq	%rbx, %rdx
	movq	160(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	80(%rsp), %r13
	movq	%r13, %rdx
	movq	104(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 168(%rsp)
	movq	%rdx, 952(%rsp)
	movq	40(%rsp), %rax
	movq	2016(%rax), %r15
	movq	2024(%rax), %r12
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 624(%rsp)
	movq	%rdx, 160(%rsp)
	movq	168(%rsp), %rdi
	movq	952(%rsp), %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r15
	movq	%rdx, %r12
	movq	48(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	624(%rsp), %rdx
	movq	160(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 80(%rsp)
	movq	%rdx, 104(%rsp)
	movq	72(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 624(%rsp)
	movq	%rdx, 160(%rsp)
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 48(%rsp)
	movq	%rdx, 64(%rsp)
	movq	208(%rsp), %rax
	movq	280(%rax), %rbx
	movq	1144(%rsp), %rdi
	movq	1136(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	336(%rsp), %rdi
	movq	1128(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	120(%rsp), %rdx
	movq	16(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	56(%rsp), %rdx
	movq	112(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 16(%rsp)
	movq	%rdx, 336(%rsp)
	movq	40(%rsp), %rax
	movq	2032(%rax), %rdx
	movq	2040(%rax), %rcx
	movq	%r14, %rdi
	movq	%r15, %rsi
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 72(%rsp)
	movq	%rdx, %r15
	movq	%rdx, 96(%rsp)
	movq	88(%rsp), %rax
	movq	64(%rax), %r14
	movq	72(%rax), %r12
	movq	80(%rax), %rdi
	movq	88(%rax), %rsi
	movq	%r14, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 56(%rsp)
	movq	%rdx, 120(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	16(%rsp), %rbx
	movq	%rbx, %rdx
	movq	336(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 88(%rsp)
	movq	%rdx, 208(%rsp)
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r14
	movq	%rdx, %r12
	movq	72(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	56(%rsp), %rbx
	movq	%rbx, %rdx
	movq	120(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	88(%rsp), %r13
	movq	%r13, %rdx
	movq	208(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 336(%rsp)
	movq	40(%rsp), %rax
	movq	2048(%rax), %r15
	movq	2056(%rax), %r12
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 40(%rsp)
	movq	%rdx, 56(%rsp)
	movq	16(%rsp), %rdi
	movq	336(%rsp), %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r15
	movq	%rdx, %r12
	movq	80(%rsp), %rdi
	movq	104(%rsp), %rsi
	movq	40(%rsp), %rdx
	movq	56(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	624(%rsp), %rdi
	movq	160(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	48(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	1152(%rsp), %rcx
	movq	%r13, (%rcx)
	movq	%rbp, 8(%rcx)
	movq	%rbx, 16(%rcx)
	movq	%r14, 24(%rcx)
	movq	%rax, 32(%rcx)
	movq	%rdx, 40(%rcx)
	movq	32(%rsp), %rax
	movq	%rax, 48(%rcx)
	movq	128(%rsp), %rax
	movq	%rax, 56(%rcx)
	movq	8(%rsp), %rax
	movq	%rax, 64(%rcx)
	movq	24(%rsp), %rax
	movq	%rax, 72(%rcx)
	addq	$1160, %rsp
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
.Lfunc_end4:
	.size	baseline, .Lfunc_end4-baseline
	.cfi_endproc

	.section	.text.driven,"ax",@progbits
	.globl	driven
	.p2align	4
	.type	driven,@function
driven:
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
	subq	$360, %rsp
	.cfi_def_cfa_offset 416
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%rcx, 352(%rsp)
	movq	%rdx, 296(%rsp)
	movq	%rdi, %rbx
	movq	%rdi, 120(%rsp)
	movq	(%rsi), %rax
	movq	%rax, 208(%rsp)
	movq	8(%rsi), %rax
	movq	%rax, 80(%rsp)
	movq	16(%rsi), %rax
	movq	%rax, 8(%rsp)
	movq	24(%rsi), %rax
	movq	%rax, 128(%rsp)
	movq	%rsi, %r14
	movq	96(%rdi), %rdx
	movq	%rdx, 24(%rsp)
	movq	104(%rdi), %rcx
	movq	%rcx, 32(%rsp)
	movq	112(%rdi), %rdi
	movq	120(%rbx), %rsi
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 152(%rsp)
	movq	%rdx, 176(%rsp)
	movq	160(%rbx), %r15
	movq	%r15, 216(%rsp)
	movq	168(%rbx), %rbp
	movq	176(%rbx), %rdi
	movq	184(%rbx), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	movq	%rbp, 136(%rsp)
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, 168(%rsp)
	movq	%r14, 56(%rsp)
	movq	32(%r14), %rbx
	movq	40(%r14), %r12
	movq	%r15, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	%r13, %rdi
	movq	%r13, %rbp
	movq	168(%rsp), %r13
	movq	%r13, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	208(%rsp), %rdi
	movq	80(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 208(%rsp)
	movq	%rdx, 80(%rsp)
	movq	8(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 128(%rsp)
	movq	%rdx, 40(%rsp)
	movq	24(%rsp), %rbx
	movq	%rbx, %rdi
	movq	32(%rsp), %r14
	movq	%r14, %rsi
	movq	216(%rsp), %rdx
	movq	136(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	152(%rsp), %r15
	movq	%r15, %rdi
	movq	176(%rsp), %r12
	movq	%r12, %rsi
	movq	%rbp, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 64(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	216(%rsp), %rdi
	movq	136(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	96(%rsp), %rbp
	movq	%rbp, %rdx
	movq	112(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	8(%rsp), %rdx
	movq	64(%rsp), %r13
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 216(%rsp)
	movq	%rdx, %r14
	movq	56(%rsp), %rax
	movq	48(%rax), %r15
	movq	56(%rax), %r12
	movq	%rbp, %rdi
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 136(%rsp)
	movq	%rdx, %rbp
	movq	216(%rsp), %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	8(%rsp), %rdi
	movq	%r13, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 152(%rsp)
	movq	%rdx, 176(%rsp)
	movq	208(%rsp), %rdi
	movq	80(%rsp), %rsi
	movq	136(%rsp), %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 136(%rsp)
	movq	%rdx, 216(%rsp)
	movq	128(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 208(%rsp)
	movq	%rdx, 40(%rsp)
	movq	120(%rsp), %rax
	movq	1280(%rax), %rbx
	movq	%rbx, 80(%rsp)
	movq	1288(%rax), %r15
	movq	%r15, 8(%rsp)
	movq	1296(%rax), %rdi
	movq	1304(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rax, 96(%rsp)
	movq	%rdx, %r13
	movq	56(%rsp), %rax
	movq	64(%rax), %r14
	movq	72(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r15, %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r15
	movq	%rdx, %rbx
	movq	%r12, %rdi
	movq	%r13, %r12
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %rbp
	movq	136(%rsp), %rdi
	movq	216(%rsp), %rsi
	movq	%r15, %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 128(%rsp)
	movq	%rdx, 24(%rsp)
	movq	208(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 32(%rsp)
	movq	%rdx, 64(%rsp)
	movq	120(%rsp), %rax
	movq	256(%rax), %r14
	movq	264(%rax), %r15
	movq	272(%rax), %rdi
	movq	280(%rax), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	80(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r14, 216(%rsp)
	movq	%r15, %rcx
	movq	%r15, 208(%rsp)
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 288(%rsp)
	movq	%rdx, 304(%rsp)
	movq	96(%rsp), %rbx
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%r13, 136(%rsp)
	movq	%rbp, 40(%rsp)
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	80(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	288(%rsp), %rbx
	movq	%rbx, %rdx
	movq	304(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	112(%rsp), %r14
	movq	%r14, %rdx
	movq	168(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 96(%rsp)
	movq	%rdx, 312(%rsp)
	movq	56(%rsp), %rax
	movq	80(%rax), %r12
	movq	88(%rax), %r13
	movq	%rbx, %rdi
	movq	%r15, %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 80(%rsp)
	movq	96(%rsp), %rdi
	movq	312(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	128(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	80(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	32(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 64(%rsp)
	movq	%rdx, 96(%rsp)
	movq	152(%rsp), %rdi
	movq	176(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 176(%rsp)
	movq	%rdx, 128(%rsp)
	movq	120(%rsp), %rbx
	movq	128(%rbx), %rdx
	movq	%rdx, 288(%rsp)
	movq	136(%rbx), %rcx
	movq	%rcx, 304(%rsp)
	movq	144(%rbx), %rdi
	movq	152(%rbx), %rsi
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	672(%rbx), %r14
	movq	%r14, 152(%rsp)
	movq	680(%rbx), %r15
	movq	%r15, 80(%rsp)
	movq	688(%rbx), %rdi
	movq	696(%rbx), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rax, 232(%rsp)
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	96(%rax), %rbx
	movq	104(%rax), %r12
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	%r13, %rdi
	movq	%rbp, %r13
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	8(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	64(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 64(%rsp)
	movq	%rdx, 96(%rsp)
	movq	288(%rsp), %rbx
	movq	%rbx, %rdi
	movq	304(%rsp), %r14
	movq	%r14, %rsi
	movq	152(%rsp), %rdx
	movq	80(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	112(%rsp), %r15
	movq	%r15, %rdi
	movq	168(%rsp), %r12
	movq	%r12, %rsi
	movq	232(%rsp), %rbp
	movq	%rbp, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 312(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	152(%rsp), %rdi
	movq	80(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	240(%rsp), %rbp
	movq	%rbp, %rdx
	movq	280(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	8(%rsp), %rdx
	movq	312(%rsp), %r13
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 152(%rsp)
	movq	%rdx, %r14
	movq	56(%rsp), %rax
	movq	112(%rax), %r15
	movq	120(%rax), %r12
	movq	%rbp, %rdi
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 80(%rsp)
	movq	%rdx, %rbp
	movq	152(%rsp), %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	8(%rsp), %rdi
	movq	%r13, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r15
	movq	%rdx, %r12
	movq	24(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	80(%rsp), %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 80(%rsp)
	movq	%rdx, 152(%rsp)
	movq	64(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 168(%rsp)
	movq	%rdx, 288(%rsp)
	movq	176(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 32(%rsp)
	movq	%rdx, 64(%rsp)
	movq	120(%rsp), %rax
	movq	1312(%rax), %rbx
	movq	%rbx, 24(%rsp)
	movq	1320(%rax), %r15
	movq	%r15, 8(%rsp)
	movq	1328(%rax), %rdi
	movq	1336(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rax, 304(%rsp)
	movq	%rdx, %r13
	movq	56(%rsp), %rax
	movq	128(%rax), %r14
	movq	136(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r15, %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r15
	movq	%rdx, %rbx
	movq	%r12, %rdi
	movq	%r13, %r12
	movq	%r13, %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %rbp
	movq	80(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%r15, %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	168(%rsp), %rdi
	movq	288(%rsp), %rsi
	movq	%r14, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 168(%rsp)
	movq	%rdx, 288(%rsp)
	movq	120(%rsp), %rax
	movq	768(%rax), %r14
	movq	776(%rax), %r15
	movq	784(%rax), %rdi
	movq	792(%rax), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	24(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r14, 152(%rsp)
	movq	%r15, %rcx
	movq	%r15, 176(%rsp)
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 280(%rsp)
	movq	%rdx, 232(%rsp)
	movq	304(%rsp), %rbx
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%r13, 80(%rsp)
	movq	%rbp, 128(%rsp)
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 312(%rsp)
	movq	%rdx, 240(%rsp)
	movq	24(%rsp), %rdi
	movq	8(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	280(%rsp), %rbx
	movq	%rbx, %rdx
	movq	232(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	312(%rsp), %r14
	movq	%r14, %rdx
	movq	240(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 304(%rsp)
	movq	%rdx, 272(%rsp)
	movq	56(%rsp), %rax
	movq	144(%rax), %r12
	movq	152(%rax), %r13
	movq	%rbx, %rdi
	movq	%r15, %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	304(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	24(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	168(%rsp), %rdi
	movq	288(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 288(%rsp)
	movq	%rdx, 240(%rsp)
	movq	32(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 304(%rsp)
	movq	%rdx, 312(%rsp)
	movq	56(%rsp), %r14
	movq	160(%r14), %rcx
	movq	%rcx, 200(%rsp)
	movq	168(%r14), %rcx
	movq	%rcx, 224(%rsp)
	movq	176(%r14), %rcx
	movq	%rcx, 24(%rsp)
	movq	184(%r14), %rcx
	movq	%rcx, 32(%rsp)
	movq	120(%rsp), %rax
	movq	192(%rax), %r12
	movq	%r12, 64(%rsp)
	movq	200(%rax), %rbx
	movq	208(%rax), %rdi
	movq	216(%rax), %rsi
	movq	%r12, %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, %r15
	movq	%rdx, 280(%rsp)
	movq	192(%r14), %r13
	movq	200(%r14), %rbp
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r12
	movq	8(%rsp), %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	288(%rsp), %rdi
	movq	240(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 288(%rsp)
	movq	%rdx, 232(%rsp)
	movq	296(%rsp), %rax
	movq	(%rax), %r14
	movq	64(%rsp), %rdi
	movq	%rbx, %rsi
	movq	%r14, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	8(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r14, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r12
	movq	24(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	56(%rsp), %rbx
	movq	208(%rbx), %rdi
	movq	216(%rbx), %rsi
	movq	%r14, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 64(%rsp)
	movq	%rdx, 96(%rsp)
	movq	224(%rbx), %rax
	movq	%rax, 8(%rsp)
	movq	232(%rbx), %rax
	movq	%rax, 192(%rsp)
	movq	120(%rsp), %rax
	movq	224(%rax), %r13
	movq	%r13, 184(%rsp)
	movq	232(%rax), %rbp
	movq	%rbp, 104(%rsp)
	movq	240(%rax), %rdi
	movq	248(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 144(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	240(%rbx), %rbx
	movq	248(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	112(%rsp), %rdi
	movq	168(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	288(%rsp), %rdi
	movq	232(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 232(%rsp)
	movq	%rdx, 272(%rsp)
	movq	296(%rsp), %rax
	movq	8(%rax), %rbx
	movq	184(%rsp), %rdi
	movq	104(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	144(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	8(%rsp), %rdi
	movq	192(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 288(%rsp)
	movq	56(%rsp), %rax
	movq	256(%rax), %rdi
	movq	264(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	120(%rsp), %rax
	movq	1344(%rax), %rbx
	movq	1352(%rax), %r13
	movq	1360(%rax), %rdi
	movq	1368(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 144(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 104(%rsp)
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	24(%rsp), %rbp
	movq	%rbp, %rdx
	movq	32(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	64(%rsp), %r14
	movq	%r14, %rdx
	movq	96(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	144(%rsp), %rdx
	movq	104(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	%rbp, %rdi
	movq	%r15, %rsi
	movq	%r14, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbx, %rdi
	movq	%r13, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	72(%rsp), %rbx
	movq	%rbx, %rdx
	movq	88(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	112(%rsp), %rdx
	movq	168(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 256(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %rbp
	movq	%rbp, %rdx
	movq	288(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	192(%rsp), %r15
	movq	%r15, %rdx
	movq	184(%rsp), %r13
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	16(%rsp), %r14
	movq	%r14, %rdi
	movq	256(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 48(%rsp)
	movq	%rdx, 264(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, %r12
	movq	112(%rsp), %r14
	movq	%r14, %rdi
	movq	168(%rsp), %rbp
	movq	%rbp, %rsi
	movq	8(%rsp), %rdx
	movq	288(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	72(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	%r14, %rdi
	movq	%rbp, %rsi
	movq	%r15, %rdx
	movq	%r13, %rcx
	movq	%r13, %r12
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 112(%rsp)
	movq	%rdx, 16(%rsp)
	movq	24(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	64(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %r15
	movq	48(%rsp), %rdi
	movq	264(%rsp), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	272(%rax), %rbx
	movq	280(%rax), %r14
	movq	%r13, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r15
	movq	%rdx, %r13
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 168(%rsp)
	movq	%rdx, 288(%rsp)
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	112(%rsp), %rdi
	movq	16(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	200(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	%r15, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 112(%rsp)
	movq	%rdx, 200(%rsp)
	movq	56(%rsp), %r14
	movq	288(%r14), %rcx
	movq	%rcx, 8(%rsp)
	movq	296(%r14), %rcx
	movq	%rcx, 24(%rsp)
	movq	296(%rsp), %rbx
	movq	16(%rbx), %r15
	movq	216(%rsp), %rdi
	movq	208(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	136(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 64(%rsp)
	movq	%rdx, 96(%rsp)
	movq	304(%r14), %rdi
	movq	312(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	320(%r14), %rax
	movq	%rax, 8(%rsp)
	movq	328(%r14), %rax
	movq	%rax, 224(%rsp)
	movq	24(%rbx), %r15
	movq	216(%rsp), %rdi
	movq	208(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	136(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 208(%rsp)
	movq	336(%r14), %rdi
	movq	344(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 40(%rsp)
	movq	%rdx, 224(%rsp)
	movq	120(%rsp), %rax
	movq	1376(%rax), %r12
	movq	1384(%rax), %rbp
	movq	1392(%rax), %rdi
	movq	1400(%rax), %rsi
	movq	%r12, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 88(%rsp)
	movq	%rdx, %r14
	movq	%rdx, 72(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	64(%rsp), %r13
	movq	%r13, %rdx
	movq	96(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	24(%rsp), %rbx
	movq	%rbx, %rdx
	movq	32(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 136(%rsp)
	movq	%rdx, 216(%rsp)
	movq	%r12, %rdi
	movq	%rbp, %rsi
	movq	88(%rsp), %rdx
	movq	72(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbp
	movq	%rdx, %r12
	movq	%r13, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbp, %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	16(%rsp), %rbx
	movq	%rbx, %rdx
	movq	48(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	136(%rsp), %rdx
	movq	216(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r12
	movq	%rdx, 160(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %r13
	movq	%r13, %rdx
	movq	208(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	40(%rsp), %rbp
	movq	%rbp, %rdx
	movq	224(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r12, %rdi
	movq	160(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 264(%rsp)
	movq	%rdx, 256(%rsp)
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	%rbp, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	136(%rsp), %r15
	movq	%r15, %rdi
	movq	216(%rsp), %r13
	movq	%r13, %rsi
	movq	8(%rsp), %rdx
	movq	208(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r15, %rdi
	movq	%r13, %rsi
	movq	%rbp, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 136(%rsp)
	movq	%rdx, 216(%rsp)
	movq	64(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	24(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	%rbp, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	352(%rax), %r14
	movq	360(%rax), %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r12
	movq	%rdx, 8(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r13
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbp
	movq	%rdx, 208(%rsp)
	movq	136(%rsp), %rdi
	movq	216(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	112(%rsp), %rdi
	movq	200(%rsp), %rsi
	movq	%r12, %rdx
	movq	8(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	168(%rsp), %rdi
	movq	288(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 168(%rsp)
	movq	%rdx, 288(%rsp)
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%rbp, %rdx
	movq	208(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 200(%rsp)
	movq	%rdx, 224(%rsp)
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	56(%rsp), %rbx
	movq	368(%rbx), %rcx
	movq	%rcx, 136(%rsp)
	movq	376(%rbx), %rcx
	movq	%rcx, 216(%rsp)
	movq	120(%rsp), %rax
	movq	288(%rax), %r13
	movq	%r13, 208(%rsp)
	movq	296(%rax), %rbp
	movq	%rbp, 40(%rsp)
	movq	304(%rax), %rdi
	movq	312(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 104(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	384(%rbx), %rbx
	movq	392(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	240(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 32(%rsp)
	movq	%rdx, 64(%rsp)
	movq	296(%rsp), %rax
	movq	32(%rax), %rbx
	movq	208(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	104(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	136(%rsp), %rdi
	movq	216(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 136(%rsp)
	movq	%rdx, 216(%rsp)
	movq	56(%rsp), %r14
	movq	400(%r14), %rdi
	movq	408(%r14), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 208(%rsp)
	movq	%rdx, 40(%rsp)
	movq	416(%r14), %rax
	movq	%rax, 240(%rsp)
	movq	424(%r14), %rax
	movq	%rax, 280(%rsp)
	movq	%r14, %rbx
	movq	120(%rsp), %rax
	movq	320(%rax), %r13
	movq	%r13, 232(%rsp)
	movq	328(%rax), %rbp
	movq	%rbp, 272(%rsp)
	movq	336(%rax), %rdi
	movq	344(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	432(%rbx), %rbx
	movq	440(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	8(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	32(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	296(%rsp), %rax
	movq	40(%rax), %rbx
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	240(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 64(%rsp)
	movq	56(%rsp), %rax
	movq	448(%rax), %rdi
	movq	456(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	120(%rsp), %rax
	movq	1408(%rax), %r13
	movq	1416(%rax), %rbp
	movq	1424(%rax), %rdi
	movq	1432(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 272(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 232(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	136(%rsp), %r14
	movq	%r14, %rdx
	movq	216(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	208(%rsp), %rbx
	movq	%rbx, %rdx
	movq	40(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	272(%rsp), %rdx
	movq	232(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	16(%rsp), %rbx
	movq	%rbx, %rdx
	movq	48(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	24(%rsp), %rdx
	movq	32(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %r15
	movq	%r15, %rdx
	movq	64(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 232(%rsp)
	movq	%rdx, 272(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	240(%rsp), %r13
	movq	%r13, %rdx
	movq	280(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %r14
	movq	%r14, %rdi
	movq	248(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 264(%rsp)
	movq	%rdx, 256(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	24(%rsp), %r14
	movq	%r14, %rdi
	movq	32(%rsp), %r15
	movq	%r15, %rsi
	movq	8(%rsp), %rdx
	movq	64(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	136(%rsp), %rdi
	movq	216(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	208(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	464(%rax), %r14
	movq	472(%rax), %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 136(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	24(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	136(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	168(%rsp), %rdi
	movq	288(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 168(%rsp)
	movq	%rdx, 288(%rsp)
	movq	200(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 232(%rsp)
	movq	%rdx, 272(%rsp)
	movq	56(%rsp), %rbx
	movq	480(%rbx), %rcx
	movq	%rcx, 136(%rsp)
	movq	488(%rbx), %rcx
	movq	%rcx, 216(%rsp)
	movq	120(%rsp), %rax
	movq	352(%rax), %r13
	movq	%r13, 208(%rsp)
	movq	360(%rax), %rbp
	movq	%rbp, 40(%rsp)
	movq	368(%rax), %rdi
	movq	376(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 200(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	496(%rbx), %rbx
	movq	504(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 32(%rsp)
	movq	%rdx, 64(%rsp)
	movq	296(%rsp), %rax
	movq	48(%rax), %rbx
	movq	208(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	200(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	136(%rsp), %rdi
	movq	216(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 136(%rsp)
	movq	%rdx, 216(%rsp)
	movq	56(%rsp), %r14
	movq	512(%r14), %rdi
	movq	520(%r14), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 208(%rsp)
	movq	%rdx, 40(%rsp)
	movq	528(%r14), %rax
	movq	%rax, 104(%rsp)
	movq	536(%r14), %rax
	movq	%rax, 144(%rsp)
	movq	%r14, %rbx
	movq	120(%rsp), %rax
	movq	384(%rax), %r13
	movq	%r13, 72(%rsp)
	movq	392(%rax), %rbp
	movq	%rbp, 88(%rsp)
	movq	400(%rax), %rdi
	movq	408(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	544(%rbx), %rbx
	movq	552(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	8(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 200(%rsp)
	movq	%rdx, 224(%rsp)
	movq	32(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	296(%rsp), %rax
	movq	56(%rax), %rbx
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 64(%rsp)
	movq	56(%rsp), %rax
	movq	560(%rax), %rdi
	movq	568(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	120(%rsp), %rax
	movq	1440(%rax), %r13
	movq	1448(%rax), %rbp
	movq	1456(%rax), %rdi
	movq	1464(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 88(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 72(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	136(%rsp), %r14
	movq	%r14, %rdx
	movq	216(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	208(%rsp), %rbx
	movq	%rbx, %rdx
	movq	40(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	88(%rsp), %rdx
	movq	72(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	16(%rsp), %rbx
	movq	%rbx, %rdx
	movq	48(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	24(%rsp), %rdx
	movq	32(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %r15
	movq	%r15, %rdx
	movq	64(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	104(%rsp), %r13
	movq	%r13, %rdx
	movq	144(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %r14
	movq	%r14, %rdi
	movq	248(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 264(%rsp)
	movq	%rdx, 256(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	24(%rsp), %r14
	movq	%r14, %rdi
	movq	32(%rsp), %r15
	movq	%r15, %rsi
	movq	8(%rsp), %rdx
	movq	64(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	136(%rsp), %rdi
	movq	216(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	208(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	576(%rax), %r14
	movq	584(%rax), %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 136(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	24(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	136(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	168(%rsp), %rdi
	movq	288(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 168(%rsp)
	movq	%rdx, 288(%rsp)
	movq	240(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 232(%rsp)
	movq	%rdx, 272(%rsp)
	movq	56(%rsp), %rbx
	movq	592(%rbx), %rcx
	movq	%rcx, 136(%rsp)
	movq	600(%rbx), %rcx
	movq	%rcx, 216(%rsp)
	movq	120(%rsp), %rax
	movq	416(%rax), %r13
	movq	%r13, 208(%rsp)
	movq	424(%rax), %rbp
	movq	%rbp, 40(%rsp)
	movq	432(%rax), %rdi
	movq	440(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 104(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	608(%rbx), %rbx
	movq	616(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	200(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 32(%rsp)
	movq	%rdx, 64(%rsp)
	movq	296(%rsp), %rax
	movq	64(%rax), %rbx
	movq	208(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	104(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	136(%rsp), %rdi
	movq	216(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 136(%rsp)
	movq	%rdx, 216(%rsp)
	movq	56(%rsp), %r14
	movq	624(%r14), %rdi
	movq	632(%r14), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 208(%rsp)
	movq	%rdx, 40(%rsp)
	movq	640(%r14), %rax
	movq	%rax, 104(%rsp)
	movq	648(%r14), %rax
	movq	%rax, 144(%rsp)
	movq	%r14, %rbx
	movq	120(%rsp), %rax
	movq	448(%rax), %r13
	movq	%r13, 72(%rsp)
	movq	456(%rax), %rbp
	movq	%rbp, 88(%rsp)
	movq	464(%rax), %rdi
	movq	472(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	656(%rbx), %rbx
	movq	664(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	8(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 200(%rsp)
	movq	%rdx, 224(%rsp)
	movq	32(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	296(%rsp), %rax
	movq	72(%rax), %rbx
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 64(%rsp)
	movq	56(%rsp), %rax
	movq	672(%rax), %rdi
	movq	680(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	120(%rsp), %rax
	movq	1472(%rax), %r13
	movq	1480(%rax), %rbp
	movq	1488(%rax), %rdi
	movq	1496(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 88(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 72(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	136(%rsp), %r14
	movq	%r14, %rdx
	movq	216(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	208(%rsp), %rbx
	movq	%rbx, %rdx
	movq	40(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	88(%rsp), %rdx
	movq	72(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	16(%rsp), %rbx
	movq	%rbx, %rdx
	movq	48(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	24(%rsp), %rdx
	movq	32(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %r15
	movq	%r15, %rdx
	movq	64(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	104(%rsp), %r13
	movq	%r13, %rdx
	movq	144(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %r14
	movq	%r14, %rdi
	movq	248(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 264(%rsp)
	movq	%rdx, 256(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	24(%rsp), %r14
	movq	%r14, %rdi
	movq	32(%rsp), %r15
	movq	%r15, %rsi
	movq	8(%rsp), %rdx
	movq	64(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	136(%rsp), %rdi
	movq	216(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	208(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	688(%rax), %r14
	movq	696(%rax), %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 136(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	24(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	136(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	168(%rsp), %rdi
	movq	288(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 168(%rsp)
	movq	%rdx, 288(%rsp)
	movq	240(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 232(%rsp)
	movq	%rdx, 272(%rsp)
	movq	56(%rsp), %rbx
	movq	704(%rbx), %rcx
	movq	%rcx, 136(%rsp)
	movq	712(%rbx), %rcx
	movq	%rcx, 216(%rsp)
	movq	120(%rsp), %rax
	movq	480(%rax), %r13
	movq	%r13, 208(%rsp)
	movq	488(%rax), %rbp
	movq	%rbp, 40(%rsp)
	movq	496(%rax), %rdi
	movq	504(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 104(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	720(%rbx), %rbx
	movq	728(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	200(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 32(%rsp)
	movq	%rdx, 64(%rsp)
	movq	296(%rsp), %rax
	movq	80(%rax), %rbx
	movq	208(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	104(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	136(%rsp), %rdi
	movq	216(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 136(%rsp)
	movq	%rdx, 216(%rsp)
	movq	56(%rsp), %r14
	movq	736(%r14), %rdi
	movq	744(%r14), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 208(%rsp)
	movq	%rdx, 40(%rsp)
	movq	752(%r14), %rax
	movq	%rax, 200(%rsp)
	movq	760(%r14), %rax
	movq	%rax, 224(%rsp)
	movq	%r14, %rbx
	movq	120(%rsp), %rax
	movq	512(%rax), %r13
	movq	%r13, 192(%rsp)
	movq	520(%rax), %rbp
	movq	%rbp, 184(%rsp)
	movq	528(%rax), %rdi
	movq	536(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	768(%rbx), %rbx
	movq	776(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	8(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	32(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	296(%rsp), %rax
	movq	88(%rax), %rbx
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	200(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 64(%rsp)
	movq	56(%rsp), %rax
	movq	784(%rax), %rdi
	movq	792(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 200(%rsp)
	movq	%rdx, 224(%rsp)
	movq	120(%rsp), %rax
	movq	1504(%rax), %r13
	movq	1512(%rax), %rbp
	movq	1520(%rax), %rdi
	movq	1528(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 184(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 192(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	136(%rsp), %r14
	movq	%r14, %rdx
	movq	216(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	208(%rsp), %rbx
	movq	%rbx, %rdx
	movq	40(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	184(%rsp), %rdx
	movq	192(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	16(%rsp), %rbx
	movq	%rbx, %rdx
	movq	48(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	24(%rsp), %rdx
	movq	32(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %r15
	movq	%r15, %rdx
	movq	64(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	200(%rsp), %r13
	movq	%r13, %rdx
	movq	224(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %r14
	movq	%r14, %rdi
	movq	248(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 264(%rsp)
	movq	%rdx, 256(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	24(%rsp), %r14
	movq	%r14, %rdi
	movq	32(%rsp), %r15
	movq	%r15, %rsi
	movq	8(%rsp), %rdx
	movq	64(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	136(%rsp), %rdi
	movq	216(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	208(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	800(%rax), %r14
	movq	808(%rax), %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 136(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	24(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	136(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	168(%rsp), %rdi
	movq	288(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 168(%rsp)
	movq	%rdx, 288(%rsp)
	movq	240(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 200(%rsp)
	movq	%rdx, 224(%rsp)
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	56(%rsp), %rbx
	movq	816(%rbx), %rcx
	movq	%rcx, 136(%rsp)
	movq	824(%rbx), %rcx
	movq	%rcx, 216(%rsp)
	movq	120(%rsp), %rax
	movq	576(%rax), %r13
	movq	%r13, 208(%rsp)
	movq	584(%rax), %rbp
	movq	%rbp, 40(%rsp)
	movq	592(%rax), %rdi
	movq	600(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 240(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	832(%rbx), %rbx
	movq	840(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 24(%rsp)
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 32(%rsp)
	movq	%rdx, 64(%rsp)
	movq	296(%rsp), %rax
	movq	96(%rax), %rbx
	movq	208(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	240(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	136(%rsp), %rdi
	movq	216(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 136(%rsp)
	movq	%rdx, 216(%rsp)
	movq	56(%rsp), %r14
	movq	848(%r14), %rdi
	movq	856(%r14), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 208(%rsp)
	movq	%rdx, 40(%rsp)
	movq	864(%r14), %rax
	movq	%rax, 104(%rsp)
	movq	872(%r14), %rax
	movq	%rax, 144(%rsp)
	movq	%r14, %rbx
	movq	120(%rsp), %rax
	movq	608(%rax), %r13
	movq	%r13, 72(%rsp)
	movq	616(%rax), %rbp
	movq	%rbp, 88(%rsp)
	movq	624(%rax), %rdi
	movq	632(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	880(%rbx), %rbx
	movq	888(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	8(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	32(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 232(%rsp)
	movq	%rdx, 272(%rsp)
	movq	296(%rsp), %rax
	movq	104(%rax), %rbx
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 64(%rsp)
	movq	56(%rsp), %rax
	movq	896(%rax), %rdi
	movq	904(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	120(%rsp), %rax
	movq	1536(%rax), %r13
	movq	1544(%rax), %rbp
	movq	1552(%rax), %rdi
	movq	1560(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 88(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 72(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	136(%rsp), %r14
	movq	%r14, %rdx
	movq	216(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	208(%rsp), %rbx
	movq	%rbx, %rdx
	movq	40(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	88(%rsp), %rdx
	movq	72(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	16(%rsp), %rbx
	movq	%rbx, %rdx
	movq	48(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	24(%rsp), %rdx
	movq	32(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %r15
	movq	%r15, %rdx
	movq	64(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	104(%rsp), %r13
	movq	%r13, %rdx
	movq	144(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %r14
	movq	%r14, %rdi
	movq	248(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 264(%rsp)
	movq	%rdx, 256(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	24(%rsp), %r14
	movq	%r14, %rdi
	movq	32(%rsp), %r15
	movq	%r15, %rsi
	movq	8(%rsp), %rdx
	movq	64(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	136(%rsp), %rdi
	movq	216(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	208(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	912(%rax), %r14
	movq	920(%rax), %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 136(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	24(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	136(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	168(%rsp), %rdi
	movq	288(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	200(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 264(%rsp)
	movq	%rdx, 256(%rsp)
	movq	56(%rsp), %rax
	movq	928(%rax), %rcx
	movq	%rcx, 8(%rsp)
	movq	936(%rax), %rax
	movq	%rax, 40(%rsp)
	movq	120(%rsp), %rax
	movq	640(%rax), %r12
	movq	%r12, 216(%rsp)
	movq	648(%rax), %r13
	movq	%r13, 208(%rsp)
	movq	656(%rax), %rdi
	movq	664(%rax), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbp
	movq	%rax, 136(%rsp)
	movq	%rdx, %r14
	movq	296(%rsp), %rbx
	movq	112(%rbx), %r15
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%r14, 288(%rsp)
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 32(%rsp)
	movq	%rdx, 64(%rsp)
	movq	56(%rsp), %r12
	movq	944(%r12), %rdi
	movq	952(%r12), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	960(%r12), %rax
	movq	%rax, 8(%rsp)
	movq	968(%r12), %rax
	movq	%rax, 96(%rsp)
	movq	120(%rbx), %r15
	movq	216(%rsp), %rdi
	movq	208(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	136(%rsp), %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 168(%rsp)
	movq	56(%rsp), %rax
	movq	976(%rax), %rdi
	movq	984(%rax), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 200(%rsp)
	movq	%rdx, 224(%rsp)
	movq	120(%rsp), %rax
	movq	1568(%rax), %r13
	movq	1576(%rax), %rbp
	movq	1584(%rax), %rdi
	movq	1592(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 184(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 192(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	32(%rsp), %r14
	movq	%r14, %rdx
	movq	64(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	40(%rsp), %rbx
	movq	%rbx, %rdx
	movq	24(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	184(%rsp), %rdx
	movq	192(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	160(%rsp), %rbx
	movq	%rbx, %rdx
	movq	248(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	96(%rsp), %rdx
	movq	112(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 328(%rsp)
	movq	%rdx, 320(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %r15
	movq	%r15, %rdx
	movq	168(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	200(%rsp), %r13
	movq	%r13, %rdx
	movq	224(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	328(%rsp), %r14
	movq	%r14, %rdi
	movq	320(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	160(%rsp), %rdi
	movq	248(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 344(%rsp)
	movq	%rdx, 336(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 160(%rsp)
	movq	%rdx, %r12
	movq	96(%rsp), %r14
	movq	%r14, %rdi
	movq	112(%rsp), %r15
	movq	%r15, %rsi
	movq	8(%rsp), %rdx
	movq	168(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	160(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	32(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	40(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	344(%rsp), %rdi
	movq	336(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	992(%rax), %r14
	movq	1000(%rax), %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 40(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	160(%rsp), %rdi
	movq	248(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	40(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 200(%rsp)
	movq	%rdx, 224(%rsp)
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	56(%rsp), %rbx
	movq	1008(%rbx), %rcx
	movq	%rcx, 40(%rsp)
	movq	1016(%rbx), %rcx
	movq	%rcx, 24(%rsp)
	movq	120(%rsp), %rax
	movq	704(%rax), %r13
	movq	%r13, 32(%rsp)
	movq	712(%rax), %rbp
	movq	%rbp, 64(%rsp)
	movq	720(%rax), %rdi
	movq	728(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	1024(%rbx), %rbx
	movq	1032(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	240(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 96(%rsp)
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	296(%rsp), %rax
	movq	128(%rax), %rbx
	movq	32(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	40(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	56(%rsp), %r14
	movq	1040(%r14), %rdi
	movq	1048(%r14), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 32(%rsp)
	movq	%rdx, 64(%rsp)
	movq	1056(%r14), %rax
	movq	%rax, 16(%rsp)
	movq	1064(%r14), %rax
	movq	%rax, 48(%rsp)
	movq	%r14, %rbx
	movq	120(%rsp), %rax
	movq	736(%rax), %r13
	movq	%r13, 264(%rsp)
	movq	744(%rax), %rbp
	movq	%rbp, 256(%rsp)
	movq	752(%rax), %rdi
	movq	760(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 160(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	1072(%rbx), %rbx
	movq	1080(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	8(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	112(%rsp), %rdi
	movq	168(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 232(%rsp)
	movq	%rdx, 272(%rsp)
	movq	296(%rsp), %rax
	movq	136(%rax), %rbx
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	160(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 168(%rsp)
	movq	56(%rsp), %rax
	movq	1088(%rax), %rdi
	movq	1096(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	120(%rsp), %rax
	movq	1600(%rax), %r13
	movq	1608(%rax), %rbp
	movq	1616(%rax), %rdi
	movq	1624(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 256(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 264(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	40(%rsp), %r14
	movq	%r14, %rdx
	movq	24(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	32(%rsp), %rbx
	movq	%rbx, %rdx
	movq	64(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	256(%rsp), %rdx
	movq	264(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	160(%rsp), %rbx
	movq	%rbx, %rdx
	movq	248(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	96(%rsp), %rdx
	movq	112(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 328(%rsp)
	movq	%rdx, 320(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %r15
	movq	%r15, %rdx
	movq	168(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 264(%rsp)
	movq	%rdx, 256(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	16(%rsp), %r13
	movq	%r13, %rdx
	movq	48(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	328(%rsp), %r14
	movq	%r14, %rdi
	movq	320(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	160(%rsp), %rdi
	movq	248(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 344(%rsp)
	movq	%rdx, 336(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 160(%rsp)
	movq	%rdx, %r12
	movq	96(%rsp), %r14
	movq	%r14, %rdi
	movq	112(%rsp), %r15
	movq	%r15, %rsi
	movq	8(%rsp), %rdx
	movq	168(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	160(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	40(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	32(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	344(%rsp), %rdi
	movq	336(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	1104(%rax), %r14
	movq	1112(%rax), %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 40(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	160(%rsp), %rdi
	movq	248(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	200(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	40(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 168(%rsp)
	movq	%rdx, 200(%rsp)
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 224(%rsp)
	movq	%rdx, 192(%rsp)
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 184(%rsp)
	movq	%rdx, 104(%rsp)
	movq	56(%rsp), %r14
	movq	1120(%r14), %rcx
	movq	%rcx, 8(%rsp)
	movq	1128(%r14), %rcx
	movq	%rcx, 40(%rsp)
	movq	296(%rsp), %rbx
	movq	144(%rbx), %r15
	movq	152(%rsp), %rdi
	movq	176(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	80(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 32(%rsp)
	movq	%rdx, 64(%rsp)
	movq	1136(%r14), %rdi
	movq	1144(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	1152(%r14), %rax
	movq	%rax, 8(%rsp)
	movq	1160(%r14), %rax
	movq	%rax, 144(%rsp)
	movq	152(%rbx), %r15
	movq	152(%rsp), %rdi
	movq	176(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	80(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 176(%rsp)
	movq	1168(%r14), %rdi
	movq	1176(%r14), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 128(%rsp)
	movq	%rdx, 144(%rsp)
	movq	120(%rsp), %rax
	movq	1632(%rax), %r13
	movq	1640(%rax), %rbp
	movq	1648(%rax), %rdi
	movq	1656(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 88(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 72(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	32(%rsp), %r14
	movq	%r14, %rdx
	movq	64(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	40(%rsp), %rbx
	movq	%rbx, %rdx
	movq	24(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 80(%rsp)
	movq	%rdx, 152(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	88(%rsp), %rdx
	movq	72(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	16(%rsp), %rbx
	movq	%rbx, %rdx
	movq	48(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	80(%rsp), %rdx
	movq	152(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %r15
	movq	%r15, %rdx
	movq	176(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	128(%rsp), %r13
	movq	%r13, %rdx
	movq	144(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %r14
	movq	%r14, %rdi
	movq	248(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 264(%rsp)
	movq	%rdx, 256(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	80(%rsp), %r14
	movq	%r14, %rdi
	movq	152(%rsp), %r15
	movq	%r15, %rsi
	movq	8(%rsp), %rdx
	movq	176(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 80(%rsp)
	movq	%rdx, 152(%rsp)
	movq	32(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	40(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	1184(%rax), %r14
	movq	1192(%rax), %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 176(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	80(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	176(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 64(%rsp)
	movq	%rdx, 96(%rsp)
	movq	168(%rsp), %rdi
	movq	200(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	224(%rsp), %rdi
	movq	192(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 200(%rsp)
	movq	%rdx, 224(%rsp)
	movq	184(%rsp), %rdi
	movq	104(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	56(%rsp), %rbx
	movq	1200(%rbx), %rcx
	movq	%rcx, 80(%rsp)
	movq	1208(%rbx), %rcx
	movq	%rcx, 152(%rsp)
	movq	120(%rsp), %rax
	movq	800(%rax), %r13
	movq	%r13, 176(%rsp)
	movq	808(%rax), %rbp
	movq	%rbp, 128(%rsp)
	movq	816(%rax), %rdi
	movq	824(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 104(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	1216(%rbx), %rbx
	movq	1224(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	240(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 40(%rsp)
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	296(%rsp), %rax
	movq	160(%rax), %rbx
	movq	176(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	104(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	80(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 80(%rsp)
	movq	%rdx, 152(%rsp)
	movq	56(%rsp), %r14
	movq	1232(%r14), %rdi
	movq	1240(%r14), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 176(%rsp)
	movq	%rdx, 128(%rsp)
	movq	1248(%r14), %rax
	movq	%rax, 240(%rsp)
	movq	1256(%r14), %rax
	movq	%rax, 280(%rsp)
	movq	%r14, %rbx
	movq	120(%rsp), %rax
	movq	832(%rax), %r13
	movq	%r13, 232(%rsp)
	movq	840(%rax), %rbp
	movq	%rbp, 272(%rsp)
	movq	848(%rax), %rdi
	movq	856(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	1264(%rbx), %rbx
	movq	1272(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	8(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	24(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	296(%rsp), %rax
	movq	168(%rax), %rbx
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	240(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 32(%rsp)
	movq	56(%rsp), %rax
	movq	1280(%rax), %rdi
	movq	1288(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	120(%rsp), %rax
	movq	1664(%rax), %r13
	movq	1672(%rax), %rbp
	movq	1680(%rax), %rdi
	movq	1688(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 272(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 232(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	80(%rsp), %r14
	movq	%r14, %rdx
	movq	152(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	176(%rsp), %rbx
	movq	%rbx, %rdx
	movq	128(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	272(%rsp), %rdx
	movq	232(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	16(%rsp), %rbx
	movq	%rbx, %rdx
	movq	48(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	40(%rsp), %rdx
	movq	24(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %r15
	movq	%r15, %rdx
	movq	32(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 232(%rsp)
	movq	%rdx, 272(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	240(%rsp), %r13
	movq	%r13, %rdx
	movq	280(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %r14
	movq	%r14, %rdi
	movq	248(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 264(%rsp)
	movq	%rdx, 256(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	40(%rsp), %r14
	movq	%r14, %rdi
	movq	24(%rsp), %r15
	movq	%r15, %rsi
	movq	8(%rsp), %rdx
	movq	32(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	80(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	176(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	1296(%rax), %r14
	movq	1304(%rax), %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 80(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	40(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	64(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	80(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 64(%rsp)
	movq	%rdx, 96(%rsp)
	movq	112(%rsp), %rdi
	movq	168(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	200(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 232(%rsp)
	movq	%rdx, 272(%rsp)
	movq	56(%rsp), %rbx
	movq	1312(%rbx), %rcx
	movq	%rcx, 80(%rsp)
	movq	1320(%rbx), %rcx
	movq	%rcx, 152(%rsp)
	movq	120(%rsp), %rax
	movq	864(%rax), %r13
	movq	%r13, 176(%rsp)
	movq	872(%rax), %rbp
	movq	%rbp, 128(%rsp)
	movq	880(%rax), %rdi
	movq	888(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 200(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	1328(%rbx), %rbx
	movq	1336(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 40(%rsp)
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	296(%rsp), %rax
	movq	176(%rax), %rbx
	movq	176(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	200(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	80(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 80(%rsp)
	movq	%rdx, 152(%rsp)
	movq	56(%rsp), %r14
	movq	1344(%r14), %rdi
	movq	1352(%r14), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 176(%rsp)
	movq	%rdx, 128(%rsp)
	movq	1360(%r14), %rax
	movq	%rax, 104(%rsp)
	movq	1368(%r14), %rax
	movq	%rax, 144(%rsp)
	movq	%r14, %rbx
	movq	120(%rsp), %rax
	movq	896(%rax), %r13
	movq	%r13, 72(%rsp)
	movq	904(%rax), %rbp
	movq	%rbp, 88(%rsp)
	movq	912(%rax), %rdi
	movq	920(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	1376(%rbx), %rbx
	movq	1384(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	8(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 200(%rsp)
	movq	%rdx, 224(%rsp)
	movq	24(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	296(%rsp), %rax
	movq	184(%rax), %rbx
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 32(%rsp)
	movq	56(%rsp), %rax
	movq	1392(%rax), %rdi
	movq	1400(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	120(%rsp), %rax
	movq	1696(%rax), %r13
	movq	1704(%rax), %rbp
	movq	1712(%rax), %rdi
	movq	1720(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 88(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 72(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	80(%rsp), %r14
	movq	%r14, %rdx
	movq	152(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	176(%rsp), %rbx
	movq	%rbx, %rdx
	movq	128(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	88(%rsp), %rdx
	movq	72(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	16(%rsp), %rbx
	movq	%rbx, %rdx
	movq	48(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	40(%rsp), %rdx
	movq	24(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %r15
	movq	%r15, %rdx
	movq	32(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	104(%rsp), %r13
	movq	%r13, %rdx
	movq	144(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %r14
	movq	%r14, %rdi
	movq	248(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 264(%rsp)
	movq	%rdx, 256(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	40(%rsp), %r14
	movq	%r14, %rdi
	movq	24(%rsp), %r15
	movq	%r15, %rsi
	movq	8(%rsp), %rdx
	movq	32(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	80(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	176(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	1408(%rax), %r14
	movq	1416(%rax), %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 80(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	40(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	64(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	80(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 64(%rsp)
	movq	%rdx, 96(%rsp)
	movq	112(%rsp), %rdi
	movq	168(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	240(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 232(%rsp)
	movq	%rdx, 272(%rsp)
	movq	56(%rsp), %rbx
	movq	1424(%rbx), %rcx
	movq	%rcx, 80(%rsp)
	movq	1432(%rbx), %rcx
	movq	%rcx, 152(%rsp)
	movq	120(%rsp), %rax
	movq	928(%rax), %r13
	movq	%r13, 176(%rsp)
	movq	936(%rax), %rbp
	movq	%rbp, 128(%rsp)
	movq	944(%rax), %rdi
	movq	952(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 104(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	1440(%rbx), %rbx
	movq	1448(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	200(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 40(%rsp)
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	296(%rsp), %rax
	movq	192(%rax), %rbx
	movq	176(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	104(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	80(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 80(%rsp)
	movq	%rdx, 152(%rsp)
	movq	56(%rsp), %r14
	movq	1456(%r14), %rdi
	movq	1464(%r14), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 176(%rsp)
	movq	%rdx, 128(%rsp)
	movq	1472(%r14), %rax
	movq	%rax, 104(%rsp)
	movq	1480(%r14), %rax
	movq	%rax, 144(%rsp)
	movq	%r14, %rbx
	movq	120(%rsp), %rax
	movq	960(%rax), %r13
	movq	%r13, 72(%rsp)
	movq	968(%rax), %rbp
	movq	%rbp, 88(%rsp)
	movq	976(%rax), %rdi
	movq	984(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	1488(%rbx), %rbx
	movq	1496(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	8(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 200(%rsp)
	movq	%rdx, 224(%rsp)
	movq	24(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	296(%rsp), %rax
	movq	200(%rax), %rbx
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 32(%rsp)
	movq	56(%rsp), %rax
	movq	1504(%rax), %rdi
	movq	1512(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	120(%rsp), %rax
	movq	1728(%rax), %r13
	movq	1736(%rax), %rbp
	movq	1744(%rax), %rdi
	movq	1752(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 88(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 72(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	80(%rsp), %r14
	movq	%r14, %rdx
	movq	152(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	176(%rsp), %rbx
	movq	%rbx, %rdx
	movq	128(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	88(%rsp), %rdx
	movq	72(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	16(%rsp), %rbx
	movq	%rbx, %rdx
	movq	48(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	40(%rsp), %rdx
	movq	24(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %r15
	movq	%r15, %rdx
	movq	32(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	104(%rsp), %r13
	movq	%r13, %rdx
	movq	144(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %r14
	movq	%r14, %rdi
	movq	248(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 264(%rsp)
	movq	%rdx, 256(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	40(%rsp), %r14
	movq	%r14, %rdi
	movq	24(%rsp), %r15
	movq	%r15, %rsi
	movq	8(%rsp), %rdx
	movq	32(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	80(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	176(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	1520(%rax), %r14
	movq	1528(%rax), %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 80(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	40(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	64(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	80(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 64(%rsp)
	movq	%rdx, 96(%rsp)
	movq	112(%rsp), %rdi
	movq	168(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	240(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 232(%rsp)
	movq	%rdx, 272(%rsp)
	movq	56(%rsp), %rbx
	movq	1536(%rbx), %rcx
	movq	%rcx, 80(%rsp)
	movq	1544(%rbx), %rcx
	movq	%rcx, 152(%rsp)
	movq	120(%rsp), %rax
	movq	992(%rax), %r13
	movq	%r13, 176(%rsp)
	movq	1000(%rax), %rbp
	movq	%rbp, 128(%rsp)
	movq	1008(%rax), %rdi
	movq	1016(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 104(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	1552(%rbx), %rbx
	movq	1560(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	200(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 40(%rsp)
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	296(%rsp), %rax
	movq	208(%rax), %rbx
	movq	176(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	104(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	80(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 80(%rsp)
	movq	%rdx, 152(%rsp)
	movq	56(%rsp), %r14
	movq	1568(%r14), %rdi
	movq	1576(%r14), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 176(%rsp)
	movq	%rdx, 128(%rsp)
	movq	1584(%r14), %rax
	movq	%rax, 104(%rsp)
	movq	1592(%r14), %rax
	movq	%rax, 144(%rsp)
	movq	%r14, %rbx
	movq	120(%rsp), %rax
	movq	1024(%rax), %r13
	movq	%r13, 72(%rsp)
	movq	1032(%rax), %rbp
	movq	%rbp, 88(%rsp)
	movq	1040(%rax), %rdi
	movq	1048(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	1600(%rbx), %rbx
	movq	1608(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	8(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 200(%rsp)
	movq	%rdx, 224(%rsp)
	movq	24(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	296(%rsp), %rax
	movq	216(%rax), %rbx
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 32(%rsp)
	movq	56(%rsp), %rax
	movq	1616(%rax), %rdi
	movq	1624(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	120(%rsp), %rax
	movq	1760(%rax), %r13
	movq	1768(%rax), %rbp
	movq	1776(%rax), %rdi
	movq	1784(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 88(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 72(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	80(%rsp), %r14
	movq	%r14, %rdx
	movq	152(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	176(%rsp), %rbx
	movq	%rbx, %rdx
	movq	128(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	88(%rsp), %rdx
	movq	72(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	16(%rsp), %rbx
	movq	%rbx, %rdx
	movq	48(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	40(%rsp), %rdx
	movq	24(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %r15
	movq	%r15, %rdx
	movq	32(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	104(%rsp), %r13
	movq	%r13, %rdx
	movq	144(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %r14
	movq	%r14, %rdi
	movq	248(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 264(%rsp)
	movq	%rdx, 256(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	40(%rsp), %r14
	movq	%r14, %rdi
	movq	24(%rsp), %r15
	movq	%r15, %rsi
	movq	8(%rsp), %rdx
	movq	32(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	80(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	176(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	1632(%rax), %r14
	movq	1640(%rax), %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 80(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	40(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	64(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	80(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 64(%rsp)
	movq	%rdx, 96(%rsp)
	movq	112(%rsp), %rdi
	movq	168(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	240(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 232(%rsp)
	movq	%rdx, 272(%rsp)
	movq	56(%rsp), %rbx
	movq	1648(%rbx), %rcx
	movq	%rcx, 80(%rsp)
	movq	1656(%rbx), %rcx
	movq	%rcx, 152(%rsp)
	movq	120(%rsp), %rax
	movq	1120(%rax), %r13
	movq	%r13, 176(%rsp)
	movq	1128(%rax), %rbp
	movq	%rbp, 128(%rsp)
	movq	1136(%rax), %rdi
	movq	1144(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 104(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	1664(%rbx), %rbx
	movq	1672(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	200(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 40(%rsp)
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	296(%rsp), %rax
	movq	224(%rax), %rbx
	movq	176(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	104(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	80(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 80(%rsp)
	movq	%rdx, 152(%rsp)
	movq	56(%rsp), %r14
	movq	1680(%r14), %rdi
	movq	1688(%r14), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 176(%rsp)
	movq	%rdx, 128(%rsp)
	movq	1696(%r14), %rax
	movq	%rax, 200(%rsp)
	movq	1704(%r14), %rax
	movq	%rax, 224(%rsp)
	movq	%r14, %rbx
	movq	120(%rsp), %rax
	movq	1152(%rax), %r13
	movq	%r13, 192(%rsp)
	movq	1160(%rax), %rbp
	movq	%rbp, 184(%rsp)
	movq	1168(%rax), %rdi
	movq	1176(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	1712(%rbx), %rbx
	movq	1720(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	8(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	24(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	296(%rsp), %rax
	movq	232(%rax), %rbx
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	200(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 32(%rsp)
	movq	56(%rsp), %rax
	movq	1728(%rax), %rdi
	movq	1736(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 200(%rsp)
	movq	%rdx, 224(%rsp)
	movq	120(%rsp), %rax
	movq	1792(%rax), %r13
	movq	1800(%rax), %rbp
	movq	1808(%rax), %rdi
	movq	1816(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 184(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 192(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	80(%rsp), %r14
	movq	%r14, %rdx
	movq	152(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	176(%rsp), %rbx
	movq	%rbx, %rdx
	movq	128(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	184(%rsp), %rdx
	movq	192(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	16(%rsp), %rbx
	movq	%rbx, %rdx
	movq	48(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	40(%rsp), %rdx
	movq	24(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %r15
	movq	%r15, %rdx
	movq	32(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	200(%rsp), %r13
	movq	%r13, %rdx
	movq	224(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %r14
	movq	%r14, %rdi
	movq	248(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 264(%rsp)
	movq	%rdx, 256(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	40(%rsp), %r14
	movq	%r14, %rdi
	movq	24(%rsp), %r15
	movq	%r15, %rsi
	movq	8(%rsp), %rdx
	movq	32(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	80(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	176(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	1744(%rax), %r14
	movq	1752(%rax), %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 80(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	40(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	64(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	80(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 64(%rsp)
	movq	%rdx, 96(%rsp)
	movq	112(%rsp), %rdi
	movq	168(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 112(%rsp)
	movq	%rdx, 168(%rsp)
	movq	240(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 200(%rsp)
	movq	%rdx, 224(%rsp)
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	56(%rsp), %rbx
	movq	1760(%rbx), %rcx
	movq	%rcx, 80(%rsp)
	movq	1768(%rbx), %rcx
	movq	%rcx, 152(%rsp)
	movq	120(%rsp), %rax
	movq	1184(%rax), %r13
	movq	%r13, 176(%rsp)
	movq	1192(%rax), %rbp
	movq	%rbp, 128(%rsp)
	movq	1200(%rax), %rdi
	movq	1208(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 240(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	1776(%rbx), %rbx
	movq	1784(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 40(%rsp)
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	296(%rsp), %rax
	movq	240(%rax), %rbx
	movq	176(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	240(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	80(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 80(%rsp)
	movq	%rdx, 152(%rsp)
	movq	56(%rsp), %r14
	movq	1792(%r14), %rdi
	movq	1800(%r14), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 176(%rsp)
	movq	%rdx, 128(%rsp)
	movq	1808(%r14), %rax
	movq	%rax, 104(%rsp)
	movq	1816(%r14), %rax
	movq	%rax, 144(%rsp)
	movq	%r14, %rbx
	movq	120(%rsp), %rax
	movq	1216(%rax), %r13
	movq	%r13, 72(%rsp)
	movq	1224(%rax), %rbp
	movq	%rbp, 88(%rsp)
	movq	1232(%rax), %rdi
	movq	1240(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	%rbx, %rax
	movq	1824(%rbx), %rbx
	movq	1832(%rax), %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r15
	movq	8(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	24(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 232(%rsp)
	movq	%rdx, 272(%rsp)
	movq	296(%rsp), %rax
	movq	248(%rax), %rbx
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 32(%rsp)
	movq	56(%rsp), %rax
	movq	1840(%rax), %rdi
	movq	1848(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	120(%rsp), %rax
	movq	1824(%rax), %r13
	movq	1832(%rax), %rbp
	movq	1840(%rax), %rdi
	movq	1848(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 88(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 72(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	80(%rsp), %r14
	movq	%r14, %rdx
	movq	152(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	176(%rsp), %rbx
	movq	%rbx, %rdx
	movq	128(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	88(%rsp), %rdx
	movq	72(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	16(%rsp), %rbx
	movq	%rbx, %rdx
	movq	48(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	40(%rsp), %rdx
	movq	24(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %r15
	movq	%r15, %rdx
	movq	32(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	104(%rsp), %r13
	movq	%r13, %rdx
	movq	144(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	160(%rsp), %r14
	movq	%r14, %rdi
	movq	248(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 264(%rsp)
	movq	%rdx, 256(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 16(%rsp)
	movq	%rdx, %r12
	movq	40(%rsp), %r14
	movq	%r14, %rdi
	movq	24(%rsp), %r15
	movq	%r15, %rsi
	movq	8(%rsp), %rdx
	movq	32(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	16(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	80(%rsp), %rdi
	movq	152(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	176(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	1856(%rax), %r14
	movq	1864(%rax), %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 80(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	16(%rsp), %rdi
	movq	48(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	40(%rsp), %rdi
	movq	24(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	64(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	80(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	112(%rsp), %rdi
	movq	168(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	200(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 200(%rsp)
	movq	%rdx, 224(%rsp)
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 192(%rsp)
	movq	%rdx, 184(%rsp)
	movq	56(%rsp), %rax
	movq	1872(%rax), %rcx
	movq	%rcx, 8(%rsp)
	movq	1880(%rax), %rax
	movq	%rax, 128(%rsp)
	movq	120(%rsp), %rax
	movq	1248(%rax), %r12
	movq	%r12, 152(%rsp)
	movq	1256(%rax), %r13
	movq	%r13, 176(%rsp)
	movq	1264(%rax), %rdi
	movq	1272(%rax), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbp
	movq	%rax, 80(%rsp)
	movq	%rdx, %r14
	movq	296(%rsp), %rbx
	movq	256(%rbx), %r15
	movq	%r12, %rdi
	movq	%r13, %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	%rbp, %rdi
	movq	%r14, %rsi
	movq	%r14, 168(%rsp)
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 24(%rsp)
	movq	%rdx, 32(%rsp)
	movq	56(%rsp), %r12
	movq	1888(%r12), %rdi
	movq	1896(%r12), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 128(%rsp)
	movq	%rdx, 40(%rsp)
	movq	1904(%r12), %rax
	movq	%rax, 8(%rsp)
	movq	1912(%r12), %rax
	movq	%rax, 64(%rsp)
	movq	264(%rbx), %r15
	movq	152(%rsp), %rdi
	movq	176(%rsp), %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r12
	movq	%rdx, %r13
	movq	80(%rsp), %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r15
	movq	%rdx, %rbp
	movq	8(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%r12, %rdx
	movq	%r13, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 8(%rsp)
	movq	%rdx, 112(%rsp)
	movq	56(%rsp), %rax
	movq	1920(%rax), %rdi
	movq	1928(%rax), %rsi
	movq	%r15, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	120(%rsp), %rax
	movq	1856(%rax), %r13
	movq	1864(%rax), %rbp
	movq	1872(%rax), %rdi
	movq	1880(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 256(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 264(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	24(%rsp), %r14
	movq	%r14, %rdx
	movq	32(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	128(%rsp), %rbx
	movq	%rbx, %rdx
	movq	40(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 64(%rsp)
	movq	%rdx, 96(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	256(%rsp), %rdx
	movq	264(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	160(%rsp), %rbx
	movq	%rbx, %rdx
	movq	248(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	64(%rsp), %rdx
	movq	96(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 328(%rsp)
	movq	%rdx, 320(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	8(%rsp), %r15
	movq	%r15, %rdx
	movq	112(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 264(%rsp)
	movq	%rdx, 256(%rsp)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	16(%rsp), %r13
	movq	%r13, %rdx
	movq	48(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	328(%rsp), %r14
	movq	%r14, %rdi
	movq	320(%rsp), %rbx
	movq	%rbx, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	160(%rsp), %rdi
	movq	248(%rsp), %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 344(%rsp)
	movq	%rdx, 336(%rsp)
	movq	%r14, %rdi
	movq	%rbx, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 160(%rsp)
	movq	%rdx, %r12
	movq	64(%rsp), %r14
	movq	%r14, %rdi
	movq	96(%rsp), %r15
	movq	%r15, %rsi
	movq	8(%rsp), %rdx
	movq	112(%rsp), %rbx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	160(%rsp), %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 160(%rsp)
	movq	%rdx, 248(%rsp)
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 64(%rsp)
	movq	%rdx, 96(%rsp)
	movq	24(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	%rbx, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	128(%rsp), %rdi
	movq	40(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	264(%rsp), %rdi
	movq	256(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	344(%rsp), %rdi
	movq	336(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	56(%rsp), %rax
	movq	1936(%rax), %r14
	movq	1944(%rax), %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 8(%rsp)
	movq	%rdx, 128(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	160(%rsp), %rdi
	movq	248(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	64(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	8(%rsp), %rdx
	movq	128(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 128(%rsp)
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 104(%rsp)
	movq	%rdx, 144(%rsp)
	movq	200(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 72(%rsp)
	movq	%rdx, 88(%rsp)
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	120(%rsp), %rax
	movq	544(%rax), %r15
	movq	%r15, 200(%rsp)
	movq	552(%rax), %r12
	movq	%r12, 224(%rsp)
	movq	560(%rax), %rdi
	movq	568(%rax), %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rax, 192(%rsp)
	movq	%rdx, %rbp
	movq	%rdx, 184(%rsp)
	movq	56(%rsp), %rax
	movq	1952(%rax), %rbx
	movq	1960(%rax), %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r15
	movq	%rdx, %r12
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	240(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 32(%rsp)
	movq	%rdx, 64(%rsp)
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 96(%rsp)
	movq	%rdx, 112(%rsp)
	movq	120(%rsp), %rax
	movq	1088(%rax), %r13
	movq	1096(%rax), %rbp
	movq	1104(%rax), %rdi
	movq	1112(%rax), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	56(%rsp), %rax
	movq	1968(%rax), %r15
	movq	1976(%rax), %r12
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r15
	movq	%rdx, %r12
	movq	32(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 232(%rsp)
	movq	%rdx, 272(%rsp)
	movq	120(%rsp), %rax
	movq	1056(%rax), %rbx
	movq	%rbx, 32(%rsp)
	movq	1064(%rax), %r14
	movq	%r14, 64(%rsp)
	movq	1072(%rax), %rdi
	movq	1080(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r15
	movq	%rax, 96(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 112(%rsp)
	movq	56(%rsp), %rax
	movq	1984(%rax), %r13
	movq	1992(%rax), %rbp
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	240(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	120(%rsp), %rax
	movq	(%rax), %rbx
	movq	8(%rax), %rbp
	movq	16(%rax), %rdi
	movq	24(%rax), %rsi
	movq	%rbx, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 16(%rsp)
	movq	%rdx, 48(%rsp)
	movq	8(%rsp), %rdi
	movq	128(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rax, 264(%rsp)
	movq	%rdx, %r12
	movq	%rdx, 256(%rsp)
	movq	104(%rsp), %rdi
	movq	144(%rsp), %rsi
	movq	240(%rsp), %rdx
	movq	280(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r14
	movq	%rax, 232(%rsp)
	movq	%rdx, %r15
	movq	%rdx, 272(%rsp)
	movq	72(%rsp), %rdi
	movq	88(%rsp), %rsi
	movq	304(%rsp), %rdx
	movq	312(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 128(%rsp)
	movq	%rbx, %rdi
	movq	%rbp, %rsi
	movq	%r13, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 304(%rsp)
	movq	%rdx, 312(%rsp)
	movq	%rbx, %rdi
	movq	%rbx, %r12
	movq	%rbp, %rbx
	movq	%rbp, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	16(%rsp), %r13
	movq	%r13, %rdi
	movq	48(%rsp), %rbp
	movq	%rbp, %rsi
	movq	264(%rsp), %rdx
	movq	256(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 240(%rsp)
	movq	%rdx, 280(%rsp)
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	8(%rsp), %rdx
	movq	128(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	232(%rsp), %rdx
	movq	272(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 232(%rsp)
	movq	%rdx, 272(%rsp)
	movq	%r12, %rdi
	movq	%rbx, %rsi
	movq	40(%rsp), %r15
	movq	%r15, %rdx
	movq	24(%rsp), %r12
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	8(%rsp), %rdx
	movq	128(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rdx, %rcx
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 8(%rsp)
	movq	%rdx, 128(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 40(%rsp)
	movq	%rdx, 24(%rsp)
	movq	296(%rsp), %rax
	movq	272(%rax), %rbx
	movq	200(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	216(%rsp), %rdx
	movq	208(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	136(%rsp), %rdx
	movq	288(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 200(%rsp)
	movq	%rdx, 224(%rsp)
	movq	56(%rsp), %rax
	movq	2000(%rax), %rdx
	movq	2008(%rax), %rcx
	movq	%r14, %rdi
	movq	%r15, %rsi
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rbx
	movq	%rax, 192(%rsp)
	movq	%rdx, %r14
	movq	%rdx, 184(%rsp)
	movq	120(%rsp), %rax
	movq	32(%rax), %r15
	movq	40(%rax), %r12
	movq	48(%rax), %rdi
	movq	56(%rax), %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 208(%rsp)
	movq	%rdx, 288(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	200(%rsp), %rbx
	movq	%rbx, %rdx
	movq	224(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 136(%rsp)
	movq	%rdx, 216(%rsp)
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r15
	movq	%rdx, %r12
	movq	192(%rsp), %rdi
	movq	184(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%r15, %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	208(%rsp), %rbx
	movq	%rbx, %rdx
	movq	288(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	136(%rsp), %r13
	movq	%r13, %rdx
	movq	216(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 200(%rsp)
	movq	%rdx, 224(%rsp)
	movq	56(%rsp), %rax
	movq	2016(%rax), %r15
	movq	2024(%rax), %r12
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 208(%rsp)
	movq	%rdx, 288(%rsp)
	movq	200(%rsp), %rdi
	movq	224(%rsp), %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r15
	movq	%rdx, %r12
	movq	304(%rsp), %rdi
	movq	312(%rsp), %rsi
	movq	208(%rsp), %rdx
	movq	288(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 136(%rsp)
	movq	%rdx, 216(%rsp)
	movq	240(%rsp), %rdi
	movq	280(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 208(%rsp)
	movq	%rdx, 288(%rsp)
	movq	232(%rsp), %rdi
	movq	272(%rsp), %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 304(%rsp)
	movq	%rdx, 312(%rsp)
	movq	296(%rsp), %rax
	movq	280(%rax), %rbx
	movq	32(%rsp), %rdi
	movq	64(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	96(%rsp), %rdi
	movq	112(%rsp), %rsi
	movq	%rbx, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	152(%rsp), %rdx
	movq	176(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r14
	movq	%rdx, %r15
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	80(%rsp), %rdx
	movq	168(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, 176(%rsp)
	movq	%rdx, 32(%rsp)
	movq	56(%rsp), %rax
	movq	2032(%rax), %rdx
	movq	2040(%rax), %rcx
	movq	%r14, %rdi
	movq	%r15, %rsi
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r14
	movq	%rax, 64(%rsp)
	movq	%rdx, %r15
	movq	%rdx, 96(%rsp)
	movq	120(%rsp), %rax
	movq	64(%rax), %rbx
	movq	72(%rax), %r12
	movq	80(%rax), %rdi
	movq	88(%rax), %rsi
	movq	%rbx, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 80(%rsp)
	movq	%rdx, 152(%rsp)
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	176(%rsp), %r14
	movq	%r14, %rdx
	movq	32(%rsp), %r15
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 120(%rsp)
	movq	%rdx, 296(%rsp)
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%r13, %rdx
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r12
	movq	64(%rsp), %rdi
	movq	96(%rsp), %rsi
	movq	%r14, %rdx
	movq	%r15, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rdx, %rcx
	movq	%rbx, %rdi
	movq	%r12, %rsi
	movq	%rax, %rdx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	80(%rsp), %rbx
	movq	%rbx, %rdx
	movq	152(%rsp), %r14
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, %rdi
	movq	%rdx, %rsi
	movq	120(%rsp), %r13
	movq	%r13, %rdx
	movq	296(%rsp), %rbp
	movq	%rbp, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub
	movq	%rax, 176(%rsp)
	movq	%rdx, 32(%rsp)
	movq	56(%rsp), %rax
	movq	2048(%rax), %r15
	movq	2056(%rax), %r12
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, 56(%rsp)
	movq	%rdx, 80(%rsp)
	movq	176(%rsp), %rdi
	movq	32(%rsp), %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	%r13, %rdi
	movq	%rbp, %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul
	movq	%rax, %r15
	movq	%rdx, %r12
	movq	136(%rsp), %rdi
	movq	216(%rsp), %rsi
	movq	56(%rsp), %rdx
	movq	80(%rsp), %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %r13
	movq	%rdx, %rbp
	movq	208(%rsp), %rdi
	movq	288(%rsp), %rsi
	movq	%rbx, %rdx
	movq	%r14, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	%rax, %rbx
	movq	%rdx, %r14
	movq	304(%rsp), %rdi
	movq	312(%rsp), %rsi
	movq	%r15, %rdx
	movq	%r12, %rcx
	callq	_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add
	movq	352(%rsp), %rcx
	movq	%r13, (%rcx)
	movq	%rbp, 8(%rcx)
	movq	%rbx, 16(%rcx)
	movq	%r14, 24(%rcx)
	movq	%rax, 32(%rcx)
	movq	%rdx, 40(%rcx)
	movq	8(%rsp), %rax
	movq	%rax, 48(%rcx)
	movq	128(%rsp), %rax
	movq	%rax, 56(%rcx)
	movq	40(%rsp), %rax
	movq	%rax, 64(%rcx)
	movq	24(%rsp), %rax
	movq	%rax, 72(%rcx)
	addq	$360, %rsp
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
.Lfunc_end5:
	.size	driven, .Lfunc_end5-driven
	.cfi_endproc

	.ident	"rustc version 1.97.1 (8bab26f4f 2026-07-14)"
	.section	".note.GNU-stack","",@progbits
