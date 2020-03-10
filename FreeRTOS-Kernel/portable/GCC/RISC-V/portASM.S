/*
 * FreeRTOS Kernel V10.2.1
 * Copyright (C) 2019 Amazon.com, Inc. or its affiliates.  All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * http://www.FreeRTOS.org
 * http://aws.amazon.com/freertos
 *
 * 1 tab == 4 spaces!
 */

/*
 * The FreeRTOS kernel's RISC-V port is split between the the code that is
 * common across all currently supported RISC-V chips (implementations of the
 * RISC-V ISA), and code which tailors the port to a specific RISC-V chip:
 *
 * + The code that is common to all RISC-V chips is implemented in
 *   FreeRTOS\Source\portable\GCC\RISC-V-RV32\portASM.S.  There is only one
 *   portASM.S file because the same file is used no matter which RISC-V chip is
 *   in use.
 *
 * + The code that tailors the kernel's RISC-V port to a specific RISC-V
 *   chip is implemented in freertos_risc_v_chip_specific_extensions.h.  There
 *   is one freertos_risc_v_chip_specific_extensions.h that can be used with any
 *   RISC-V chip that both includes a standard CLINT and does not add to the
 *   base set of RISC-V registers.  There are additional
 *   freertos_risc_v_chip_specific_extensions.h files for RISC-V implementations
 *   that do not include a standard CLINT or do add to the base set of RISC-V
 *   registers.
 *
 * CARE MUST BE TAKEN TO INCLDUE THE CORRECT
 * freertos_risc_v_chip_specific_extensions.h HEADER FILE FOR THE CHIP
 * IN USE.  To include the correct freertos_risc_v_chip_specific_extensions.h
 * header file ensure the path to the correct header file is in the assembler's
 * include path.
 *
 * This freertos_risc_v_chip_specific_extensions.h is for use on RISC-V chips
 * that include a standard CLINT and do not add to the base set of RISC-V
 * registers.
 *
 */

/* ------------------------------------------------------------------
 * This file is part of the FreeRTOS distribution and was contributed
 * to the project by SiFive
 * ------------------------------------------------------------------
 */

#include "FreeRTOSConfig.h"

#ifndef __riscv_xlen
#error Missing __riscv_xlen
#endif

#if __riscv_xlen == 64
	#define store_x sd
	#define load_x ld
#elif __riscv_xlen == 32
	#define store_x sw
	#define load_x lw
#else
	#error __riscv_xlen with an unsupported value
#endif
#include "FreeRTOSConfig.h"

#include "freertos_risc_v_chip_specific_extensions.h"

/* integer registers */
#define portWORD_SIZE        (__riscv_xlen / 8)

#if defined(__riscv_flen)
/* how large are floating point registers */
#define PORT_FPU_REGISTER_SIZEOF  (__riscv_flen / 8)
#endif

/* Number of FPU register */
/* FPU is not yet  supported so PORT_FPU_REGISTER = 0 */
#define portasmFPU_CONTEXT_SIZE	  0

#define PORT_CONTEXT_xIDX(X)		(X) /* index into "raw" for register x? */
#define PORT_CONTEXT_mcauseIDX		(32)
#define PORT_CONTEXT_mepcIDX		(33)
#define PORT_CONTEXT_mstatusIDX		(34)
#define PORT_CONTEXT_rufIDX			(35)
#define PORT_CONTEXT_fpuIDX(X)		(36 + X)
#define PORT_CONTEXT_lastIDX		(36 + portasmFPU_CONTEXT_SIZE + portasmADDITIONAL_CONTEXT_SIZE)

/* used in assembler, as byte offsets from the start of the context */
#define PORT_CONTEXT_xOFFSET( X )   (PORT_CONTEXT_xIDX(X)    * portWORD_SIZE)
#define PORT_CONTEXT_mcauseOFFSET   (PORT_CONTEXT_mcauseIDX  * portWORD_SIZE)
#define PORT_CONTEXT_mepcOFFSET     (PORT_CONTEXT_mepcIDX    * portWORD_SIZE)
#define PORT_CONTEXT_mstatusOFFSET  (PORT_CONTEXT_mstatusIDX * portWORD_SIZE)
#define PORT_CONTEXT_rufOFFSET   	(PORT_CONTEXT_rufIDX  	 * portWORD_SIZE)
#define PORT_CONTEXT_fpuOFFSET(X) 	(PORT_CONTEXT_fpuIDX(X)  * portWORD_SIZE)
/* total size of the structure usable in ASM. */
#define portasmREGISTER_CONTEXT_WORDSIZE		((36) * portWORD_SIZE)
#define portasmADDITIONAL_CONTEXT_WORDSIZE		((portasmADDITIONAL_CONTEXT_SIZE) * portWORD_SIZE )
#define portasmFPU_CONTEXT_WORDSIZE					((portasmFPU_CONTEXT_SIZE) * portWORD_SIZE )

