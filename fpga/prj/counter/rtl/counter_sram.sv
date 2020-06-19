/**
 * Simple dual channel SRAM for the counter module.
 *
 * We need two channels in order to allow simultaneous reading/writing
 * from the counter and the system bus: While we read the buffer from software,
 * the counter must be able to fill up the buffer with new counts.
 *
 * Channel A has write priority over channel B, i.e. when A and B are trying to
 * write to the same address, A wins.
 */

module counter_sram
  #(
    int unsigned ADDR_WIDTH = 12,
    int unsigned DATA_WIDTH = 18,
    int unsigned DEPTH = 4096
    )
   (
    input logic                   i_clk,
    input logic [ADDR_WIDTH-1:0]  i_addr_a,
    input logic                   i_write_enable_a,
    input logic [DATA_WIDTH-1:0]  i_data_a,
    output logic [DATA_WIDTH-1:0] o_data_a,
    input logic [ADDR_WIDTH-1:0]  i_addr_b,
    input logic                   i_write_enable_b,
    input logic [DATA_WIDTH-1:0]  i_data_b,
    output logic [DATA_WIDTH-1:0] o_data_b,
    );

   logic [DATA_WIDTH-1:0]         memory [0:DEPTH-1];

   always @ (posedge i_clk)
   begin
      if (i_write_enable_a) begin
         memory[i_addr_a] <= i_data_a;
      end else begin
         o_data_a <= memory[i_addr_a];
      end

      if (i_write_enable_b) begin
         // Only write from B channel if A channel is not writing
         if ((not i_write_enable_a) or (i_addr_a != i_addr_b)) begin
            memory[i_addr_b] <= i_data_b;
         end
      end else begin
         o_data_b <= memory[i_addr_b];
      end
   end // always @ (posedge i_clk)

endmodule
