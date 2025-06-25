`timescale 1ns / 1ps
`include "memory/memory_sizes.vh"
// -----------------------------------------------------------------------------
// screen_over – solid red screen, exits on any key
// -----------------------------------------------------------------------------
module screen_over (
    input  wire                       clk,
    input  wire                       reset_n,
    input  wire [25:0]                key_status,

    output reg                        fb_we,
    output reg [`DISP_ADDR_WIDTH-1:0]  fb_addr,
    output reg  [31:0]               fb_wdata,
    output wire                       screen_done
);
    //------------------------------------------------------------------
    // Key edge detection (any key)
    //------------------------------------------------------------------
    reg  [25:0] key_prev;
    reg         armed;
    wire        any_key_edge;

    assign any_key_edge = armed & |(key_status & ~key_prev);
    assign screen_done  = any_key_edge;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            key_prev <= 26'd0;
            armed    <= 1'b0;
        end else begin
            key_prev <= key_status;
            if (!armed && key_status == 26'd0)
                armed <= 1'b1;
        end
    end

    //------------------------------------------------------------------
    // Stream 320×240 lose texture from ROM
    //------------------------------------------------------------------
    reg  [16:0] pix_cnt;
    reg  [16:0] pix_cnt_d;
    wire [11:0] rom_data;

    lose_screen_rom u_rom (
        .clka  (clk),
        .ena   (1'b1),
        .addra (pix_cnt),
        .douta (rom_data)
    );

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pix_cnt   <= 17'd0;
            pix_cnt_d <= 17'd0;
            fb_we     <= 1'b0;
        end else begin
            if (pix_cnt == 17'd76799)
                pix_cnt <= 17'd0;
            else
                pix_cnt <= pix_cnt + 1'b1;

            pix_cnt_d <= pix_cnt;

            fb_we    <= 1'b1;
            fb_addr  <= pix_cnt_d;
            fb_wdata <= {20'd0, rom_data};
        end
    end
endmodule
