`timescale 1ns / 1ps
`include "memory/memory_sizes.vh"

// -----------------------------------------------------------------------------
// 2048 Game – Complete enhanced display system
// -----------------------------------------------------------------------------
// Complete rendering system with:
// - Advanced tile rendering with numbers
// - UI elements rendering (title, score, instructions)
// - Professional visual effects
// - Modular design for easy maintenance
// -----------------------------------------------------------------------------
module game_2048_logic (
    input  wire                       clk,
    input  wire                       reset_n,

    // Keyboard A-Z status (see keyboard_status_keeper)
    input  wire [25:0]                key_status,

    // Framebuffer write port (to display pipeline, port A)
    output reg                        fb_we,
    output reg [`DISP_ADDR_WIDTH-1:0] fb_addr,
    output reg [31:0]                 fb_wdata
);
    // ---------------------------------------------------------------------
    // Keyboard edge detection (W,A,S,D)
    // ---------------------------------------------------------------------
    reg  [3:0] key_prev;
    wire       key_w = key_status[22]; // W
    wire       key_a = key_status[0];  // A
    wire       key_s = key_status[18]; // S
    wire       key_d = key_status[3];  // D
    wire [3:0] key_curr    = {key_w, key_a, key_s, key_d};
    wire [3:0] key_pressed = key_curr & ~key_prev; // rising edge (1-cycle-wide)

    // ---------------------------------------------------------------------
    // Interface to core logic
    // ---------------------------------------------------------------------
    reg        move_valid;
    reg  [1:0] move_dir;
    wire [63:0] board_state;

    game_2048_core u_core (
        .clk        (clk),
        .reset_n    (reset_n),
        .move_valid (move_valid),
        .move_dir   (move_dir),
        .board_state(board_state)
    );

    // Generate move_valid/dir from key presses
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            key_prev   <= 4'b0;
            move_valid <= 1'b0;
            move_dir   <= 2'd0;
        end else begin
            key_prev   <= key_curr;
            move_valid <= |key_pressed;  // 1-cycle pulse

            if (|key_pressed) begin
                // Priority: W > A > S > D (matches bit order)
                if (key_pressed[3])      move_dir <= 2'd0; // up (W)
                else if (key_pressed[2]) move_dir <= 2'd1; // left (A)
                else if (key_pressed[1]) move_dir <= 2'd2; // down (S)
                else                     move_dir <= 2'd3; // right (D)
            end
        end
    end

    // ---------------------------------------------------------------------
    // Helpers to read packed board_state
    // ---------------------------------------------------------------------
    function automatic [3:0] tile_at;
        input [63:0] packed;
        input [3:0]  idx; // 0-15
        begin
            tile_at = packed[idx*4 +: 4];
        end
    endfunction

    // ---------------------------------------------------------------------
    // Enhanced framebuffer fill with complete rendering system
    // ---------------------------------------------------------------------
    reg  [16:0] pix_cnt;          // 0 … 76799 (320×240-1)
    wire [8:0]  pix_x = pix_cnt % 320; // 0-319
    wire [7:0]  pix_y = pix_cnt / 320; // 0-239

    // Game board layout parameters
    localparam BOARD_START_X = 40;
    localparam BOARD_START_Y = 20;
    localparam TILE_SIZE = 60;
    localparam GRID_LINE_WIDTH = 2;
    
    // Determine if we're in the game board area
    wire in_board_area = (pix_x >= BOARD_START_X) && (pix_x < BOARD_START_X + 4*TILE_SIZE) &&
                        (pix_y >= BOARD_START_Y) && (pix_y < BOARD_START_Y + 4*TILE_SIZE);
    
    // Calculate tile coordinates
    wire [8:0] board_x = pix_x - BOARD_START_X;
    wire [7:0] board_y = pix_y - BOARD_START_Y;
    wire [1:0] tile_x = board_x / TILE_SIZE;
    wire [1:0] tile_y = board_y / TILE_SIZE;
    wire [3:0] tile_val = tile_at(board_state, tile_y*4 + tile_x);
    
    // Position within current tile
    wire [5:0] tile_pos_x = board_x % TILE_SIZE;
    wire [5:0] tile_pos_y = board_y % TILE_SIZE;
    
    // Grid line detection
    wire is_grid_line = (tile_pos_x < GRID_LINE_WIDTH) || (tile_pos_y < GRID_LINE_WIDTH);
        
    // ---------------------------------------------------------------------
    // Tile sprite renderer instantiation (using real images)
    // ---------------------------------------------------------------------
    wire [11:0] tile_pixel_color;
    
    tile_sprite_renderer tile_render_inst (
        .clk(clk),
        .reset_n(reset_n),
        .tile_value(tile_val),
        .tile_pos_x(tile_pos_x),
        .tile_pos_y(tile_pos_y),
        .pixel_color(tile_pixel_color)
    );

    // ---------------------------------------------------------------------
    // UI renderer instantiation
    // ---------------------------------------------------------------------
    wire ui_in_area;
    wire [11:0] ui_pixel_color;
    
    ui_renderer ui_render_inst (
        .clk(clk),
        .reset_n(reset_n),
        .pixel_x(pix_x),
        .pixel_y(pix_y),
        .board_state(board_state),
        .score(16'd0),              // TODO: implement score calculation
        .game_over(1'b0),           // TODO: implement game over detection
        .in_ui_area(ui_in_area),
        .ui_color(ui_pixel_color)
    );

    // ---------------------------------------------------------------------
    // Background pattern for non-game, non-UI areas
    // ---------------------------------------------------------------------
    function automatic [11:0] get_background_color;
        input [8:0] x;
        input [7:0] y;
        reg [11:0] bg_color;
        begin
            // Create a subtle animated pattern
            reg [3:0] pattern_val = (x >> 4) + (y >> 4) + (pix_cnt >> 12);
            case (pattern_val & 3)
                0: bg_color = 12'h111;  // Very dark gray
                1: bg_color = 12'h222;  // Dark gray
                2: bg_color = 12'h333;  // Medium dark gray
                3: bg_color = 12'h444;  // Medium gray
            endcase
            get_background_color = bg_color;
        end
    endfunction

    always @(posedge clk) begin
        if (!reset_n) begin
            pix_cnt <= 17'd0;
            fb_we   <= 1'b0;
        end else begin
            // Write current pixel
            fb_we   <= 1'b1;
            fb_addr <= pix_cnt;
            
            // Pixel priority: UI > Game Board > Background
            if (ui_in_area) begin
                // UI elements have highest priority
                fb_wdata <= {20'd0, ui_pixel_color};
            end else if (in_board_area) begin
                if (is_grid_line) begin
                    // Grid lines - dark separator with slight gradient
                    reg [11:0] grid_color = 12'h222 + {8'd0, tile_pos_x[1:0], tile_pos_y[1:0]};
                    fb_wdata <= {20'd0, grid_color};
                end else begin
                    // Tile area - use tile renderer
                    fb_wdata <= {20'd0, tile_pixel_color};
                end
            end else begin
                // Background area
                fb_wdata <= {20'd0, get_background_color(pix_x, pix_y)};
            end

            // Advance pixel counter
            if (pix_cnt == 17'd76799)
                pix_cnt <= 0;
            else
                pix_cnt <= pix_cnt + 1'b1;
        end
    end
endmodule
