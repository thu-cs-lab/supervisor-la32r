ENTRY(INITLOCATE)
OUTPUT("kernel.elf")
OUTPUT_ARCH("loongarch32r")
OUTPUT_FORMAT("elf32-loongarch")

PROVIDE(SerialData = 0xBFD003F8);
PROVIDE(SerialStat = 0xBFD003FC);

/* Qemu serial constants */
PROVIDE(COM1 = 0xBFE001E0);
PROVIDE(KERNEL_STACK_INIT = 0x80800000);
PROVIDE(USER_STACK_INIT = 0x807F0000);
SECTIONS
{
    . = 0x80000000;
    .text : {
        *(.text.init)
        . = 0x1000;
        *(.text.ebase)
        . = 0x1180;
        *(.text.ebase180)
        . = ALIGN(0x1000);
        *(.text)
        . = ALIGN(0x1000); /* "fixed" utest address */
        *(.text.utest)
    }
    .rodata : {
        *(.rodata)
    }
    
    . = 0x807F0000;
    .bss : {
        _sbss = .;         /* define a global symbol at bss start */
        *(.bss.uregs)
        *(.bss)
        *(.bss.ptes)
        . = ALIGN(4);
        _ebss = .;         /* define a global symbol at bss end */
    }
    PROVIDE(uregs_sp = uregs + (3 - 1) * 4); /* sp(r3) */
    PROVIDE(uregs_fp = uregs + (22 - 1) * 4); /* sp(r22) */
}
