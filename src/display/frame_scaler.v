`timescale 1ns / 1ps
`include "../memory/memory_sizes.vh"

// Frame Scaler module - scales 320x240 8-bit RGB to 800x600 with 2x scaling and black padding
module frame_scaler (
    input wire clk,
    input wire reset_n,
    
    // VGA timing inputs
    input wire [9:0] pixel_x,      // Current pixel X position (0-799)
    input wire [9:0] pixel_y,      // Current pixel Y position (0-599)
    
    // Frame buffer interface
    output wire [`DISP_ADDR_WIDTH-1:0] fb_read_addr, // Address to read from frame buffer
    input wire [11:0] fb_read_data,   // 12-bit RGB data from frame buffer
    
    // Output to VGA
    output reg [3:0] color_r,      // 4-bit Red output
    output reg [3:0] color_g,      // 4-bit Green output
    output reg [3:0] color_b       // 4-bit Blue output
);

    // Calculate the position of the scaled frame buffer in the 800x600 display
    // For 320x240 scaled 2x = 640x480, centered in 800x600
    localparam H_OFFSET = 80;  // (800 - 640) / 2 pixels offset from left
    localparam V_OFFSET = 60;  // (600 - 480) / 2 pixels offset from top
    
    // Determine if current pixel is within the scaled frame buffer area
    wire in_display_area = (pixel_x >= H_OFFSET) && (pixel_x < H_OFFSET + 640) && 
                           (pixel_y >= V_OFFSET) && (pixel_y < V_OFFSET + 480);
    
    // Calculate the corresponding pixel in the 320x240 frame buffer
    wire [9:0] fb_x_sub_offset = pixel_x - H_OFFSET;
    wire [9:0] fb_y_sub_offset = pixel_y - V_OFFSET;
    wire [8:0] fb_x = fb_x_sub_offset[9:1];
    wire [7:0] fb_y = fb_y_sub_offset[8:1];
    
    // Calculate frame buffer read address
    assign fb_read_addr = in_display_area ? (fb_y * 320 + {8'b0, fb_x}) : 17'd0;
    
    // Extract RGB components from 12-bit frame buffer data
    wire [3:0] fb_r = fb_read_data[11:8];  // 4 bits for red
    wire [3:0] fb_g = fb_read_data[7:4];  // 4 bits for green
    wire [3:0] fb_b = fb_read_data[3:0];  // 4 bits for blue
        
    // Output color logic
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            color_r <= 4'b0000;
            color_g <= 4'b0000;
            color_b <= 4'b0000;
        end else if (in_display_area) begin
            // Inside the scaled frame buffer area - use frame buffer color
            color_r <= fb_r;
            color_g <= fb_g;
            color_b <= fb_b;
        end else begin
            // Outside the scaled frame buffer area - white padding
            color_r <= 4'hF;
            color_g <= 4'hF;
            color_b <= 4'hE;
        end
    end
endmodule
