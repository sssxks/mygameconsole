`timescale 1ns / 1ps
`include "memory/memory_sizes.vh"

// -----------------------------------------------------------------------------
// screen_game – full gameplay screen: handles keyboard → move_dir, interfaces
//               with game_2048_core, renders the 4×4 board, and reports win/lose
// -----------------------------------------------------------------------------
module screen_game (
    input  wire                       clk,
    input  wire                       reset_n,
    input  wire [25:0]                key_status,

    // Framebuffer write port
    output reg                        fb_we,
    output reg [`DISP_ADDR_WIDTH-1:0] fb_addr,
    output reg [31:0]                 fb_wdata,

    // To top-level FSM
    output wire                       game_win,
    output wire                       game_lose
);
    // ------------------------------------------------------------------
    // WASD edge detection
    // ------------------------------------------------------------------
    reg  [4:0] key_prev;
    wire       key_w = key_status[22]; // W
    wire       key_a = key_status[0];  // A
    wire       key_s = key_status[18]; // S
    wire       key_d = key_status[3];  // D
    wire       key_c = key_status[2];  // C (cheat)
    // key_curr[4]=cheat C, [3]=W, [2]=A, [1]=S, [0]=D
    wire [4:0] key_curr    = {key_c, key_w, key_a, key_s, key_d};
    wire [4:0] key_pressed = key_curr & ~key_prev; // 1-cycle-wide pulse
    wire       cheat_pressed = key_pressed[4];



    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            key_prev <= 5'd0;
        else
            key_prev <= key_curr;
    end

    // ------------------------------------------------------------------
    // Interface to core logic
    // ------------------------------------------------------------------
    reg        move_valid;
    reg  [1:0] move_dir;
    reg        cheat_valid;
    wire [63:0] board_state;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            move_valid  <= 1'b0;
            move_dir    <= 2'd0;
            cheat_valid <= 1'b0;
        end else begin
            move_valid <= |key_pressed;   // pulse
            // cheat valid pulse
            cheat_valid <= cheat_pressed;
            if (|key_pressed) begin
                if (key_pressed[3])      move_dir <= 2'd0; // up (W)
                else if (key_pressed[2]) move_dir <= 2'd1; // left (A)
                else if (key_pressed[1]) move_dir <= 2'd2; // down (S)
                else                     move_dir <= 2'd3; // right (D)
            end
        end
    end

    game_2048_core u_core (
        .clk        (clk),
        .reset_n    (reset_n),
        .move_valid (move_valid),
        .move_dir   (move_dir),
        .cheat_valid(cheat_valid),
        .board_state(board_state)
    );

    // Win/Lose detection
    game_2048_check u_check (
        .board_state(board_state),
        .game_win   (game_win),
        .game_lose  (game_lose)
    );

    // ------------------------------------------------------------------
    // Helper to unpack tiles
    // ------------------------------------------------------------------
    function [3:0] tile_at;
        input [63:0] packed;
        input [3:0]  idx;
        begin
            tile_at = packed[idx*4 +: 4];
        end
    endfunction

    // ------------------------------------------------------------------
    // Continuous framebuffer fill – 1 pixel per clock
    // ------------------------------------------------------------------
    reg  [16:0] pix_cnt;          // 0 … 76799 (320×240-1)
    wire [8:0]  pix_x = pix_cnt % 320; // 0-319
    wire [7:0]  pix_y = pix_cnt / 320; // 0-239

    // Board geometry
    localparam integer BOARD_X_START = 40;
    localparam integer TILE_SIZE     = 60;

    // Tile indices
    wire [1:0] tile_x = (pix_x >= BOARD_X_START && pix_x < BOARD_X_START + 4*TILE_SIZE) ?
                        (pix_x - BOARD_X_START) / TILE_SIZE : 2'd3;
    wire [1:0] tile_y = pix_y / TILE_SIZE;

    // seems an additional left 1px is included?
    // quick and dirty fix here
    wire in_board = (pix_x > BOARD_X_START && pix_x < BOARD_X_START + 4*TILE_SIZE) &&
                    (pix_y < 4*TILE_SIZE);

    wire [5:0] off_x = pix_x - (BOARD_X_START + tile_x*TILE_SIZE);
    wire [5:0] off_y = pix_y - (tile_y*TILE_SIZE);

    // Tile texture lookup
    wire [11:0] tex_colour;
    tile_renderer u_tile_renderer (
        .clk      (clk),
        .off_x    (off_x),
        .off_y    (off_y),
        .tile_val (tile_at(board_state, tile_y*4 + tile_x)),
        .colour   (tex_colour)
    );

    // Final colour: board / white background
    wire [11:0] pixel_colour = in_board ? tex_colour : 12'hFFE;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pix_cnt <= 17'd0;
            fb_we   <= 1'b0;
        end else begin
            fb_we   <= 1'b1;
            fb_addr <= pix_cnt;
            fb_wdata<= {20'd0, pixel_colour};

            if (pix_cnt == 17'd76799)
                pix_cnt <= 17'd0;
            else
                pix_cnt <= pix_cnt + 1'b1;
        end
    end
endmodule
