#include <regdef.h>
#include <la32regs.h>
#include <unistd.h>
#include <exception.h>

    .section .bss
    .p2align 2
    // TCBT(thread control block table)
    // 每个线程对应一个 32 位地址，系统中有两个线程：
    // thread0(idle)
    // thread1(shell/user)
    .global TCBT
TCBT:
    .long 0
    .long 0

    // 当前线程的 thread control block 地址
    .global current
current:
    .long 0

#ifdef ENABLE_TLB                   // 声明页表
    .section .bss.ptes
    .global PTECODE
    .global PTESTACK
    .p2align 12
    // RAM0: 0x00000000 - 0x002FFFFF
    //     ->0x00100000 - 0x003FFFFF
    // 共 768 个页，每两个页需要保存 8 字节数据
    // 一共 3072 字节
PTECODE:
    .rept PTECODE_SIZE / 4
    .long 0
    .endr

    .p2align 12
    // RAM1: 0x7FC10000 - 0x7FFFFFFF
    //     ->0x00400000 - 0x007EFFFF
    // 共 1008 个页，每两个页需要保存 8 字节数据
    // 一共 4032 字节
PTESTACK:
    .rept PTESTACK_SIZE / 4
    .long 0
    .endr
#endif

    .section .rodata
    .p2align 2
monitor_version:
    .asciz "MONITOR for LA32R - initialized."

    // 从 0x80000000 地址启动
    .section .text.init
    .p2align 2
    .global START
START:

    // .bss 清零
    la.abs t0, _sbss
    la.abs t1, _sbss
bss_init:
    beq t0, t1, bss_init_done
    st.w zero, t0, 0
    addi.w t0, t0, 4
    b   bss_init

bss_init_done:
#ifdef ENABLE_INT
    // 设置异常处理函数
    la.abs t0, EXCEPTIONHANDLER
    csrwr t0, CSR_EENTRY
#endif

    // 设置内核栈
    la.abs sp, KERNEL_STACK_INIT
    la.abs fp, KERNEL_STACK_INIT

    // 把初始用户栈地址写入 uregs_sp & uregs_fp
    la.abs t0, USER_STACK_INIT
    la.abs t1, uregs_sp
    st.w t0, t1, 0
    la.abs t1, uregs_fp
    st.w t0, t1, 0

    // 配置直接映射窗口
    // 0x80000000-0x9FFFFFFF: 映射到 0x00000000-0x1FFFFFFF
    // 访问类型为一致可缓存
    // 对应 CSR.DMW0=0x80000011
    li.w t0, 0x80000011
    csrwr t0, CSR_DMW0
    // 0xA0000000-0xBFFFFFFF: 映射到 0x00000000-0x1FFFFFFF
    // 访问类型为强序非缓存
    // 对应 CSR.DMW1=0xA0000001
    li.w t0, 0xA0000011
    csrwr t0, CSR_DMW1

    // 初始化 QEMU 串口
#ifdef MACH_QEMU
    la.abs t0, COM1

    // COM_FCR(2) = 0x07(Enable FIFO, clear tx & rx FIFO)
    li.w t1, 0x07
    st.b t1, t0, 2

    // COM_LCR(3) = 0x80(Set DLAB=1)
    li.w t1, 0x80
    st.b t1, t0, 3

    // COM_DLL(0) = 0x1(115200 baud)
    li.w t1, 0x01
    st.b t1, t0, 0

    // COM_DLM(1) = 0x0(115200 baud)
    li.w t1, 0x00
    st.b t1, t0, 1

    // COM_LCR(3) = 0x3(Set DLAB=0, 8 bits, no party, 1 stop bit)
    li.w t1, 0x03
    st.b t1, t0, 3

    // COM_MCR(4) = 0x0(Data terminal ready)
    li.w t1, 0x00
    st.b t1, t0, 4

    // COM_IER(1) = 0x1(Received data available)
    li.w t1, 0x01
    st.b t1, t0, 1
#endif

    // 在栈上预留大小为 TF_SIZE 空间且清零
    li.w t0, TF_SIZE / 4
