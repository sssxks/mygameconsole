`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Testbench for top-level game_2048_main
// - checks basic state transitions:
//   RESET  -> START screen
//   key press -> PLAY screen
//   force win  -> WIN screen
//   key press -> back to START
// -----------------------------------------------------------------------------
module tb_game_2048_main;
    // clock
    reg clk = 0;
    always #5 clk = ~clk; // 100 MHz → 10 ns period

    // DUT ports
    reg         reset_n  = 0;
    reg  [25:0] key_status = 26'd0;

    wire        fb_we;
    wire [15:0] fb_addr;   // narrow just for simulation convenience
    wire [31:0] fb_wdata;

    // DUT
    game_2048_main dut (
        .clk(clk),
        .reset_n(reset_n),
        .key_status(key_status),
        .fb_we(fb_we),
        .fb_addr(fb_addr),
        .fb_wdata(fb_wdata)
    );

    // Convenience hierarchical access to internal resets (declared inside DUT)
    wire st_active = dut.st_reset_n;
    wire gm_active = dut.gm_reset_n;
    wire wn_active = dut.wn_reset_n;

    initial begin
        $display("\n=== tb_game_2048_main ===\n");
        $dumpfile("tb_game_2048_main.vcd");
        $dumpvars(0, tb_game_2048_main);

        // Apply reset
        reset_n = 0;
        repeat (5) @(posedge clk);
        reset_n = 1;
        $display("[TB] Released reset");

        // START screen should be active
        repeat (10) @(posedge clk);
        if (!st_active) begin
            $fatal(1, "Expected START screen after reset");
        end
        $display("[TB] In START screen OK");

        // Press any key for 20 cycles (use key A bit0)
        #1;
        key_status[0] = 1'b1;
        repeat (20) @(posedge clk);
        key_status[0] = 1'b0;
        $display("[TB] Key pressed -> transition to PLAY");

        // Wait some cycles for FSM to update
        repeat (10) @(posedge clk);
        if (!gm_active) begin
            $fatal(1, "Did not enter PLAY state after key press");
        end
        $display("[TB] In PLAY screen OK");

        // Force game win for 1 cycle
        force dut.gm_win = 1'b1;
        @(posedge clk);
        release dut.gm_win;
        $display("[TB] Forced game win -> transition to WIN");

        // Wait for FSM
        repeat (10) @(posedge clk);
        if (!wn_active) begin
            $fatal(1, "Did not enter WIN state after gm_win");
        end
        $display("[TB] In WIN screen OK");

        // Any key returns to START
        #1;
        key_status[0] = 1'b1;
        @(posedge clk);
        key_status[0] = 1'b0;

        repeat (10) @(posedge clk);
        if (!st_active) begin
            $fatal(1, "Did not return to START after key press");
        end
        $display("[TB] Returned to START OK");

        $display("[TB] Test PASSED!\n");
        $finish;
    end
endmodule
