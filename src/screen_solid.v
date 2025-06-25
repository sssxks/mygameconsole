`timescale 1ns / 1ps
`include "memory/memory_sizes.vh"
// -----------------------------------------------------------------------------
// screen_solid – fills the whole 320×240 framebuffer with a constant colour
// -----------------------------------------------------------------------------
// Parameters
//   COLOUR : 12-bit RGB colour to paint (default: white)
//
// Ports (all screens share this common subset)
//   clk, reset_n   : system clock / active-low reset
//   key_status     : 26-bit key status (used for edge detection)
//   fb_we, fb_addr, fb_wdata : write port to the display framebuffer
//   screen_done    : 1-cycle pulse when ANY key was pressed (used by top FSM)
// -----------------------------------------------------------------------------
module screen_solid #(
    parameter [11:0] COLOUR = 12'hFFF  // default white
)(
    input  wire                       clk,
    input  wire                       reset_n,
    input  wire [25:0]                key_status,

    output reg                        fb_we,
    output reg [`DISP_ADDR_WIDTH-1:0] fb_addr,
    output reg [31:0]                 fb_wdata,
    output wire                       screen_done
);
    // ------------------------------------------------------------------
    // Key edge detection (any key)
    // ------------------------------------------------------------------
    reg  [25:0] key_prev;
    wire        any_key_edge;

    assign any_key_edge = |(key_status & ~key_prev);
    assign screen_done  = any_key_edge;   // pulse used by top level

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            key_prev <= 26'd0;
        else
            key_prev <= key_status;
    end

    // ------------------------------------------------------------------
    // Simple framebuffer painter – walk through all pixels sequentially
    // ------------------------------------------------------------------
    reg [16:0] pix_cnt;              // 0 … 76799 for 320×240

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pix_cnt <= 17'd0;
            fb_we   <= 1'b0;
        end else begin
            // write pixel
            fb_we   <= 1'b1;
            fb_addr <= pix_cnt;
            fb_wdata<= {20'd0, COLOUR};

            // advance counter
            if (pix_cnt == 17'd76799)
                pix_cnt <= 17'd0;
            else
                pix_cnt <= pix_cnt + 1'b1;
        end
    end
endmodule