/* Check the freertos_risc_v_chip_specific_extensions.h and/or command line
definitions. */
#ifndef portasmHAS_CLINT
	#error freertos_risc_v_chip_specific_extensions.h must define portasmHAS_CLINT to either 1 (CLINT present) or 0 (clint not present).
#endif

#ifndef portHANDLE_INTERRUPT
	#error portHANDLE_INTERRUPT must be defined to the function to be called to handle external/peripheral interrupts.
#endif

#ifndef portHANDLE_EXCEPTION
	#error portHANDLE_EXCEPTION must be defined to the function to be called to handle execption.
#endif

.global xPortStartFirstTask
.global freertos_risc_v_trap_handler
.global xPortMoveISRStackTop
.global xPortRestoreBeforeFirstTask
.global pxPortInitialiseStack

.extern pxCurrentTCB
.extern vTaskSwitchContext
.extern pullMachineTimerCompareRegister
.extern pullMachineTimerRegister
.extern pullNextTime
.extern uxTimerIncrementsForOneTick /* size_t type so 32-bit on 32-bit core and 64-bits on 64-bit core. */
.extern xISRStackTop

#if( portUSING_MPU_WRAPPERS == 1 )
	.extern vPortPmpSwitch
	.extern xPmpInfo
    .extern privilege_status
#endif

#if( configUSE_SEGGER_SYSTEMVIEW == 1 )
# ifndef SYSVIEW_RECORD_ENTER_ISR
	#error SYSVIEW_RECORD_ENTER_ISR must be defined to the function to be called when you enter into ISR. In basic usage it is define to SEGGER_SYSVIEW_RecordEnterISR 
# endif
# ifndef SYSVIEW_RECORD_EXIT_ISR
	#error SYSVIEW_RECORD_EXIT_ISR must be defined to the function to be called when you enter into ISR. In basic usage it is define to SEGGER_SYSVIEW_RecordExitISR 
# endif
# ifndef SYSVIEW_RECORD_EXIT_ISR_TO_SCHEDULER
	#error SYSVIEW_RECORD_EXIT_ISR_TO_SCHEDULER must be defined to the function to be called when you enter into ISR. In basic usage it is define to SEGGER_SYSVIEW_RecordExitISRToScheduler 
# endif
#endif

/*------------------------------------------------------------------*/
/*
 * Register		ABI Name	Description						Saver
 * x0			zero		Hard-wired zero					-
 * x1			ra			Return address					Caller
 * x2			sp			Stack pointer					Callee
 * x3			gp			Global pointer					-
 * x4			tp			Thread pointer					-
 * x5-7			t0-2		Temporaries						Caller
 * x8			s0/fp		Saved register/Frame pointer	Callee
 * x9			s1			Saved register					Callee
 * x10-11		a0-1		Function arguments/return values Caller
 * x12-17		a2-7		Function arguments				Caller
 * x18-27		s2-11		Saved registers					Callee
 * x28-31		t3-6		Temporaries						Caller
 */

/*-----------------------------------------------------------------*/
.macro portSAVE_FpuReg
	/* Make room for the additional FPU registers. */
	addi sp, sp, -(portasmFPU_CONTEXT_WORDSIZE)
	.endm
/*************************************************************/

.macro portRESTORE_FpuReg
	/* Remove space added for additional fpu registers. */
	addi sp, sp, (portasmFPU_CONTEXT_WORDSIZE)
	.endm
/*************************************************************/