.LC0:
    addi.w t0, t0, -1
    addi.w sp, sp, -4
    st.w zero, sp, 0
    bne t0, zero, .LC0

    // 把 thread0(idle) 的异常帧地址设为当前栈地址
    la.abs t0, TCBT
    st.w sp, t0, 0

#ifdef ENABLE_INT
    // 在 thread0(idle) 线程中允许串口中断 LIE[3]=1
    li.w t1, 0x8
    st.w t1, sp, TF_ECFG

    // 在 thread0(idle) 线程中打开全局中断 PIE=1 且运行在特权态 PPLV=0
    li.w t1, 0x4
    st.w t1, sp, TF_PRMD

    // 设置 thread0(idle) 用户态入口为 IDLELOOP
    la.abs t3, IDLELOOP
    st.w t3, sp, TF_ERA
#endif

    // t6 寄存器保存 idle 异常帧位置
    move t6, sp

    // 在栈上预留大小为 TF_SIZE 空间且清零
    li.w t0, TF_SIZE / 4
.LC1:
    addi.w t0, t0, -1
    addi.w sp, sp, -4
    st.w zero, sp, 0
    bne t0, zero, .LC1

    // 把 thread1(shell/user) 的异常帧地址设为当前栈地址
    la.abs t0, TCBT
    st.w sp, t0, 4

    // 设置当前线程为 thread1
    la.abs t0, current
    st.w sp, t0, 0

#ifdef ENABLE_TLB
    // 用户栈设置为 0x80000000
    li.w t0, 0x80000000
    la.abs t1, uregs_sp
    st.w t0, t1, 0
    la.abs t1, uregs_fp
    st.w t0, t1, 0

    // 清除所有 TLB 表项
    invtlb 0, zero, zero

    // 填写 RAM0 页表
    la.abs a0, PTECODE
    li.w t0, PRAM0UBASE

    // 构造 EntryLo
    // PPN = PA >> 12
    // EntryLo = (PPN << 8) | VALID | DIRTY | GLOBAL | CACHE
    srli.w t0, t0, 4
    li.w t1, (ELO_VALIDF | ELO_DIRTYF | ELO_GLOBALF | ELO_CACHEF)
    or t0, t0, t1

    // 循环每个 EntryLo
    li.w t6, PTECODE_SIZE / 4
.LC_pte1:
    st.w t0, a0, 0
    addi.w t6, t6, -1
    addi.w a0, a0, 4
    addi.w t0, t0, PAGE_SIZE >> 4
    bne t6, zero, .LC_pte1

    // 填写 RAM1 页表
    la.abs a0, PTESTACK
    li.w t0, PRAM1BASE

    // 构造 EntryLo
    // PPN = PA >> 12
    // EntryLo = (PPN << 8) | VALID | DIRTY | GLOBAL | CACHE
    srli.w t0, t0, 4
    li.w t1, (ELO_VALIDF | ELO_DIRTYF | ELO_GLOBALF | ELO_CACHEF)
    or t0, t0, t1

    // 循环每个 EntryLo
    li.w t6, PTESTACK_SIZE / 4
.LC_pte2:
    st.w t0, a0, 0
    addi.w t6, t6, -1
    addi.w a0, a0, 4
    addi.w t0, t0, PAGE_SIZE >> 4
    bne t6, zero, .LC_pte2

    // 设置 TLB Refill 异常入口
    la.abs t0, TLBREFILL
    // 计算出物理地址
    li.w t1, KSEG0_BASE
    sub.w t0, t0, t1
    csrwr t0, CSR_TLBRENTRY
#endif

    // 进入主线程
    b WELCOME

    .text
WELCOME:
    // 通过串口发送启动信息
    la.abs s0, monitor_version

    ld.b a0, s0, 0
.Loop0:
    addi.w s0, s0, 1

    // 调用串口写函数
    bl WRITESERIAL

    ld.b a0, s0, 0
    bne a0, zero, .Loop0

    // 进入 shell
    b SHELL

IDLELOOP:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    b IDLELOOP








// vim: syntax=asm
