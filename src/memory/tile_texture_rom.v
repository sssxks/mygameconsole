// -----------------------------------------------------------------------------
// Tile texture ROM
// -----------------------------------------------------------------------------
module tile_texture_rom (
    input  wire        clk,
    input  wire [15:0] addr,
    output reg  [11:0] data
);
    // 64 Ki × 12-bit texture ROM initialised from generated hex file.
    // Address mapping in the design: {tile_val, off_y, off_x} = 16-bit
    // depth, so we need 2¹⁶ = 65 536 words.
    // The file is produced by tool/merge_tile_hex.py and located at
    //   src/memory/tile_textures.hex
    // Each line is a 3-digit RGB444 value suitable for $readmemh.

    reg [11:0] rom [0:65535];

    initial begin
        // Path is relative to the directory where the simulator/synthesiser
        // is launched.  Using a relative path keeps it portable.
        $readmemh("tile_texture.hex", rom);
    end

    always @(posedge clk) begin
        data <= rom[addr];
    end
endmodule