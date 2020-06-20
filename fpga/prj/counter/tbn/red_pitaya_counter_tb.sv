/**
 *
 * @brief Red Pitaya counter testbench.
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

module red_pitaya_counter_tb #(
   // time periods
   realtime     TP = 8.0ns // 125MHz
);


////////////////////////////////////////////////////////////////////////////////
// Signal generation
////////////////////////////////////////////////////////////////////////////////

   function count_signal_a (input int unsigned cyc);
      // Toggle a counting signal every 10 clock cycles (== 80ns)
      count_signal_a = (cyc % 10 == 0) ? 1'b1 : 1'b0;
   endfunction: count_signal_a

   function count_signal_b (input int unsigned cyc);
      // Send a counting signal every 5 clock cycles (== 40ns) and hold it high for 2 cycles
      count_signal_b = (cyc % 5 < 2) ? 1'b1 : 1'b0;
   endfunction: count_signal_b

   logic          clk;
   logic          rstn;
   logic [4-1:0]  signal;

   assign signal[0] = count_signal_a(clk_cyc);
   assign signal[1] = count_signal_b(clk_cyc);

   // Clock signal
   initial clk = 1'b0;
   always #(TP/2) clk = ~clk;

   // Reset
   initial begin
      rstn = 1'b0;
      repeat(4) @(posedge clk);
      rstn = 1'b1;
   end

   initial begin
      signal[2] = 0;
      signal[3] = 0;
   end

   // Clock cycle
   int unsigned clk_cyc = 0;
   always_ff @(posedge clk)
     clk_cyc <= clk_cyc + 1;

////////////////////////////////////////////////////////////////////////////////
// test sequence
////////////////////////////////////////////////////////////////////////////////

   logic [ 32-1: 0] sys_addr  = 0;
   logic [ 32-1: 0] sys_wdata = 0;
   logic            sys_wen   = 0;
   logic            sys_ren   = 0;
   logic [ 32-1: 0] sys_rdata;
   logic            sys_err;
   logic            sys_ack;

   logic [32-1: 0]  counts_1  = 0;
   logic [32-1: 0]  counts_2  = 0;
   logic [32-1: 0]  rdata     = 0;

   logic            failure   = 0;

// --- SYSTEM BUS TASKS ---

task bus_transaction (
  input  logic we,
  input  [32-1:0] addr,
  input  [32-1:0] wdata,
  output [32-1:0] rdata
);
  #1;
  sys_wen    <=  we;
  sys_ren    <= ~we;
  sys_addr   <= addr;
  sys_wdata  <= wdata;
  #1;
  sys_wen    <= 1'b0;
  sys_ren    <= 1'b0;
  while (~sys_ack & ~sys_err)
  #1;
  rdata <= sys_rdata;
  #1;
endtask: bus_transaction

// bus write transfer
task bus_write (
  input  [32-1:0] addr,
  input  [32-1:0] wdata
);
  logic [32-1:0] rdata;
  bus_transaction (.we (1'b1), .addr (addr), .wdata (wdata), .rdata (rdata));
endtask: bus_write

// bus read transfer
task bus_read (
  input  [32-1:0] addr,
  output [32-1:0] rdata
);
  bus_transaction (.we (1'b0), .addr (addr), .wdata ('x), .rdata (rdata));
endtask: bus_read


   initial begin
      $display ("-- Waiting for reset sequence");
      // Wait for initialization to finish
      wait (rstn)
        repeat(10) @(posedge clk);

      $display ("-- Configuring counter");
      // Configure counter
      bus_write(32'h04, 32'd100);    // set timeout to 100 clk cycles (=8us)
      bus_write(32'h10, 32'h1000);    // use all bins (4096)
      bus_write(32'h14, 32'h0);       // no repetitions per bin
      bus_write(32'h18, 32'h0);       // no predelay
      bus_write(32'h1C, 32'h8004);    // trigger when signal[3] gets high, no gating

      // Count immediately
      failure = 0;
      $display ("-- countImmediately");
      bus_write(32'h00, 32'h03);      // send command countImmediately
      repeat(10) @(posedge clk);
      bus_read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 2): $d", rdata);
      failure = (failure || (rdata != 2));
      repeat(110) @(posedge clk);        // Allow for counting to end
      bus_read(32'h08, counts_1);        // read counter ch1
      bus_read(32'h1C, counts_2);        // read counter ch2
      bus_read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 0): $d", rdata);
      failure = (failure || (rdata != 0));
      $display ("counter ch1 (expected 100): %d", counts_1);
      failure = (failure || (counts_1 != 100));
      $display ("counter ch2 (expected 200): %d", counts_2);
      failure = (failure || (counts_2 != 200));
      if (failure) $display ("FAILURE");
      else $display ("SUCCESS");

      // Count triggered, using software trigger command
      failure = 0;
      $display ("-- countTriggered (sw trigger)");
      bus_write(32'h00, 32'h02);         // send command reset
      repeat(10) @(posedge clk);
      bus_read(32'h20, rdata);           // read bin index
      $display ("bin index (expected 0):     $d", rdata);
      failure = (failure || (rdata != 0));
      bus_read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 0): $d", rdata);
      failure = (failure || (rdata != 0));
      bus_write(32'h00, 32'h04);         // send command countTriggered
      repeat(10) @(posedge clk);
      bus_read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 3): $d", rdata);
      failure = (failure || (rdata != 3));
      bus_write(32'h00, 32'h06);         // send command trigger
      repeat(10) @(posedge clk);
      bus_read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 7): $d", rdata);
      failure = (failure || (rdata != 7));
      repeat(110) @(posedge clk);        // Allow for counting to end
      $display ("bin index (expected 1):     $d", rdata);
      failure = (failure || (rdata != 1));
      bus_read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 3): $d", rdata);
      failure = (failure || (rdata != 3));
      bus_read(32'h10000, counts_1);     // read counter 1, bin 1
      bus_read(32'h14000, counts_2);     // read counter 2, bin 1
      $display ("counter ch1 (expected 100): %d", counts_1);
      failure = (failure || (counts_1 != 100));
      $display ("counter ch2 (expected 200): %d", counts_2);
      failure = (failure || (counts_2 != 200));
      if (failure) $display ("FAILURE");
      else $display ("SUCCESS");

      // Count triggered, using external trigger signal
      failure = 0;
      $display ("-- countTriggered (ext trigger)");
      bus_write(32'h00, 32'h02);         // send command reset
      repeat(10) @(posedge clk);
      bus_read(32'h20, rdata);           // read bin index
      $display ("bin index (expected 0):     $d", rdata);
      failure = (failure || (rdata != 0));
      bus_read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 0): $d", rdata);
      failure = (failure || (rdata != 0));
      bus_write(32'h00, 32'h04);         // send command countTriggered
      repeat(10) @(posedge clk);
      bus_read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 3): $d", rdata);
      failure = (failure || (rdata != 3));
      signal[4-1] = 1'b1;                // set input 4 high -- trigger signal
      repeat(10) @(posedge clk);
      signal[4-1] = 1'b0;                // set input 4 low
      repeat(10) @(posedge clk);
      bus_read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 7): $d", rdata);
      failure = (failure || (rdata != 7));
      repeat(110) @(posedge clk);       // Allow for counting to end
      $display ("bin index (expected 1):     $d", rdata);
      failure = (failure || (rdata != 1));
      bus_read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 3): $d", rdata);
      failure = (failure || (rdata != 3));
      bus_read(32'h10000, counts_1);     // read counter 1, bin 1
      bus_read(32'h14000, counts_2);     // read counter 2, bin 1
      $display ("counter ch1 (expected 100): %d", counts_1);
      failure = (failure || (counts_1 != 100));
      $display ("counter ch2 (expected 200): %d", counts_2);
      failure = (failure || (counts_2 != 200));
      if (failure) $display ("FAILURE");
      else $display ("SUCCESS");

      // Count gated
      failure = 0;
      $display ("-- countGated (ext trigger)");
      bus_write(32'h00, 32'h02);         // send command reset
      repeat(10) @(posedge clk);
      bus_read(32'h20, rdata);           // read bin index
      $display ("bin index (expected 0):     $d", rdata);
      failure = (failure || (rdata != 0));
      bus_read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 0): $d", rdata);
      failure = (failure || (rdata != 0));
      bus_write(32'h00, 32'h05);         // send command countGated
      repeat(10) @(posedge clk);
      bus_read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 8): $d", rdata);
      failure = (failure || (rdata != 8));
      signal[4-1] = 1'b1;                // set input 4 high -- gate signal
      repeat(100) @(posedge clk);        // keep gate high for 100 clock cycles
      signal[4-1] = 1'b0;                // set input 4 low
      repeat(10) @(posedge clk);         // allow for count storage
      bus_read(32'h00, rdata);           // read counter state
      $display ("bin index (expected 1):     $d", rdata);
      failure = (failure || (rdata != 1));
      bus_read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 8): $d", rdata);
      failure = (failure || (rdata != 8));
      bus_read(32'h10000, counts_1);     // read counter 1, bin 1
      bus_read(32'h14000, counts_2);     // read counter 2, bin 1
      $display ("counter ch1 (expected 100): %d", counts_1);
      failure = (failure || (counts_1 != 100));
      $display ("counter ch2 (expected 200): %d", counts_2);
      failure = (failure || (counts_2 != 200));
      if (failure) $display ("FAILURE");
      else $display ("SUCCESS");

      repeat (10) @(posedge clk);
      $finish ();
   end

////////////////////////////////////////////////////////////////////////////////
// module instances
////////////////////////////////////////////////////////////////////////////////


red_pitaya_counter i_counter (
      // signals
      .i_clk         (clk         ),
      .i_rstn        (rstn        ),
      .inputs        (signal      ),
      // System bus
      .sys_addr      (sys_addr ),
      .sys_wdata     (sys_wdata),
      .sys_wen       (sys_wen  ),
      .sys_ren       (sys_ren  ),
      .sys_rdata     (sys_rdata),
      .sys_err       (sys_err  ),
      .sys_ack       (sys_ack  )
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
endmodule: red_pitaya_counter_tb
