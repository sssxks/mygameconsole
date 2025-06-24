`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// UI Renderer - Renders text and UI elements for 2048 game
// -----------------------------------------------------------------------------
// This module handles rendering of:
// - Game title "2048"
// - Score display
// - Instructions (WASD to move)
// - Game over screen
// - Various UI decorations
// -----------------------------------------------------------------------------
module ui_renderer (
    input wire clk,
    input wire reset_n,
    
    // Position inputs
    input wire [8:0] pixel_x,           // Current pixel X (0-319)
    input wire [7:0] pixel_y,           // Current pixel Y (0-239)
    
    // Game state inputs
    input wire [63:0] board_state,      // Current board state
    input wire [15:0] score,            // Current score (for future use)
    input wire game_over,               // Game over flag (for future use)
    
    // UI area flags
    output reg in_ui_area,              // Whether we're in a UI area
    output reg [11:0] ui_color          // UI pixel color
);

    // ---------------------------------------------------------------------
    // UI area definitions
    // ---------------------------------------------------------------------
    wire in_title_area = (pixel_y >= 2) && (pixel_y < 18) && (pixel_x >= 120) && (pixel_x < 200);
    wire in_score_area = (pixel_x >= 260) && (pixel_x < 318) && (pixel_y >= 20) && (pixel_y < 80);
    wire in_instructions_area = (pixel_y >= 205) && (pixel_y < 235) && (pixel_x >= 20) && (pixel_x < 300);
    
    // Overall UI area flag
    always @(*) begin
        in_ui_area = in_title_area || in_score_area || in_instructions_area;
    end

    // ---------------------------------------------------------------------
    // Font patterns for characters (8x8 bitmap font)
    // ---------------------------------------------------------------------
    function automatic [63:0] get_char_pattern;
        input [7:0] char_code;
        begin
            case (char_code)
                "0": get_char_pattern = 64'h3C4242424242423C; // 0
                "1": get_char_pattern = 64'h18080808080808FC; // 1
                "2": get_char_pattern = 64'h3C42020C30407E7E; // 2
                "3": get_char_pattern = 64'h3C4202381C02423C; // 3
                "4": get_char_pattern = 64'h0C1C2C4C7E0C0C0C; // 4
                "5": get_char_pattern = 64'h7E40407C02024278; // 5
                "6": get_char_pattern = 64'h1C20407C42424238; // 6
                "7": get_char_pattern = 64'h7E0204081020207E; // 7
                "8": get_char_pattern = 64'h3C4242243C42423C; // 8
                "9": get_char_pattern = 64'h3C4242423E02040C; // 9
                "A": get_char_pattern = 64'h183C4242427E4242; // A
                "B": get_char_pattern = 64'h7C4242427C42427C; // B
                "C": get_char_pattern = 64'h3C4242404040423C; // C
                "D": get_char_pattern = 64'h7C4242424242427C; // D
                "E": get_char_pattern = 64'h7E4040407C40407E; // E
                "F": get_char_pattern = 64'h7E40404078404040; // F
                "G": get_char_pattern = 64'h3C4242404E42423C; // G
                "H": get_char_pattern = 64'h424242427E424242; // H
                "I": get_char_pattern = 64'h3E08080808080838; // I
                "J": get_char_pattern = 64'h1F040404044442BC; // J
                "K": get_char_pattern = 64'h424448507048444A; // K
                "L": get_char_pattern = 64'h404040404040407E; // L
                "M": get_char_pattern = 64'h42667E5A42424242; // M
                "N": get_char_pattern = 64'h42626252424A4642; // N
                "O": get_char_pattern = 64'h3C4242424242423C; // O
                "P": get_char_pattern = 64'h7C4242427C404040; // P
                "Q": get_char_pattern = 64'h3C4242424A46423D; // Q
                "R": get_char_pattern = 64'h7C4242427C484442; // R
                "S": get_char_pattern = 64'h3C42403C02024274; // S
                "T": get_char_pattern = 64'h7F080808080808F8; // T
                "U": get_char_pattern = 64'h424242424242423C; // U
                "V": get_char_pattern = 64'h4242424242241818; // V
                "W": get_char_pattern = 64'h4242425A5A666642; // W
                "X": get_char_pattern = 64'h4242241818244242; // X
                "Y": get_char_pattern = 64'h4142221408081018; // Y
                "Z": get_char_pattern = 64'h7E02040810207E7E; // Z
                " ": get_char_pattern = 64'h0000000000000000; // Space
                ":": get_char_pattern = 64'h0000180000180000; // Colon
                "-": get_char_pattern = 64'h00000000FC000000; // Dash
                ">": get_char_pattern = 64'h00102040201010000; // Greater than
                default: get_char_pattern = 64'h0000000000000000; // Blank
            endcase
        end
    endfunction

    // ---------------------------------------------------------------------
    // Text rendering functions
    // ---------------------------------------------------------------------
    function automatic render_text_pixel;
        input [8:0] base_x, base_y;     // Base position of text
        input [8:0] current_x, current_y; // Current pixel position
        input [7:0] char_code;          // Character to render
        input [3:0] char_offset;        // Character position in string
        reg [8:0] char_x, char_y;
        reg [2:0] bit_x, bit_y;
        reg [5:0] bit_index;
        reg [63:0] pattern;
        begin
            // Calculate character position
            char_x = base_x + (char_offset * 9); // 8 pixels + 1 space
            char_y = base_y;
            
            // Check if we're within this character's bounds
            if ((current_x >= char_x) && (current_x < char_x + 8) &&
                (current_y >= char_y) && (current_y < char_y + 8)) begin
                
                // Calculate bit position within character
                bit_x = current_x - char_x;
                bit_y = current_y - char_y;
                bit_index = bit_y * 8 + bit_x;
                
                // Get character pattern and check bit
                pattern = get_char_pattern(char_code);
                render_text_pixel = pattern[63 - bit_index];
            end else begin
                render_text_pixel = 1'b0;
            end
        end
    endfunction

    // ---------------------------------------------------------------------
    // Main UI rendering logic
    // ---------------------------------------------------------------------
    reg [11:0] background_color;
    reg [11:0] text_color;
    reg is_text_pixel;
    
    always @(*) begin
        // Default values
        background_color = 12'h000;
        text_color = 12'hFFF;
        is_text_pixel = 1'b0;
        ui_color = background_color;
        
        if (in_title_area) begin
            // Render "2048" title
            background_color = 12'h123; // Dark blue background
            text_color = 12'hFFD; // Light yellow text
            
            // Check each character of "2048"
            is_text_pixel = render_text_pixel(125, 5, "2", 0, pixel_x, pixel_y) ||
                           render_text_pixel(125, 5, "0", 1, pixel_x, pixel_y) ||
                           render_text_pixel(125, 5, "4", 2, pixel_x, pixel_y) ||
                           render_text_pixel(125, 5, "8", 3, pixel_x, pixel_y);
            
            ui_color = is_text_pixel ? text_color : background_color;
            
        end else if (in_score_area) begin
            // Score area
            background_color = 12'h444; // Medium gray background
            text_color = 12'hFFF; // White text
            
            // Render "SCORE:" label
            is_text_pixel = render_text_pixel(265, 25, "S", 0, pixel_x, pixel_y) ||
                           render_text_pixel(265, 25, "C", 1, pixel_x, pixel_y) ||
                           render_text_pixel(265, 25, "O", 2, pixel_x, pixel_y) ||
                           render_text_pixel(265, 25, "R", 3, pixel_x, pixel_y) ||
                           render_text_pixel(265, 25, "E", 4, pixel_x, pixel_y) ||
                           render_text_pixel(265, 25, ":", 5, pixel_x, pixel_y);
            
            // TODO: Add actual score rendering here
            // For now, just show "0000"
            is_text_pixel = is_text_pixel ||
                           render_text_pixel(265, 40, "0", 0, pixel_x, pixel_y) ||
                           render_text_pixel(265, 40, "0", 1, pixel_x, pixel_y) ||
                           render_text_pixel(265, 40, "0", 2, pixel_x, pixel_y) ||
                           render_text_pixel(265, 40, "0", 3, pixel_x, pixel_y);
            
            ui_color = is_text_pixel ? text_color : background_color;
            
        end else if (in_instructions_area) begin
            // Instructions area
            background_color = 12'h222; // Dark gray background
            text_color = 12'hAAA; // Light gray text
            
            // Render "WASD TO MOVE"
            is_text_pixel = render_text_pixel(25, 210, "W", 0, pixel_x, pixel_y) ||
                           render_text_pixel(25, 210, "A", 1, pixel_x, pixel_y) ||
                           render_text_pixel(25, 210, "S", 2, pixel_x, pixel_y) ||
                           render_text_pixel(25, 210, "D", 3, pixel_x, pixel_y) ||
                           render_text_pixel(25, 210, " ", 4, pixel_x, pixel_y) ||
                           render_text_pixel(25, 210, "T", 5, pixel_x, pixel_y) ||
                           render_text_pixel(25, 210, "O", 6, pixel_x, pixel_y) ||
                           render_text_pixel(25, 210, " ", 7, pixel_x, pixel_y) ||
                           render_text_pixel(25, 210, "M", 8, pixel_x, pixel_y) ||
                           render_text_pixel(25, 210, "O", 9, pixel_x, pixel_y) ||
                           render_text_pixel(25, 210, "V", 10, pixel_x, pixel_y) ||
                           render_text_pixel(25, 210, "E", 11, pixel_x, pixel_y);
            
            ui_color = is_text_pixel ? text_color : background_color;
        end
    end

endmodule 