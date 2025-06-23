#![no_std]
#![no_main]

use core::panic::PanicInfo;
use riscv_rt::entry;

// Panic handler
#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {
        for i in 0..FB_WORDS {
            let value: u32 = 0xFFF;
    
            unsafe {
                let addr = DISP_BASE.add(i);
                core::ptr::write_volatile(addr, value)
            };
        }
    }
}

// -----------------------------------------------------------------------------
// Basic display helper
// -----------------------------------------------------------------------------
const DISP_BASE: *mut u32 = 0x3000_0000 as *mut u32;
const FB_WORDS: usize = 76800;

unsafe fn fill_display_pattern() {
    for i in 0..FB_WORDS {
        let value: u32 = if i & 1 == 0 {
            0x0FF /*lime*/
        } else {
            0xF0F /*purple*/
        };

        unsafe {
            let addr = DISP_BASE.add(i);
            core::ptr::write_volatile(addr, value)
        };
    }
}

#[entry]
fn main() -> ! {
    unsafe {
        fill_display_pattern();
    }

    loop {}
}
