#include <regdef.h>
#include <la32regs.h> 
#include <shell.h>

    .section .bss.uregs
    .p2align 2
    .global uregs
uregs:
    // 保存 31 个通用寄存器以及用户程序入口地址临时保存
    .rept 32
    .long 0
    .endr

    .text
    .p2align 2
    .global SHELL

    //  SHELL: 监控程序交互模块
    // 
    //  用户空间寄存器：$r1-$r31 依次保存在 0x807F0000 连续 124 字节
    //  用户程序入口临时存储：0x807F007C
SHELL:
    // 从 Term 程序读取操作
    bl READSERIAL

    li.w t0, SH_OP_R
    beq a0, t0, .OP_R

    li.w t0, SH_OP_D
    beq a0, t0, .OP_D

    li.w t0, SH_OP_A
    beq a0, t0, .OP_A

    li.w t0, SH_OP_G
    beq a0, t0, .OP_G

    li.w t0, SH_OP_T
    beq a0, t0, .OP_T

    // 错误的操作符，忽略错误
    b .DONE

    // 操作 - 打印 TLB 项
.OP_T:
    // 从 Term 读取 TLB Index
    bl READSERIALWORD

    // 分配栈空间
    addi.w sp, sp, -0x18

#ifdef ENABLE_TLB
    csrwr a0, CSR_TLBIDX
    tlbrd
    // 取出 EntryHi
    csrrd s0, CSR_TLBEHI
    st.w s0, sp, 0xC
    csrrd s0, CSR_TLBELO0
    st.w s0, sp, 0x10
    csrrd s0, CSR_TLBELO1
    st.w s0, sp, 0x14
#else
    // 不支持 TLB 则返回全1
    li.w s0, -1
    st.w s0, sp, 0xC
    st.w s0, sp, 0x10
    st.w s0, sp, 0x14
#endif

    // 打印栈上的 12 字节数据
    li.w s1, 0xC
    // 起始地址
    addi.w s0, sp, 0xC
.LC3:
    ld.w a0, s0, 0
    bl WRITESERIAL
    addi.w s1, s1, -1
    addi.w s0, s0, 1
    bne s1, zero, .LC3

    addi.w sp, sp, 0x18

    b .DONE

    // 操作 - 打印用户空间寄存器
.OP_R:
    // 打印 uregs 124 字节
    la.abs s0, uregs
    li.w s1, 124
.LC0:
    ld.b a0, s0, 0
    bl WRITESERIAL
    addi.w s1, s1, -1
    addi.w s0, s0, 1
    bne s1, zero, .LC0

    b .DONE

    // 操作 - 打印内存 num 字节
.OP_D:

    // 从 Term 读取起始地址
    bl READSERIALWORD
    move s0, a0

    // 从 Term 读取 num
    bl READSERIALWORD
    move s1, a0

    // 循环读取内存，发送数据到串口
.LC1:
    ld.b a0, s0, 0
    bl WRITESERIAL
    addi.w s1, s1, -1
    addi.w s0, s0, 1
    bne s1, zero, .LC1

    b .DONE

    // 操作 - 写入内存 num 字节，num 要求为 4 的倍数
.OP_A:

    // 从 Term 读取起始地址
    bl READSERIALWORD
    move s0, a0

    // 从 Term 读取 num
    bl READSERIALWORD
    move s1, a0

    // 每次循环处理 4 个字节，循环次数等于 num / 4
    srli.w s1, s1, 2
.LC2:
    // 从串口读取 4 个字节
    bl READSERIALWORD
    st.w a0, s0, 0

#ifdef ENABLE_CACOP
    // 有 Cache 时让写入的代码生效
    // L1 ICache
    cacop 0x10, s0, 0
    // L1 DCache
    cacop 0x11, s0, 0
#endif

    addi.w s1, s1, -1
    addi.w s0, s0, 4
    bne s1, zero, .LC2

#ifdef ENABLE_IBAR
    // 有 Cache 时让写入的代码生效
    ibar 0
#endif

    b .DONE

    // 操作 - 运行用户程序
.OP_G:
    // 从 Term 获取用户程序地址
    bl READSERIALWORD
    move s0, a0

    // 向 Term 发送 TIMERSET(0x06)，告诉 Term 用户程序开始运行
    li.w a0, TIMERSET
    bl WRITESERIAL

