`timescale 1ns / 1ps
`include "memory_sizes.vh"

module ROM_D #(
    parameter ADDR_WIDTH = `ROM_ADDR_WIDTH,
    parameter MEM_SIZE   = 1 << ADDR_WIDTH
)(
    input  wire                 clk,
    input  wire [ADDR_WIDTH-1:0] a,
    output wire [31:0]          spo,
    input  wire [ADDR_WIDTH-1:0] a2,
    output wire [31:0]          spo2
);

    // tell the synthesiser we want BRAM
    (* rom_style = "block", ram_style = "block" *) reg [31:0] inst_data [0:MEM_SIZE-1];

    initial $readmemh("rom.hex", inst_data);

    // async read
    assign spo  = inst_data[a];
    assign spo2 = inst_data[a2];

    // synchronous read – dual port
    // always @(posedge clk) begin
    // end
endmodule