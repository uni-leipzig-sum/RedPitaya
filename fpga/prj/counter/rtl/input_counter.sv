/**
 * Simple counter module. Increments o_count when i_signal and i_gate are both high.
 * Resets o_count when i_reset is high.
 */

module input_counter (
   input logic i_signal,
   input logic i_clk,
   input logic i_gate,
   input logic i_reset,
   output logic [32-1:0] o_count
);

   logic input_buffer;
   logic input_ack;
   logic edge_detected;
   logic [32-1:0] counts;

   assign o_count = counts;

   always_ff @(posedge i_clk) begin
      if (!input_ack && i_signal && i_gate) begin
         input_buffer <= '1;
      end
      if (input_ack) begin
         input_ack <= '0;
         input_buffer <= '0;
         edge_detected = '1;
      end else begin
         input_ack <= input_buffer;
         edge_detected = '0;
      end
      if (i_reset)
        counts <= '0;
      else if (edge_detected)
        counts <= counts + 1;
   end // always_ff @ (posedge clk)

endmodule
