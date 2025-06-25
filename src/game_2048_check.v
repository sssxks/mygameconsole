`timescale 1ns / 1ps

module game_2048_check (
    input  wire [63:0] board_state,   // board state input
    output wire        game_win,      // success mark
    output wire        game_lose      // fail mark
);

    // 棋盘解包函数
    function [3:0] tile_at;
        input [63:0] packed;
        input [3:0]  idx; // 0-15
        begin
            tile_at = packed[idx*4 +: 4];
        end
    endfunction

    // check if it appears 2048
    function is_win;
        input [63:0] board;
        reg win_found;
        integer i;
        begin
            win_found = 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                //  (2^11 = 2048)
                if (tile_at(board, i) == 4'd11) begin
                    win_found = 1'b1;
                end
            end
            is_win = win_found;
        end
    endfunction

    // check if it can not move
    function is_lose;
        input [63:0] board;
        reg has_empty;
        reg has_merge;
        integer i, r, c;
        reg [3:0] current, right, down;
        begin
            has_empty = 1'b0;
            has_merge = 1'b0;
            
            // check if there is available space
            for (i = 0; i < 16; i = i + 1) begin
                if (tile_at(board, i) == 4'd0) begin
                    has_empty = 1'b1;
                end
            end
            
            // if not,check if there are cubes can combine
            if (!has_empty) begin
                for (r = 0; r < 4; r = r + 1) begin
                    for (c = 0; c < 4; c = c + 1) begin
                        current = tile_at(board, r*4 + c);
                        
                        // check cubes in the right
                        if (c < 3) begin
                            right = tile_at(board, r*4 + c + 1);
                            if (current == right) begin
                                has_merge = 1'b1;
                            end
                        end
                        
                        // check cubes below
                        if (r < 3) begin
                            down = tile_at(board, (r+1)*4 + c);
                            if (current == down) begin
                                has_merge = 1'b1;
                            end
                        end
                    end
                end
            end
            
            is_lose = !has_empty && !has_merge;
        end
    endfunction

    assign game_win = is_win(board_state);
    assign game_lose = !game_win && is_lose(board_state);
endmodule