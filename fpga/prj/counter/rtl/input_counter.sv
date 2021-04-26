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

   (* ASYNC_REG = "TRUE" *) logic input_meta, input_meta2, input_buffer, input_buffer_last;
   logic [32-1:0] counts;

   assign o_count = counts;

   // Two stage flip-flop stabilizer
   always_ff @(posedge i_clk) begin
      if (i_reset | ~i_gate) begin
         counts = 32'h0;
         input_meta = 1'h0;
         input_meta2 = 1'h0;
         input_buffer = 1'h0;
         input_buffer_last = 1'h0;
      end else if (i_gate) begin
         input_meta <= i_signal;
         input_meta2 <= input_meta;
         input_buffer <= input_meta2;
         input_buffer_last <= input_buffer;
         if (~input_buffer_last && input_buffer) begin
            counts = counts + 1'b1;
         end
      end
   end // always_ff @ (posedge clk)

endmodule
