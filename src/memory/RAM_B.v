`timescale 1ns / 1ps
`include "memory_sizes.vh"

module RAM_B #(
    parameter ADDR_WIDTH = `RAM_ADDR_WIDTH,
    parameter MEM_SIZE   = 1 << ADDR_WIDTH  // word count
)(
    input  wire               clka,
    input  wire [ADDR_WIDTH-1:0] addra,      // word-address (32-bit aligned)
    input  wire [31:0]        dina,
    input  wire [3:0]         wea,           // per-byte write enable – LSB = byte 0
    output reg  [31:0]        douta
);

    reg [31:0] data [0:MEM_SIZE-1];

    // Synchronous write, one clock behind for read – using per-byte enable
    always @(posedge clka) begin
        if (wea[0]) data[addra][7:0]   <= dina[7:0];
        if (wea[1]) data[addra][15:8]  <= dina[15:8];
        if (wea[2]) data[addra][23:16] <= dina[23:16];
        if (wea[3]) data[addra][31:24] <= dina[31:24];
        douta <= data[addra];
    end
endmodule