#ifndef _EXCEPTION_H
#define _EXCEPTION_H

#define EX_IRQ      0       /* Interrupt */
#define EX_SYS      11      /* Syscall */

#define TF_SIZE     0x84    /* trap frame size */

#define TF_ra       0x00
#define TF_tp       0x04
#define TF_sp       0x08
#define TF_a0       0x0C
#define TF_a1       0x10
#define TF_a2       0x14
#define TF_a3       0x18
#define TF_a4       0x1C
#define TF_a5       0x20
#define TF_a6       0x24
#define TF_a7       0x28
#define TF_t0       0x2C
#define TF_t1       0x30
#define TF_t2       0x34
#define TF_t3       0x38
#define TF_t4       0x3C
#define TF_t5       0x40
#define TF_t6       0x44
#define TF_t7       0x48
#define TF_t8       0x4C
#define TF_rsv      0x50
#define TF_fp       0x54
#define TF_s0       0x58
#define TF_s1       0x5C
#define TF_s2       0x60
#define TF_s3       0x64
#define TF_s4       0x68
#define TF_s5       0x6C
#define TF_s6       0x70
#define TF_s7       0x74
#define TF_s8       0x78
#define TF_ECFG     0x7C
#define TF_ERA      0x80


#endif
