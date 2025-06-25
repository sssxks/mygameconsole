`timescale 1ns / 1ps
`include "memory/memory_sizes.vh"
// -----------------------------------------------------------------------------
// screen_over – solid red screen, exits on any key
// -----------------------------------------------------------------------------
module screen_over (
    input  wire                       clk,
    input  wire                       reset_n,
    input  wire [25:0]                key_status,

    output wire                       fb_we,
    output wire [`DISP_ADDR_WIDTH-1:0] fb_addr,
    output wire [31:0]                fb_wdata,
    output wire                       screen_done
);
    screen_solid #(.COLOUR(12'hF00)) u_solid (
        .clk(clk),
        .reset_n(reset_n),
        .key_status(key_status),
        .fb_we(fb_we),
        .fb_addr(fb_addr),
        .fb_wdata(fb_wdata),
        .screen_done(screen_done)
    );
endmodule
