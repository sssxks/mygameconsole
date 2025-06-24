`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// 2048 Tile Sprite Renderer - Image-based tile rendering using COE files
// -----------------------------------------------------------------------------
// This module renders 2048 game tiles using pre-generated sprite images
// stored in block RAM. Each tile type has its own 60x60 pixel image.
// The images are stored as COE files and loaded into block RAM.
// -----------------------------------------------------------------------------
module tile_sprite_renderer (
    input wire clk,
    input wire reset_n,
    
    // Tile information
    input wire [3:0] tile_value,        // Tile value (0=empty, 1=2, 2=4, etc.)
    input wire [5:0] tile_pos_x,        // Position within tile (0-59)
    input wire [5:0] tile_pos_y,        // Position within tile (0-59)
    
    // Output
    output reg [11:0] pixel_color       // 12-bit RGB color
);

    // ---------------------------------------------------------------------
    // Tile sprite memory parameters
    // ---------------------------------------------------------------------
    localparam TILE_SIZE = 60;
    localparam PIXELS_PER_TILE = TILE_SIZE * TILE_SIZE; // 3600 pixels
    localparam ADDR_WIDTH = 12; // log2(3600) = ~12 bits
    
    // Calculate pixel address within current tile sprite
    wire [ADDR_WIDTH-1:0] pixel_addr = tile_pos_y * TILE_SIZE + tile_pos_x;
    
    // ---------------------------------------------------------------------
    // Block RAM for tile sprites
    // ---------------------------------------------------------------------
    
    // Blank tile (empty) sprite memory
    (* ram_style = "block" *) reg [11:0] blank_tile_mem [0:PIXELS_PER_TILE-1];
    initial $readmemh("memory/blank_tile.hex", blank_tile_mem);
    
    // Value 2 sprite memory
    (* ram_style = "block" *) reg [11:0] value_2_mem [0:PIXELS_PER_TILE-1];
    initial $readmemh("memory/value_2.hex", value_2_mem);
    
    // Value 4 sprite memory
    (* ram_style = "block" *) reg [11:0] value_4_mem [0:PIXELS_PER_TILE-1];
    initial $readmemh("memory/value_4.hex", value_4_mem);
    
    // Value 8 sprite memory
    (* ram_style = "block" *) reg [11:0] value_8_mem [0:PIXELS_PER_TILE-1];
    initial $readmemh("memory/value_8.hex", value_8_mem);
    
    // Value 16 sprite memory
    (* ram_style = "block" *) reg [11:0] value_16_mem [0:PIXELS_PER_TILE-1];
    initial $readmemh("memory/value_16.hex", value_16_mem);
    
    // Value 32 sprite memory
    (* ram_style = "block" *) reg [11:0] value_32_mem [0:PIXELS_PER_TILE-1];
    initial $readmemh("memory/value_32.hex", value_32_mem);
    
    // Value 64 sprite memory
    (* ram_style = "block" *) reg [11:0] value_64_mem [0:PIXELS_PER_TILE-1];
    initial $readmemh("memory/value_64.hex", value_64_mem);
    
    // Value 128 sprite memory
    (* ram_style = "block" *) reg [11:0] value_128_mem [0:PIXELS_PER_TILE-1];
    initial $readmemh("memory/value_128.hex", value_128_mem);
    
    // Value 256 sprite memory
    (* ram_style = "block" *) reg [11:0] value_256_mem [0:PIXELS_PER_TILE-1];
    initial $readmemh("memory/value_256.hex", value_256_mem);
    
    // Value 512 sprite memory
    (* ram_style = "block" *) reg [11:0] value_512_mem [0:PIXELS_PER_TILE-1];
    initial $readmemh("memory/value_512.hex", value_512_mem);
    
    // Value 1024 sprite memory
    (* ram_style = "block" *) reg [11:0] value_1024_mem [0:PIXELS_PER_TILE-1];
    initial $readmemh("memory/value_1024.hex", value_1024_mem);
    
    // Value 2048 sprite memory
    (* ram_style = "block" *) reg [11:0] value_2048_mem [0:PIXELS_PER_TILE-1];
    initial $readmemh("memory/value_2048.hex", value_2048_mem);
    
    // ---------------------------------------------------------------------
    // Sprite selection and pixel output
    // ---------------------------------------------------------------------
    reg [11:0] selected_pixel;
    
    // Select appropriate sprite memory based on tile value
    always @(posedge clk) begin
        if (!reset_n) begin
            selected_pixel <= 12'h000;
        end else begin
            case (tile_value)
                4'd0:  selected_pixel <= blank_tile_mem[pixel_addr];   // Empty tile
                4'd1:  selected_pixel <= value_2_mem[pixel_addr];      // 2
                4'd2:  selected_pixel <= value_4_mem[pixel_addr];      // 4
                4'd3:  selected_pixel <= value_8_mem[pixel_addr];      // 8
                4'd4:  selected_pixel <= value_16_mem[pixel_addr];     // 16
                4'd5:  selected_pixel <= value_32_mem[pixel_addr];     // 32
                4'd6:  selected_pixel <= value_64_mem[pixel_addr];     // 64
                4'd7:  selected_pixel <= value_128_mem[pixel_addr];    // 128
                4'd8:  selected_pixel <= value_256_mem[pixel_addr];    // 256
                4'd9:  selected_pixel <= value_512_mem[pixel_addr];    // 512
                4'd10: selected_pixel <= value_1024_mem[pixel_addr];   // 1024
                4'd11: selected_pixel <= value_2048_mem[pixel_addr];   // 2048
                default: selected_pixel <= blank_tile_mem[pixel_addr]; // Default to blank for higher values
            endcase
        end
    end
    
    // Output the selected pixel
    always @(posedge clk) begin
        if (!reset_n) begin
            pixel_color <= 12'h000;
        end else begin
            pixel_color <= selected_pixel;
        end
    end

endmodule 