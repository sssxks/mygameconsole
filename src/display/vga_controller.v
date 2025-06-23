`timescale 1ns / 1ps

module vga_controller (
    // Inputs
    input wire clk,          // Pixel clock (40MHz)
    input wire reset_n,      // Asynchronous reset (active low)

    // Color inputs from game logic
    input wire [3:0] input_r, // 4-bit Red input
    input wire [3:0] input_g, // 4-bit Green input
    input wire [3:0] input_b, // 4-bit Blue input

    // Outputs
    output reg hsync,         // Horizontal Sync
    output reg vsync,         // Vertical Sync
    output reg [3:0] red,     // 4-bit Red
    output reg [3:0] green,   // 4-bit Green
    output reg [3:0] blue,    // 4-bit Blue

    output reg [9:0] pixel_x, // Current X coordinate (0-799 for 800 width)
    output reg [9:0] pixel_y,  // Current Y coordinate (0-599 for 600 height)
    output wire video_on        // Video_on (display enable or blanking_n) signal
);

    // VGA Timing Parameters for 800x600 @ 60Hz
    // Horizontal Timing (pixels)
    localparam H_DISPLAY      = 800; // Horizontal display area
    localparam H_FP           = 40;  // Horizontal front porch
    localparam H_SYNC_PULSE   = 128; // Horizontal sync pulse width
    localparam H_BP           = 88;  // Horizontal back porch
    localparam H_TOTAL        = 1056; // Total horizontal pixels (H_DISPLAY + H_FP + H_SYNC_PULSE + H_BP)

    // Vertical Timing (lines)
    localparam V_DISPLAY      = 600; // Vertical display area
    localparam V_FP           = 1;   // Vertical front porch
    localparam V_SYNC_PULSE   = 4;   // Vertical sync pulse width
    localparam V_BP           = 23;  // Vertical back porch
    localparam V_TOTAL        = 628; // Total vertical lines (V_DISPLAY + V_FP + V_SYNC_PULSE + V_BP)

    // Counters for horizontal and vertical position
    reg [10:0] h_count; // Max H_TOTAL is 1056, needs 11 bits
    reg [9:0] v_count; // Max V_TOTAL is 628, needs 10 bits

    // Logic for h_count and v_count (pixel counters)
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            h_count <= 0;
            v_count <= 0;
            pixel_x <= 0;
            pixel_y <= 0;
        end else begin
            if (h_count < H_TOTAL - 1) begin
                h_count <= h_count + 1;
            end else begin
                h_count <= 0;
                if (v_count < V_TOTAL - 1) begin
                    v_count <= v_count + 1;
                end else begin
                    v_count <= 0;
                end
            end

            // Update pixel_x and pixel_y based on h_count and v_count
            // pixel_x and pixel_y should reflect the current screen coordinate when display is active
            if ((h_count < H_DISPLAY) && (v_count < V_DISPLAY)) begin // Active display region
                pixel_x <= h_count[9:0];
                pixel_y <= v_count;
            end else begin
                pixel_x <= 10'h3FF; // Indicate invalid or out of active display range
                pixel_y <= 10'h3FF; // Indicate invalid or out of active display range
            end
        end
    end

    // HSync is active low during H_SYNC_PULSE period
    // It starts after H_DISPLAY and H_FP
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            hsync <= 1'b1; // Typically inactive high
        end else begin
            if (h_count >= H_DISPLAY + H_FP && h_count < H_DISPLAY + H_FP + H_SYNC_PULSE) begin
                hsync <= 1'b0; // Active low
            end else begin
                hsync <= 1'b1;
            end
        end
    end

    // VSync is active low during V_SYNC_PULSE period
    // It starts after V_DISPLAY and V_FP
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            vsync <= 1'b1; // Typically inactive high
        end else begin
            if (v_count >= V_DISPLAY + V_FP && v_count < V_DISPLAY + V_FP + V_SYNC_PULSE) begin
                vsync <= 1'b0; // Active low
            end else begin
                vsync <= 1'b1;
            end
        end
    end

    // Video_on (display enable or blanking_n) signal generation
    // Active high during the visible display area
    assign video_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);

    // Logic for RGB output
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            red   <= 4'b0000;
            green <= 4'b0000;
            blue  <= 4'b0000;
        end else begin
            if (video_on) begin
                // Output color based on inputs from game logic
                red   <= input_r;
                green <= input_g;
                blue  <= input_b;
            end else begin
                red   <= 4'b0000; // Black during blanking intervals
                green <= 4'b0000;
                blue  <= 4'b0000;
            end
        end
    end

endmodule
