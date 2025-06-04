module game_console (
    // System Inputs
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

    // Wires from VGA controller, used for drawing logic
    wire display_enable_internal; 
    wire [9:0] pixel_x_internal;  
    wire [9:0] pixel_y_internal;  
    wire video_on_internal;     

    // Wires for color data to VGA controller
    wire [3:0] color_r_to_vga;
    wire [3:0] color_g_to_vga;
    wire [3:0] color_b_to_vga;

    // Define rectangle coordinates (e.g., a 400x300 rectangle in the middle)
    // For 800x600 display
    localparam RECT_X1 = 200; // Start X
    localparam RECT_Y1 = 150; // Start Y
    localparam RECT_X2 = 600; // End X (exclusive, so width is RECT_X2 - RECT_X1 = 400)
    localparam RECT_Y2 = 450; // End Y (exclusive, so height is RECT_Y2 - RECT_Y1 = 300)

    // Scan codes for keys (make codes)
    localparam KEY_R = 8'h2D;
    localparam KEY_G = 8'h34;
    localparam KEY_B = 8'h32;
    localparam KEY_W = 8'h1D; // For White

    // Registers for rectangle color, controlled by keyboard
    reg [3:0] rect_color_r_reg;
    reg [3:0] rect_color_g_reg;
    reg [3:0] rect_color_b_reg;

    // Logic to draw a colored rectangle on a black background
    // pixel_x_internal and pixel_y_internal are outputs from vga_controller
    assign color_r_to_vga = (video_on_internal && pixel_x_internal >= RECT_X1 && pixel_x_internal < RECT_X2 &&
                             pixel_y_internal >= RECT_Y1 && pixel_y_internal < RECT_Y2) ? rect_color_r_reg : 4'b0000;
    assign color_g_to_vga = (video_on_internal && pixel_x_internal >= RECT_X1 && pixel_x_internal < RECT_X2 &&
                             pixel_y_internal >= RECT_Y1 && pixel_y_internal < RECT_Y2) ? rect_color_g_reg : 4'b0000;
    assign color_b_to_vga = (video_on_internal && pixel_x_internal >= RECT_X1 && pixel_x_internal < RECT_X2 &&
                             pixel_y_internal >= RECT_Y1 && pixel_y_internal < RECT_Y2) ? rect_color_b_reg : 4'b0000;

    clk_wiz_0 clk_gen(
        .clk_in1(clk),
        .clk_100(clk_100), 
        .clk_40(clk_40),  
        .reset(~reset_n), 
        .locked(locked)
    );

    // Downstream logic should be reset if system reset is active OR PLL is not locked
    wire vga_reset_n;       // Active-low reset for vga_controller, gated by 'locked'
    assign vga_reset_n = reset_n & locked;
    
    // --- PS/2 Keyboard Controller ---
    wire [7:0] ps2_keycode;
    wire       ps2_keycode_valid;
    // wire       ps2_error;
    ps2_keyboard_controller ps2_inst (
        .clk(clk_100),              // System clock for PS/2 logic (e.g. 100MHz)
        .reset_n(vga_reset_n),      // System reset (active low, gated by PLL lock)
        
        .ps2_clk(ps2_clk),    // PS/2 Clock line from keyboard pin
        .ps2_data(ps2_data),  // PS/2 Data line from keyboard pin

        .data_out(ps2_keycode[7:0]), // discard extent, break
        .ready(ps2_keycode_valid)
    );

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

    // --- Keyboard Color Control Logic ---
    always @(posedge clk_100 or negedge vga_reset_n) begin
        if (!vga_reset_n) begin
            rect_color_r_reg <= 4'b1111; // Default to White
            rect_color_g_reg <= 4'b1111;
            rect_color_b_reg <= 4'b1111;
        end else begin
            if (ps2_keycode_valid) begin
                case (ps2_keycode)
                    KEY_R: begin
                        rect_color_r_reg <= 4'b1111;
                        rect_color_g_reg <= 4'b0000;
                        rect_color_b_reg <= 4'b0000;
                    end
                    KEY_G: begin
                        rect_color_r_reg <= 4'b0000;
                        rect_color_g_reg <= 4'b1111;
                        rect_color_b_reg <= 4'b0000;
                    end
                    KEY_B: begin
                        rect_color_r_reg <= 4'b0000;
                        rect_color_g_reg <= 4'b0000;
                        rect_color_b_reg <= 4'b1111;
                    end
                    KEY_W: begin
                        rect_color_r_reg <= 4'b1111;
                        rect_color_g_reg <= 4'b1111;
                        rect_color_b_reg <= 4'b1111;
                    end
                    default: begin
                        // Optional: Do nothing or revert to a default color on other key presses
                        // For now, keeps the current color if key is not R, G, B, or W
                    end
                endcase
            end
        end
    end

    // For now, we are not using the keycode outputs beyond this demo.
    // Game logic will use ps2_keycode when ps2_keycode_valid is high.

endmodule
