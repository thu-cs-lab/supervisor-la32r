#include <regdef.h>
#include <mipsregs.h>
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
    .p2align 12                     // 每个两页，页对齐
PTECODE:
    .rept PAGE_SIZE / 2             // 8KB一个TLB项
    .long 0
    .endr
PTE2BASE:
    .rept PAGE_SIZE / 2 - PTESTACK_SIZE / 4
                                    // 空余
    .long 0
    .endr
PTESTACK:
    .rept PTESTACK_SIZE / 4
    .long 0
    .endr
#endif

    .text
    .p2align 2
monitor_version:
    .asciz "MONITOR for LA32R - initialized."

    // .bss 段的起始和结束地址，见 kernel.ld
    .word   _sbss
    .word   _ebss

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
    mfc0 t0, CP0_STATUS             // 取得cp0的status Reg
    nop
    xori t1, t0, (ST0_IM | ST0_IE | ST0_EXL | ST0_ERL)
                                    // 取消错误、异常位，使得eret正常
                                    // 见Vol3p196ERL,错误置位会让eret跳ErEPC
    and t0, t0, t1                  // status Reg 的IE位和IM位置零
    mtc0 t0, CP0_STATUS             // 暂停中断响应，直到启动完成
    nop

    mfc0 t0, CP0_STATUS
    lui t1, %hi(ST0_BEV)
    xor t1, t0, t1
    and t0, t0, t1                  // status Reg 的BEV位置零
    mtc0 t0, CP0_STATUS             // 中断处理转为正常模式
    ori t2, zero, PAGE_SIZE
    mtc0 t2, CP0_EBASE              // 设定中断响应基址为0x8000.1000
    mfc0 t0, CP0_CAUSE
    lui t1, %hi(CAUSEF_IV)
    xor t1, t1, t0
    and t0, t0, t1                  // Cause IV位置零
    mtc0 t0, CP0_CAUSE              // 关闭中断特殊入口
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
#endif

#ifdef ENABLE_INT
    /* enable serial interrupt */
    mfc0 t0, CP0_STATUS
    ori t0, t0, STATUSF_IP4         // hardware interrupt source #2, irq #4
    mtc0 t0, CP0_STATUS
#endif


    // 在栈上预留大小为 TF_SIZE 空间且清零
    li.w t0, TF_SIZE / 4
.LC0:
    addi.w t0, t0, -1
    addi.w sp, sp, -4
    st.w zero, sp, 0
    bne t0, zero, .LC0

    // 把 thread0(idle) 的中断帧地址设为当前栈地址
    la.abs t0, TCBT
    st.w sp, t0, 0

#ifdef ENABLE_INT
    mfc0 t1, CP0_STATUS             // 取STATUS
    mfc0 t2, CP0_CAUSE              // 取CAUSE
    ori t1, t1, ST0_IE              // 使能中断
    sw t2, TF_CAUSE(sp)             // 写中断帧CAUSE
    sw t1, TF_STATUS(sp)            // 写中断帧STATUS; idle线程打开串口硬件中断响应
    lui t3, %hi(IDLELOOP)
    addiu t3, %lo(IDLELOOP)       // 取得idle线程入口
    sw t3, TF_EPC(sp)               // 写中断帧EPC
#endif

    // t6 寄存器保存 idle 中断帧位置
    move t6, sp

    // 在栈上预留大小为 TF_SIZE 空间且清零
    li.w t0, TF_SIZE / 4
.LC1:
    addi.w t0, t0, -1
    addi.w sp, sp, -4
    st.w zero, sp, 0
    bne t0, zero, .LC1

    // 把 thread1(shell/user) 的中断帧地址设为当前栈地址
    la.abs t0, TCBT
    st.w sp, t0, 4

    // 设置当前线程为 thread1
    la.abs t0, current
    st.w sp, t0, 0

#ifdef ENABLE_TLB                   // 打开TLB机制
    lui t0, 0xC000                  // PTE在kseg2
    mtc0 zero, CP0_PAGEMASK         // pagemask置零，使用4kB页
    mtc0 t0, CP0_CONTEXT            // 设置PTEBase
    lui t0, 0x8000                  // 使用kuseg，用户栈地址确定
    lui t1, %hi(uregs_sp)           // 写入用户空间备份
    sw t0, %lo(uregs_sp)(t1)
    lui t1, %hi(uregs_fp)
    sw t0, %lo(uregs_fp)(t1)
    mfc0 t3, CP0_CONFIG, 1          // CP0_Config1
    srl t3, t3, 25
    andi t3, t3, 0x3F               // 截取MMUSize
    addiu t3, t3, 1                 // TLB有MMUSize+1项
    lui t4, 0x8000                  // 用于检测TLB命中
    or t2, t4, t4                   // va = begin(kseg0)
    mtc0 zero, CP0_ENTRYLO0
    mtc0 zero, CP0_ENTRYLO1         // 设为非可用
