/* memory.x - override memory regions; pull in default riscv-rt definitions */

MEMORY
{
  /* 128 KiB of on-chip flash / ROM */
  FLASH (rx)  : ORIGIN = 0x00000000, LENGTH = 128K
  /* 128 KiB of on-chip SRAM */
  RAM   (rwx) : ORIGIN = 0x10000000, LENGTH = 128K
}

/* Map riscv-rt logical regions to the physical ones */
REGION_ALIAS("REGION_TEXT",   FLASH);
REGION_ALIAS("REGION_RODATA", FLASH);
REGION_ALIAS("REGION_DATA",   RAM);
REGION_ALIAS("REGION_BSS",    RAM);
REGION_ALIAS("REGION_HEAP",   RAM);
REGION_ALIAS("REGION_STACK",  RAM);

/* Optional tunables */
/* _heap_size = 0; */
/* _hart_stack_size = 2K; */

/* Pull in riscv-rt default linker script logic */
INCLUDE link.x


/* Application memory map is inherited from riscv-rt's `link.x` */