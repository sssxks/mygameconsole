`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// 2048 Tile Renderer - Advanced tile rendering with numbers
// -----------------------------------------------------------------------------
// This module handles the detailed rendering of individual 2048 game tiles
// including:
// - Tile backgrounds with gradients
// - Number rendering using bitmap fonts
// - 3D border effects
// - Animation support (future enhancement)
// -----------------------------------------------------------------------------
module tile_renderer (
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
    // Tile layout parameters
    // ---------------------------------------------------------------------
    localparam TILE_SIZE = 60;
    localparam BORDER_SIZE = 3;
    localparam NUMBER_START_X = 15;
    localparam NUMBER_START_Y = 20;
    localparam NUMBER_WIDTH = 30;
    localparam NUMBER_HEIGHT = 20;

    // ---------------------------------------------------------------------
    // Number bitmap patterns (5x7 font for each digit)
    // ---------------------------------------------------------------------
    // Each number is represented as a 7x5 bitmap (35 bits)
    // Bit layout: row 0 (bits 34-30), row 1 (bits 29-25), ..., row 6 (bits 4-0)
    
    function automatic [34:0] get_digit_pattern;
        input [3:0] digit;
        begin
            case (digit)
                0: get_digit_pattern = 35'b01110_10001_10001_10001_10001_10001_01110; // 0
                1: get_digit_pattern = 35'b00100_01100_00100_00100_00100_00100_01110; // 1
                2: get_digit_pattern = 35'b01110_10001_00001_00010_00100_01000_11111; // 2
                3: get_digit_pattern = 35'b01110_10001_00001_00110_00001_10001_01110; // 3
                4: get_digit_pattern = 35'b00010_00110_01010_10010_11111_00010_00010; // 4
                5: get_digit_pattern = 35'b11111_10000_11110_00001_00001_10001_01110; // 5
                6: get_digit_pattern = 35'b00110_01000_10000_11110_10001_10001_01110; // 6
                7: get_digit_pattern = 35'b11111_00001_00010_00100_01000_10000_10000; // 7
                8: get_digit_pattern = 35'b01110_10001_10001_01110_10001_10001_01110; // 8
                9: get_digit_pattern = 35'b01110_10001_10001_01111_00001_00010_01100; // 9
                default: get_digit_pattern = 35'b00000_00000_00000_00000_00000_00000_00000; // blank
            endcase
        end
    endfunction

    // ---------------------------------------------------------------------
    // Base tile colors with enhanced palette
    // ---------------------------------------------------------------------
    function automatic [11:0] get_base_color;
        input [3:0] val;
        begin
            case (val)
                0: get_base_color = 12'hDDD;    // Empty - light gray
                1: get_base_color = 12'hFFE;    // 2 - cream
                2: get_base_color = 12'hFFB;    // 4 - light yellow
                3: get_base_color = 12'hFC8;    // 8 - light orange
                4: get_base_color = 12'hF96;    // 16 - orange
                5: get_base_color = 12'hF74;    // 32 - red-orange
                6: get_base_color = 12'hF52;    // 64 - red
                7: get_base_color = 12'hE42;    // 128 - dark red
                8: get_base_color = 12'hEC6;    // 256 - golden orange
                9: get_base_color = 12'hEC4;    // 512 - gold
                10: get_base_color = 12'hEA2;   // 1024 - dark gold
                11: get_base_color = 12'hE81;   // 2048 - bright gold
                12: get_base_color = 12'hC60;   // 4096 - golden brown
                13: get_base_color = 12'hA40;   // 8192 - brown
                14: get_base_color = 12'h820;   // 16384 - dark brown
                default: get_base_color = 12'h600; // Higher - very dark brown
            endcase
        end
    endfunction

    // ---------------------------------------------------------------------
    // Text color based on tile value (light text on dark tiles, dark on light)
    // ---------------------------------------------------------------------
    function automatic [11:0] get_text_color;
        input [3:0] val;
        begin
            if (val <= 2)
                get_text_color = 12'h666; // Dark gray for light tiles
            else
                get_text_color = 12'hFFF; // White for dark tiles
        end
    endfunction

    // ---------------------------------------------------------------------
    // Main rendering logic
    // ---------------------------------------------------------------------
    wire is_border = (tile_pos_x < BORDER_SIZE) || (tile_pos_x >= TILE_SIZE - BORDER_SIZE) ||
                     (tile_pos_y < BORDER_SIZE) || (tile_pos_y >= TILE_SIZE - BORDER_SIZE);
    
    wire is_top_left_border = (tile_pos_x < BORDER_SIZE) || (tile_pos_y < BORDER_SIZE);
    
    // Number rendering area
    wire in_number_area = (tile_pos_x >= NUMBER_START_X) && (tile_pos_x < NUMBER_START_X + NUMBER_WIDTH) &&
                         (tile_pos_y >= NUMBER_START_Y) && (tile_pos_y < NUMBER_START_Y + NUMBER_HEIGHT);
    
    // Convert tile value to actual number for display
    wire [15:0] display_number = (tile_value == 0) ? 0 : (1 << tile_value);
    
    // Extract digits
    wire [3:0] digit_thousands = display_number / 1000;
    wire [3:0] digit_hundreds = (display_number / 100) % 10;
    wire [3:0] digit_tens = (display_number / 10) % 10;
    wire [3:0] digit_ones = display_number % 10;
    
    // Position within number area
    wire [4:0] num_x = tile_pos_x - NUMBER_START_X;
    wire [4:0] num_y = tile_pos_y - NUMBER_START_Y;
    
    // Determine which digit we're rendering (each digit is 6 pixels wide + 1 space)
    wire [1:0] digit_index = num_x / 7;
    wire [2:0] digit_x = num_x % 7;
    wire [2:0] digit_y = num_y / 3; // Scale up 3x
    
    // Get current digit based on position
    reg [3:0] current_digit;
    always @(*) begin
        case (digit_index)
            0: current_digit = (display_number >= 1000) ? digit_thousands : 4'hF; // blank if not needed
            1: current_digit = (display_number >= 100) ? digit_hundreds : 4'hF;
            2: current_digit = (display_number >= 10) ? digit_tens : 4'hF;
            3: current_digit = digit_ones;
            default: current_digit = 4'hF;
        endcase
    end
    
    // Get digit pattern and check if current pixel should be lit
    wire [34:0] pattern = get_digit_pattern(current_digit);
    wire [4:0] pattern_bit = digit_y * 5 + digit_x;
    wire digit_pixel = (current_digit != 4'hF) && (digit_x < 5) && (digit_y < 7) && 
                      pattern[pattern_bit] && (num_x < 28); // 4 digits * 7 pixels each

    // Main color selection logic
    reg [11:0] base_color;
    reg [11:0] final_color;
    
    always @(*) begin
        base_color = get_base_color(tile_value);
        
        if (tile_value == 0) begin
            // Empty tile - simple flat color
            final_color = base_color;
        end else if (in_number_area && digit_pixel) begin
            // Number pixel - use text color
            final_color = get_text_color(tile_value);
        end else if (is_border) begin
            // Border area - 3D effect
            if (is_top_left_border) begin
                // Top/left border - lighter (highlight)
                final_color = {
                    (base_color[11:8] < 4'hE) ? base_color[11:8] + 2 : 4'hF,
                    (base_color[7:4] < 4'hE) ? base_color[7:4] + 2 : 4'hF,
                    (base_color[3:0] < 4'hE) ? base_color[3:0] + 2 : 4'hF
                };
            end else begin
                // Bottom/right border - darker (shadow)
                final_color = {
                    (base_color[11:8] > 4'h1) ? base_color[11:8] - 2 : 4'h0,
                    (base_color[7:4] > 4'h1) ? base_color[7:4] - 2 : 4'h0,
                    (base_color[3:0] > 4'h1) ? base_color[3:0] - 2 : 4'h0
                };
            end
        end else begin
            // Center area - base color with subtle gradient
            reg [1:0] gradient = (tile_pos_x + tile_pos_y) >> 5;
            final_color = {
                (base_color[11:8] < 4'hE) ? base_color[11:8] + gradient[0] : base_color[11:8],
                (base_color[7:4] < 4'hE) ? base_color[7:4] + gradient[0] : base_color[7:4],
                (base_color[3:0] < 4'hE) ? base_color[3:0] + gradient[0] : base_color[3:0]
            };
        end
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pixel_color <= 12'h000;
        end else begin
            pixel_color <= final_color;
        end
    end

endmodule 