#ifdef ENABLE_INT
    // 把用户程序入口写入 ERA
    csrwr s0, CSR_ERA
#endif

    la.abs ra, uregs
    // 保存用户程序入口
    st.w s0, ra, PUTREG(32)
    // 保存栈指针
    st.w sp, ra, PUTREG(33)

    // 恢复 $r1-$r31
    // $r1(ra) 最后处理
    // ld.w $r1, ra, PUTREG(1)
    ld.w $r2, ra, PUTREG(2)
    ld.w $r3, ra, PUTREG(3)
    ld.w $r4, ra, PUTREG(4)
    ld.w $r5, ra, PUTREG(5)
    ld.w $r6, ra, PUTREG(6)
    ld.w $r7, ra, PUTREG(7)
    ld.w $r8, ra, PUTREG(8)
    ld.w $r9, ra, PUTREG(9)
    ld.w $r10, ra, PUTREG(10)
    ld.w $r11, ra, PUTREG(11)
    ld.w $r12, ra, PUTREG(12)
    ld.w $r13, ra, PUTREG(13)
    ld.w $r14, ra, PUTREG(14)
    ld.w $r15, ra, PUTREG(15)
    ld.w $r16, ra, PUTREG(16)
    ld.w $r17, ra, PUTREG(17)
    ld.w $r18, ra, PUTREG(18)
    ld.w $r19, ra, PUTREG(19)
    ld.w $r20, ra, PUTREG(20)
    ld.w $r21, ra, PUTREG(21)
    ld.w $r22, ra, PUTREG(22)
    ld.w $r23, ra, PUTREG(23)
    ld.w $r24, ra, PUTREG(24)
    ld.w $r25, ra, PUTREG(25)
    ld.w $r26, ra, PUTREG(26)
    ld.w $r27, ra, PUTREG(27)
    ld.w $r28, ra, PUTREG(28)
    ld.w $r29, ra, PUTREG(29)
    ld.w $r30, ra, PUTREG(30)

#ifdef ENABLE_INT
    // 进入用户程序，可能切换特权级
    // 用户程序 ret 后回到 .USERRET2
    la.abs ra, .USERRET2
    ertn
#else
    // 读取用户程序入口并跳转
    // 用户 ret 后回到 .USERRET2
    ld.w ra, ra, PUTREG(32)
    jirl ra, ra, 0
#endif
.USERRET2:

    // 保存寄存器 $r1-$r30 到 uregs
    la.abs ra, uregs

    st.w $r1, ra, PUTREG(1)
    st.w $r2, ra, PUTREG(2)
    st.w $r3, ra, PUTREG(3)
    st.w $r4, ra, PUTREG(4)
    st.w $r5, ra, PUTREG(5)
    st.w $r6, ra, PUTREG(6)
    st.w $r7, ra, PUTREG(7)
    st.w $r8, ra, PUTREG(8)
    st.w $r9, ra, PUTREG(9)
    st.w $r10, ra, PUTREG(10)
    st.w $r11, ra, PUTREG(11)
    st.w $r12, ra, PUTREG(12)
    st.w $r13, ra, PUTREG(13)
    st.w $r14, ra, PUTREG(14)
    st.w $r15, ra, PUTREG(15)
    st.w $r16, ra, PUTREG(16)
    st.w $r17, ra, PUTREG(17)
    st.w $r18, ra, PUTREG(18)
    st.w $r19, ra, PUTREG(19)
    st.w $r20, ra, PUTREG(20)
    st.w $r21, ra, PUTREG(21)
    st.w $r22, ra, PUTREG(22)
    st.w $r23, ra, PUTREG(23)
    st.w $r24, ra, PUTREG(24)
    st.w $r25, ra, PUTREG(25)
    st.w $r26, ra, PUTREG(26)
    st.w $r27, ra, PUTREG(27)
    st.w $r28, ra, PUTREG(28)
    st.w $r29, ra, PUTREG(29)
    st.w $r30, ra, PUTREG(30)

    // 恢复栈指针
    ld.w sp, ra, PUTREG(33)

    // 发送 TIMETOKEN(0x07) 告诉 Term 用户程序结束运行
    li.w a0, TIMETOKEN
    bl WRITESERIAL

    b .DONE

.DONE:
    b SHELL



