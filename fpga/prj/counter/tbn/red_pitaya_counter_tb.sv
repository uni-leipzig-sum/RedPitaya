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
   realtime     TP = 8.0ns, // 125MHz
);


////////////////////////////////////////////////////////////////////////////////
// Signal generation
////////////////////////////////////////////////////////////////////////////////

   function count_signal_a (input int unsigned cyc);
      // Toggle a counting signal every 100 clock cycles (== 800ns)
      count_signal_a = (cyc % 100 == 0) ? 1'b1 : 1'b0;
   endfunction: count_signal_a

   function count_signal_b (input int unsigned cyc);
      // Send a counting signal every 50 clock cycles (== 400ns) and hold it high for 10 cycles
      count_signal_b = (cyc % 50 < 10) ? 1'b1 : 1'b0;
   endfunction: count_signal_b

   logic        clk;
   logic        rstn;
   logic        signal [4-1:0];

   assign signal[0] = count_signal_a;
   assign signal[1] = count_signal_b;

   // Clock signal
   initial clk = 1'b0;
   always #(TP/2) clk = ~clk;

   // Reset
   initial begin
      rstn = 1'b0;
      repeat(4) @(posedge clk);
      rstn = 1'b1;
   end

   // Clock cycle
   int unsigned clk_cyc = 0;
   always_ff @(posedge clk)
     clk_cyc <= clk_cyc + 1;