.macro portSAVE_BaseReg
	/* Make room for the registers. */
	addi	sp, sp, -portasmREGISTER_CONTEXT_WORDSIZE
	/* x1(ra)			Return address */
	store_x  x1,  PORT_CONTEXT_xOFFSET(1)(sp)
	/* x2(sp) ***** Should be save ouside this macro */
	/* x3(gp)			Global pointer */
	store_x  x3,  PORT_CONTEXT_xOFFSET(3)(sp)
	/* x4(tp)			Thread pointer */
	store_x  x4,  PORT_CONTEXT_xOFFSET(4)(sp)
	/* x5-7(t0-2)		Temporaries */
	store_x  x5,  PORT_CONTEXT_xOFFSET(5)(sp)
	store_x  x6,  PORT_CONTEXT_xOFFSET(6)(sp)
	store_x  x7,  PORT_CONTEXT_xOFFSET(7)(sp)
	/* x8(s0/fp)		Saved register/Frame pointer */
	store_x  x8,  PORT_CONTEXT_xOFFSET(8)(sp)
	/* x9(s1)			Saved register */
	store_x  x9,  PORT_CONTEXT_xOFFSET(9)(sp)
	/* x10-17(a0-7)		Function arguments */
	store_x  x10, PORT_CONTEXT_xOFFSET(10)(sp)
	store_x  x11, PORT_CONTEXT_xOFFSET(11)(sp)
	store_x  x12, PORT_CONTEXT_xOFFSET(12)(sp)
	store_x  x13, PORT_CONTEXT_xOFFSET(13)(sp)
	store_x  x14, PORT_CONTEXT_xOFFSET(14)(sp)
	store_x  x15, PORT_CONTEXT_xOFFSET(15)(sp)
	store_x  x16, PORT_CONTEXT_xOFFSET(16)(sp)
	store_x  x17, PORT_CONTEXT_xOFFSET(17)(sp)
	/* x18-27(s2-11)		Saved registers */
	store_x  x18, PORT_CONTEXT_xOFFSET(18)(sp)
	store_x  x19, PORT_CONTEXT_xOFFSET(19)(sp)
	store_x  x20, PORT_CONTEXT_xOFFSET(20)(sp)
	store_x  x21, PORT_CONTEXT_xOFFSET(21)(sp)
	store_x  x22, PORT_CONTEXT_xOFFSET(22)(sp)
	store_x  x23, PORT_CONTEXT_xOFFSET(23)(sp)
	store_x  x24, PORT_CONTEXT_xOFFSET(24)(sp)
	store_x  x25, PORT_CONTEXT_xOFFSET(25)(sp)
	store_x  x26, PORT_CONTEXT_xOFFSET(26)(sp)
	store_x  x27, PORT_CONTEXT_xOFFSET(27)(sp)
	/* x28-31(t3-6)		Temporaries */
	store_x  x28, PORT_CONTEXT_xOFFSET(28)(sp)
	store_x  x29, PORT_CONTEXT_xOFFSET(29)(sp)
	store_x  x30, PORT_CONTEXT_xOFFSET(30)(sp)
	store_x  x31, PORT_CONTEXT_xOFFSET(31)(sp)

	/* Save mcause, mepc & mstatus state */
    csrr s2, mcause
	csrr s3, mepc
	csrr s4, mstatus		/* Required for MPIE bit. */
	store_x s2, PORT_CONTEXT_mcauseOFFSET(sp)
	store_x s3, PORT_CONTEXT_mepcOFFSET(sp)
	store_x s4, PORT_CONTEXT_mstatusOFFSET(sp)
	.endm
/*************************************************************/

.macro portRESTORE_BaseReg
	/* Restore mepc & mstatus state */
	load_x  s3, PORT_CONTEXT_mepcOFFSET(sp)
	load_x  s4, PORT_CONTEXT_mstatusOFFSET(sp)
	csrw	mepc, s3
	csrw	mstatus, s4

	/* x1(ra)			Return address */
	load_x  x1,  PORT_CONTEXT_xOFFSET(1)(sp)
	/* x2(sp) ***** Should be restore outside this macro */
	/* x3(gp)			Global pointer */
	load_x  x3,  PORT_CONTEXT_xOFFSET(3)(sp)
	/* x4(tp)			Thread pointer */
	load_x  x4,  PORT_CONTEXT_xOFFSET(4)(sp)
	/* x5-7(t0-2)		Temporaries */
	load_x  x5,  PORT_CONTEXT_xOFFSET(5)(sp)
	load_x  x6,  PORT_CONTEXT_xOFFSET(6)(sp)
	load_x  x7,  PORT_CONTEXT_xOFFSET(7)(sp)
	/* x8(s0/fp)		Saved register/Frame pointer */
	load_x  x8,  PORT_CONTEXT_xOFFSET(8)(sp)
	/* x9(s1)			Saved register */
	load_x  x9,  PORT_CONTEXT_xOFFSET(9)(sp)
	/* x10-17(a0-7)		Function arguments */
	load_x  x10, PORT_CONTEXT_xOFFSET(10)(sp)
	load_x  x11, PORT_CONTEXT_xOFFSET(11)(sp)
	load_x  x12, PORT_CONTEXT_xOFFSET(12)(sp)
	load_x  x13, PORT_CONTEXT_xOFFSET(13)(sp)
	load_x  x14, PORT_CONTEXT_xOFFSET(14)(sp)
	load_x  x15, PORT_CONTEXT_xOFFSET(15)(sp)
	load_x  x16, PORT_CONTEXT_xOFFSET(16)(sp)
	load_x  x17, PORT_CONTEXT_xOFFSET(17)(sp)
	/* x18-27(s2-11)		Saved registers */
	load_x  x18, PORT_CONTEXT_xOFFSET(18)(sp)
	load_x  x19, PORT_CONTEXT_xOFFSET(19)(sp)
	load_x  x20, PORT_CONTEXT_xOFFSET(20)(sp)
	load_x  x21, PORT_CONTEXT_xOFFSET(21)(sp)
	load_x  x22, PORT_CONTEXT_xOFFSET(22)(sp)
	load_x  x23, PORT_CONTEXT_xOFFSET(23)(sp)
	load_x  x24, PORT_CONTEXT_xOFFSET(24)(sp)
	load_x  x25, PORT_CONTEXT_xOFFSET(25)(sp)
	load_x  x26, PORT_CONTEXT_xOFFSET(26)(sp)
	load_x  x27, PORT_CONTEXT_xOFFSET(27)(sp)
	/* x28-31(t3-6)		Temporaries */
	load_x  x28, PORT_CONTEXT_xOFFSET(28)(sp)
	load_x  x29, PORT_CONTEXT_xOFFSET(29)(sp)
	load_x  x30, PORT_CONTEXT_xOFFSET(30)(sp)
	load_x  x31, PORT_CONTEXT_xOFFSET(31)(sp)
	.endm
