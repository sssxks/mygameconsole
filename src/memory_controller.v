`timescale 1ns / 1ps

module memory_controller (    
    // CPU memory interface
    input wire [31:0] addr,  // Memory address from CPU
    input wire [31:0] wdata, // Write data from CPU
    output reg [31:0] rdata, // Read data to CPU
    input wire mem_read,     // Read enable from CPU
    input wire mem_write,    // Write enable from CPU
    
    // RAM interface
    output reg ram_read,     // RAM read enable
    output reg ram_write,    // RAM write enable
    output reg [31:0] ram_addr, // RAM address
    output reg [31:0] ram_wdata, // RAM write data
    input wire [31:0] ram_rdata, // RAM read data
    
    // Keyboard interface
    output reg kb_read,      // Keyboard read enable
    output reg [7:0] kb_addr, // Keyboard register address
    input wire [31:0] kb_rdata, // Keyboard read data
    
    // Display interface
    output reg disp_write,   // Display write enable
    output reg [15:0] disp_addr, // Display address
    output reg [31:0] disp_wdata // Display write data
);

    // Memory map:
    // 0x10000000 - 0x1000FFFF: RAM (64KB)
    // 0x20000000 - 0x2000000F: Keyboard registers
    // 0x30000000 - 0x3000FFFF: Display frame buffer
    
    // Address decoding
    wire is_ram_access   = (addr[31:16] == 16'h1000);
    wire is_kb_access    = (addr[31:16] == 16'h2000);
    wire is_disp_access  = (addr[31:16] == 16'h3000);
    
    // Memory access control
    always @(*) begin
        // Default values
        ram_read = 1'b0;
        ram_write = 1'b0;
        kb_read = 1'b0;
        disp_write = 1'b0;
        
        ram_addr = 32'h0;
        ram_wdata = 32'h0;
        kb_addr = 8'h0;
        disp_addr = 16'h0;
        disp_wdata = 32'h0;
        
        rdata = 32'h0;
        
        // Route access to appropriate peripheral based on address
        if (is_ram_access) begin
            ram_addr = addr;
            ram_wdata = wdata;
            ram_read = mem_read;
            ram_write = mem_write;
            rdata = ram_rdata;
        end
        else if (is_kb_access && mem_read) begin
            kb_addr = addr[7:0];
            kb_read = mem_read;
            rdata = kb_rdata;
        end
        else if (is_disp_access && mem_write) begin
            disp_addr = addr[15:0];
            disp_wdata = wdata;
            disp_write = mem_write;
        end
    end

endmodule
