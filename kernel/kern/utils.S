#include <regdef.h>
#include <mipsregs.h>
#include <unistd.h>

    .p2align 2
    .text
    .global WRITESERIAL
    .global READSERIAL
    .global READSERIALWORD

    // 写串口：将 a0 的低八位写入串口
WRITESERIAL:
    la.abs t1, COM1
    st.b a0, t1, 0
    jr ra

    // 读串口：将读到的数据写入 a0 低八位
READSERIAL:
    la.abs t1, COM1
.TESTR:
    // COM_LSR(5), 0x01(Data available)
    ld.b t0, t1, 5
    andi t0, t0, 0x1
    bne t0, zero, .RSERIAL

#ifdef ENABLE_INT
    // donghy's debug
    // if interrupt is not enabled, shell will always check COM STATUS
    ori v0, zero, SYS_wait
    syscall SYSCALL_BASE
#endif
    b .TESTR

.RSERIAL:
    la.abs t1, COM1
    // COM_RBR
    ld.b a0, t1, 0
    jr ra

    // 读串口：将读到的四字节数据写入 a0
READSERIALWORD:
    // 保存寄存器
    addi.w sp, sp, -0x14
    st.w ra, sp, 0x0
    st.w s0, sp, 0x4
    st.w s1, sp, 0x8
    st.w s2, sp, 0xC
    st.w s3, sp, 0x10

    // 读串口获得八个比特，结果存入 s0
    bl READSERIAL
    move s0, a0

    // 读串口获得八个比特，结果存入 s1
    bl READSERIAL
    move s1, a0

    // 读串口获得八个比特，结果存入 s2
    bl READSERIAL
    move s2, a0

    // 读串口获得八个比特，结果存入 s3
    bl READSERIAL
    move s3, a0

    // 截取低八位
    andi s0, s0, 0x00FF
    andi s3, s3, 0x00FF
    andi s2, s2, 0x00FF
    andi s1, s1, 0x00FF

    // 组合成一个 32 位数
    or a0, zero, s3                 // 存高八位
    slli.w a0, a0, 8                // 左移
    or a0, a0, s2                   // 存八位
    slli.w a0, a0, 8                // 左移
    or a0, a0, s1                   // 存八位
    slli.w a0, a0, 8                // 左移
    or a0, a0, s0                   // 存低八位

    // 恢复寄存器
    ld.w ra, sp, 0x0
    ld.w s0, sp, 0x4
    ld.w s1, sp, 0x8
    ld.w s2, sp, 0xC
    ld.w s3, sp, 0x10
    addi.w sp, sp, 0x14
    jr ra
