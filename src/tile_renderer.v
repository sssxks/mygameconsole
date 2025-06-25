`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Tile renderer – maps a single board cell to a texture pixel
// -----------------------------------------------------------------------------
module tile_renderer (
    input  wire        clk,
    input  wire [5:0]  off_x,  // 0-59 within tile
    input  wire [5:0]  off_y,  // 0-59 within tile
    input  wire [3:0]  tile_val,
    output wire [11:0] colour
);
    // Address into the texture ROM: {value, y, x} = 4 + 6 + 6 = 16 bits
    wire [15:0] tex_addr = {tile_val, off_y, off_x};

    // External ROM that stores 60×60 textures for each exponent value
    tile_texture_rom u_tex_rom (
        .clk  (clk),
        .addr (tex_addr),
        .data (colour)
    );
endmodule
