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

    // Active-low reset for system components, gated by 'locked'
    wire sys_reset_n = reset_n & locked;
    
    // --- Memory-mapped I/O signals ---
    // CPU memory interface
    wire [31:0] cpu_mem_addr;
    wire [31:0] cpu_mem_wdata;
    wire [31:0] cpu_mem_rdata;
    wire cpu_mem_read;
    wire cpu_mem_write;
    
    // RAM interface
    wire ram_read;
    wire ram_write;
    wire [31:0] ram_addr;
    wire [31:0] ram_wdata;
    wire [31:0] ram_rdata;
    
    // Keyboard interface
    wire kb_read;
    wire [7:0] kb_addr;
    wire [31:0] kb_rdata;
    
    // Display interface
    wire disp_write;
    wire [15:0] disp_addr;
    wire [31:0] disp_wdata;
    
    // --- Keyboard Module ---
    keyboard keyboard_inst (
        .clk(clk_100),              // System clock for keyboard logic
        .reset_n(sys_reset_n),      // System reset (active low)
        
        .ps2_clk(ps2_clk),         // PS/2 Clock line from keyboard pin
        .ps2_data(ps2_data),       // PS/2 Data line from keyboard pin
        
        // Memory-mapped interface
        .mem_read(kb_read),
        .mem_addr(kb_addr),
        .mem_rdata(kb_rdata)
    );

    // --- Display Controller ---
    display display_inst (
        .clk_40(clk_40),           // 40MHz clock for VGA timing
        .reset_n(sys_reset_n),      // System reset
        
        // VGA outputs
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        
        // Memory-mapped interface
        .clk_cpu(clk_100),         // CPU clock domain
        .mem_write(disp_write),
        .mem_addr(disp_addr),
        .mem_wdata(disp_wdata)
    );
    
    // --- Memory Controller ---
    memory_controller mem_ctrl (        
        // CPU memory interface
        .addr(cpu_mem_addr),
        .wdata(cpu_mem_wdata),
        .rdata(cpu_mem_rdata),
        .mem_read(cpu_mem_read),
        .mem_write(cpu_mem_write),
        
        // RAM interface
        .ram_read(ram_read),
        .ram_write(ram_write),
        .ram_addr(ram_addr),
        .ram_wdata(ram_wdata),
        .ram_rdata(ram_rdata),
        
        // Keyboard interface
        .kb_read(kb_read),
        .kb_addr(kb_addr),
        .kb_rdata(kb_rdata),
        
        // Display interface
        .disp_write(disp_write),
        .disp_addr(disp_addr),
        .disp_wdata(disp_wdata)
    );
    
    // --- CPU Core ---
    wire debug_en = 1'b0;
    wire debug_step = 1'b0;
    wire [6:0] debug_addr = 7'b0;
    wire [39:0] debug_data;
    
    RV32core cpu_inst (
        // Debug interface
        .debug_en(debug_en),
        .debug_step(debug_step),
        .debug_addr(debug_addr),
        .debug_data(debug_data),
        
        // Clock and reset
        .clk(clk_100),
        .rst(~sys_reset_n),
        
        // Memory-mapped I/O interface
        .mem_addr(cpu_mem_addr),
        .mem_wdata(cpu_mem_wdata),
        .mem_rdata(cpu_mem_rdata),
        .mem_read(cpu_mem_read),
        .mem_write(cpu_mem_write)
    );
    
    // RAM module for the system
    RAM_B ram_inst (
        .clka(clk_100),
        .addra(ram_addr),
        .dina(ram_wdata),
        .wea(ram_write),
        .douta(ram_rdata),
        .mem_u_b_h_w(3'b000) // Word access
    );

endmodule