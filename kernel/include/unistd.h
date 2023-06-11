#ifndef __LIBS_UNISTD_H__
#define __LIBS_UNISTD_H__
#include <la32regs.h>

#define PAGE_SIZE   0x1000          // 4KB页
// 用户程序虚拟地址映射：
// RAM0: 0x00000000 - 0x002FFFFF
//     ->0x00100000 - 0x003FFFFF
// RAM1: 0x7FC10000 - 0x7FFFFFFF
//     ->0x00400000 - 0x007EFFFF
#define PRAM0UBASE  0x00100000
#define RAM0UBASE   0x80100000

#define PRAM1BASE   0x00400000
#define RAM1BASE    0x80400000
#define RAM1KBASE   0x807F0000
#define KSEG0_BASE  0x80000000

#define PTECODE_SIZE    ((RAM1BASE - RAM0UBASE) / 0x1000 * 4)
#define PTESTACK_SIZE   ((RAM1KBASE - RAM1BASE) / 0x1000 * 4)

/* for EntryLo0-1   */
#define ELO_VALIDF  ((1) << 0)
#define ELO_DIRTYF  ((1) << 1)
#define ELO_GLOBALF ((1) << 6)
#define ELO_CACHEF  ((1) << 4)

#define SYSCALL_BASE            0x80

/* syscall number */
#define SYS_exit            1
#define SYS_fork            2
#define SYS_wait            3
#define SYS_exec            4
#define SYS_clone           5
#define SYS_yield           10
#define SYS_sleep           11
#define SYS_kill            12
#define SYS_gettime         17
#define SYS_getpid          18
#define SYS_mmap            20
#define SYS_munmap          21
#define SYS_shmem           22
#define SYS_putc            30
#define SYS_pgdir           31
#define SYS_open            100
#define SYS_close           101
#define SYS_read            102
#define SYS_write           103
#define SYS_seek            104
#define SYS_fstat           110
#define SYS_fsync           111
#define SYS_getcwd          121
#define SYS_getdirentry     128
#define SYS_dup             130

#endif /* !__LIBS_UNISTD_H__ */

