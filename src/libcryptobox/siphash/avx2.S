/*-
 * Copyright 2015 Google Inc. All Rights Reserved.
 * Copyright 2016 Vsevolod Stakhov
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#include "../macro.S"
#include "constants.S"

/*
 * Generated by clang-3.8 from siphash avx2 implementation written by
 * Jan Wassenberg and Jyrki Alakuijala
 */

SECTION_TEXT

GLOBAL_HIDDEN_FN siphash_avx2
siphash_avx2_local:
	.cfi_startproc
## BB#0:                                ## %entry
	pushq	%rbp
Ltmp0:
	.cfi_def_cfa_offset 16
Ltmp1:
	.cfi_offset %rbp, -16
	movq	%rsp, %rbp
Ltmp2:
	.cfi_def_cfa_register %rbp
	pushq	%rbx
	subq	$40, %rsp
Ltmp3:
	.cfi_offset %rbx, -24
	movq	%rdx, %rbx
	vmovdqu	(%rdi), %xmm0
	vpxor	LCPI0_0(%rip), %xmm0, %xmm1
	vpxor	LCPI0_1(%rip), %xmm0, %xmm0
	vpunpcklqdq	%xmm0, %xmm1, %xmm6 ## xmm6 = xmm1[0],xmm0[0]
	vpunpckhqdq	%xmm0, %xmm1, %xmm7 ## xmm7 = xmm1[1],xmm0[1]
	movq	%rbx, %rax
	andq	$-8, %rax
	je	LBB0_1
## BB#2:                                ## %for.body.preheader
	xorl	%ecx, %ecx
	vmovdqa	LCPI0_2(%rip), %xmm0    ## xmm0 = [13,16]
	vmovdqa	LCPI0_3(%rip), %xmm1    ## xmm1 = [51,48]
	vmovdqa	LCPI0_4(%rip), %xmm2    ## xmm2 = [17,21]
	vmovdqa	LCPI0_5(%rip), %xmm3    ## xmm3 = [47,43]
	.align	4, 0x90
LBB0_3:                                 ## %for.body
                                        ## =>This Inner Loop Header: Depth=1
	vmovq	(%rsi,%rcx), %xmm4      ## xmm4 = mem[0],zero
	vpslldq	$8, %xmm4, %xmm5        ## xmm5 = zero,zero,zero,zero,zero,zero,zero,zero,xmm4[0,1,2,3,4,5,6,7]
	vpxor	%xmm5, %xmm7, %xmm5
	vpaddq	%xmm6, %xmm5, %xmm6
	vpsllvq	%xmm0, %xmm5, %xmm7
	vpsrlvq	%xmm1, %xmm5, %xmm5
	vpor	%xmm7, %xmm5, %xmm5
	vpxor	%xmm6, %xmm5, %xmm5
	vpshufd	$30, %xmm6, %xmm6       ## xmm6 = xmm6[2,3,1,0]
	vpaddq	%xmm5, %xmm6, %xmm6
	vpsllvq	%xmm2, %xmm5, %xmm7
	vpsrlvq	%xmm3, %xmm5, %xmm5
	vpor	%xmm7, %xmm5, %xmm5
	vpxor	%xmm6, %xmm5, %xmm5
	vpshufd	$30, %xmm6, %xmm6       ## xmm6 = xmm6[2,3,1,0]
	vpaddq	%xmm5, %xmm6, %xmm6
	vpsllvq	%xmm0, %xmm5, %xmm7
	vpsrlvq	%xmm1, %xmm5, %xmm5
	vpor	%xmm7, %xmm5, %xmm5
	vpxor	%xmm6, %xmm5, %xmm5
	vpshufd	$30, %xmm6, %xmm6       ## xmm6 = xmm6[2,3,1,0]
	vpaddq	%xmm5, %xmm6, %xmm6
	vpsllvq	%xmm2, %xmm5, %xmm7
	vpsrlvq	%xmm3, %xmm5, %xmm5
	vpor	%xmm7, %xmm5, %xmm5
	vpxor	%xmm6, %xmm5, %xmm7
	vpshufd	$30, %xmm6, %xmm5       ## xmm5 = xmm6[2,3,1,0]
	vpxor	%xmm5, %xmm4, %xmm6
	addq	$8, %rcx
	cmpq	%rax, %rcx
	jb	LBB0_3
