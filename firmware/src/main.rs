#![no_std]
#![no_main]

use core::panic::PanicInfo;
use riscv_rt::entry;

// Panic handler
#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}

// Entry point of the application
#[entry]
fn main() -> ! {
    // Your application logic goes here.
    // For example, you could interact with peripherals
    // at KB_BASE or DISP_BASE.

    // An infinite loop to prevent the program from exiting
    loop {
        // Your main loop code
    }
}