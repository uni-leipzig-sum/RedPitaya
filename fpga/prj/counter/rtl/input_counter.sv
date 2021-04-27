/**
 * Simple counter module. Increments o_count when i_signal and i_gate are both high.
 * Resets o_count when i_reset is high.
 */

module input_counter (
   input logic           i_signal,
   input wire            i_clk,
   input wire            i_gate,
   input wire            i_reset,
   output logic [32-1:0] o_count
);

   logic signal_last;
   logic [32-1:0] counts;

   assign o_count = counts;

   // Two stage flip-flop stabilizer
   always_ff @(posedge i_clk) begin
      if (i_reset | ~i_gate) begin
         counts = 32'h0;
         signal_last = 1'h0;
      end else if (i_gate) begin
         signal_last <= i_signal;
         if (~signal_last && i_signal) begin
            counts = counts + 1'b1;
         end
      end
   end // always_ff @ (posedge clk)

endmodule