## BB#4:                                ## %for.end.loopexit
	vmovdqa	%xmm7, -48(%rbp)        ## 16-byte Spill
	vmovdqa	%xmm6, -32(%rbp)        ## 16-byte Spill
	addq	%rax, %rsi
	jmp	LBB0_5
LBB0_1:
	vmovdqa	%xmm7, -48(%rbp)        ## 16-byte Spill
	vmovdqa	%xmm6, -32(%rbp)        ## 16-byte Spill
	xorl	%eax, %eax
LBB0_5:                                 ## %for.end
	movq	$0, -16(%rbp)
	movq	%rbx, %rdx
	subq	%rax, %rdx
	leaq	-16(%rbp), %rdi
	movq	%rdx, %rcx
	shrq	$2, %rcx
	rep;	movsl
	movq	%rdx, %rcx
	andq	$3, %rcx
	rep;	movsb
	movb	%bl, -9(%rbp)
	vmovq	-16(%rbp), %xmm4        ## xmm4 = mem[0],zero
	vpslldq	$8, %xmm4, %xmm0        ## xmm0 = zero,zero,zero,zero,zero,zero,zero,zero,xmm4[0,1,2,3,4,5,6,7]
	vpxor	-48(%rbp), %xmm0, %xmm2 ## 16-byte Folded Reload
	vpaddq	-32(%rbp), %xmm2, %xmm3 ## 16-byte Folded Reload
	vmovdqa	LCPI0_2(%rip), %xmm0    ## xmm0 = [13,16]
	vpsllvq	%xmm0, %xmm2, %xmm5
	vmovdqa	LCPI0_3(%rip), %xmm1    ## xmm1 = [51,48]
	vpsrlvq	%xmm1, %xmm2, %xmm2
	vpor	%xmm5, %xmm2, %xmm2
	vpxor	%xmm3, %xmm2, %xmm5
	vpshufd	$30, %xmm3, %xmm2       ## xmm2 = xmm3[2,3,1,0]
	vpaddq	%xmm5, %xmm2, %xmm6
	vmovdqa	LCPI0_4(%rip), %xmm2    ## xmm2 = [17,21]
	vpsllvq	%xmm2, %xmm5, %xmm7
	vmovdqa	LCPI0_5(%rip), %xmm3    ## xmm3 = [47,43]
	vpsrlvq	%xmm3, %xmm5, %xmm5
	vpor	%xmm7, %xmm5, %xmm5
	vpxor	%xmm6, %xmm5, %xmm5
	vpshufd	$30, %xmm6, %xmm6       ## xmm6 = xmm6[2,3,1,0]
	vpaddq	%xmm5, %xmm6, %xmm6
	vpsllvq	%xmm0, %xmm5, %xmm7
	vpsrlvq	%xmm1, %xmm5, %xmm5
	vpor	%xmm7, %xmm5, %xmm5
	vpxor	%xmm6, %xmm5, %xmm5
	vpshufd	$30, %xmm6, %xmm6       ## xmm6 = xmm6[2,3,1,0]
	vpaddq	%xmm5, %xmm6, %xmm6
	vpsllvq	%xmm2, %xmm5, %xmm7
	vpsrlvq	%xmm3, %xmm5, %xmm5
	vpor	%xmm7, %xmm5, %xmm5
	vpxor	%xmm6, %xmm5, %xmm5
	vpshufd	$30, %xmm6, %xmm6       ## xmm6 = xmm6[2,3,1,0]
	movl	$255, %eax
	vmovq	%rax, %xmm7
	vpslldq	$8, %xmm7, %xmm7        ## xmm7 = zero,zero,zero,zero,zero,zero,zero,zero,xmm7[0,1,2,3,4,5,6,7]
	vpxor	%xmm7, %xmm4, %xmm4
	vpxor	%xmm4, %xmm6, %xmm4
	vpaddq	%xmm5, %xmm4, %xmm4
	vpsllvq	%xmm0, %xmm5, %xmm6
	vpsrlvq	%xmm1, %xmm5, %xmm5
	vpor	%xmm6, %xmm5, %xmm5
	vpxor	%xmm4, %xmm5, %xmm5
	vpshufd	$30, %xmm4, %xmm4       ## xmm4 = xmm4[2,3,1,0]
	vpaddq	%xmm5, %xmm4, %xmm4
	vpsllvq	%xmm2, %xmm5, %xmm6
	vpsrlvq	%xmm3, %xmm5, %xmm5
	vpor	%xmm6, %xmm5, %xmm5
	vpxor	%xmm4, %xmm5, %xmm5
	vpshufd	$30, %xmm4, %xmm4       ## xmm4 = xmm4[2,3,1,0]
	vpaddq	%xmm5, %xmm4, %xmm4
	vpsllvq	%xmm0, %xmm5, %xmm6
	vpsrlvq	%xmm1, %xmm5, %xmm5
	vpor	%xmm6, %xmm5, %xmm5
	vpxor	%xmm4, %xmm5, %xmm5
	vpshufd	$30, %xmm4, %xmm4       ## xmm4 = xmm4[2,3,1,0]
	vpaddq	%xmm5, %xmm4, %xmm4
	vpsllvq	%xmm2, %xmm5, %xmm6
	vpsrlvq	%xmm3, %xmm5, %xmm5
	vpor	%xmm6, %xmm5, %xmm5
	vpxor	%xmm4, %xmm5, %xmm5
	vpshufd	$30, %xmm4, %xmm4       ## xmm4 = xmm4[2,3,1,0]
	vpaddq	%xmm5, %xmm4, %xmm4
	vpsllvq	%xmm0, %xmm5, %xmm6
	vpsrlvq	%xmm1, %xmm5, %xmm5
	vpor	%xmm6, %xmm5, %xmm5
	vpxor	%xmm4, %xmm5, %xmm5
	vpshufd	$30, %xmm4, %xmm4       ## xmm4 = xmm4[2,3,1,0]
	vpaddq	%xmm5, %xmm4, %xmm4
	vpsllvq	%xmm2, %xmm5, %xmm6
	vpsrlvq	%xmm3, %xmm5, %xmm5
	vpor	%xmm6, %xmm5, %xmm5
	vpxor	%xmm4, %xmm5, %xmm5
	vpshufd	$30, %xmm4, %xmm4       ## xmm4 = xmm4[2,3,1,0]
	vpaddq	%xmm5, %xmm4, %xmm4
	vpsllvq	%xmm0, %xmm5, %xmm0
	vpsrlvq	%xmm1, %xmm5, %xmm1
	vpor	%xmm0, %xmm1, %xmm0
	vpxor	%xmm4, %xmm0, %xmm0
	vpshufd	$30, %xmm4, %xmm1       ## xmm1 = xmm4[2,3,1,0]
	vpaddq	%xmm0, %xmm1, %xmm1
	vpsllvq	%xmm2, %xmm0, %xmm2
	vpsrlvq	%xmm3, %xmm0, %xmm0
	vpor	%xmm2, %xmm0, %xmm0
	vpshufd	$30, %xmm1, %xmm2       ## xmm2 = xmm1[2,3,1,0]
	vpxor	%xmm2, %xmm1, %xmm1
	vpxor	%xmm1, %xmm0, %xmm0
	vpshufd	$78, %xmm0, %xmm1       ## xmm1 = xmm0[2,3,0,1]
	vpxor	%xmm1, %xmm0, %xmm0
	vmovq	%xmm0, %rax
	addq	$40, %rsp
	popq	%rbx
	popq	%rbp
	retq
	.cfi_endproc
FN_END siphash_avx2
