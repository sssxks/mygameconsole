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

// Initialize ROM with Super Mario Overworld theme
integer i;
initial begin
    // Main melody - Super Mario Bros Overworld Theme
    // Each value represents 1/16th note duration
    
    // Phrase 1: E5, C5, E5, G5
    rom_data[0]  = note_octave(4, E);   // E5
    rom_data[1]  = note_octave(4, E);
    rom_data[2]  = note_octave(4, E);
    rom_data[3]  = REST;
    rom_data[4]  = note_octave(4, C);   // C5
    rom_data[5]  = note_octave(4, C);
    rom_data[6]  = note_octave(4, C);
    rom_data[7]  = REST;
    rom_data[8]  = note_octave(4, E);   // E5
    rom_data[9]  = note_octave(4, E);
    rom_data[10] = note_octave(4, E);
    rom_data[11] = REST;
    rom_data[12] = note_octave(4, G);   // G5
    rom_data[13] = note_octave(4, G);
    rom_data[14] = note_octave(4, G);
    rom_data[15] = REST;
    
    // Phrase 2: G4, C5, G4, E4
    rom_data[16] = note_octave(3, G);   // G4
    rom_data[17] = note_octave(3, G);
    rom_data[18] = note_octave(3, G);
    rom_data[19] = REST;
    rom_data[20] = note_octave(4, C);   // C5
    rom_data[21] = note_octave(4, C);
    rom_data[22] = note_octave(4, C);
    rom_data[23] = REST;
    rom_data[24] = note_octave(3, G);   // G4
    rom_data[25] = note_octave(3, G);
    rom_data[26] = note_octave(3, G);
    rom_data[27] = REST;
    rom_data[28] = note_octave(3, E);   // E4
    rom_data[29] = note_octave(3, E);
    rom_data[30] = note_octave(3, E);
    rom_data[31] = REST;
    
    // Phrase 3: A4, B4, As4, A4
    rom_data[32] = note_octave(3, A);   // A4
    rom_data[33] = note_octave(3, A);
    rom_data[34] = note_octave(3, A);
    rom_data[35] = REST;
    rom_data[36] = note_octave(3, B);   // B4
    rom_data[37] = note_octave(3, B);
    rom_data[38] = note_octave(3, B);
    rom_data[39] = REST;
    rom_data[40] = note_octave(3, As);  // A#4
    rom_data[41] = note_octave(3, As);
    rom_data[42] = note_octave(3, As);
    rom_data[43] = REST;
    rom_data[44] = note_octave(3, A);   // A4
    rom_data[45] = note_octave(3, A);
    rom_data[46] = note_octave(3, A);
    rom_data[47] = REST;
    
    // Phrase 4: G4, E5, G5, A5
    rom_data[48] = note_octave(3, G);   // G4
    rom_data[49] = note_octave(3, G);
    rom_data[50] = note_octave(3, G);
    rom_data[51] = REST;
    rom_data[52] = note_octave(4, E);   // E5
    rom_data[53] = note_octave(4, E);
    rom_data[54] = note_octave(4, E);
    rom_data[55] = REST;
    rom_data[56] = note_octave(4, G);   // G5
    rom_data[57] = note_octave(4, G);
    rom_data[58] = note_octave(4, G);
    rom_data[59] = REST;
    rom_data[60] = note_octave(4, A);   // A5
    rom_data[61] = note_octave(4, A);
    rom_data[62] = note_octave(4, A);
    rom_data[63] = REST;
    
    // Phrase 5: F5, G5, E5, C5
    rom_data[64] = note_octave(4, F);   // F5
    rom_data[65] = note_octave(4, F);
    rom_data[66] = note_octave(4, F);
    rom_data[67] = REST;
    rom_data[68] = note_octave(4, G);   // G5
    rom_data[69] = note_octave(4, G);
    rom_data[70] = note_octave(4, G);
    rom_data[71] = REST;
    rom_data[72] = note_octave(4, E);   // E5
    rom_data[73] = note_octave(4, E);
    rom_data[74] = note_octave(4, E);
    rom_data[75] = REST;
    rom_data[76] = note_octave(4, C);   // C5
    rom_data[77] = note_octave(4, C);
    rom_data[78] = note_octave(4, C);
    rom_data[79] = REST;
    
    // Phrase 6: D5, B4, G5
    rom_data[80] = note_octave(4, D);   // D5
    rom_data[81] = note_octave(4, D);
    rom_data[82] = note_octave(4, D);
    rom_data[83] = REST;
    rom_data[84] = note_octave(3, B);   // B4
    rom_data[85] = note_octave(3, B);
    rom_data[86] = note_octave(3, B);
    rom_data[87] = REST;
    rom_data[88] = note_octave(4, G);   // G5
    rom_data[89] = note_octave(4, G);
    rom_data[90] = note_octave(4, G);
    rom_data[91] = note_octave(4, G);
    rom_data[92] = note_octave(4, G);
    rom_data[93] = note_octave(4, G);
    rom_data[94] = note_octave(4, G);
    rom_data[95] = REST;
    
    // Fill the rest with the main theme loop
    for (i = 96; i < ROM_SIZE; i = i+1) begin
        rom_data[i] = rom_data[i % 96];  // Loop the entire theme
    end
end

// Output note based on address
always @(posedge clk) begin
    note <= rom_data[address];
end

endmodule