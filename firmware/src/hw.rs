#![allow(dead_code)]
//! Minimal hardware abstraction layer for the MyGameConsole SoC.
//!
//! This module provides *very* thin, zero-cost wrappers around the
//! memory-mapped peripherals exposed by the `memory_controller` block in
//! `src/memory/memory_controller.v`.
//!
//! The goal is **clarity & type-safety**, not completeness.  All
//! interactions ultimately resolve to `volatile` reads / writes so the
//! compiler never optimises them away.
//!
//! Memory map (top nibble):
//! 0x0_----  ROM  – 4 KiB (read-only)
//! 0x1_----  RAM  – 256 B  (read/write)
//! 0x2_----  KB   – keyboard registers
//! 0x3_----  DISP – 64 KiB framebuffer (write-only)
//!
//! The constants below match the Verilog `localparam`s so that software
//! and hardware stay in lock-step.

use core::ptr::{read_volatile, write_volatile};

/* ------------------------------------------------------------------------- */
/*                              Base addresses                               */
/* ------------------------------------------------------------------------- */

pub const ROM_BASE: *const u32 = 0x0000_0000 as *const u32;
pub const RAM_BASE: *mut u32 = 0x1000_0000 as *mut u32;
pub const KB_BASE: *const u32 = 0x2000_0000 as *const u32;
pub const DISP_BASE: *mut u32 = 0x3000_0000 as *mut u32;

/* ------------------------------------------------------------------------- */
/*                                  Display                                  */
/* ------------------------------------------------------------------------- */

/// Width of the framebuffer in pixels/words.
pub const DISP_WIDTH: usize = 320;
/// Height of the framebuffer in pixels/words.
pub const DISP_HEIGHT: usize = 240;
/// Total number of 32-bit words in the framebuffer.
pub const FB_WORDS: usize = DISP_WIDTH * DISP_HEIGHT;

/// 32-bit write-only framebuffer.
/// Every pixel is encoded in the lower 12 bits (RGB-444).
pub struct Display;

impl Display {
    /// Fill the entire framebuffer with `value`.
    pub fn fill(value: u32) {
        for i in 0..FB_WORDS {
            unsafe { write_volatile(DISP_BASE.add(i), value) };
        }
    }

    /// Write a single pixel (`x`,`y`) with `color` (RGB-444 in lower bits).
    pub fn set_pixel(x: usize, y: usize, color: u32) {
        debug_assert!(x < DISP_WIDTH && y < DISP_HEIGHT);
        let idx = x + y * DISP_WIDTH;
        unsafe { write_volatile(DISP_BASE.add(idx), color) };
    }
}

/* ------------------------------------------------------------------------- */
/*                                 Keyboard                                  */
/* ------------------------------------------------------------------------- */

/*
 * Bit indices for the 26 alphabet keys as produced by the Verilog
 * `keyboard_status_keeper` module.  The hardware maps the first bit to the
 * letter `A`, the second to `B`, and so on up to `Z`.
 */
pub const KEY_A: u8 = 0;
pub const KEY_B: u8 = 1;
pub const KEY_C: u8 = 2;
pub const KEY_D: u8 = 3;
pub const KEY_E: u8 = 4;
pub const KEY_F: u8 = 5;
pub const KEY_G: u8 = 6;
pub const KEY_H: u8 = 7;
pub const KEY_I: u8 = 8;
pub const KEY_J: u8 = 9;
pub const KEY_K: u8 = 10;
pub const KEY_L: u8 = 11;
pub const KEY_M: u8 = 12;
pub const KEY_N: u8 = 13;
pub const KEY_O: u8 = 14;
pub const KEY_P: u8 = 15;
pub const KEY_Q: u8 = 16;
pub const KEY_R: u8 = 17;
pub const KEY_S: u8 = 18;
pub const KEY_T: u8 = 19;
pub const KEY_U: u8 = 20;
pub const KEY_V: u8 = 21;
pub const KEY_W: u8 = 22;
pub const KEY_X: u8 = 23;
pub const KEY_Y: u8 = 24;
pub const KEY_Z: u8 = 25;


