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
    output wire [3:0] vga_b, // 4-bit Blue
    
    // Memory-mapped interface for CPU
    input wire clk_cpu,      // CPU clock domain
    input wire mem_write,    // CPU write signal
    input wire [16:0] mem_addr, // CPU address bus (17 bits for frame buffer addressing)
    input wire [31:0] mem_wdata // CPU write data bus
);

    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire video_on = 1'b1;
    wire [16:0] fb_read_addr;
    wire [11:0] fb_read_data;
    wire [3:0] color_r;
    wire [3:0] color_g;
    wire [3:0] color_b;
    
    // Frame buffer memory (320x240 pixels, 12-bit color)
    // True dual-port RAM: Port A = CPU writes, Port B = VGA reads
    // The following template allows Vivado to infer block RAMs.
    (* ram_style = "block" *) reg [11:0] frame_buffer [0:76799];

    // --------------------------------------------------------------------
    // CPU WRITE PORT  (Port A)
    // --------------------------------------------------------------------
    always @(posedge clk_cpu) begin
        if (mem_write) begin
            frame_buffer[mem_addr] <= mem_wdata[11:0];
        end
    end

    // make warning less overwhelming
    wire unused_mem_wdata = |mem_wdata[31:12];

    // --------------------------------------------------------------------
    // VGA READ PORT  (Port B) – synchronous read
    // --------------------------------------------------------------------
    reg [11:0] fb_read_data_r;
    always @(posedge clk_40) begin
        fb_read_data_r <= frame_buffer[fb_read_addr];
    end
    assign fb_read_data = fb_read_data_r;

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
    
    // Initialize frame buffer with a simple pattern for testing
    integer i;
    initial begin
        for (i = 0; i < 76800; i = i + 1) begin
            frame_buffer[i] = {4'h0, 4'h0, 4'h0}; // Black background
        end
    end
endmodule
