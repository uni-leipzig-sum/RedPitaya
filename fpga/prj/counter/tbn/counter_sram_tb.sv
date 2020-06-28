/**
 *
 * @brief Red Pitaya counter sram testbench.
 *
 * @Author Lukas Botsch <lukas.botsch@uni-leipzig.de>
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */

/**
 * GENERAL DESCRIPTION:
 *
 * Testbench for Red Pitaya counter module.
 *
 */


`timescale 1ns / 1ps

module counter_sram_tb #(
   // time periods
   realtime     TP = 8.0ns, // 125MHz
   parameter ADDR_WIDTH = 12,
   parameter DATA_WIDTH = 18,
   parameter DEPTH = 4096
);


////////////////////////////////////////////////////////////////////////////////
// Signal generation
////////////////////////////////////////////////////////////////////////////////

   logic          clk;
   logic          rstn;
   
   // Clock signal
   initial clk = 1'b0;
   always #(TP/2) clk = ~clk;

   // Reset
   initial begin
      rstn = 1'b0;
      repeat(4) @(posedge clk);
      rstn = 1'b1;
   end

////////////////////////////////////////////////////////////////////////////////
// test sequence
////////////////////////////////////////////////////////////////////////////////

   logic [ADDR_WIDTH-1:0]  i_addr_a;
   logic                   i_write_enable_a;
   logic [DATA_WIDTH-1:0]  i_data_a;
   logic [DATA_WIDTH-1:0]  o_data_a;
   logic [ADDR_WIDTH-1:0]  i_addr_b;
   logic                   i_write_enable_b;
   logic [DATA_WIDTH-1:0]  i_data_b;
   logic [DATA_WIDTH-1:0]  o_data_b;

   logic            failure   = 0;

   initial begin
      $display ("-- Waiting for reset sequence");
      // Wait for initialization to finish
      wait (rstn)
        repeat(10) @(posedge clk);

      $display ("-- Reading from port A");
      i_addr_a = {ADDR_WIDTH{1'b0}};
      repeat(2) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_a, o_data_a);
      i_addr_a = {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
      repeat(2) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_a, o_data_a);
      i_addr_a = {{(ADDR_WIDTH-2){1'b0}}, 2'b10};
      repeat(2) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_a, o_data_a);
      i_addr_a = {{(ADDR_WIDTH-2){1'b0}}, 2'b11};
      repeat(2) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_a, o_data_a);
      
      $display("-- Writing to port A");
      i_write_enable_a = 1'b1;
      i_addr_a = 12'h0;
      i_data_a = 18'h0;
      repeat(3) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_a, o_data_a);
      i_addr_a = 12'h1;
      i_data_a = 18'h1;
      repeat(3) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_a, o_data_a);
      i_addr_a = 12'h2;
      i_data_a = 18'h2;
      repeat(3) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_a, o_data_a);
      i_addr_a = 12'h3;
      i_data_a = 18'h3;
      repeat(3) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_a, o_data_a);
      i_write_enable_a = 1'b0;
      
      $display ("-- Reading from port A");
      i_addr_a = 12'h0;
      repeat(2) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_a, o_data_a);
      i_addr_a = 12'h1;
      repeat(2) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_a, o_data_a);
      i_addr_a = 12'h2;
      repeat(2) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_a, o_data_a);
      i_addr_a = 12'h3;
      repeat(2) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_a, o_data_a);

      $display("-- Writing to port B");
      i_write_enable_b = 1'b1;
      i_addr_b = 12'h0;
      i_data_b = 18'h3;
      repeat(3) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_b, o_data_b);
      i_addr_b = 12'h1;
      i_data_b = 18'h2;
      repeat(3) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_b, o_data_b);
      i_addr_b = 12'h2;
      i_data_b = 18'h1;
      repeat(3) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_b, o_data_b);
      i_addr_b = 12'h3;
      i_data_b = 18'h0;
      repeat(3) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_b, o_data_b);
      
      $display ("-- Reading from port B");
      i_addr_b = 12'h0;
      repeat(2) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_b, o_data_b);
      i_addr_b = 12'h1;
      repeat(2) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_b, o_data_b);
      i_addr_b = 12'h2;
      repeat(2) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_b, o_data_b);
      i_addr_b = 12'h3;
      repeat(2) @(posedge clk);
      $display("@0x%08x: 0x%08x", i_addr_b, o_data_b);

      repeat (10) @(posedge clk);
      $finish ();
   end

////////////////////////////////////////////////////////////////////////////////
// module instances
////////////////////////////////////////////////////////////////////////////////


counter_sram #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) counter_sram_inst (
      // signals
      .i_clk(clk),
      .i_addr_a(i_addr_a),
      .i_write_enable_a(i_write_enable_a),
      .i_data_a(i_data_a),
      .o_data_a(o_data_a),
      .i_addr_b(i_addr_b),
      .i_write_enable_b(i_write_enable_b),
      .i_data_b(i_data_b),
      .o_data_b(o_data_b)
);

////////////////////////////////////////////////////////////////////////////////
// waveforms
////////////////////////////////////////////////////////////////////////////////

/*
initial begin
  $dumpfile("red_pitaya_counter_tb.vcd");
  $dumpvars(0, red_pitaya_counter_tb);
end
*/
endmodule: counter_sram_tb
