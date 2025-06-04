`timescale 1ns / 1ps

module display
(
    input wire clk_40,       // System clock (40MHz)
    input wire reset_n,      // Asynchronous reset (active low)

    // VGA Outputs
    output wire vga_hsync,   // Horizontal Sync
    output wire vga_vsync,   // Vertical Sync
    output wire [3:0] vga_r, // 4-bit Red
    output wire [3:0] vga_g, // 4-bit Green
    output wire [3:0] vga_b  // 4-bit Blue
);

    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire video_on;
    wire [16:0] fb_read_addr;
    wire [11:0] fb_read_data;
    wire [3:0] color_r;
    wire [3:0] color_g;
    wire [3:0] color_b;

    vga_controller vga_inst (
        .clk(clk_40),
        .reset_n(reset_n), 
        
        .input_r(color_r),
        .input_g(color_g),
        .input_b(color_b),
        
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .red(vga_r),
        .green(vga_g),
        .blue(vga_b),

        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .video_on(video_on)
    );

    frame_scaler frame_scaler_inst (
        .clk(clk_40),
        .reset_n(reset_n),
        
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .video_on(video_on),
        
        .fb_read_addr(fb_read_addr),
        .fb_read_data(fb_read_data),

        .color_r(color_r),
        .color_g(color_g),
        .color_b(color_b)
    );
endmodule
