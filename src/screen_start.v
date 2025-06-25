`timescale 1ns / 1ps
`include "memory/memory_sizes.vh"
// -----------------------------------------------------------------------------
// screen_start – yellow "press any key" screen (solid colour reuse)
// -----------------------------------------------------------------------------
module screen_start (
    input  wire                       clk,
    input  wire                       reset_n,
    input  wire [25:0]                key_status,

    output wire                       fb_we,
    output wire [`DISP_ADDR_WIDTH-1:0] fb_addr,
    output wire [31:0]                fb_wdata,
    output wire                       screen_done
);
    // Re-use screen_solid with COLOUR=12'hFF0 (yellow)
    screen_solid #(.COLOUR(12'hFF0)) u_solid (
        .clk(clk),
        .reset_n(reset_n),
        .key_status(key_status),
        .fb_we(fb_we),
        .fb_addr(fb_addr),
        .fb_wdata(fb_wdata),
        .screen_done(screen_done)
    );
endmodule
