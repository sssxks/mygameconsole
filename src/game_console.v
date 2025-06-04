`timescale 1ns / 1ps

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
    wire locked;
    
    clk_wiz_0 clk_gen(.clk_in1(clk),.reset(~reset_n),.clk_100(clk_100),.clk_40(clk_40),.locked(locked));

    // Active-low reset for vga_controller, gated by 'locked'
    wire vga_reset_n = reset_n & locked;
    
    // --- PS2 ---
    wire [25:0] key_status;
    wire [7:0] ps2_keycode;
    wire       ps2_keycode_valid;

    ps2_keyboard_controller ps2_inst (
        .clk(clk_100),              // System clock for PS/2 logic (e.g. 100MHz)
        .reset_n(vga_reset_n),      // System reset (active low, gated by PLL lock)
        
        .ps2_clk(ps2_clk),    // PS/2 Clock line from keyboard pin
        .ps2_data(ps2_data),  // PS/2 Data line from keyboard pin
        
        .key_status(key_status),
        .ps2_ready(ps2_keycode_valid),
        .ps2_data_out(ps2_keycode[7:0])// discard extent, break
    );

endmodule