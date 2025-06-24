`timescale 1ns / 1ps
`include "memory_sizes.vh"

// Memory controller: handles address decoding, 32-bit alignment and
// sub-word (byte/half-word) access logic.
//
// mem_u_b_h_w encoding (matches previous RAM_B implementation):
// bit0 = 1 -> half-word access (16-bit)
// bit1 = 1 -> word access   (32-bit)            
//            (when bit1 = 1, bit0 is don't care)
// bit2 = 1 -> UNSIGNED load, 0 -> SIGNED (for byte/half loads)
// When {bit1,bit0} == 00   -> byte access
// When {bit1,bit0} == 01   -> half-word access
// When {bit1,bit0} == 1x   -> word access
//
// For writes we honour the same encoding to generate per-byte write enables.
// The downstream RAM_B stores words and accepts 4-bit byte enables.

module memory_controller (
    // CPU memory interface
    input  wire [31:0]   addr,          // byte address from CPU
    input  wire [31:0]   wdata,         // write data from CPU (LSB significant)
    output reg  [31:0]   rdata,         // read data back to CPU
    input  wire          mem_read,      // CPU read strobe (one cycle)
    input  wire          mem_write,     // CPU write strobe (one cycle)
    input  wire [2:0]    mem_u_b_h_w,   // size / sign control from core

    // ROM
    output reg  [`ROM_ADDR_WIDTH-1:0]   rom_addr,      // 4096 words
    input  wire [31:0]   rom_rdata,
    output reg           rom_read,

    // RAM
    output reg  [`RAM_ADDR_WIDTH-1:0]    ram_addr,      // 32-bit aligned word index
    output reg  [31:0]   ram_wdata,
    output reg  [3:0]    ram_we,        // byte enables
    input  wire [31:0]   ram_rdata,
    output reg           ram_access,    // simplified chip-enable

    // Keyboard – simple read-only 32-bit registers (256 bytes)
    output reg           kb_read,
    output reg  [`KB_ADDR_WIDTH-1:0]    kb_addr,
    input  wire [31:0]   kb_rdata,

    // Display – write-only 32-bit framebuffer (64KB -> 16-bit address)
    output reg           disp_write,
    output reg  [`DISP_ADDR_WIDTH-1:0]   disp_addr,
    output reg  [31:0]   disp_wdata
);

    // ---------------------------------------------------------------------
    // Address decoding (top nibble only – simple)
    // ---------------------------------------------------------------------
    localparam ROM_BASE  = 4'h0;  // 0x0-------
    localparam RAM_BASE  = 4'h1;  // 0x1-------
    localparam KB_BASE   = 4'h2;  // 0x2-------
    localparam DISP_BASE = 4'h3;  // 0x3-------

    wire [3:0] addr_hi = addr[31:28];
    wire is_rom  = addr_hi == ROM_BASE;
    wire is_ram  = addr_hi == RAM_BASE;
    wire is_kb   = addr_hi == KB_BASE;
    wire is_disp = addr_hi == DISP_BASE;

    // Word-aligned address and byte offset within the word
    wire [1:0] byte_sel = addr[1:0];  // 0-3
    wire [31:0] aligned_addr = {addr[31:2], 2'b00};

    // Combinatorial control generation
    always @(*) begin
        // Defaults
        rom_read   = 1'b0;
        kb_read    = 1'b0;
        disp_write = 1'b0;
        ram_we     = 4'b0000;
        ram_access = 1'b0;
        ram_wdata  = wdata;
        rom_addr   = {2'b0, addr[27:2]};
        ram_addr   = {2'b0, addr[27:2]};
        kb_addr    = {2'b0, addr[27:2]};
        disp_addr  = {2'b0, addr[27:2]};
        disp_wdata = wdata;

        // --------------------------------------------------------------
        // READ path
        // --------------------------------------------------------------
        rdata = 32'h0;
        if (mem_read) begin
            if (is_rom) begin
                rom_read = 1'b1;
                rdata_word_select(rom_rdata); // macro below
            end else if (is_ram) begin
                ram_access = 1'b1;
                rdata_word_select(ram_rdata);
            end else if (is_kb) begin
                kb_read = 1'b1;
                rdata = kb_rdata; // always full word
            end else begin
                rdata = 32'h0;
            end
        end

        // --------------------------------------------------------------
        // WRITE path (RAM or display)
        // --------------------------------------------------------------
        if (mem_write) begin
            if (is_ram) begin
                ram_access = 1'b1;
                {ram_we, ram_wdata} = gen_write_enable_and_data(ram_rdata);
            end else if (is_disp) begin
                disp_write = 1'b1;
            end
        end
    end

    // ------------------------------------------------------------------
    // Helpers – generate rdata for sub-word loads (function) and write masks
    // ------------------------------------------------------------------

    task automatic rdata_word_select(input [31:0] raw_word);
        begin
            case ({mem_u_b_h_w[1], mem_u_b_h_w[0]})
                2'b10: begin // word
                    rdata = raw_word;
                end
                2'b01: begin // half-word
                    if (byte_sel[1]) begin
                        rdata = mem_u_b_h_w[2] ? {16'b0, raw_word[31:16]} : {{16{raw_word[31]}}, raw_word[31:16]};
                    end else begin
                        rdata = mem_u_b_h_w[2] ? {16'b0, raw_word[15:0]}  : {{16{raw_word[15]}}, raw_word[15:0]};
                    end
                end
                default: begin // byte
                    case (byte_sel)
                        2'd0: rdata = mem_u_b_h_w[2] ? {24'b0, raw_word[7:0]}   : {{24{raw_word[7]}},   raw_word[7:0]};
                        2'd1: rdata = mem_u_b_h_w[2] ? {24'b0, raw_word[15:8]}  : {{24{raw_word[15]}},  raw_word[15:8]};
                        2'd2: rdata = mem_u_b_h_w[2] ? {24'b0, raw_word[23:16]} : {{24{raw_word[23]}}, raw_word[23:16]};
                        default: rdata = mem_u_b_h_w[2] ? {24'b0, raw_word[31:24]} : {{24{raw_word[31]}}, raw_word[31:24]};
                    endcase
                end
            endcase
        end
    endtask

    function automatic [35:0] gen_write_enable_and_data;
        input [31:0] current_word;
        reg   [3:0] we;
        reg   [31:0] wd;
        begin
            we = 4'b0000;
            wd = current_word; // default keep
            case ({mem_u_b_h_w[1], mem_u_b_h_w[0]})
                2'b10: begin // word
                    we = 4'b1111;
                    wd = wdata;
                end
                2'b01: begin // half-word
                    we = byte_sel[1] ? 4'b1100 : 4'b0011;
                    if (byte_sel[1]) begin
                        wd[31:16] = wdata[15:0];
                    end else begin
                        wd[15:0]  = wdata[15:0];
                    end
                end
                default: begin // byte
                    we = 4'b0001 << byte_sel;
                    case (byte_sel)
                        2'd0: wd[7:0]   = wdata[7:0];
                        2'd1: wd[15:8]  = wdata[7:0];
                        2'd2: wd[23:16] = wdata[7:0];
                        default: wd[31:24] = wdata[7:0];
                    endcase
                end
            endcase
            gen_write_enable_and_data = {we, wd};
        end
    endfunction

endmodule