/*************************************************************/

.align 8
.type   freertos_risc_v_trap_handler, @function
freertos_risc_v_trap_handler:
	/* We do not know if this is an ASYNC or SYNC
	 * If ASYNC, it is a normal interrupt
	 *  and the stack pointer is assumed good.
	 * else (SYNC)
	 *  We could be here due to a bus fault.
	 */
    csrw	mscratch, t0
    csrr	t0, mcause
    blt  	t0, x0, handle_interrupt

handle_exception:
	/* mscratch = old t0
	 * t0 = mcause
	 * mcause = small number 0..16
	 *  0 Instruction address misaligned
	 *  1 Instruction access fault
	 *  2 Illegal instruction
	 *  3 Breakpoint
	 *  4 Load address misaligned
	 *  5 Load access fault
	 *  6 Store/AMO address misaligned
	 *  7 Store/AMO access fault
	 *  8 Environment call from U-mode
	 *  9 Environment call from S-mode
	 *  10 Reserved
	 *  11 Environment call from M-mode
	 *  12 Instruction page fault
	 *  13 Load page fault
	 *  14 Reserved
	 *  15 Store/AMO page fault
	 *  ≥16 Reserved
	 *
	 * if( mcause between 8 and 11  ) we are good - ecall
	 * else: problem
	 */

	addi	t0, t0, -8
	blt		t0, x0, is_exception /* mcause < 8, must be fault */
	addi	t0, t0, -4
#if( portUSING_MPU_WRAPPERS == 1 )
	blt		t0, x0, environment_switch
#else
	blt		t0, x0, ecall_yield
#endif

is_exception:
	/* restore t0 and save sp in mscratch. */
	csrr	t0, mscratch
    csrw	mscratch, sp
	/* Switch to ISR stack before function call. */
	load_x	sp, xISRStackTop			
	portSAVE_BaseReg
	csrrw	t0, mscratch, t0
	/* SP = X2, so save it */
	store_x	t0, PORT_CONTEXT_xOFFSET(2)(sp)

	/* Defined in freertos_risc_v_chip_specific_extensions.h to save any registers unique to the RISC-V implementation. */
	portasmSAVE_ADDITIONAL_REGISTERS

	/* Execption is treated by freedom metal functions */
	jal portHANDLE_EXCEPTION

	portasmRESTORE_ADDITIONAL_REGISTERS
	portRESTORE_BaseReg

	load_x  x2, PORT_CONTEXT_xOFFSET(2)(sp)
	mret

#if( portUSING_MPU_WRAPPERS == 1 )
environment_switch:
	li t0, 4
	bgt	a0,	t0,	ecall_end
	la t0, 1f
	slli	a0, a0, 2
	add t0, t0, a0
	jr t0
1:
	jal x0, ecall_yield
	jal x0, ecall_disable_interrupt
	jal x0, ecall_enable_interrupt
	jal x0, ecall_switch_to_machine
	jal x0, ecall_switch_to_user

ecall_disable_interrupt:
	/* Clear mpie */
	li a0, 0x80
	csrc mstatus, a0
	j ecall_mret

ecall_enable_interrupt:
	/* Set mpie */
	li a0, 0x80
	csrs mstatus, a0
	j ecall_mret

ecall_switch_to_machine:
	/* Set mpp */
	li a0, 0x1800
	csrs mstatus, a0
	j ecall_mret

ecall_switch_to_user:
	/* Clear mpp */
	li a0, 0x1800
	csrc mstatus, a0
	j ecall_mret

ecall_mret:
	/* update privilege_status value */
    csrr t0, mstatus
    li a0, 0x1800
    and t0, t0, a0
    srli t0, t0, 11
    la a0, privilege_status
    sw t0, 0(a0)
	/* Synchronous so updated exception return address to the instruction after the instruction that generated the exeption. */
	csrr t0, mepc
	addi	t0, t0, 4
	csrw	mepc, t0
	/* restore t0 */
	csrr	t0, mscratch
	mret

ecall_end:
        /* unauthorized ecall */
        j       unrecoverable_error
#endif

