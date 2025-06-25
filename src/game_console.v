`timescale 1ns / 1ps
`include "memory/memory_sizes.vh"

module game_console (
    input wire clk,          // System clock (100MHz)
    input wire reset_n,      // Asynchronous reset (active low)

    // PS/2 Keyboard Inputs
    input wire ps2_clk,    // PS/2 Clock from keyboard
    input wire ps2_data,   // PS/2 Data from keyboard

    // VGA Outputs
    output wire vga_hsync,   // Horizontal Sync
    output wire vga_vsync,   // Vertical Sync
    output wire [3:0] vga_r, // 4-bit Red
    output wire [3:0] vga_g, // 4-bit Green
    output wire [3:0] vga_b  // 4-bit Blue
);
    wire clk_100;
    wire clk_40;
    wire clk_10;
    wire locked;
    
    clk_wiz_0 clk_gen(.clk_in1(clk),.reset(~reset_n),.clk_100(clk_100),.clk_40(clk_40),.clk_10(clk_10),.locked(locked));

    // Active-low reset for system components, gated by 'locked'
    wire sys_reset_n = reset_n & locked;

    // ------------------------------------------------------------------
    // Keyboard interface (WASD controls)
    // ------------------------------------------------------------------
    wire [25:0] key_status;
    wire [9:0]  ps2_data_dummy;
    wire        ps2_ready_dummy;

    keyboard_status_keeper kb_inst (
        .clk(clk_100),
        .reset_n(sys_reset_n),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .key_status(key_status),
        .ps2_data_out(ps2_data_dummy),
        .ps2_ready(ps2_ready_dummy)
    );

    // ------------------------------------------------------------------
    // 2048 game logic → framebuffer write signals
    // ------------------------------------------------------------------
    wire                        fb_we;
    wire [`DISP_ADDR_WIDTH-1:0] fb_addr;
    wire [31:0]                 fb_wdata;

    game_2048_main game_inst (
        .clk(clk_10),
        .reset_n(sys_reset_n),
        .key_status(key_status),
        .fb_we(fb_we),
        .fb_addr(fb_addr),
        .fb_wdata(fb_wdata)
    );

    // ------------------------------------------------------------------
    // Display module (VGA out)
    // ------------------------------------------------------------------
    display disp_inst (
        .clk_40(clk_40),
        .reset_n(sys_reset_n),
        // VGA outs
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        // "CPU" write port
        .clk_cpu(clk_10),
        .mem_write(fb_we),
        .mem_addr(fb_addr),
        .mem_wdata(fb_wdata)
    );
    
endmodule