.LC_tlb:
    addiu t3, t3, -1
.LC_vamat:
    addiu t2, t2, PAGE_SIZE * 2     // va += 8KB
    mtc0 t2, CP0_ENTRYHI            // 写va
    nop
    tlbp
    nop
    mfc0 t1, CP0_INDEX              // 获得匹配结果
    and t1, t1, t4                  // 截取最高位
    beq t1, zero, .LC_vamat         // 匹配到则不能设这个va
    nop
    mtc0 t3, CP0_INDEX
    nop
    tlbwi                           // 清零
    bne t3, zero, .LC_tlb
    nop

    lui a0, %hi(PTECODE)            // 填页表1
    addiu a0, %lo(PTECODE)
    lui t0, %hi(PRAM0UBASE)
    addiu t0, %lo(PRAM0UBASE)     // 物理地址
    srl t0, t0, 6                   // pa(12)->pfn(6)
    ori t0, t0, (ELO_VALIDF | ELO_DIRTYF | ELO_GLOBALF)
                                    // 可访问可写
    ori t6, zero, PTECODE_SIZE / 8  // 计数器
.LC_pte1:
    sw t0, 0x0(a0)                  // 写Lo
    addiu t6, t6, -1                // 滚动计数器
    addiu a0, a0, 8                 // 下一个Lo
    addiu t0, t0, PAGE_SIZE >> 6    // 下一页
    bne t6, zero, .LC_pte1
    nop

    lui a0, %hi(PTESTACK)           // 填页表2
    addiu a0, %lo(PTESTACK)
    lui t0, %hi(PRAM1BASE)
    addiu t0, %lo(PRAM1BASE)      // 物理地址
    srl t0, t0, 6                   // pa(12)->pfn(6)
    ori t0, t0, (ELO_VALIDF | ELO_DIRTYF | ELO_GLOBALF)
                                    // 可访问可写
    ori t6, zero, PTESTACK_SIZE / 8 // 计数器
.LC_pte2:
    sw t0, 0x0(a0)                  // 写Lo
    addiu t6, t6, -1                // 滚动计数器
    addiu a0, a0, 8                 // 下一个Lo
    addiu t0, t0, PAGE_SIZE >> 6    // 下一页
    bne t6, zero, .LC_pte2
    nop

    ori t0, zero, 2
    mtc0 t0, CP0_WIRED              // wired置二

    lui s2, 0x1FFF
    ori s2, s2, 0xFFFF              // kseg0 掩码
    mtc0 zero, CP0_INDEX            // 取TLB第一项
    lui a0, %hi(PTECODE)            // kseg2页表page0
    addiu a0, %lo(PTECODE)
    and a0, a0, s2                  // 取物理地址
    srl a0, a0, 6                   // PA[35..12] => ENTRYLO{0,1}[29..6]
    ori a0, a0, ELO_VALIDF | ELO_GLOBALF    // 置合法位，不允许修改kseg2
    addiu a1, a0, PAGE_SIZE >> 6    // page1
    mtc0 a0, CP0_ENTRYLO0
    mtc0 a1, CP0_ENTRYLO1
    lui t0, %hi(KSEG2PAGE0)         // kseg2第一二页
    addiu t0, %lo(KSEG2PAGE0)
    mtc0 t0, CP0_ENTRYHI            // kseg2第一页翻译为ptecode
    nop
    tlbwi
    ori t0, zero, 0x1               // 2
    mtc0 t0, CP0_INDEX              // 取TLB第二项
    lui a0, %hi(PTE2BASE)           // kseg2页表page1022
    addiu a0, %lo(PTE2BASE)
    and a0, a0, s2                  // 取物理地址
    srl a0, a0, 6                   // PA[35..12] => ENTRYLO{0,1}[29..6]
    ori a0, a0, ELO_VALIDF | ELO_GLOBALF    // 置合法位，不允许修改kseg2
    addiu a1, a0, PAGE_SIZE >> 6    // page1023
    mtc0 a0, CP0_ENTRYLO0
    mtc0 a1, CP0_ENTRYLO1
    lui t0, 0xC03F                  // kseg2第1022,1023页
    ori t0, t0, 0xE000
    mtc0 t0, CP0_ENTRYHI
    nop
    tlbwi
    nop
#endif

#ifdef ENABLE_INT
    mfc0 t0, CP0_STATUS             // 取得cp0的status Reg
    nop
    ori t0, t0, ST0_IE              // status Reg 的IE位置一
    xori t1, t0, STATUSF_IP4
    and t0, t0, t1                  // 主线程屏蔽串口硬件中断
    mtc0 t0, CP0_STATUS             // 启动完成，恢复中断机制
    nop
#endif

    // 进入主线程
    b WELCOME



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
