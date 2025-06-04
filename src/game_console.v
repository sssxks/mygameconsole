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
    
    // Frame buffer parameters
    localparam FB_WIDTH = 800;
    localparam FB_HEIGHT = 600;
    localparam FB_ADDR_WIDTH = 19;  // log2(800*600) = 18.6, round up to 19
    localparam FB_DATA_WIDTH = 12;  // 4 bits each for R, G, B

    // Wires from VGA controller, used for drawing logic
    wire display_enable_internal; 
    wire [9:0] pixel_x_internal;  
    wire [9:0] pixel_y_internal;  
    wire video_on_internal;     

    // Wires for color data to VGA controller
    wire [3:0] color_r_to_vga;
    wire [3:0] color_g_to_vga;
    wire [3:0] color_b_to_vga;
    
    // Frame buffer signals
    reg [FB_ADDR_WIDTH-1:0] fb_write_addr;
    reg [FB_DATA_WIDTH-1:0] fb_write_data;
    reg fb_write_enable;
    wire [FB_ADDR_WIDTH-1:0] fb_read_addr;
    wire [FB_DATA_WIDTH-1:0] fb_read_data;

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

    // Frame buffer read address calculation
    assign fb_read_addr = pixel_y_internal * FB_WIDTH + pixel_x_internal;
    
    // Extract color components from frame buffer data
    wire [3:0] fb_r = fb_read_data[11:8];
    wire [3:0] fb_g = fb_read_data[7:4];
    wire [3:0] fb_b = fb_read_data[3:0];
    
    // Output color from frame buffer when video is active
    assign color_r_to_vga = video_on_internal ? fb_r : 4'b0000;
    assign color_g_to_vga = video_on_internal ? fb_g : 4'b0000;
    assign color_b_to_vga = video_on_internal ? fb_b : 4'b0000;

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
    wire [25:0] key_status;
    wire [7:0] ps2_keycode;
    wire       ps2_keycode_valid;
    // wire       ps2_error;
    ps2_keyboard_controller ps2_inst (
        .clk(clk_100),              // System clock for PS/2 logic (e.g. 100MHz)
        .reset_n(vga_reset_n),      // System reset (active low, gated by PLL lock)
        
        .ps2_clk(ps2_clk),    // PS/2 Clock line from keyboard pin
        .ps2_data(ps2_data),  // PS/2 Data line from keyboard pin
        
        .key_status(key_status),
        .ps2_ready(ps2_keycode_valid),
        .ps2_data_out(ps2_keycode[7:0])// discard extent, break
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

    // Frame buffer memory instantiation
    frame_buffer fb_inst (
        .clk(clk_100),
        .write_enable(fb_write_enable),
        .write_addr(fb_write_addr),
        .write_data(fb_write_data),
        .read_addr(fb_read_addr),
        .read_data(fb_read_data)
    );
    
    // --- Keyboard Color Control Logic ---
    always @(posedge clk_100 or negedge vga_reset_n) begin
        if (!vga_reset_n) begin
            rect_color_r_reg <= 4'b1111; // Default to White
            rect_color_g_reg <= 4'b1111;
            rect_color_b_reg <= 4'b1111;
            fb_write_enable <= 0;
        end else begin
            // Default state - no write to frame buffer
            fb_write_enable <= 0;
            
            if (ps2_keycode_valid) begin
                case (ps2_keycode)
                    KEY_R: begin
                        rect_color_r_reg <= 4'b1111;
                        rect_color_g_reg <= 4'b0000;
                        rect_color_b_reg <= 4'b0000;
                        // Trigger frame buffer update
                        fb_write_enable <= 1;
                    end
                    KEY_G: begin
                        rect_color_r_reg <= 4'b0000;
                        rect_color_g_reg <= 4'b1111;
                        rect_color_b_reg <= 4'b0000;
                        // Trigger frame buffer update
                        fb_write_enable <= 1;
                    end
                    KEY_B: begin
                        rect_color_r_reg <= 4'b0000;
                        rect_color_g_reg <= 4'b0000;
                        rect_color_b_reg <= 4'b1111;
                        // Trigger frame buffer update
                        fb_write_enable <= 1;
                    end
                    KEY_W: begin
                        rect_color_r_reg <= 4'b1111;
                        rect_color_g_reg <= 4'b1111;
                        rect_color_b_reg <= 4'b1111;
                        // Trigger frame buffer update
                        fb_write_enable <= 1;
                    end
                    default: begin
                        // Optional: Do nothing or revert to a default color on other key presses
                        // For now, keeps the current color if key is not R, G, B, or W
                    end
                endcase
            end
        end
    end
    
    // Frame buffer update logic - fill rectangle with current color
    reg [9:0] fb_update_x;
    reg [9:0] fb_update_y;
    reg fb_update_active;
    reg [1:0] fb_update_state;
    
    always @(posedge clk_100 or negedge vga_reset_n) begin
        if (!vga_reset_n) begin
            fb_update_x <= 0;
            fb_update_y <= 0;
            fb_update_active <= 0;
            fb_update_state <= 0;
            fb_write_addr <= 0;
            fb_write_data <= 0;
        end else begin
            case (fb_update_state)
                0: begin // Idle state
                    if (fb_write_enable) begin
                        // Start filling the frame buffer
                        fb_update_x <= 0;
                        fb_update_y <= 0;
                        fb_update_active <= 1;
                        fb_update_state <= 1;
                    end
                end
                
                1: begin // Fill frame buffer
                    // Calculate write address
                    fb_write_addr <= fb_update_y * FB_WIDTH + fb_update_x;
                    
                    // Set write data based on position (inside or outside rectangle)
                    if (fb_update_x >= RECT_X1 && fb_update_x < RECT_X2 &&
                        fb_update_y >= RECT_Y1 && fb_update_y < RECT_Y2) begin
                        // Inside rectangle - use current color
                        fb_write_data <= {rect_color_r_reg, rect_color_g_reg, rect_color_b_reg};
                    end else begin
                        // Outside rectangle - black
                        fb_write_data <= 12'h000;
                    end
                    
                    // Move to next pixel
                    fb_update_state <= 2;
                end
                
                2: begin // Update coordinates
                    if (fb_update_x < FB_WIDTH - 1) begin
                        fb_update_x <= fb_update_x + 1;
                    end else begin
                        fb_update_x <= 0;
                        if (fb_update_y < FB_HEIGHT - 1) begin
                            fb_update_y <= fb_update_y + 1;
                        end else begin
                            // Finished filling the frame buffer
                            fb_update_active <= 0;
                            fb_update_state <= 0;
                        end
                    end
                    
                    // Go back to state 1 if not done
                    if (fb_update_active) begin
                        fb_update_state <= 1;
                    end
                end
            endcase
        end
    end

    // For now, we are not using the keycode outputs beyond this demo.
    // Game logic will use ps2_keycode when ps2_keycode_valid is high.

endmodule

// Frame buffer module
module frame_buffer (
    input wire clk,
    input wire write_enable,
    input wire [18:0] write_addr,  // 19 bits to address 800x600 pixels
    input wire [11:0] write_data,  // 12 bits for RGB (4 bits each)
    input wire [18:0] read_addr,
    output reg [11:0] read_data
);

    // Dual-port RAM for frame buffer
    // 800x600 pixels, 12 bits per pixel
    reg [11:0] buffer [0:480000-1];  // 800*600 = 480,000 pixels
    
    // Initialize buffer to black
    integer i;
    initial begin
        for (i = 0; i < 480000; i = i + 1) begin
            buffer[i] = 12'h000;
        end
    end
    
    // Write port
    always @(posedge clk) begin
        if (write_enable) begin
            buffer[write_addr] <= write_data;
        end
    end
    
    // Read port
    always @(posedge clk) begin
        read_data <= buffer[read_addr];
    end

endmodule
