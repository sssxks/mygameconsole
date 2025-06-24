`include "memory_sizes.vh"

module keyboard(
    input clk,
    input reset_n,
    input ps2_clk,              // PS/2 clock signal
    input ps2_data,             // PS/2 data signal
    
    // Memory-mapped interface for CPU
    input wire mem_read,         // CPU read signal
    input wire [`KB_ADDR_WIDTH-1:0] mem_addr,   // CPU address bus (8 bits for simplicity)
    output reg [31:0] mem_rdata  // CPU read data bus
);
    
    // Internal signals from PS/2 controller
    wire [25:0] key_status;     // One bit for each letter A-Z
    wire [9:0] ps2_data_out;    // PS2 data from controller
    wire ps2_ready;             // PS2 ready signal from controller
    
    // Instantiate the PS/2 keyboard controller
    keyboard_status_keeper status_inst(
        .clk(clk),
        .reset_n(reset_n),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .key_status(key_status),
        .ps2_data_out(ps2_data_out),
        .ps2_ready(ps2_ready)
    );
    
    // Memory-mapped interface logic
    // When CPU reads from keyboard memory space
    always @(posedge clk) begin
        if (!reset_n) begin
            mem_rdata <= 32'h0;
        end else if (mem_read) begin
            case (mem_addr)
                `KB_ADDR_WIDTH'h00: mem_rdata <= {6'b0, key_status};      // Key status register
                `KB_ADDR_WIDTH'h01: mem_rdata <= {24'b0, ps2_data_out[7:0]}; // Last scan code
                `KB_ADDR_WIDTH'h02: mem_rdata <= {31'b0, ps2_ready};      // Ready flag
                default: mem_rdata <= 32'h0;
            endcase
        end
    end
    
endmodule