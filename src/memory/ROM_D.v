`timescale 1ns / 1ps

module ROM_D #(
    parameter ADDR_WIDTH = 12,              // Default address width is 12 bits (4096 locations)
    parameter MEM_SIZE = 4096               // Default memory size is 4096 words
)(
    // First port
    input[ADDR_WIDTH-1:0] a,
    output[31:0] spo,
    
    // Second port
    input[ADDR_WIDTH-1:0] a2,
    output[31:0] spo2
);

    reg[31:0] inst_data[0:MEM_SIZE-1];

    initial	begin
        $readmemh("rom.hex", inst_data);
    end

    // Output for first port
    assign spo = inst_data[a];
    
    // Output for second port
    assign spo2 = inst_data[a2];

endmodule