ecall_yield:
	portSAVE_BaseReg
	/* s2 = mcause
	 * s3 = mepc
	 * s4 = mstatus
	 * s9 will be use for pxCurrentTCB
	 * s11 will be use to save sp
	 */
	/* Synchronous so updated exception return address to the instruction after the instruction that generated the exeption. */
	addi	t0, s3, 4
	store_x	t0, PORT_CONTEXT_mepcOFFSET(sp) 
	/* Store the value of sp when the interrupt occur */
	addi 	t0, sp, portasmREGISTER_CONTEXT_WORDSIZE
	store_x t0, PORT_CONTEXT_xOFFSET(2)(sp)

	/* Defined in freertos_risc_v_chip_specific_extensions.h to save any registers unique to the RISC-V implementation. */
	portasmSAVE_ADDITIONAL_REGISTERS

	/* Load pxCurrentTCB and update first TCB member(pxTopOfStack) with sp. */
	load_x  s9, pxCurrentTCB
	store_x  sp, 0( s9 )

	/* Save sp into s11 */
	mv  s11, sp
	load_x sp, xISRStackTop			/* Switch to ISR stack before function call. */

	j	switch_context

handle_interrupt:
	portSAVE_BaseReg
	/* s2 = mcause
	 * s3 = mepc
	 * s4 = mstatus
	 * s9 will be use for pxCurrentTCB
	 * s11 will be use to save sp
	 */

	/* Store the value of sp when the interrupt occur */
	addi t0, sp, portasmREGISTER_CONTEXT_WORDSIZE
	store_x  t0, PORT_CONTEXT_xOFFSET(2)(sp)

	/* Defined in freertos_risc_v_chip_specific_extensions.h to save any registers unique to the RISC-V implementation. */
	portasmSAVE_ADDITIONAL_REGISTERS

	/* Load pxCurrentTCB and update first TCB member(pxTopOfStack) with sp. */
	load_x  s9, pxCurrentTCB
	store_x  sp, 0( s9 )

	/* Save sp into s11 */
	mv  s11, sp
	load_x sp, xISRStackTop			/* Switch to ISR stack before function call. */

#if( configUSE_SEGGER_SYSTEMVIEW == 1 )
	jal SYSVIEW_RECORD_ENTER_ISR
#endif

#if( portasmHAS_CLINT != 0 )
	addi t0, x0, 1

	slli t0, t0, __riscv_xlen - 1   /* LSB is already set, shift into MSB.  Shift 31 on 32-bit or 63 on 64-bit cores. */
	addi t1, t0, 7					/* 0x8000[]0007 == machine timer interrupt. */
	bne s2, t1, test_if_external_interrupt

	load_x t0, pullMachineTimerCompareRegister  /* Load address of compare register into t0. */
	load_x t1, pullNextTime  		/* Load the address of ullNextTime into t1. */

# if __riscv_xlen == 32 
	/* Update the 64-bit mtimer compare match value in two 32-bit writes. */
	lw 	t2, 0(t1)				/* Load the low word of ullNextTime into t2. */
	lw 	t3, 4(t1)				/* Load the high word of ullNextTime into t3. */
	sw 	t2, 0(t0)				/* Store low word of ullNextTime into compare register. */
	sw 	t3, 4(t0)				/* Store high word of ullNextTime into compare register. */
	lw 	t0, uxTimerIncrementsForOneTick	/* Load the value of ullTimerIncrementForOneTick into t0 (could this be optimized by storing in an array next to pullNextTime?). */
	add t4, t0, t2				/* Add the low word of ullNextTime to the timer increments for one tick (assumes timer increment for one tick fits in 32-bits). */
	sltu t5, t4, t2				/* See if the sum of low words overflowed (what about the zero case?). */
	add t6, t3, t5				/* Add overflow to high word of ullNextTime. */
	sw 	t4, 0(t1)				/* Store new low word of ullNextTime. */
	sw 	t6, 4(t1)				/* Store new high word of ullNextTime. */
# elif __riscv_xlen == 64 
	/* Update the 64-bit mtimer compare match value. */
	ld 	t2, 0(t1)			 	/* Load ullNextTime into t2. */
	sd 	t2, 0(t0)				/* Store ullNextTime into compare register. */
	ld 	t0, uxTimerIncrementsForOneTick  /* Load the value of ullTimerIncrementForOneTick into t0 (could this be optimized by storing in an array next to pullNextTime?). */
	add 	t4, t0, t2				/* Add ullNextTime to the timer increments for one tick. */
	sd 	t4, 0(t1)				/* Store ullNextTime. */
# endif /* __riscv_xlen == 64 */

	jal xTaskIncrementTick
	beqz a0, restore_before_exit		/* Don't switch context if incrementing tick didn't unblock a task. */
	j switch_context

restore_before_exit:
#if( configUSE_SEGGER_SYSTEMVIEW == 1 )
	jal SYSVIEW_RECORD_EXIT_ISR
#endif
	mv  sp, s11
	j end_trap_handler

test_if_external_interrupt:			/* If there is a CLINT and the mtimer interrupt is not pending then check to see if an external interrupt is pending. */
	addi t1, t1, 4					/* 0x80000007 + 4 = 0x8000000b == Machine external interrupt. */
	bne s2, t1, unrecoverable_error	/* Something as yet unhandled. */
	j unrecoverable_error

