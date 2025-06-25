`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Simple testbench for game_2048_core – applies a deterministic sequence of
// moves and prints board state to console.
// -----------------------------------------------------------------------------
module tb_game_2048_core;
    reg clk = 0;
    always #5 clk = ~clk; // 100 MHz → 10 ns period

    reg reset_n = 0;
    reg move_valid = 0;
    reg [1:0] move_dir = 0;
    reg cheat_valid = 0;

    wire [63:0] board_state;

    game_2048_core dut (
        .clk(clk), .reset_n(reset_n),
        .move_valid(move_valid), .move_dir(move_dir), .cheat_valid(cheat_valid),
        .board_state(board_state)
    );

    // helper to print board
    task display_board;
        integer r,c;
        integer exp, tile;
        begin
            $display("-----------------\n");
            for (r = 0; r < 4; r = r + 1) begin
                for (c = 0; c < 4; c = c + 1) begin
                                        exp  = board_state[((r*4+c)*4)+:4];
                    tile = (exp == 0) ? 0 : (1 << exp);
                    if (tile == 0)
                        $write("   . ");
                    else
                        $write("%4d ", tile);
                end
                $write("\n");
            end
            $display("-----------------\n");
        end
    endtask

    initial begin
        $dumpfile("tb_game_2048_core.vcd");
        $dumpvars(0, dut);

        // reset
        #12; reset_n = 0; #10; reset_n = 1;
        #10; display_board();

        // Sequence: up, left, down, right
        repeat (4) begin
            apply_move(0); // up
            apply_move(1); // left
            apply_move(2); // down
            apply_move(3); // right
        end

        // Test cheat function three times
        repeat (3) begin
            apply_cheat();
        end

        $finish;
    end

    task apply_move(input [1:0] dir);
        begin
            @(negedge clk);
            move_dir   <= dir;
            move_valid <= 1'b1;
            @(negedge clk);
            move_valid <= 1'b0;
            // FSM now needs two extra cycles: one for MOVE, one for RAND
            repeat (3) @(negedge clk);
            display_board();
        end
    endtask

    task apply_cheat;
        begin
            @(negedge clk);
            cheat_valid <= 1'b1;
            @(negedge clk);
            cheat_valid <= 1'b0;
            @(negedge clk); // allow core to apply cheat
            display_board();
        end
    endtask
endmodule
