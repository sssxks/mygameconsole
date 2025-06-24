`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Simple testbench for the top-level game_console.
// It provides a 100 MHz system clock, de-asserts reset, leaves the PS/2 lines
// idle (logic-high) and captures waveforms to a VCD file so that the user can
// inspect internal behaviour and VGA timing.
// -----------------------------------------------------------------------------
module tb_game_console;
    // ---------------------------------------------------------------------
    // Clock generation – 100 MHz (10 ns period)
    // ---------------------------------------------------------------------
    reg clk = 0;
    always #5 clk = ~clk;

    // Asynchronous reset (active-low)
    reg reset_n = 0;

    // PS/2 interface – idle state is logic-high on both lines
    reg ps2_clk  = 1;
    reg ps2_data = 1;

    // VGA outputs from DUT
    wire vga_hsync;
    wire vga_vsync;
    wire [3:0] vga_r;
    wire [3:0] vga_g;
    wire [3:0] vga_b;

    // ---------------------------------------------------------------------
    // Device-Under-Test instantiation
    // ---------------------------------------------------------------------
    game_console dut (
        .clk        (clk),
        .reset_n    (reset_n),
        .ps2_clk    (ps2_clk),
        .ps2_data   (ps2_data),
        .vga_hsync  (vga_hsync),
        .vga_vsync  (vga_vsync),
        .vga_r      (vga_r),
        .vga_g      (vga_g),
        .vga_b      (vga_b)
    );

    // ---------------------------------------------------------------------
    // Optional: generate a slow toggling PS/2 clock to avoid constant-driver
    // warnings.  Left commented out because no keyboard traffic is required
    // for this smoke-test bench.
    // ---------------------------------------------------------------------
    //always #150 ps2_clk = ~ps2_clk; // ≈3.3 MHz

    // ---------------------------------------------------------------------
    // Test sequence
    // ---------------------------------------------------------------------
    initial begin
        // Dump waveforms for inspection (e.g. with GTKWave)
        $dumpfile("tb_game_console.vcd");
        $dumpvars(0, dut);

        // Release reset after a short delay so the PLL lock signal can settle
        #25;        // 25 ns
        reset_n = 1;

        // Run the simulation long enough to observe a few VGA frames
        #1000000;   // 1 ms simulated time

        $finish;
    end
endmodule
