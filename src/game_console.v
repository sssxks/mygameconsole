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
    wire [11:0] cpu_rom_addr;
    wire [31:0] cpu_rom_rdata;

    // ROM interface
    wire [11:0] rom_addr;
    wire [31:0] rom_rdata;
    wire        rom_read;
    
    // RAM interface (32-bit word, byte-enable)
    wire [5:0]  ram_addr;
    wire [31:0] ram_wdata;
    wire [31:0] ram_rdata;
    wire [3:0]  ram_we;
    wire        ram_access;
    
    // Keyboard interface
    wire kb_read;
    wire [7:0] kb_addr;
    wire [31:0] kb_rdata;
    
    // Display interface
    wire disp_write;
    wire [16:0] disp_addr;
    wire [31:0] disp_wdata;

    // -------------------- New synchronizer and registered I/O --------------------
    // PS/2 input synchronizers (to clk_100 domain)
    reg ps2_clk_sync1, ps2_clk_sync2;
    reg ps2_data_sync1, ps2_data_sync2;
    wire ps2_clk_sync = ps2_clk_sync2;
    wire ps2_data_sync = ps2_data_sync2;

    always @(posedge clk_100 or negedge sys_reset_n) begin
        if (!sys_reset_n) begin
            ps2_clk_sync1  <= 1'b0;
            ps2_clk_sync2  <= 1'b0;
            ps2_data_sync1 <= 1'b0;
            ps2_data_sync2 <= 1'b0;
        end else begin
            ps2_clk_sync1  <= ps2_clk;
            ps2_clk_sync2  <= ps2_clk_sync1;
            ps2_data_sync1 <= ps2_data;
            ps2_data_sync2 <= ps2_data_sync1;
        end
    end

    // VGA output registering (clk_40 domain, placed in IOBs)
    wire disp_vga_hsync;
    wire disp_vga_vsync;
    wire [3:0] disp_vga_r;
    wire [3:0] disp_vga_g;
    wire [3:0] disp_vga_b;

    (* IOB = "TRUE" *) reg vga_hsync_reg, vga_vsync_reg;
    (* IOB = "TRUE" *) reg [3:0] vga_r_reg, vga_g_reg, vga_b_reg;

    always @(posedge clk_40 or negedge sys_reset_n) begin
        if (!sys_reset_n) begin
            vga_hsync_reg <= 1'b0;
            vga_vsync_reg <= 1'b0;
            vga_r_reg <= 4'b0;
            vga_g_reg <= 4'b0;
            vga_b_reg <= 4'b0;
        end else begin
            vga_hsync_reg <= disp_vga_hsync;
            vga_vsync_reg <= disp_vga_vsync;
            vga_r_reg <= disp_vga_r;
            vga_g_reg <= disp_vga_g;
            vga_b_reg <= disp_vga_b;
        end
    end

    assign vga_hsync = vga_hsync_reg;
    assign vga_vsync = vga_vsync_reg;
    assign vga_r     = vga_r_reg;
    assign vga_g     = vga_g_reg;
    assign vga_b     = vga_b_reg;
    // ---------------------------------------------------------------------------

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
        .mem_write(cpu_mem_write),
        
        .rom_addr(cpu_rom_addr),
        .rom_rdata(cpu_rom_rdata)
    );

    // --- Memory Controller ---
    // Constant word access for now (bits 2:0 = 3'b010)
    wire [2:0] mem_bhw_const = 3'b010;

    memory_controller mem_ctrl (
        // CPU memory interface
        .addr(cpu_mem_addr),
        .wdata(cpu_mem_wdata),
        .rdata(cpu_mem_rdata),
        .mem_read(cpu_mem_read),
        .mem_write(cpu_mem_write),
        .mem_u_b_h_w(mem_bhw_const),

        // ROM interface
        .rom_addr(rom_addr),
        .rom_rdata(rom_rdata),
        .rom_read(rom_read),

        // RAM interface
        .ram_addr(ram_addr),
        .ram_wdata(ram_wdata),
        .ram_we(ram_we),
        .ram_rdata(ram_rdata),
        .ram_access(ram_access),
        
        // Keyboard interface
        .kb_read(kb_read),
        .kb_addr(kb_addr),
        .kb_rdata(kb_rdata),
        
        // Display interface
        .disp_write(disp_write),
        .disp_addr(disp_addr),
        .disp_wdata(disp_wdata)
    );
    
    // RAM module – 64 words / 256 bytes
    RAM_B ram_inst (
        .clka(clk_100),
        .addra(ram_addr),
        .dina(ram_wdata),
        .wea(ram_we),
        .douta(ram_rdata)
    );

    // --- ROM Instance ---
    ROM_D rom_inst (
        .clk(clk_100),
        .a(rom_addr),
        .spo(rom_rdata),
        .a2(cpu_rom_addr),
        .spo2(cpu_rom_rdata)
    );
       
    // --- Keyboard Module ---
    keyboard keyboard_inst (
        .clk(clk_100),              // System clock for keyboard logic
        .reset_n(sys_reset_n),      // System reset (active low)
        
        .ps2_clk(ps2_clk_sync),         // PS/2 Clock line (synchronised)
        .ps2_data(ps2_data_sync),       // PS/2 Data line (synchronised)
        
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
        .vga_hsync(disp_vga_hsync),
        .vga_vsync(disp_vga_vsync),
        .vga_r(disp_vga_r),
        .vga_g(disp_vga_g),
        .vga_b(disp_vga_b),
        
        // Memory-mapped interface
        .clk_cpu(clk_100),         // CPU clock domain
        .mem_write(disp_write),
        .mem_addr(disp_addr),
        .mem_wdata(disp_wdata)
    );
endmodule