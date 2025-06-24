`timescale 1ns / 1ps
`include "memory/memory_sizes.vh"

// -----------------------------------------------------------------------------
// 2048 Game – display + keyboard wrapper around game_2048_core
// -----------------------------------------------------------------------------
// Keeps VGA-framebuffer fill and WASD edge-detection, but delegates board
// mutations to `game_2048_core`.  The public interface is unchanged so the
// top-level design does not need to change (just make sure to compile this
// file instead of the old monolithic version).
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
    // Continuous framebuffer fill (one pixel per clock)
    // ---------------------------------------------------------------------
    reg  [16:0] pix_cnt;          // 0 … 76799 (320×240-1)
    wire [8:0]  pix_x = pix_cnt % 320; // 0-319
    wire [7:0]  pix_y = pix_cnt / 320; // 0-239

    // Tile indices within the board
    wire [1:0] tile_x = (pix_x >= 40 && pix_x < 280) ? (pix_x - 40) / 60 : 2'd3;
    wire [1:0] tile_y = pix_y / 60; // top padding = 0
    wire [3:0] tile_val = tile_at(board_state, tile_y*4 + tile_x);

    // Colour LUT (12-bit RGB)
    function automatic [11:0] tile_colour;
        input [3:0] val;
        begin
            case (val)
                0: tile_colour = 12'hEEE;
                1: tile_colour = 12'hFFE;
                2: tile_colour = 12'hFFC;
                3: tile_colour = 12'hFC8;
                4: tile_colour = 12'hF96;
                5: tile_colour = 12'hF74;
                6: tile_colour = 12'hF52;
                default: tile_colour = 12'hF30;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (!reset_n) begin
            pix_cnt <= 17'd0;
            fb_we   <= 1'b0;
        end else begin
            // write current pixel
            fb_we   <= 1'b1;
            fb_addr <= pix_cnt;
            fb_wdata<= {20'd0, tile_colour(tile_val)}; // colour in lower 12 bits to match display.v

            // advance pixel counter
            if (pix_cnt == 17'd76799)
                pix_cnt <= 0;
            else
                pix_cnt <= pix_cnt + 1'b1;
        end
    end
endmodule