/// Very simple read-only 32-bit register block.
/// Stateful keyboard abstraction.  Each `Keyboard` instance keeps track
/// of the previously observed register value so that edge-detection (e.g.
/// `just_pressed`) can be implemented without relying on globals.
#[derive(Copy, Clone)]
pub struct Keyboard {
    prev_state: u32,
}

impl Keyboard {
    /// Create a new `Keyboard` handle with no prior key state.
    pub const fn new() -> Self {
        Self { prev_state: 0 }
    }

    /// Reads the raw 32-bit value from the keyboard register block.
    #[inline(always)]
    fn read_raw(&self) -> u32 {
        unsafe { read_volatile(KB_BASE) }
    }

    /// Returns `true` if **any** key is currently pressed.
    #[inline(always)]
    pub fn any_pressed(&self) -> bool {
        self.read_raw() != 0
    }

    /// Returns `true` while the given `bit_index` key (0-31) is held down.
    #[inline(always)]
    fn is_pressed_idx(&self, bit_index: u8) -> bool {
        debug_assert!(bit_index < 32);
        let mask = 1u32 << bit_index;
        self.read_raw() & mask != 0
    }

    /// Returns `true` **once** on the rising edge of the specified key.
    /// Continues to return `false` while the key remains pressed until it is
    /// released and pressed again.
    #[inline(always)]
    fn just_pressed_idx(&mut self, bit_index: u8) -> bool {
        debug_assert!(bit_index < 32);
        let current = self.read_raw();
        let mask = 1u32 << bit_index;
        let previously_set = self.prev_state & mask != 0;
        let now_set = current & mask != 0;
        // Update state for next call.
        self.prev_state = current;
        now_set && !previously_set
    }

    /* --------------------------------------------------------------------- */
    /*                       Letter-centric convenience API                   */
    /* --------------------------------------------------------------------- */

    /// Internal helper that converts an ASCII letter (either case) to the
    /// corresponding bit index (0-25).  Returns `None` for non-alphabet
    /// characters.
    #[inline(always)]
    fn letter_index(ch: char) -> Option<u8> {
        let byte = ch as u32 as u8; // we only care about ASCII, higher bytes ignored
        let upper = match byte {
            b'a'..=b'z' => byte - 32, // to upper case
            _ => byte,
        };
        if (b'A'..=b'Z').contains(&upper) {
            Some(upper - b'A')
        } else {
            None
        }
    }

    /// Returns `true` while the specified ASCII letter (case-insensitive) is
    /// held down.
    #[inline(always)]
    pub fn is_pressed(&self, ch: char) -> bool {
        if let Some(idx) = Self::letter_index(ch) {
            self.is_pressed_idx(idx)
        } else {
            false
        }
    }

    /// Rising-edge detection variant of [`is_letter_pressed`].  Returns `true`
    /// exactly **once** when the key goes from released → pressed.
    #[inline(always)]
    pub fn just_pressed(&mut self, ch: char) -> bool {
        if let Some(idx) = Self::letter_index(ch) {
            self.just_pressed_idx(idx)
        } else {
            false
        }
    }
}

/* ------------------------------------------------------------------------- */
/*                                    RAM                                    */
/* ------------------------------------------------------------------------- */

/// On-chip scratch RAM (256 bytes = 64 words).  Exposed mainly as a proof of
/// concept – the core will normally use regular Rust variables placed in
/// `.data` / `.bss`, but direct access can still be useful.
pub struct ScratchRam;

impl ScratchRam {
    /// Write word at `word_index` (0-63).
    pub unsafe fn write(word_index: usize, value: u32) {
        debug_assert!(word_index < 64);
        unsafe { write_volatile(RAM_BASE.add(word_index), value) };
    }

    /// Read word at `word_index` (0-63).
    pub unsafe fn read(word_index: usize) -> u32 {
        debug_assert!(word_index < 64);
        unsafe { read_volatile(RAM_BASE.add(word_index)) }
    }
}
