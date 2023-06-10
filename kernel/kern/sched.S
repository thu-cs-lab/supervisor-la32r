#include <regdef.h>
#include <la32regs.h> 

    .p2align 2
    .text
    .global SCHEDULE

    // 仅在启用异常处理时定义
SCHEDULE:
#ifdef ENABLE_INT
    // 获取 thread0(idle) 线程的 TCB
    la.abs t1, TCBT
    ld.w t2, t1, 0

    // 获取当前线程的 TCB
    la.abs t4, current
    ld.w t3, t4, 0

    // 如果当前线程是 thread0，切换到 thread1
    // 如果当前线程是 thread1，切换到 thread0
    bne t2, t3, .LC0
    // 获取 thread1 线程的 TCB
    ld.w t2, t1, 4
.LC0:
    st.w t2, t4, 0

    // 结束中断响应
    move sp, t2
    b RETURNFRMTRAP
#else
    b SCHEDULE
#endif

