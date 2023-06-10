#include <regdef.h>
#include <la32regs.h>
#include <unistd.h>
#include <exception.h>

    .p2align 2
    .text
    .global EXCEPTIONHANDLER
    .global RETURNFRMTRAP

/* 本文件仅在启用异常处理时有用 */

#ifndef ENABLE_INT
FATAL:
EXCEPTIONHANDLER:
RETURNFRMTRAP:
WAKEUPSHELL:
SYSCALL:
    b   FATAL                       // 不支持异常时，这些入口都不应该进入，如果进入就永远等待，用于调试
    nop
#else

    // 遇到不可恢复问题，重启
FATAL:
    // 通知 Term
    li.w a0, 0x80
    b WRITESERIAL

    // 重启
    b START

EXCEPTIONHANDLER:
    // 腾出 sp 寄存器
    csrwr sp, CSR_SAVE0

    // 获取当前线程的中断帧地址
    la.abs sp, current
    ld.w sp, sp, 0

    // 保存寄存器到中断帧
    st.w ra, sp, TF_ra
    st.w tp, sp, TF_tp

    // 真正的 sp 保存在 CSR_SAVE0 中
    csrrd tp, CSR_SAVE0
    st.w tp, sp, TF_sp

    st.w a0, sp, TF_a0
    st.w a1, sp, TF_a1
    st.w a2, sp, TF_a2
    st.w a3, sp, TF_a3
    st.w a4, sp, TF_a4
    st.w a5, sp, TF_a5
    st.w a6, sp, TF_a6
    st.w a7, sp, TF_a7

    st.w t0, sp, TF_t0
    st.w t1, sp, TF_t1
    st.w t2, sp, TF_t2
    st.w t3, sp, TF_t3
    st.w t4, sp, TF_t4
    st.w t5, sp, TF_t5
    st.w t6, sp, TF_t6
    st.w t7, sp, TF_t7
    st.w t8, sp, TF_t8

    st.w rsv, sp, TF_rsv
    st.w fp, sp, TF_fp

    st.w s0, sp, TF_s0
    st.w s1, sp, TF_s1
    st.w s2, sp, TF_s2
    st.w s3, sp, TF_s3
    st.w s4, sp, TF_s4
    st.w s5, sp, TF_s5
    st.w s6, sp, TF_s6
    st.w s7, sp, TF_s7
    st.w s8, sp, TF_s8

    csrrd t0, CSR_ECFG
    st.w t0, sp, TF_ECFG

    csrrd t0, CSR_ERA
    st.w t0, sp, TF_ERA

    csrrd t0, CSR_PRMD
    st.w t0, sp, TF_PRMD

    // 判断异常类型 ESTAT.Ecode
    csrrd t0, CSR_ESTAT
    srli.w t0, t0, 16
    andi t0, t0, 0x3F

    // 如果是中断，则切换到主线程
    li.w t1, EX_IRQ
    beq t1, t0, WAKEUPSHELL

    // 如果是系统调用
    li.w t1, EX_SYS
    beq t1, t0, SYSCALL

    b FATAL                         // 无法处理的中断，出现严重错误

    // 从异常中恢复
RETURNFRMTRAP:
    // 从中断帧恢复 ERA ECFG PRMD
    ld.w t0, sp, TF_ERA
    csrwr t0, CSR_ERA
    ld.w t0, sp, TF_ECFG
    csrwr t0, CSR_ECFG
    ld.w t0, sp, TF_PRMD
    csrwr t0, CSR_PRMD

    // 从中断帧恢复除了 sp 以外的寄存器
    ld.w ra, sp, TF_ra
    ld.w tp, sp, TF_tp

    ld.w a0, sp, TF_a0
    ld.w a1, sp, TF_a1
    ld.w a2, sp, TF_a2
    ld.w a3, sp, TF_a3
    ld.w a4, sp, TF_a4
    ld.w a5, sp, TF_a5
    ld.w a6, sp, TF_a6
    ld.w a7, sp, TF_a7

    ld.w t0, sp, TF_t0
    ld.w t1, sp, TF_t1
    ld.w t2, sp, TF_t2
    ld.w t3, sp, TF_t3
    ld.w t4, sp, TF_t4
    ld.w t5, sp, TF_t5
    ld.w t6, sp, TF_t6
    ld.w t7, sp, TF_t7
    ld.w t8, sp, TF_t8

    ld.w rsv, sp, TF_rsv
    ld.w fp, sp, TF_fp
    ld.w s0, sp, TF_s0
    ld.w s1, sp, TF_s1
    ld.w s2, sp, TF_s2
    ld.w s3, sp, TF_s3
    ld.w s4, sp, TF_s4
    ld.w s5, sp, TF_s5
    ld.w s6, sp, TF_s6
    ld.w s7, sp, TF_s7
    ld.w s8, sp, TF_s8

    // 最后恢复 sp
    ld.w sp, sp, TF_sp
    ertn


WAKEUPSHELL:
    // 获取当前线程 TCB
    la.abs t1, current
    ld.w t1, t1, 0

    // 获取 thread0 线程 TCB
    la.abs t0, TCBT
    ld.w t0, t0, 0

    // 如果当前线程是 thread1，则直接返回
    bne t0, t1, RETURNFRMTRAP

    // 如果当前现场是 thread0，则调度到 thread1
    b SCHEDULE

    // 处理 syscall
SYSCALL:
    // ERA 加四，防止重复执行 syscall 指令
    ld.w t0, sp, TF_ERA
    addi.w t0, t0, 0x4
    st.w t0, sp, TF_ERA

    // 如果是 wait 系统调用
    ld.w t1, sp, TF_a7
    li.w t0, SYS_wait
    beq t1, t0, .syscall_wait

    // 如果是 putc 系统调用
    ld.w t1, sp, TF_a7
    li.w t0, SYS_putc
    beq t1, t0, .syscall_putc

    // 结束异常处理
    b RETURNFRMTRAP

.syscall_wait:
    // 切换到另一个线程
    b SCHEDULE

.syscall_putc:
    // 写串口
    ld.w a0, sp, TF_a0
    bl WRITESERIAL

    // 结束异常处理
    b RETURNFRMTRAP
#endif

#ifdef ENABLE_TLB
    .section .text
    .global TLBREFILL
TLBREFILL:                          // TLB快速重填
    mfc0 k1, CP0_CONTEXT
    lw k0, 0x0(k1)
    lw k1, 0x8(k1)
    mtc0 k0, CP0_ENTRYLO0
    mtc0 k1, CP0_ENTRYLO1
    nop
    tlbwr
    eret
    nop
#endif