////////////////////////////////////////////////////////////////////////////////
// test sequence
////////////////////////////////////////////////////////////////////////////////

   logic [ 32-1: 0] sys_addr ;
   logic [ 32-1: 0] sys_wdata;
   logic            sys_wen  ;
   logic            sys_ren  ;
   logic [ 32-1: 0] sys_rdata;
   logic            sys_err  ;
   logic            sys_ack  ;

   logic [32-1: 0]  counts_1;
   logic [32-1: 0]  counts_2;
   logic [32-1: 0]  rdata;

   logic            failure;

   initial begin
      // Wait for initialization to finish
      wait (rstn)
        repeat(10) @(posedge clk);

      // Configure counter
      bus.write(32'h04, 32'd1000);    // set timeout to 1000 clk cycles (=8us)
      bus.write(32'h10, 32'h1000);    // use all bins (4096)
      bus.write(32'h14, 32'h0);       // no repetitions per bin
      bus.write(32'h18, 32'h0);       // no predelay
      bus.write(32'h1C, 32'h8004);    // trigger when signal[3] gets high, no gating

      // Count immediately
      failure = 0;
      $display ("-- countImmediately");
      bus.write(32'h00, 32'h03);      // send command countImmediately
      repeat(10) @(posedge clk);
      bus.read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 2): $d", rdata);
      failure = (failure || (rdata != 2));
      repeat(1010) @(posedge clk);       // Allow for counting to end
      bus.read(32'h08, counts_1);        // read counter ch1
      bus.read(32'h1C, counts_2);        // read counter ch2
      bus.read(32'h00, rdata);           // read counter state
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
      bus.write(32'h00, 32'h02);         // send command reset
      repeat(10) @(posedge clk);
      bus.read(32'h20, rdata);           // read bin index
      $display ("bin index (expected 0):     $d", rdata);
      failure = (failure || (rdata != 0));
      bus.read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 0): $d", rdata);
      failure = (failure || (rdata != 0));
      bus.write(32'h00, 32'h04);         // send command countTriggered
      repeat(10) @(posedge clk);
      bus.read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 3): $d", rdata);
      failure = (failure || (rdata != 3));
      bus.write(32'h00, 32'h06);         // send command trigger
      repeat(10) @(posedge clk);
      bus.read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 7): $d", rdata);
      failure = (failure || (rdata != 7));
      repeat(1010) @(posedge clk);       // Allow for counting to end
      $display ("bin index (expected 1):     $d", rdata);
      failure = (failure || (rdata != 1));
      bus.read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 3): $d", rdata);
      failure = (failure || (rdata != 3));
      bus.read(32'h10000, counts_1);     // read counter 1, bin 1
      bus.read(32'h14000, counts_2);     // read counter 2, bin 1
      $display ("counter ch1 (expected 100): %d", counts_1);
      failure = (failure || (counts_1 != 100));
      $display ("counter ch2 (expected 200): %d", counts_2);
      failure = (failure || (counts_2 != 200));
      if (failure) $display ("FAILURE");
      else $display ("SUCCESS");

      // Count triggered, using external trigger signal
      failure = 0;
      $display ("-- countTriggered (ext trigger)");
      bus.write(32'h00, 32'h02);         // send command reset
      repeat(10) @(posedge clk);
      bus.read(32'h20, rdata);           // read bin index
      $display ("bin index (expected 0):     $d", rdata);
      failure = (failure || (rdata != 0));
      bus.read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 0): $d", rdata);
      failure = (failure || (rdata != 0));
      bus.write(32'h00, 32'h04);         // send command countTriggered
      repeat(10) @(posedge clk);
      bus.read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 3): $d", rdata);
      failure = (failure || (rdata != 3));
      signal[4-1] = 1'b1;                // set input 4 high -- trigger signal
      repeat(10) @(posedge clk);
      signal[4-1] = 1'b0;                // set input 4 low
      repeat(10) @(posedge clk);
      bus.read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 7): $d", rdata);
      failure = (failure || (rdata != 7));
      repeat(1010) @(posedge clk);       // Allow for counting to end
      $display ("bin index (expected 1):     $d", rdata);
      failure = (failure || (rdata != 1));
      bus.read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 3): $d", rdata);
      failure = (failure || (rdata != 3));
      bus.read(32'h10000, counts_1);     // read counter 1, bin 1
      bus.read(32'h14000, counts_2);     // read counter 2, bin 1
      $display ("counter ch1 (expected 100): %d", counts_1);
      failure = (failure || (counts_1 != 100));
      $display ("counter ch2 (expected 200): %d", counts_2);
      failure = (failure || (counts_2 != 200));
      if (failure) $display ("FAILURE");
      else $display ("SUCCESS");

      // Count gated
      failure = 0;
      $display ("-- countGated (ext trigger)");
      bus.write(32'h00, 32'h02);         // send command reset
      repeat(10) @(posedge clk);
      bus.read(32'h20, rdata);           // read bin index
      $display ("bin index (expected 0):     $d", rdata);
      failure = (failure || (rdata != 0));
      bus.read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 0): $d", rdata);
      failure = (failure || (rdata != 0));
      bus.write(32'h00, 32'h05);         // send command countGated
      repeat(10) @(posedge clk);
      bus.read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 8): $d", rdata);
      failure = (failure || (rdata != 8));
      signal[4-1] = 1'b1;                // set input 4 high -- gate signal
      repeat(1000) @(posedge clk);       // keep gate high for 1000 clock cycles
      signal[4-1] = 1'b0;                // set input 4 low
      repeat(10) @(posedge clk);         // allow for count storage
      bus.read(32'h00, rdata);           // read counter state
      $display ("bin index (expected 1):     $d", rdata);
      failure = (failure || (rdata != 1));
      bus.read(32'h00, rdata);           // read counter state
      $display ("counter state (expected 8): $d", rdata);
      failure = (failure || (rdata != 8));
      bus.read(32'h10000, counts_1);     // read counter 1, bin 1
      bus.read(32'h14000, counts_2);     // read counter 2, bin 1
      $display ("counter ch1 (expected 100): %d", counts_1);
      failure = (failure || (counts_1 != 100));
      $display ("counter ch2 (expected 200): %d", counts_2);
      failure = (failure || (counts_2 != 200));
      if (failure) $display ("FAILURE");
      else $display ("SUCCESS");

   end

////////////////////////////////////////////////////////////////////////////////
// module instances
////////////////////////////////////////////////////////////////////////////////

sys_bus_model bus (
  // system signals
  .clk          (clk      ),
  .rstn         (rstn     ),
  // bus protocol signals
  .sys_addr     (sys_addr ),
  .sys_wdata    (sys_wdata),
  .sys_wen      (sys_wen  ),
  .sys_ren      (sys_ren  ),
  .sys_rdata    (sys_rdata),
  .sys_err      (sys_err  ),
  .sys_ack      (sys_ack  ) 
);

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

initial begin
  $dumpfile("red_pitaya_counter_tb.vcd");
  $dumpvars(0, red_pitaya_counter_tb);
end

endmodule: red_pitaya_counter_tb
