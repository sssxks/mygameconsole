`ifndef MEMORY_SIZES_VH
`define MEMORY_SIZES_VH

//-----------------------------------------------------------------------------//
// Common memory sizing constants for the game console project.
// All memory depths/widths are expressed as powers-of-two so we can derive the
// required address width easily.  Changing a single value here automatically
// updates every module that includes this header.
//-----------------------------------------------------------------------------//

// Program ROM – 4096 x 32-bit words (16 KiB)
`define ROM_ADDR_WIDTH 12

// Data RAM – 512 x 32-bit words (2 KiB)
`define RAM_ADDR_WIDTH 9

// Keyboard register file – 256 bytes organised as 64 x 32-bit words
`define KB_ADDR_WIDTH 8

// Framebuffer – 64 Ki words (320 × 240 pixels)
`define DISP_ADDR_WIDTH 17

// Optional derived constants --------------------------------------------------
`define ROM_WORDS (1 << `ROM_ADDR_WIDTH)
`define RAM_WORDS (1 << `RAM_ADDR_WIDTH)
`define KB_WORDS  (1 << `KB_ADDR_WIDTH)
`define DISP_WORDS (1 << `DISP_ADDR_WIDTH)

`endif // MEMORY_SIZES_VH
