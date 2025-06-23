module ROM_music(
    input clk,
    input [7:0] address,
    output reg [7:0] note
);

// Define ROM size
parameter ROM_SIZE = 256;

// Define musical notes (using low 6 bits as per music module)
localparam REST = 6'd0;   // Rest/silence
localparam C    = 6'd3;   // C (Do)
localparam Cs   = 6'd4;   // C# (Do#)
localparam D    = 6'd5;   // D (Re)
localparam Ds   = 6'd6;   // D# (Re#)
localparam E    = 6'd7;   // E (Mi)
localparam F    = 6'd8;   // F (Fa)
localparam Fs   = 6'd9;   // F# (Fa#)
localparam G    = 6'd10;  // G (Sol)
localparam Gs   = 6'd11;  // G# (Sol#)
localparam A    = 6'd12;  // A (La)
localparam As   = 6'd13;  // A# (La#)
localparam B    = 6'd14;  // B (Si)

// Calculate note values with octaves
function [5:0] note_octave(input [2:0] octave, input [5:0] note);
    note_octave = (octave * 6'd12) + note;
endfunction

// ROM storage
reg [7:0] rom_data [0:ROM_SIZE-1];

// Initialize ROM with underwater theme
integer i;
initial begin
    // Underwater theme melody - Super Mario Bros
    rom_data[0]  = note_octave(3, E);
    rom_data[1]  = note_octave(3, Ds);
    rom_data[2]  = note_octave(3, E);
    rom_data[3]  = note_octave(3, Ds);
    rom_data[4]  = note_octave(3, E);
    rom_data[5]  = note_octave(3, B);
    rom_data[6]  = note_octave(3, D);
    rom_data[7]  = note_octave(3, C);
    
    rom_data[8]  = note_octave(3, A);
    rom_data[9]  = REST;
    rom_data[10] = note_octave(2, C);
    rom_data[11] = note_octave(3, E);
    rom_data[12] = note_octave(3, A);
    rom_data[13] = note_octave(3, B);
    rom_data[14] = REST;
    rom_data[15] = note_octave(3, E);
    
    rom_data[16] = note_octave(3, Gs);
    rom_data[17] = note_octave(3, B);
    rom_data[18] = note_octave(4, C);
    rom_data[19] = REST;
    rom_data[20] = note_octave(3, E);
    rom_data[21] = note_octave(4, E);
    rom_data[22] = note_octave(4, Ds);
    rom_data[23] = note_octave(4, E);
    
    rom_data[24] = note_octave(4, Ds);
    rom_data[25] = note_octave(4, E);
    rom_data[26] = note_octave(4, B);
    rom_data[27] = note_octave(4, D);
    rom_data[28] = note_octave(4, C);
    rom_data[29] = note_octave(4, A);
    
    // Repeat the melody with variations
    for (i = 30; i < 60; i = i+1) begin
        rom_data[i] = rom_data[i-30];
    end
    
    // Add some variations in the second half
    rom_data[60] = note_octave(4, C);
    rom_data[61] = note_octave(4, B);
    rom_data[62] = note_octave(4, A);
    rom_data[63] = REST;
    
    // Fill the rest with the main theme
    for (i = 64; i < ROM_SIZE; i = i+1) begin
        rom_data[i] = rom_data[i % 64];
    end
end

// Output note based on address
always @(posedge clk) begin
    note <= rom_data[address];
end

endmodule