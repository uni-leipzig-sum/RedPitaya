/**
 * Simple counter module. Increments o_count when i_signal and i_gate are both high.
 * Resets o_count when i_reset is high.
 */

module input_counter (input i_signal, i_clk, i_gate, i_reset, output buf [32-1:0] o_count);
   logic input_buffer;
   logic input_ack;
   logic edge_detected;

   always_ff @(posedge i_signal, input_ack) begin
      if (input_ack) input_buffer <= '0;
      else if ((posedge i_signal) and gate) input_buffer <= '1;
   end

   always_ff @(posedge clk) begin
      if (input_ack) begin
         input_ack <= '0;
         edge_detected = '1;
      end else begin
         input_ack <= input_buffer;
         edge_detected = '0;
      end
      if (reset)
        o_count <= '0;
      else if (edge_detected)
        o_count <= o_count + 1;
   end // always_ff @ (posedge clk)

endmodule