#endif /* portasmHAS_CLINT */

external_interrupt:
	csrr 	a0, mhartid
	mv		a1, s2
	mv 		a2, s5
	/* Switch to ISR stack before function call. */
	load_x sp, xISRStackTop
	jal portHANDLE_INTERRUPT
	mv	sp, s11
	j end_trap_handler

unrecoverable_error:
	wfi
	j unrecoverable_error

switch_context:
	jal	vTaskSwitchContext
#if( configUSE_SEGGER_SYSTEMVIEW == 1 )
	jal SYSVIEW_RECORD_EXIT_ISR_TO_SCHEDULER
#endif
	load_x s9, pxCurrentTCB			/* Load pxCurrentTCB. */
	load_x  sp, 0( s9 )				/* Read sp from first TCB member. */
#if( portUSING_MPU_WRAPPERS == 1 )
	lw a0, xPmpInfo
    li a1, 3
    sub a0, a0, a1
    addi a1, s9, 4
    jal vPortPmpSwitch   
	fence.i
#endif

end_trap_handler:	
	load_x  t1, PORT_CONTEXT_xOFFSET(2)(sp)
	store_x  t1, 0( s9 )				/* Write sp saved value to first TCB member. */

#if( portUSING_MPU_WRAPPERS == 1 )
	load_x  t0, PORT_CONTEXT_mstatusOFFSET(sp)
    li a0, 0x1800
    and t0, t0, a0
    srli t0, t0, 11
    la a0, privilege_status
    sw t0, 0(a0)
#endif

	portasmRESTORE_ADDITIONAL_REGISTERS
	portRESTORE_BaseReg
	load_x  x2, PORT_CONTEXT_xOFFSET(2)(sp)
	mret
/*-----------------------------------------------------------*/

.align 8
.type   xPortStartFirstTask, @function
xPortStartFirstTask:
	/*
	 * Save all register to space before xISRStackTop (it should be prepared by vPortFreeRTOSInit).
	 * It will be restored when vPortEndScheduler will be call
	 */
    csrw	mscratch, sp

	load_x  sp, xISRStackTop
	addi sp, sp, portasmADDITIONAL_CONTEXT_WORDSIZE 
	addi sp, sp, portasmREGISTER_CONTEXT_WORDSIZE

	portSAVE_BaseReg

	csrrw	t0, mscratch, t0
	/* SP = X2, so save it */
	store_x	t0, PORT_CONTEXT_xOFFSET(2)(sp)
	/* x1			ra			Return address */
	store_x  x1,  PORT_CONTEXT_xOFFSET(1)(sp)

	/* Defined in freertos_risc_v_chip_specific_extensions.h to save any registers unique to the RISC-V implementation. */
	portasmSAVE_ADDITIONAL_REGISTERS

	/** Set all register to the FirstTask context */
	load_x  t2, pxCurrentTCB			/* Load pxCurrentTCB. */
	load_x  sp, 0( t2 )				 	/* Read sp from first TCB member. */

#if( portUSING_MPU_WRAPPERS == 1 )
	load_x  t1, PORT_CONTEXT_mstatusOFFSET(sp)
    li a0, 0x1800
    and t1, t1, a0
    srli t1, t1, 11
    la a0, privilege_status
    sw t1, 0(a0)

	lw a0, xPmpInfo
    li a1, 3
    sub a0, a0, a1
	addi a1, t2, 4
	jal vPortPmpSwitch
# endif
	
	load_x  t2, pxCurrentTCB                        /* Load pxCurrentTCB. */

	/* Restore first TCB member */
	load_x  t1,  PORT_CONTEXT_xOFFSET(2)(sp)
	store_x  t1, 0( t2 )				/* Write sp saved value to first TCB member. */

	load_x t0, pullMachineTimerRegister  /* Load address of compare register into t0. */
	load_x t1, pullNextTime  		/* Load the address of ullNextTime into t1. */

# if __riscv_xlen == 32 
		/* Read the 64-bit mtimer match value in two 32-bit writes. */
		lw t3, 4(t0)				/* Load mtimer register high address. */
