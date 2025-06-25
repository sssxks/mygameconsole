`timescale 1ns / 1ps
`include "memory/memory_sizes.vh"

// -----------------------------------------------------------------------------
// game_2048_main – top wrapper that selects one of four "screen_*" modules
//                  according to the current game state.
// -----------------------------------------------------------------------------
// Screen modules:
//   screen_start : yellow start screen – exits on ANY key
//   screen_game  : gameplay – delivers game_win / game_lose
//   screen_win   : solid green – exits on ANY key
//   screen_over  : solid red   – exits on ANY key
// -----------------------------------------------------------------------------
module game_2048_main (
    input  wire                       clk,
    input  wire                       reset_n,

    // Keyboard A–Z status (see keyboard_status_keeper)
    input  wire [25:0]                key_status,

    // Framebuffer write port (to display pipeline, port A)
    output reg                        fb_we,
    output reg [`DISP_ADDR_WIDTH-1:0] fb_addr,
    output reg [31:0]                 fb_wdata
);
    // ------------------------------------------------------------------
    // Game-state constants and register declared EARLY so we can use them for
    // per-screen gated resets before the instantiations.
    // ------------------------------------------------------------------
    localparam [1:0] GAME_START = 2'd0;
    localparam [1:0] GAME_PLAY  = 2'd1;
    localparam [1:0] GAME_WIN   = 2'd2;
    localparam [1:0] GAME_OVER  = 2'd3;

    reg [1:0] game_state;

    // Per-screen resets: active only when that screen is selected.
    wire st_reset_n = reset_n & (game_state == GAME_START);
    wire gm_reset_n = reset_n & (game_state == GAME_PLAY );
    wire wn_reset_n = reset_n & (game_state == GAME_WIN  );
    wire ov_reset_n = reset_n & (game_state == GAME_OVER );

    // ------------------------------------------------------------------
    // Instantiate all screen modules
    // ------------------------------------------------------------------
    // START screen (yellow)
    wire                        st_fb_we;
    wire [`DISP_ADDR_WIDTH-1:0] st_fb_addr;
    wire [31:0]                 st_fb_wdata;
    wire                        st_done;

    screen_start u_start (
        .clk        (clk),
        .reset_n    (st_reset_n),
        .key_status (key_status),
        .fb_we      (st_fb_we),
        .fb_addr    (st_fb_addr),
        .fb_wdata   (st_fb_wdata),
        .screen_done(st_done)
    );

    // GAMEPLAY screen
    wire                        gm_fb_we;
    wire [`DISP_ADDR_WIDTH-1:0] gm_fb_addr;
    wire [31:0]                 gm_fb_wdata;
    wire                        gm_win;
    wire                        gm_lose;

    screen_game u_game (
        .clk        (clk),
        .reset_n    (gm_reset_n),
        .key_status (key_status),
        .fb_we      (gm_fb_we),
        .fb_addr    (gm_fb_addr),
        .fb_wdata   (gm_fb_wdata),
        .game_win   (gm_win),
        .game_lose  (gm_lose)
    );

    // WIN screen (green)
    wire                        wn_fb_we;
    wire [`DISP_ADDR_WIDTH-1:0] wn_fb_addr;
    wire [31:0]                 wn_fb_wdata;
    wire                        wn_done;

    screen_win u_win (
        .clk        (clk),
        .reset_n    (wn_reset_n),
        .key_status (key_status),
        .fb_we      (wn_fb_we),
        .fb_addr    (wn_fb_addr),
        .fb_wdata   (wn_fb_wdata),
        .screen_done(wn_done)
    );

    // OVER screen (red)
    wire                        ov_fb_we;
    wire [`DISP_ADDR_WIDTH-1:0] ov_fb_addr;
    wire [31:0]                 ov_fb_wdata;
    wire                        ov_done;

    screen_over u_over (
        .clk        (clk),
        .reset_n    (ov_reset_n),
        .key_status (key_status),
        .fb_we      (ov_fb_we),
        .fb_addr    (ov_fb_addr),
        .fb_wdata   (ov_fb_wdata),
        .screen_done(ov_done)
    );

    // ------------------------------------------------------------------
    // Top-level FSM for game state
    // ------------------------------------------------------------------

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            game_state <= GAME_START;
        else begin
            case (game_state)
                GAME_START: if (st_done)          game_state <= GAME_PLAY;
                GAME_PLAY : if (gm_win)           game_state <= GAME_WIN;
                            else if (gm_lose)     game_state <= GAME_OVER;
                GAME_WIN  : if (wn_done)          game_state <= GAME_START;
                GAME_OVER : if (ov_done)          game_state <= GAME_START;
                default   : game_state <= GAME_START;
            endcase
        end
    end

    // ------------------------------------------------------------------
    // Framebuffer output multiplexer – combinational
    // ------------------------------------------------------------------
    always @(*) begin
        case (game_state)
            GAME_START: begin
                fb_we   = st_fb_we;
                fb_addr = st_fb_addr;
                fb_wdata= st_fb_wdata;
            end
            GAME_PLAY: begin
                fb_we   = gm_fb_we;
                fb_addr = gm_fb_addr;
                fb_wdata= gm_fb_wdata;
            end
            GAME_WIN: begin
                fb_we   = wn_fb_we;
                fb_addr = wn_fb_addr;
                fb_wdata= wn_fb_wdata;
            end
            default: begin // GAME_OVER
                fb_we   = ov_fb_we;
                fb_addr = ov_fb_addr;
                fb_wdata= ov_fb_wdata;
            end
        endcase
    end
endmodule