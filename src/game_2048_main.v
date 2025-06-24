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

    // Board/tile geometry parameters
    localparam integer BOARD_X_START = 40;
    localparam integer TILE_SIZE     = 60;

    // Tile indices within the board
    wire [1:0] tile_x = (pix_x >= BOARD_X_START && pix_x < BOARD_X_START + 4*TILE_SIZE) ?
                        (pix_x - BOARD_X_START) / TILE_SIZE : 2'd3;
    wire [1:0] tile_y = pix_y / TILE_SIZE; // top padding = 0

    // Is the current pixel within the 4×4 board region?
    wire in_board = (pix_x >= BOARD_X_START && pix_x < BOARD_X_START + 4*TILE_SIZE) &&
                    (pix_y < 4*TILE_SIZE);

    // Relative pixel coordinates within the current tile (0-59)
    wire [5:0] off_x = pix_x - (BOARD_X_START + tile_x*TILE_SIZE);
    wire [5:0] off_y = pix_y - (tile_y*TILE_SIZE);

    // Lookup the tile's texture pixel using a single renderer/ROM
    wire [11:0] tex_colour;
    tile_renderer u_tile_renderer (
        .clk      (clk),
        .off_x    (off_x),
        .off_y    (off_y),
        .tile_val (tile_at(board_state, tile_y*4 + tile_x)),
        .colour   (tex_colour)
    );

    // Final pixel colour
    wire [11:0] pixel_colour = in_board ? tex_colour : 12'h555; // background outside board

    always @(posedge clk) begin
        if (!reset_n) begin
            pix_cnt <= 17'd0;
            fb_we   <= 1'b0;
        end else begin
            // write current pixel
            fb_we   <= 1'b1;
            fb_addr <= pix_cnt;
            fb_wdata<= {20'd0, pixel_colour}; // colour in lower 12 bits to match display.v

            // advance pixel counter
            if (pix_cnt == 17'd76799)
                pix_cnt <= 0;
            else
                pix_cnt <= pix_cnt + 1'b1;
        end
    end
endmodule

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

    tile_texture_rom u_tex_rom (
        .clk  (clk),
        .addr (tex_addr),
        .data (colour)
    );
endmodule

// -----------------------------------------------------------------------------
// Placeholder texture ROM – to be replaced with actual texture data
// -----------------------------------------------------------------------------
module tile_texture_rom (
    input  wire        clk,
    input  wire [15:0] addr,
    output reg  [11:0] data
);
    // NOTE: Replace this behavioural ROM with your texture memory.
    //       The lower 12 bits of `data` are RGB (4-4-4).
    // Combinational colour lookup based on the tile value (upper 4 address bits).
    // The same colour is used for every pixel of a tile – later you can replace this
    // with a proper texture ROM. Colours are encoded RGB in 4-4-4 format.
    always @(*) begin
        case (addr[15:12]) // tile value selector
            4'd0:  data = 12'h888; // blank cell – mid-grey
            4'd1:  data = 12'hEEE; // 2
            4'd2:  data = 12'hDDD; // 4
            4'd3:  data = 12'hFFB; // 8
            4'd4:  data = 12'hFF9; // 16
            4'd5:  data = 12'hFF6; // 32
            4'd6:  data = 12'hFF3; // 64
            4'd7:  data = 12'hFD0; // 128
            4'd8:  data = 12'hFA0; // 256
            4'd9:  data = 12'hF70; // 512
            4'd10: data = 12'hF40; // 1024
            4'd11: data = 12'hF10; // 2048
            default: data = 12'h000; // fallback black
        endcase
    end
endmodule