first_task_timer_loop:
		lw t2, 0(t0)				/* Load mtimer register low address. */
		mv t4, t3
		lw t3, 4(t0)				/* Load mtimer register high address. */
		bne t4, t3, first_task_timer_loop

		lw t0, uxTimerIncrementsForOneTick	/* Load the value of ullTimerIncrementForOneTick into t0 (could this be optimized by storing in an array next to pullNextTime?). */
		add t4, t0, t2				/* Add the low word of mtimer for one tick (assumes timer increment for one tick fits in 32-bits). */
		sltu t5, t4, t2				/* See if the sum of low words overflowed (what about the zero case?). */
		add t6, t3, t5				/* Add overflow to high word of mtimer. */
	
		load_x t2, pullMachineTimerCompareRegister  /* Load address of compare register into t0. */
		sw t4, 0(t2)				/* Store new low word of ullNextTime. */
		sw t6, 4(t2)				/* Store new high word of ullNextTime. */

		add t2, t0, t4				/* Add the low word of ullNextTime to the timer increments for one tick (assumes timer increment for one tick fits in 32-bits). */
		sltu t5, t2, t4				/* See if the sum of low words overflowed (what about the zero case?). */
		add t3, t6, t5				/* Add overflow to high word of ullNextTime. */
		sw t2, 0(t1)				/* Store new low word of ullNextTime. */
		sw t3, 4(t1)				/* Store new high word of ullNextTime. */

# elif __riscv_xlen == 64 
		/* Read the 64-bit mtimer */
		ld t2, 0(t0)			 	/* Load mtimer register into t2. */
		ld t3, uxTimerIncrementsForOneTick  /* Load the value of ullTimerIncrementForOneTick into t0 (could this be optimized by storing in an array next to pullNextTime?). */
		add t4, t3, t2				/* Add ullNextTime to the timer increments for one tick. */
		load_x t2, pullMachineTimerCompareRegister  /* Load address of compare register into t0. */
		sd t4, 0(t2)				/* Store ullNextTime into compare register. */
		/* Update the 64-bit mtimer compare match value. */
		add t4, t3, t4				/* Add ullNextTime to the timer increments for one tick. */
		sd t4, 0(t1)				/* Store ullNextTime. */
# endif /* __riscv_xlen == 64 */

	/* enable interrupt */
	li t0, 0x880
	csrs mie, t0

	portasmRESTORE_ADDITIONAL_REGISTERS
	portRESTORE_BaseReg

	load_x  ra, PORT_CONTEXT_mepcOFFSET(sp) /* Note for starting the scheduler the exception return address is used as the function return address. */
	load_x  x2, PORT_CONTEXT_xOFFSET(2)(sp)
	mret
/*-----------------------------------------------------------*/


/**
 * StackType_t *pxPortInitialiseStack( StackType_t *pxTopOfStack, TaskFunction_t pxCode, void *pvParameters )
 * StackType_t *pxPortInitialiseStack( StackType_t *pxTopOfStack, TaskFunction_t pxCode, void *pvParameters, BaseType_t xRunPrivileged ) PRIVILEGED_FUNCTION
 **/
//#if( portUSING_MPU_WRAPPERS == 1 )
//.section .privileged_functions
//#endif
.align 8
.type   pxPortInitialiseStack, @function
pxPortInitialiseStack:
	/*
	 * To maintain RISCV ABI stack alignment requirements(16bytes)
	 * this data structure must be a MULTIPLE of 16 bytes in size.
	 * 32 Registers is 16byte aligned :)
	 * We add portADDITIONAL_CONTEXT_REGS  that Must be multiple of 4.
	 * mcause 33rd register
	 * mepc 34th register 
	 * mstatus 35th register
	 * ruf 36th register
	 */
	/* Obtain current mstatus value. */
	csrr t0, mstatus
	/* Generate the value 0x1880, which are the MPIE and MPP bits to set in mstatus. */
	addi t1, x0, 0x188
	slli t1, t1, 4
	/* reset previous value */
	not t2, t1
	and t0, t0, t2
	/* Generate the value 0x1880, which are the MPIE and MPP bits to set in mstatus. */
#if( portUSING_MPU_WRAPPERS == 1 )
	mv t1, x0
	beqz a3, 1f
	addi t1, t1, 0x180
1:	
	ori t1, t1, 0x8
#else
	addi t1, x0, 0x188
#endif
	slli t1, t1, 4
	/* Set MPIE and MPP bits in mstatus value. */
	or t0, t0, t1

	/* Make room for the registers. */
	addi	t2, a0, -portasmREGISTER_CONTEXT_WORDSIZE
	/* x1(ra)			Return address */
	store_x  x0,  PORT_CONTEXT_xOFFSET(1)(t2)
	/* x2(sp) ***** Should be save ouside this macro */
	store_x  a0,  PORT_CONTEXT_xOFFSET(2)(t2)
	/* x3(gp)			Global pointer */
	store_x  x3,  PORT_CONTEXT_xOFFSET(3)(t2)
	/* x4(tp)			Thread pointer */
	store_x  x4,  PORT_CONTEXT_xOFFSET(4)(t2)
	/* x5-7(t0-2)		Temporaries */
	store_x  x0,  PORT_CONTEXT_xOFFSET(5)(t2)
	store_x  x0,  PORT_CONTEXT_xOFFSET(6)(t2)
	store_x  x0,  PORT_CONTEXT_xOFFSET(7)(t2)
	/* x8(s0/fp)		Saved register/Frame pointer */
	store_x  x0,  PORT_CONTEXT_xOFFSET(8)(t2)
	/* x9(s1)			Saved register */
	store_x  x0,  PORT_CONTEXT_xOFFSET(9)(t2)
	/* x10-17(a0-7)		Function arguments */
	store_x  a2, PORT_CONTEXT_xOFFSET(10)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(11)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(12)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(13)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(14)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(15)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(16)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(17)(t2)
	/* x18-27(s2-11)		Saved registers */
	store_x  x0, PORT_CONTEXT_xOFFSET(18)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(19)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(20)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(21)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(22)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(23)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(24)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(25)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(26)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(27)(t2)
	/* x28-31(t3-6)		Temporaries */
	store_x  x0, PORT_CONTEXT_xOFFSET(28)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(29)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(30)(t2)
	store_x  x0, PORT_CONTEXT_xOFFSET(31)(t2)

	store_x x0, PORT_CONTEXT_mcauseOFFSET(t2)
	store_x a1, PORT_CONTEXT_mepcOFFSET(t2)
	store_x t0, PORT_CONTEXT_mstatusOFFSET(t2)
	store_x x0, PORT_CONTEXT_rufOFFSET(t2)

	/* The number of chip fpu additional registers. */
	addi t0, x0, portasmFPU_CONTEXT_SIZE 
