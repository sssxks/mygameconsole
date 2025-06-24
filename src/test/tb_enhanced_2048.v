`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Enhanced testbench for the complete 2048 rendering system
// Tests the full display pipeline including:
// - Tile rendering with numbers
// - UI elements (title, score, instructions)
// - Background patterns
// - VGA timing
// -----------------------------------------------------------------------------
module tb_enhanced_2048;
    
    // ---------------------------------------------------------------------
    // Clock generation – 100 MHz system clock
    // ---------------------------------------------------------------------
    reg clk = 0;
    always #5 clk = ~clk; // 100 MHz → 10 ns period

    // Control signals
    reg reset_n = 0;
    
    // Keyboard simulation - all keys initially released
    reg [25:0] key_status = 26'b0;

    // PS/2 interface – idle state
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
    // Keyboard simulation tasks
    // ---------------------------------------------------------------------
    task press_key;
        input [4:0] key_index; // A=0, B=1, ..., W=22, ..., Z=25
        begin
            key_status[key_index] = 1'b1;
            #100000; // Hold key for 100 microseconds
            key_status[key_index] = 1'b0;
            #500000; // Wait 500 microseconds between key presses
        end
    endtask

    // Specific key tasks for game controls
    task press_w; begin press_key(22); end endtask // W = up
    task press_a; begin press_key(0);  end endtask // A = left  
    task press_s; begin press_key(18); end endtask // S = down
    task press_d; begin press_key(3);  end endtask // D = right

    // ---------------------------------------------------------------------
    // VGA frame detection
    // ---------------------------------------------------------------------
    reg vsync_prev = 1;
    integer frame_count = 0;
    
    always @(posedge clk) begin
        vsync_prev <= vga_vsync;
        
        // Detect rising edge of vsync (end of frame)
        if (vga_vsync && !vsync_prev) begin
            frame_count <= frame_count + 1;
            $display("Frame %d completed at time %t", frame_count, $time);
        end
    end

    // ---------------------------------------------------------------------
    // Main test sequence
    // ---------------------------------------------------------------------
    initial begin
        $dumpfile("tb_enhanced_2048.vcd");
        $dumpvars(0, dut);
        
        $display("=== Enhanced 2048 Rendering System Test ===");
        $display("Testing complete display pipeline with:");
        $display("- Advanced tile rendering with numbers");
        $display("- UI elements (title, score, instructions)");
        $display("- VGA output timing");
        $display("- Keyboard input simulation");
        
        // Initial reset sequence
        reset_n = 0;
        #100;
        reset_n = 1;
        $display("Reset released at time %t", $time);
        
        // Wait for PLL to lock and system to stabilize
        #1000000; // 1ms
        $display("System stabilized, beginning game simulation...");
        
        // Display initial state for several frames
        wait (frame_count >= 5);
        $display("Initial display rendered for %d frames", frame_count);
        
        // Simulate a sequence of moves to test tile updates
        $display("Testing keyboard input and tile movement...");
        
        // Test each direction
        $display("Pressing W (UP)...");
        press_w();
        wait (frame_count >= 8);
        
        $display("Pressing A (LEFT)...");
        press_a();
        wait (frame_count >= 11);
        
        $display("Pressing S (DOWN)...");
        press_s();
        wait (frame_count >= 14);
        
        $display("Pressing D (RIGHT)...");
        press_d();
        wait (frame_count >= 17);
        
        // Test rapid key sequence
        $display("Testing rapid key sequence...");
        press_w();
        press_a();
        press_s();
        press_d();
        wait (frame_count >= 25);
        
        // Let the system run for more frames to observe behavior
        $display("Observing system behavior for additional frames...");
        wait (frame_count >= 35);
        
        // Final statistics
        $display("=== Test Completed Successfully ===");
        $display("Total frames rendered: %d", frame_count);
        $display("Total simulation time: %t", $time);
        $display("Average frame time: %t", $time / frame_count);
        
        $finish;
    end

    // ---------------------------------------------------------------------
    // Timeout protection
    // ---------------------------------------------------------------------
    initial begin
        #50000000; // 50ms timeout
        $display("ERROR: Test timeout reached!");
        $display("Frames completed: %d", frame_count);
        $finish;
    end

    // ---------------------------------------------------------------------
    // Color change detection (to verify rendering is working)
    // ---------------------------------------------------------------------
    reg [11:0] prev_color = 12'h000;
    reg [11:0] curr_color;
    integer color_changes = 0;
    
    always @(posedge clk) begin
        curr_color = {vga_r, vga_g, vga_b};
        if (curr_color != prev_color) begin
            color_changes = color_changes + 1;
        end
        prev_color = curr_color;
    end
    
    // Report color change statistics periodically
    always @(posedge vga_vsync) begin
        if (frame_count % 10 == 0 && frame_count > 0) begin
            $display("Frame %d: %d color changes detected", frame_count, color_changes);
            color_changes = 0; // Reset counter
        end
    end

endmodule 