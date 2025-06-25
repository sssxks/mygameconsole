`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// 2048 Game – core logic (board state, merge, random tile, move handling)
// -----------------------------------------------------------------------------
// This module is display-agnostic and input-device-agnostic.  It simply maintains
// the 4×4 board given move requests.
//
// Interface
//   clk, reset_n : system clock and active-low asynchronous reset
//   move_valid   : pulse high for **one** clk when a new move should be applied
//   move_dir     : 0 = up, 1 = left, 2 = down, 3 = right
//   board_state  : 16 × 4-bit packed vector, row-major order {tile0, … tile15}
// -----------------------------------------------------------------------------
module game_2048_core (
    input  wire        clk,
    input  wire        reset_n,

    input  wire        move_valid,
    input  wire [1:0]  move_dir,
    input  wire        cheat_valid,

    output wire [63:0] board_state
);
    // Board representation – internal unpacked array for easy indexing
    reg [3:0] board [0:15];

    // LFSR for pseudo-random placement; simple 16-bit Galois LFSR
    reg [15:0] lfsr;

    // Helper function: merge/shift a 4-element line to the left (same algorithm
    // as the original monolithic implementation)
    function [15:0] merge_line;
        input [15:0] in_line; // packed {a,b,c,d}
        reg   [3:0]  t  [0:3];
        reg   [3:0]  out[0:3];
        integer      i, idx;
        begin
            // clear out
            for (i = 0; i < 4; i = i + 1) out[i] = 0;

            // Stage 1 – compress non-zero tiles to the left
            {t[0], t[1], t[2], t[3]} = in_line;
            idx = 0;
            for (i = 0; i < 4; i = i + 1) begin
                if (t[i] != 0) begin
                    out[idx] = t[i];
                    idx = idx + 1;
                end
            end

            // Stage 2 – merge equal adjacent pairs
            for (i = 0; i < 3; i = i + 1) begin
                if (out[i] != 0 && out[i] == out[i+1]) begin
                    out[i]   = out[i] + 1;
                    out[i+1] = 0;
                end
            end

            // Stage 3 – compress again to remove gaps after merges
            {t[0], t[1], t[2], t[3]} = {out[0], out[1], out[2], out[3]};
            for (i = 0; i < 4; i = i + 1) out[i] = 0;
            idx = 0;
            for (i = 0; i < 4; i = i + 1) begin
                if (t[i] != 0) begin
                    out[idx] = t[i];
                    idx = idx + 1;
                end
            end

            merge_line = {out[0], out[1], out[2], out[3]};
        end
    endfunction

    // ---------------------------------------------------------------------
    // Task: add a random tile (2 with 87.5 %, 4 with 12.5 %)
    // ---------------------------------------------------------------------
    task automatic add_random_tile;
        integer i, start_idx, pos;
        reg     placed;
        begin
            start_idx = lfsr[3:0];
            placed    = 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                pos = (start_idx + i) & 4'hF;
                if (!placed && board[pos] == 0) begin
                    board[pos] <= (lfsr[3:1] == 3'b000) ? 4'd2 : 4'd1;
                    placed     = 1'b1;
                end
            end
        end
    endtask

    // ---------------------------------------------------------------------
    // Two-cycle state-machine implementation
    // ---------------------------------------------------------------------
    // FSM states
    localparam S_IDLE   = 2'd0;  // waiting for move_valid pulse
    localparam S_MOVE   = 2'd1;  // perform move / merge
    localparam S_RAND   = 2'd2;  // add random tile after a successful move

    integer r,c,idx,j; // re-use loop indices
    reg [15:0] line_in, line_out;
    reg [1:0]  state;
    reg        moved_reg;        // latched "moved" flag between cycles
    reg [1:0]  move_dir_lat;     // latched move direction
    reg        found_pair;       // cheat helper flag

    // Copy of board to compare before/after a move (for change detection)
    reg [3:0] old_board [0:15];
    

    // Combinational packing of board into single vector for output
    genvar gi;
    generate
        for (gi = 0; gi < 16; gi = gi + 1) begin : pack
            assign board_state[gi*4 +: 4] = board[gi];
        end
    endgenerate

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // asynchronous reset – clear board & seed LFSR
            for (idx = 0; idx < 16; idx = idx + 1) board[idx] <= 0;
            lfsr  <= 16'hACE1;
            state <= S_IDLE;
            moved_reg <= 1'b0;
            // game starts with two tiles
            add_random_tile();
            add_random_tile();
        end else begin
            // LFSR (x^16 + x^14 + x^13 + x^11 + 1) update every cycle
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

            case (state)
                //-------------------------------------------------------------
                // IDLE – wait for new move request
                //-------------------------------------------------------------
                S_IDLE: begin
                    if (cheat_valid) begin
                        // -------------------------------------------------
                        // CHEAT – merge first pair of equal non-zero tiles
                        // -------------------------------------------------
                        found_pair = 1'b0;
                        for (idx = 0; idx < 15; idx = idx + 1) begin
                            for (j = idx + 1; j < 16; j = j + 1) begin
                                if (!found_pair && board[idx] != 0 && board[idx] == board[j]) begin
                                    board[idx] <= board[idx] + 1; // increment exponent (value ×2)
                                    board[j]   <= 0;
                                    found_pair = 1'b1;
                                end
                            end
                        end
                        // Remain in IDLE; no random tile insertion
                    end else if (move_valid) begin
                        move_dir_lat <= move_dir;
                        // snapshot board for change detection later
                        for (idx = 0; idx < 16; idx = idx + 1) old_board[idx] = board[idx];
                        state <= S_MOVE;
                    end
                end

                //-------------------------------------------------------------
                // MOVE – execute the move / merge in a single clock
                //-------------------------------------------------------------
                S_MOVE: begin
                    case (move_dir_lat)
                        2'd0: begin // up
                            for (c = 0; c < 4; c = c + 1) begin
                                line_in  = {board[0*4+c], board[1*4+c], board[2*4+c], board[3*4+c]};
                                line_out = merge_line(line_in);
                                {board[0*4+c], board[1*4+c], board[2*4+c], board[3*4+c]} = line_out;
                            end
                        end
                        2'd1: begin // left
                            for (r = 0; r < 4; r = r + 1) begin
                                line_in  = {board[r*4+0], board[r*4+1], board[r*4+2], board[r*4+3]};
                                line_out = merge_line(line_in);
                                {board[r*4+0], board[r*4+1], board[r*4+2], board[r*4+3]} = line_out;
                            end
                        end
                        2'd2: begin // down
                            for (c = 0; c < 4; c = c + 1) begin
                                line_in  = {board[3*4+c], board[2*4+c], board[1*4+c], board[0*4+c]};
                                line_out = merge_line(line_in);
                                {board[3*4+c], board[2*4+c], board[1*4+c], board[0*4+c]} = line_out;
                            end
                        end
                        default: begin // right (2'd3)
                            for (r = 0; r < 4; r = r + 1) begin
                                line_in  = {board[r*4+3], board[r*4+2], board[r*4+1], board[r*4+0]};
                                line_out = merge_line(line_in);
                                {board[r*4+3], board[r*4+2], board[r*4+1], board[r*4+0]} = line_out;
                            end
                        end
                    endcase

                    // detect changes vs. original board snapshot
                    moved_reg = 1'b0;
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        if (board[idx] != old_board[idx]) moved_reg = 1'b1;
                    end

                    state <= S_RAND; // next cycle → optional random insertion
                end

                //-------------------------------------------------------------
                // RAND – optionally insert random tile, then go back to IDLE
                //-------------------------------------------------------------
                S_RAND: begin
                    if (moved_reg) add_random_tile();
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