chip_fpu_stack_frame:
	beq t0, x0, 1f
	addi t2, t2, -portWORD_SIZE
	store_x x0, 0(t2)
	addi t0, t0, -1
	j chip_fpu_stack_frame
1:

	addi t0, x0, portasmADDITIONAL_CONTEXT_SIZE /* The number of chip specific additional registers. */
chip_specific_stack_frame:				/* First add any chip specific registers to the stack frame being created. */
	beq t0, x0, 1f						/* No more chip specific registers to save. */
	addi t2, t2, -portWORD_SIZE			/* Make space for chip specific register. */
	store_x x0, 0(t2)					/* Give the chip specific register an initial value of zero. */
	addi t0, t0, -1						/* Decrement the count of chip specific registers remaining. */
	j chip_specific_stack_frame			/* Until no more chip specific registers. */
1:
	mv a0, t2
	ret
//#if( portUSING_MPU_WRAPPERS == 1 )
//.section .text
//#endif
/*-----------------------------------------------------------*/

/**
 * void xPortRestoreBeforeFirstTask(void)
 */
.align 8
.type   xPortRestoreBeforeFirstTask, @function
xPortRestoreBeforeFirstTask:
	load_x  sp, xISRStackTop
	portasmRESTORE_ADDITIONAL_REGISTERS
	portRESTORE_BaseReg
	load_x  x2, PORT_CONTEXT_xOFFSET(2)(sp)
	ret
/*-----------------------------------------------------------*/

/**
 * BaseType_t xPortMoveISRStackTop( StackType_t *xISRStackTop);
 */
.align 8
.type   xPortMoveISRStackTop, @function
xPortMoveISRStackTop:	
	load_x	t0, 0(a0)
	beqz t0, 1f
	addi t1, x0, portasmREGISTER_CONTEXT_WORDSIZE
	addi t2, t1, portasmADDITIONAL_CONTEXT_WORDSIZE 
	bltu t2, t1, 1f
	addi t1, t2, portWORD_SIZE 
	bltu t1, t2, 1f
	bgtu t1, t0, 1f
	sub	t1, t0, t1
	store_x	t1, 0(a0)
	mv a0, t1
	j 2f
1:
	li	a0, 0
2:
	ret
/*-----------------------------------------------------------*/

/*
 * Unlike other ports pxPortInitialiseStack() is written in assembly code as it
 * needs access to the portasmADDITIONAL_CONTEXT_SIZE constant.  The prototype
 * for the function is as per the other ports:
 * StackType_t *pxPortInitialiseStack( StackType_t *pxTopOfStack, TaskFunction_t pxCode, void *pvParameters );
 *
 * As per the standard RISC-V ABI pxTopcOfStack is passed in in a0, pxCode in
 * a1, and pvParameters in a2.  The new top of stack is passed out in a0.
 *
 * RISC-V maps registers to ABI names as follows (X1 to X31 integer registers
 * for the 'I' profile, X1 to X15 for the 'E' profile, currently I assumed).
 *
 * Register		ABI Name	Description						Saver
 * x0			zero		Hard-wired zero					-
 * x1			ra			Return address					Caller
 * x2			sp			Stack pointer					Callee
 * x3			gp			Global pointer					-
 * x4			tp			Thread pointer					-
 * x5-7			t0-2		Temporaries						Caller
 * x8			s0/fp		Saved register/Frame pointer	Callee
 * x9			s1			Saved register					Callee
 * x10-11		a0-1		Function Arguments/return values Caller
 * x12-17		a2-7		Function arguments				Caller
 * x18-27		s2-11		Saved registers					Callee
 * x28-31		t3-6		Temporaries						Caller
 *
 */

/*-----------------------------------------------------------*/
