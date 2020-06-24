/**
 * Simple counter module. Increments o_count when i_signal and i_gate are both high.
 * Resets o_count when i_reset is high.
 */

module input_counter (
   input wire            i_signal,
   input wire            i_clk,
   input wire            i_gate,
   input wire            i_reset,
   output logic [32-1:0] o_count
);

   logic input_buffer;
   logic input_buffer2;
   logic input_buffer3;
   logic input_buffer4;
   logic [32-1:0] counts;

   assign o_count = counts;

   // Two stage flip-flop stabilizer
   always_ff @(posedge i_clk) begin
      if (i_reset) begin
         counts = 32'h0;
      end else if (i_gate) begin
         input_buffer <= i_signal;
         input_buffer2 <= input_buffer;
         input_buffer3 <= input_buffer2;
         input_buffer4 <= input_buffer3;
         if (~input_buffer4 && input_buffer3) begin
            counts = counts + 1'b1;
         end
      end
   end // always_ff @ (posedge clk)

endmodule
