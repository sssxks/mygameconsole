`timescale 1ns / 1ps
`include "memory/memory_sizes.vh"

// -----------------------------------------------------------------------------
// 2048 Game Logic + Simple Framebuffer Renderer
// -----------------------------------------------------------------------------
// This module maintains the 4×4 grid, processes WASD keyboard inputs (mapped to
// up/left/down/right) and continuously renders the board into the 320×240
// framebuffer used by the existing display pipeline.  Each tile occupies a
// 60×60 pixel square.  The screen is therefore split into a centred 240×240
// game area (left-aligned at x = 40) with a 20-pixel border left/right and an
// extra 0-pixel border top/bottom.
//
// Colour scheme (12-bit RGB)
//   0/empty : 12'hEEE (light grey)
//   1 (2)   : 12'hFFE (yellow-ish)
//   2 (4)   : 12'hFFC (light orange)
//   3 (8)   : 12'hFC8
//   4 (16)  : 12'hF96
//   5 (32)  : 12'hF74
//   6 (64)  : 12'hF52
//   7+      : 12'hF30 (dark orange)
//
// The framebuffer is written one pixel per system clock cycle (clk) in a simple
// raster-scan manner.  Because the framebuffer is dual-port block RAM, this
// continuous CPU-side fill does not interfere with the VGA controller reads.
// -----------------------------------------------------------------------------
module game_2048_logic (
    input  wire                       clk,          // 100 MHz system clock
    input  wire                       reset_n,      // async active-low reset

    // Keyboard status – 26 bits mapping to A-Z (see keyboard_status_keeper)
    input  wire [25:0]                key_status,

    // Frame-buffer write port (to display.sv, port A)
    output reg                        fb_we,        // write enable
    output reg [`DISP_ADDR_WIDTH-1:0] fb_addr,
    output reg [31:0]                 fb_wdata
);
    // ---------------------------------------------------------------------
    // Board representation: 16 tiles, 4-bit exponent (0 = empty, 1 = 2, ...)
    // ---------------------------------------------------------------------
    reg [3:0] board  [0:15];    // current board
    reg [3:0] old_board [0:15]; // copy used for change detection

    // LFSR for pseudo-random tile placement
    reg [15:0] lfsr;

    // Keyboard edge detection (W,A,S,D)
    reg [3:0]  key_prev;
    wire       key_w = key_status[22]; // W
    wire       key_a = key_status[0];  // A
    wire       key_s = key_status[18]; // S
    wire       key_d = key_status[3];  // D
    wire [3:0] key_curr = {key_w, key_a, key_s, key_d};
    wire [3:0] key_pressed = key_curr & ~key_prev; // rising edge

    // ---------------------------------------------------------------------
    // Helper function – merge/shift a 4-element line to the left
    // ---------------------------------------------------------------------
    function [15:0] merge_line;
        input [15:0] in_line; // {a,b,c,d} each 4-bit
        reg   [3:0]  t  [0:3];
        reg   [3:0]  out[0:3];
        integer      i, idx;
        begin
            // -----------------------------------------------------------------
            // Stage 0 : initialise output array to zero to avoid unknown values
            // -----------------------------------------------------------------
            for (i = 0; i < 4; i = i + 1) begin
                out[i] = 4'd0;
            end

            // -----------------------------------------------------------------
            // Stage 1 : compress – copy non-zero tiles to the leftmost side
            // -----------------------------------------------------------------
            {t[0], t[1], t[2], t[3]} = in_line;
            idx = 0;
            for (i = 0; i < 4; i = i + 1) begin
                if (t[i] != 0) begin
                    out[idx] = t[i];
                    idx      = idx + 1;
                end
            end

            // -----------------------------------------------------------------
            // Stage 2 : merge equal adjacent pairs (2→4, 4→8, …)
            // -----------------------------------------------------------------
            for (i = 0; i < 3; i = i + 1) begin
                if (out[i] != 0 && out[i] == out[i+1]) begin
                    out[i]   = out[i] + 1;
                    out[i+1] = 0;
                end
            end

            // -----------------------------------------------------------------
            // Stage 3 : final compress to fill any gaps caused by merging
            // -----------------------------------------------------------------
            t[0] = out[0];
            t[1] = out[1];
            t[2] = out[2];
            t[3] = out[3];
            for (i = 0; i < 4; i = i + 1) begin
                out[i] = 0; // clear again
            end

            idx = 0;
            for (i = 0; i < 4; i = i + 1) begin
                if (t[i] != 0) begin
                    out[idx] = t[i];
                    idx      = idx + 1;
                end
            end

            // -----------------------------------------------------------------
            // Combine array back into packed 16-bit vector
            // -----------------------------------------------------------------
            merge_line = {out[0], out[1], out[2], out[3]};
        end
    endfunction

    // ---------------------------------------------------------------------
    // Add random tile (2 with 7/8 probability, 4 with 1/8 probability)
    // ---------------------------------------------------------------------
    task add_random_tile;
        integer i;
        integer start_idx;
        integer pos;
        reg      found;
        begin
            // Choose a pseudo-random starting tile position (0-15)
            start_idx = lfsr[3:0];
            found     = 1'b0;

            // Scan the board once, starting at start_idx and wrapping around, to
            // locate the first empty tile. Because the loop bounds are fixed and
            // we no longer modify the loop variable inside the body, synthesis
            // tools can converge on the loop condition.
            for (i = 0; i < 16; i = i + 1) begin
                pos = (start_idx + i) & 4'hF;
                if (!found && board[pos] == 0) begin
                    board[pos] <= (lfsr[3:1] == 3'b000) ? 2 : 1; // 12.5% chance of 4, else 2
                    found      = 1'b1; // prevent further writes this iteration
                end
            end
        end
    endtask

    // ---------------------------------------------------------------------
    // Board update on key press
    // ---------------------------------------------------------------------
    integer r,c,idx;
    reg   [15:0] line_in, line_out;
    reg   moved;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // reset / initial state – clear board and seed LFSR
            for (idx = 0; idx < 16; idx = idx + 1) board[idx] <= 0;
            lfsr     <= 16'hACE1; // non-zero seed
            key_prev <= 4'b0;
            // add two starting tiles
            add_random_tile();
            add_random_tile();
        end else begin
            // LFSR update – x^16 + x^14 + x^13 + x^11 + 1 (tap 16,14,13,11)
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

            // keyboard edge detection
            key_prev <= key_curr;

            moved = 1'b0;
            if (|key_pressed) begin
                // Make a copy for comparison later (detect if board changed)
                
                for (idx = 0; idx < 16; idx = idx + 1) old_board[idx] = board[idx];

                if (key_pressed[3]) begin // W (up)
                    for (c = 0; c < 4; c = c + 1) begin
                        line_in = {board[0*4 + c], board[1*4 + c], board[2*4 + c], board[3*4 + c]};
                        line_out = merge_line(line_in);
                        {board[0*4 + c], board[1*4 + c], board[2*4 + c], board[3*4 + c]} <= line_out;
                    end
                end else if (key_pressed[2]) begin // A (left)
                    for (r = 0; r < 4; r = r + 1) begin
                        line_in = {board[r*4 + 0], board[r*4 + 1], board[r*4 + 2], board[r*4 + 3]};
                        line_out = merge_line(line_in);
                        {board[r*4 + 0], board[r*4 + 1], board[r*4 + 2], board[r*4 + 3]} <= line_out;
                    end
                end else if (key_pressed[1]) begin // S (down)
                    for (c = 0; c < 4; c = c + 1) begin
                        line_in = {board[3*4 + c], board[2*4 + c], board[1*4 + c], board[0*4 + c]};
                        line_out = merge_line(line_in);
                        {board[3*4 + c], board[2*4 + c], board[1*4 + c], board[0*4 + c]} <= line_out;
                    end
                end else if (key_pressed[0]) begin // D (right)
                    for (r = 0; r < 4; r = r + 1) begin
                        line_in = {board[r*4 + 3], board[r*4 + 2], board[r*4 + 1], board[r*4 + 0]};
                        line_out = merge_line(line_in);
                        {board[r*4 + 3], board[r*4 + 2], board[r*4 + 1], board[r*4 + 0]} <= line_out;
                    end
                end

                // Check if board changed → add random tile
                for (idx = 0; idx < 16; idx = idx + 1) begin
                    if (board[idx] != old_board[idx]) moved = 1'b1;
                end
                if (moved) add_random_tile();
            end
        end
    end

    // ---------------------------------------------------------------------
    // Continuous framebuffer fill (one pixel per clock)
    // ---------------------------------------------------------------------
    reg [16:0] pix_cnt; // 0 … 76799 (320×240-1)
    wire [8:0] pix_x = pix_cnt % 320; // 0-319
    wire [7:0] pix_y = pix_cnt / 320; // 0-239

    // Tile indices
    wire [1:0] tile_x = (pix_x >= 40 && pix_x < 280) ? (pix_x - 40) / 60 : 2'd3;
    wire [1:0] tile_y = (pix_y) / 60; // top padding = 0
    wire [3:0] tile_val = board[tile_y*4 + tile_x];

    // Colour LUT
    function [11:0] tile_colour;
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
            pix_cnt <= 0;
            fb_we   <= 1'b0;
        end else begin
            // write current pixel
            fb_we   <= 1'b1;
            fb_addr <= pix_cnt;
            fb_wdata<= {tile_colour(tile_val), 20'd0}; // colour in upper 12 bits

            // advance pixel counter
            if (pix_cnt == 17'd76799)
                pix_cnt <= 0;
            else
                pix_cnt <= pix_cnt + 1'b1;
        end
    end
endmodule
