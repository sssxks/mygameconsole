`timescale 1ns / 1ps

module RAM_B #(
    parameter ADDR_WIDTH = 7,              // Default address width is 7 bits (128 locations)
    parameter MEM_SIZE = 128               // Default memory size is 128 bytes
)(
    input [31:0] addra,
    input clka,      // normal clock
    input[31:0] dina,
    input wea, 
    output[31:0] douta,
    input[2:0] mem_u_b_h_w
);

    reg[7:0] data[0:MEM_SIZE-1];

    initial	begin
        $readmemh("ram.hex", data);
    end

    always @ (negedge clka) begin
        if (wea & ~|addra[31:ADDR_WIDTH]) begin
            data[addra[ADDR_WIDTH-1:0]] <= dina[7:0];
            if(mem_u_b_h_w[0] | mem_u_b_h_w[1])
                data[addra[ADDR_WIDTH-1:0] + 1] <= dina[15:8];
            if(mem_u_b_h_w[1]) begin
                data[addra[ADDR_WIDTH-1:0] + 2] <= dina[23:16];
                data[addra[ADDR_WIDTH-1:0] + 3] <= dina[31:24];
            end
        end
    end

    
    assign douta = addra[31:ADDR_WIDTH] ? 32'b0 :
        mem_u_b_h_w[1] ? {data[addra[ADDR_WIDTH-1:0] + 3], data[addra[ADDR_WIDTH-1:0] + 2],
                    data[addra[ADDR_WIDTH-1:0] + 1], data[addra[ADDR_WIDTH-1:0]]} :
        mem_u_b_h_w[0] ? {mem_u_b_h_w[2] ? 16'b0 : {16{data[addra[ADDR_WIDTH-1:0] + 1][7]}},
                    data[addra[ADDR_WIDTH-1:0] + 1], data[addra[ADDR_WIDTH-1:0]]} :
        {mem_u_b_h_w[2] ? 24'b0 : {24{data[addra[ADDR_WIDTH-1:0]][7]}}, data[addra[ADDR_WIDTH-1:0]]};

endmodule