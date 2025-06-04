module ps2_keyboard_controller(
    input clk,
    input reset_n,
    input ps2_clk,
    input ps2_data,
    output [25:0] key_status, // One bit for each letter A-Z
    output ps2_ready,// pass through from ps2 keyboard
    output [9:0] ps2_data_out // pass through from ps2 keyboard
);
    // Internal signals
    wire [9:0] ps2_data_out;
    wire ps2_ready;
    
    // Instantiate the PS2 keyboard controller
    ps2_keyboard ps2_controller(
        .clk(clk),
        .reset_n(reset_n),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .data_out(ps2_data_out),
        .ready(ps2_ready)
    );
    
    // Key status register (1 bit per key, A-Z)
    reg [25:0] key_status_reg;
    
    // Extract scan code and break flag from ps2_data_out
    wire [7:0] scan_code = ps2_data_out[7:0];
    wire key_break = ps2_data_out[8];
    
    // Key mapping constants (scan codes for A-Z)
    localparam KEY_A = 8'h1C;
    localparam KEY_B = 8'h32;
    localparam KEY_C = 8'h21;
    localparam KEY_D = 8'h23;
    localparam KEY_E = 8'h24;
    localparam KEY_F = 8'h2B;
    localparam KEY_G = 8'h34;
    localparam KEY_H = 8'h33;
    localparam KEY_I = 8'h43;
    localparam KEY_J = 8'h3B;
    localparam KEY_K = 8'h42;
    localparam KEY_L = 8'h4B;
    localparam KEY_M = 8'h3A;
    localparam KEY_N = 8'h31;
    localparam KEY_O = 8'h44;
    localparam KEY_P = 8'h4D;
    localparam KEY_Q = 8'h15;
    localparam KEY_R = 8'h2D;
    localparam KEY_S = 8'h1B;
    localparam KEY_T = 8'h2C;
    localparam KEY_U = 8'h3C;
    localparam KEY_V = 8'h2A;
    localparam KEY_W = 8'h1D;
    localparam KEY_X = 8'h22;
    localparam KEY_Y = 8'h35;
    localparam KEY_Z = 8'h1A;
    
    // Update key status on each valid PS2 data
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            key_status_reg <= 26'b0; // Reset all keys to released state
        end else if (ps2_ready) begin
            case (scan_code)
                KEY_A: key_status_reg[0] <= ~key_break; // Set if pressed (break=0), clear if released (break=1)
                KEY_B: key_status_reg[1] <= ~key_break;
                KEY_C: key_status_reg[2] <= ~key_break;
                KEY_D: key_status_reg[3] <= ~key_break;
                KEY_E: key_status_reg[4] <= ~key_break;
                KEY_F: key_status_reg[5] <= ~key_break;
                KEY_G: key_status_reg[6] <= ~key_break;
                KEY_H: key_status_reg[7] <= ~key_break;
                KEY_I: key_status_reg[8] <= ~key_break;
                KEY_J: key_status_reg[9] <= ~key_break;
                KEY_K: key_status_reg[10] <= ~key_break;
                KEY_L: key_status_reg[11] <= ~key_break;
                KEY_M: key_status_reg[12] <= ~key_break;
                KEY_N: key_status_reg[13] <= ~key_break;
                KEY_O: key_status_reg[14] <= ~key_break;
                KEY_P: key_status_reg[15] <= ~key_break;
                KEY_Q: key_status_reg[16] <= ~key_break;
                KEY_R: key_status_reg[17] <= ~key_break;
                KEY_S: key_status_reg[18] <= ~key_break;
                KEY_T: key_status_reg[19] <= ~key_break;
                KEY_U: key_status_reg[20] <= ~key_break;
                KEY_V: key_status_reg[21] <= ~key_break;
                KEY_W: key_status_reg[22] <= ~key_break;
                KEY_X: key_status_reg[23] <= ~key_break;
                KEY_Y: key_status_reg[24] <= ~key_break;
                KEY_Z: key_status_reg[25] <= ~key_break;
                default: key_status_reg <= key_status_reg; // No change for other keys
            endcase
        end
    end
    
    // Output the key status
    assign key_status = key_status_reg;
    
endmodule
