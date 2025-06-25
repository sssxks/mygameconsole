`timescale 1ns / 1ps
`include "memory/memory_sizes.vh"
// -----------------------------------------------------------------------------
// screen_start – yellow "press any key" screen (solid colour reuse)
// -----------------------------------------------------------------------------
module screen_start (
    input  wire                       clk,
    input  wire                       reset_n,
    input  wire [25:0]                key_status,

    output reg                        fb_we,
    output reg [`DISP_ADDR_WIDTH-1:0]  fb_addr,
    output reg  [31:0]               fb_wdata,
    output wire                       screen_done
);
    //------------------------------------------------------------------
    // Key edge detection (any key, identical to screen_solid)
    //------------------------------------------------------------------
    reg  [25:0] key_prev;
    reg         armed;          // becomes 1 when key_status == 0 once

    wire        any_key_edge;

    assign any_key_edge = armed & |(key_status & ~key_prev);
    assign screen_done  = any_key_edge;   // 1-cycle pulse to top FSM

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            key_prev <= 26'd0;
            armed    <= 1'b0;
        end else begin
            key_prev <= key_status;
            // (Re)arm once we have observed all keys released
            if (!armed) begin
                if (key_status == 26'd0)
                    armed <= 1'b1;
            end
        end
    end

    //------------------------------------------------------------------
    // Framebuffer painter – stream 320×240 texture from ROM
    //------------------------------------------------------------------
    reg  [16:0] pix_cnt;       // 0 … 76799 for 320×240
    reg  [16:0] pix_cnt_d;     // delayed address (ROM latency = 1 cycle)

    wire [11:0] rom_data;

    // Block Memory Generator IP instance generated via Vivado
    start_screen_rom u_rom (
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
            // Advance address counter
            if (pix_cnt == 17'd76799)
                pix_cnt <= 17'd0;
            else
                pix_cnt <= pix_cnt + 1'b1;

            // Pipeline to account for ROM read latency
            pix_cnt_d <= pix_cnt;

            // Write data from previous cycle to framebuffer
            fb_we    <= 1'b1;
            fb_addr  <= pix_cnt_d;
            fb_wdata <= {20'd0, rom_data};
        end
    end
endmodule
