module game_console (
    // System Inputs
    input wire clk,          // System clock (100MHz)
    input wire reset_n,      // Asynchronous reset (active low)

    // Controller Inputs (Placeholder - define based on your controller)
    // Example: 8-bit input for D-pad and buttons
    input wire [7:0] controller_in,

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

    // Wires for color data to VGA controller
    wire [3:0] color_r_to_vga;
    wire [3:0] color_g_to_vga;
    wire [3:0] color_b_to_vga;

    // Assign a dynamic color based on pixel coordinates
    // pixel_x_internal ranges 0-799 (H_DISPLAY-1)
    // pixel_y_internal ranges 0-599 (V_DISPLAY-1)
    // Use upper bits for 4-bit color. E.g. pixel_x_internal[9:6] and pixel_y_internal[9:6]
    assign color_r_to_vga = pixel_x_internal[9:6]; // Red from X coord
    assign color_g_to_vga = 4'b0000;                // Green is off for now
    assign color_b_to_vga = pixel_y_internal[9:6]; // Blue from Y coord

    clk_wiz_0 clk_gen(
        .clk_in1(clk),
        .clk_100(clk_100), 
        .clk_40(clk_40),  
        .reset(~reset_n), 
        .locked(locked)
    );

    // Downstream logic should be reset if system reset is active OR PLL is not locked
    wire vga_reset_n;       // Active-low reset for vga_controller, gated by 'locked'
    assign vga_reset_n = reset_n | ~locked;

    wire display_enable_internal; // To connect to vga_controller's display_enable output if needed elsewhere
    wire [9:0] pixel_x_internal;  // To connect to vga_controller's pixel_x output
    wire [9:0] pixel_y_internal;  // To connect to vga_controller's pixel_y output
    wire video_on_internal;     // To connect to vga_controller's video_on output

    vga_controller vga_inst (
        .clk(clk_40),              // Using the main clock as the pixel clock for now
        .reset_n(vga_reset_n), 
        
        // Color inputs
        .input_r(color_r_to_vga),
        .input_g(color_g_to_vga),
        .input_b(color_b_to_vga),
        
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .red(vga_r),
        .green(vga_g),
        .blue(vga_b),

        .display_enable(display_enable_internal), // Connect if needed by other modules
        .pixel_x(pixel_x_internal),               // Connect if needed by other modules
        .pixel_y(pixel_y_internal),                // Connect if needed by other modules
        .video_on(video_on_internal)              // Connect new video_on signal
    );

    // The controller_in is not used yet, will be used by game logic later.

endmodule
