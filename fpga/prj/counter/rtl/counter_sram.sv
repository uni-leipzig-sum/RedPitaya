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
    input logic                   i_rstn,
    input logic [ADDR_WIDTH-1:0]  i_addr_a,
    input logic                   i_write_enable_a,
    input logic [DATA_WIDTH-1:0]  i_data_a,
    output logic [DATA_WIDTH-1:0] o_data_a,
    input logic [ADDR_WIDTH-1:0]  i_addr_b,
    input logic                   i_write_enable_b,
    input logic [DATA_WIDTH-1:0]  i_data_b,
    output logic [DATA_WIDTH-1:0] o_data_b
    );

   logic [DATA_WIDTH-1:0]         memory [0:DEPTH-1];

   logic [ADDR_WIDTH-1:0]         write_addr;
   logic [DATA_WIDTH-1:0]         write_buffer;
   logic                          write_enable;

   always @ (posedge i_clk)
     begin
        if (i_rstn) begin
           // Initialize memory to all zero
           for (int i = 0; i < DEPTH; i++)
             memory[i] = DATA_WIDTH'h0;
           o_data_a <= DATA_WIDTH'h0;
           o_data_b <= DATA_WIDTH'h0;
        end else begin
           if (i_write_enable_a) begin
              write_addr = i_addr_a;
              write_buffer = i_data_a;
              write_enable = 1'b1;
           end else if (i_write_enable_b) begin
              write_addr = i_addr_b;
              write_buffer = i_data_b;
              write_enable = 1'b1;
           end else write_enable = 1'b0;

           if (write_enable) begin
              memory[write_addr] <= write_buffer;
           end

           o_data_a <= memory[i_addr_a];
           o_data_b <= memory[i_addr_b];
        end
     end // always @ (posedge i_clk)

endmodule
