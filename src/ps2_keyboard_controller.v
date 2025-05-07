module ps2_keyboard_controller (
    input clk,              // System clock (e.g., 50MHz or 100MHz)
    input reset_n,          // Asynchronous reset, active low

    // PS/2 Interface (from FPGA pins)
    input ps2_clk_pin,      // PS/2 Clock line from keyboard
    input ps2_data_pin,     // PS/2 Data line from keyboard

    // Outputs
    output reg [7:0] keycode_out, // Last valid scancode received (make/break code)
    output reg keycode_valid,     // Pulsed high for one system clock cycle when keycode_out is valid
    output reg error_flag         // Indicates a PS/2 communication error (e.g., parity, framing)
);

// Internal logic for PS/2 protocol handling, debouncing, and scan code decoding will be added here.

    // --- Input Synchronizers (3-flop) ---
    reg ps2_clk_q1, ps2_clk_q2, ps2_clk_sync;
    reg ps2_data_q1, ps2_data_q2, ps2_data_sync;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            ps2_clk_q1 <= 1'b1;
            ps2_clk_q2 <= 1'b1;
            ps2_clk_sync <= 1'b1;
            ps2_data_q1 <= 1'b1;
            ps2_data_q2 <= 1'b1;
            ps2_data_sync <= 1'b1;
        end else begin
            ps2_clk_q1 <= ps2_clk_pin;
            ps2_clk_q2 <= ps2_clk_q1;
            ps2_clk_sync <= ps2_clk_q2; 

            ps2_data_q1 <= ps2_data_pin;
            ps2_data_q2 <= ps2_data_q1;
            ps2_data_sync <= ps2_data_q2;
        end
    end

    // --- PS/2 Clock Falling Edge Detection ---
    reg ps2_clk_sync_prev;
    wire ps2_clk_falling_edge;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            ps2_clk_sync_prev <= 1'b1;
        end else begin
            ps2_clk_sync_prev <= ps2_clk_sync;
        end
    end

    assign ps2_clk_falling_edge = ps2_clk_sync_prev & ~ps2_clk_sync;

    // --- PS/2 Frame Reception ---
    reg [10:0] rx_shift_reg;    // Shift register for the 11-bit frame (Start, D7-D0, Parity, Stop)
    reg [3:0]  bit_count;       // Counts bits received (0 to 10)
    reg        receiving_frame; // Flag to indicate if we are currently receiving a frame

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            rx_shift_reg <= 11'h000;
            bit_count <= 4'd0;
            receiving_frame <= 1'b0;
            keycode_out <= 8'h00;
            keycode_valid <= 1'b0;
            error_flag <= 1'b0;
        end else begin
            keycode_valid <= 1'b0; // Default to not valid

            if (ps2_clk_falling_edge) begin
                if (!receiving_frame) begin // Start of a new frame
                    if (~ps2_data_sync) begin // Check for start bit (must be 0)
                        receiving_frame <= 1'b1;
                        rx_shift_reg <= {ps2_data_sync, 10'h000}; // Start bit captured
                        bit_count <= 4'd1; // We've received 1 bit (the start bit)
                    end
                end else begin // Continue receiving frame
                    // Shift in the current data bit
                    rx_shift_reg <= {ps2_data_sync, rx_shift_reg[10:1]};
                    bit_count <= bit_count + 1;

                    if (bit_count == 4'd10) begin // All 11 bits received (0-start, 1-8 data, 9-parity, 10-stop)
                        receiving_frame <= 1'b0; // Done with this frame
                        bit_count <= 4'd0;       // Reset for next frame

                        // Parity check: For odd parity, XOR of data bits and parity bit should be 1
                        // Data bits are rx_shift_reg[8:1], Parity bit is rx_shift_reg[9]

                        // Frame validation: Start bit == 0, Stop bit == 1, Odd Parity correct
                        if (rx_shift_reg[0] == 1'b0 && rx_shift_reg[10] == 1'b1 && (^(rx_shift_reg[9:1]))) begin
                            // Data bits are D7..D0 which are rx_shift_reg[8:1]
                            keycode_out <= rx_shift_reg[8:1];
                            keycode_valid <= 1'b1;
                            error_flag <= 1'b0;
                        end else begin
                            // Error could be framing (start/stop) or parity
                            error_flag <= 1'b1;
                        end
                    end
                end
            end
        end
    end

// This will involve:
// 1. Synchronizing ps2_clk_pin and ps2_data_pin to the system clk. (DONE)
// 2. Detecting the falling edge of ps2_clk_pin to sample ps2_data_pin. (DONE)
// 3. Assembling the 11-bit PS/2 frame (start bit, 8 data bits, parity bit, stop bit).
// 4. Validating parity and framing.
// 5. Outputting the 8 data bits as keycode_out.

    initial begin
        // These are reset in the always block now
    end

endmodule
