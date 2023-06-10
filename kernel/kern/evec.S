#include <regdef.h>
#include <mipsregs.h> 


    // 从 0x80000000 地址启动
    .p2align 2
    .section .text.init
    .global INITLOCATE
INITLOCATE:
    // 跳转到真正的启动程序
    la.abs t0, START
    jr t0

// 以下是异常处理的代码

#ifdef ENABLE_INT
    .section .text.ebase180
EHANDLERLOCATE:                     // 定位普通中断处理程序
    lui k0, %hi(EXCEPTIONHANDLER)
    addiu k0, %lo(EXCEPTIONHANDLER)
    jr k0
    nop
#endif

#ifdef ENABLE_TLB
    .section .text.ebase
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

