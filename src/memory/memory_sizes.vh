`ifndef MEMORY_SIZES_VH
`define MEMORY_SIZES_VH

// Keyboard register file – 256 bytes organised as 64 x 32-bit words
`define KB_ADDR_WIDTH 8

// Framebuffer – 64 Ki words (320 × 240 pixels)
`define DISP_ADDR_WIDTH 17

// Optional derived constants --------------------------------------------------
`define KB_WORDS  (1 << `KB_ADDR_WIDTH)
`define DISP_WORDS (1 << `DISP_ADDR_WIDTH)

`endif // MEMORY_SIZES_VH
