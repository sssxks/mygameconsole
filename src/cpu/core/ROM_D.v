`timescale 1ns / 1ps

module ROM_D #(
    parameter ADDR_WIDTH = 7,              // Default address width is 7 bits (128 locations)
    parameter MEM_SIZE = 128               // Default memory size is 128 words
)(
    input[ADDR_WIDTH-1:0] a,
    output[31:0] spo
);

    reg[31:0] inst_data[0:MEM_SIZE-1];

    initial	begin
        $readmemh("rom.hex", inst_data);
    end

    assign spo = inst_data[a];

endmodule