/**
 * The main redpitaya counter module.
 *
 * @author Lukas Botsch <lukas.botsch@uni-leipzig.de>
 */

/**
 * System bus address layout:
 *
 * +------------+-----+------------------------------+
 * | Addr       | R/W | Description                  |
 * +------------+-----+------------------------------+
 * | 0x00000000 | RW  | send cmd / get current state |
 * | 0x00000004 | RW  | timeout                      |
 * | 0x00000008 | R   | last count ch 1              |
 * | 0x0000000C | R   | last count ch 2              |
 * | 0x00000010 | RW  | number of bins in use        |
 * | 0x00000014 | RW  | number of bin repetitions    |
 * | 0x00000018 | RW  | predelay                     |
 * | 0x0000001C | RW  | trigger config               |
 * | 0x00000020 | R   | current bin index            |
 * | 0x00000024 | R   | current repetition index     |
 * | 0x00000028 | R   | DNA                          |
 * | 0x0000002C | R   | debug clock                  |
 * | 0x00000030 | RW  | debug mode                   |
 * | 0x00000034 | R   | last count duration          |
 * +------------+-----+------------------------------+
 * | ...        |     |                              |
 * +------------+-----+------------------------------+
 * | 0x00010000 | RW  | bin data ch1                 |
 * | ...        |     |                              |
 * +------------+-----+------------------------------+
 * | 0x00014000 | RW  | bin data ch2                 |
 * | ...        |     |                              |
 * +------------+-----+------------------------------+
 * | 0x00018000 | RW  | bin duration (in clk cycles) |
 * | ...        |     |                              |
 * +------------+-----+------------------------------+
 */

module red_pitaya_counter
  #(
    int unsigned num_inputs = 4,
    int unsigned num_counters = 2,
    int unsigned default_trigger_input = 4,
    bit [32-1:0] DNA = 32'hA1B2C3D6
    )
   (
    // Inputs
    input logic                  i_clk,      // 125MHz clock (default)
    input logic                  i_fast_clk, // 500MHz clock (for counters)
    input logic                  i_rstn,
    input logic [num_inputs-1:0] inputs,
    output logic [8-1:0]         o_led,

    // System bus
    input logic [ 32-1: 0]       sys_addr, // bus saddress
    input logic [ 32-1: 0]       sys_wdata, // bus write data
    input logic                  sys_wen, // bus write enable
    input logic                  sys_ren, // bus read enable
    output logic [ 32-1: 0]      sys_rdata, // bus read data
    output logic                 sys_err, // bus error indicator
    output logic                 sys_ack   // bus acknowledge signal
    );

   typedef enum {
         idle,                               // 0
         immediateCounting_start,            // 1
         immediateCounting_waitForTimeout,   // 2
         triggeredCounting_waitForTrigger,   // 3
         triggeredCounting_store,            // 4
         triggeredCounting_predelay,         // 5
         triggeredCounting_prestore,         // 6
         triggeredCounting_waitForTimeout,   // 7
         gatedCounting_waitForGateRise,      // 8
         gatedCounting_waitForGateFall,      // 9
         gatedCounting_prestore,             // 10
         gatedCounting_store                 // 11
         } counter_state_t;
   typedef enum {
         none,                 // 0
         gotoIdle,             // 1
         reset,                // 2
         countImmediately,     // 3
         countTriggered,       // 4
         countGated,           // 5
         trigger               // 6
         } control_command_t;

   // --- Debug logic ---
   logic [32-1:0]            debug_clock;
   logic                     debug_mode;


   // --- Counter logic ---
   // Clock for predelay and timeout
   logic [32-1:0]            counter_clock;
   // The current counts
   wire [32-1:0]             counters_current_count [num_counters-1:0];
   // The last completed count result
   logic [32-1:0]            counters_last_count [num_counters-1:0];
   // The duration of the last count cycle
   logic [32-1:0]            counters_last_duration;
   // Reset the counters
   logic                     counters_reset [num_counters-1:0];

   // The number of cycles to count (immediate and trigger mode)
   logic [32-1:0]            counter_timeout;
   // The number of cycles to wait before counting (immediate and trigger mode)
   logic [32-1:0]            counter_predelay;
   // The last bin to fill (0 indexed). Once the last bin is full, start over with first bin
   logic [12-1:0]            counter_max_bin_address;
   // Accumulate (sum) N counts per bin
   logic [16-1:0]            counter_number_of_bin_repetitions;

   // Index of current bin repetition
   logic [16-1:0]            bin_repetition_index;

   // Current state of the counter state machine
   counter_state_t           counter_state;
   // Indicates that the counter is not counting
   logic                     counting_stopped;
   // The control command
   control_command_t         control_command;
   logic                     control_command_signal;
   logic                     control_command_ack;
   // Counter -> Counter RAM channel
   logic [12-1:0]            cnt_counter_ram_addr;
   logic [32-1:0]            cnt_counter_ram_rdata [num_counters-1:0];
   logic [32-1:0]            cnt_counter_ram_wdata [num_counters-1:0];
   logic                     cnt_counter_ram_write_enable;
   logic [32-1:0]            cnt_duration_ram_rdata;
   logic [32-1:0]            cnt_duration_ram_wdata;


   // --- Trigger logic ---
   // input signal buffers -- for signal synchronization
   (* ASYNC_REG = "TRUE" *) logic [num_inputs-1:0]    inputs_meta, inputs_meta2, inputs_buffer;
   // trigger_signal = !!((inputs_buffer3 ^ trigger_invert) & trigger_mask) == trigger_polarity
   logic                     trigger_signal;
   // Trigger input mask
   logic [num_inputs-1:0]             trigger_mask;
   // Trigger input inversion mask
   logic [num_inputs-1:0]             trigger_invert;
   // The polarity of the trigger signal
   logic                     trigger_polarity;
   // The gate signal
   logic                     gate_signal;

   // --- System BUS communication ---
   logic                     sw_counter_ram_id;
   logic [16-1:0]            sw_counter_ram_read_in_progress;
   logic [12-1:0]            sw_counter_ram_addr;
   logic [32-1:0]            sw_counter_ram_rdata [num_counters-1:0];
   logic [32-1:0]            sw_counter_ram_wdata [num_counters-1:0];
   logic                     sw_counter_ram_write_enable [num_counters-1:0];
   logic [32-1:0]            sw_duration_ram_rdata;
   logic [32-1:0]            sw_duration_ram_wdata;
   logic                     sw_duration_ram_write_enable;
   logic [16-1:0]            sw_duration_ram_read_in_progress;


   // Generate counting modules
   generate
      for (genvar i = 0; i < num_counters; i++) begin
         // Counter
         input_counter input_counter_inst (
           .i_signal(inputs[i]),
           .i_clk(i_clk),
           .i_gate(1'b1), //(gate_signal),
           .i_reset(counters_reset[i]),
           .o_count(counters_current_count[i])
         );
         // Counter RAM
         counter_sram  #(
           .ADDR_WIDTH(12), .DATA_WIDTH(32), .DEPTH(4096)
         ) counter_sram_inst (
           .i_clk(i_clk),
           .i_addr_a(cnt_counter_ram_addr),
           .i_write_enable_a(cnt_counter_ram_write_enable),
           .i_data_a(cnt_counter_ram_wdata[i]),
           .o_data_a(cnt_counter_ram_rdata[i]),
           .i_addr_b(sw_counter_ram_addr),
           .i_write_enable_b(sw_counter_ram_write_enable[i]),
           .i_data_b(sw_counter_ram_wdata[i]),
           .o_data_b(sw_counter_ram_rdata[i])
         );
      end
   endgenerate
   counter_sram  #(
      .ADDR_WIDTH(12), .DATA_WIDTH(32), .DEPTH(4096)
    ) duration_sram_inst (
      .i_clk(i_clk),
      .i_addr_a(cnt_counter_ram_addr),
      .i_write_enable_a(cnt_counter_ram_write_enable),
      .i_data_a(cnt_duration_ram_wdata),
      .o_data_a(cnt_duration_ram_rdata),
      .i_addr_b(sw_counter_ram_addr),
      .i_write_enable_b(sw_duration_ram_write_enable),
      .i_data_b(sw_duration_ram_wdata),
      .o_data_b(sw_duration_ram_rdata)
    );

   // ------ IMPLEMENTATION ------

   // --- Debug mode ---
   // In debug mode we map the inputs to the last LEDs
   // The trigger_signal is mapped to LED0
   // The gate_signal is mapped to LED1
   assign o_led[0] = (debug_mode) ? trigger_signal : 1'b0;
   assign o_led[1] = (debug_mode) ? gate_signal : 1'b0;
   assign o_led[2] = (debug_mode) ? ((counters_last_count[0] > 0)? 1'b1 : 1'b0) : 1'b0;
   assign o_led[3] = (debug_mode) ? ((counters_last_count[1] > 0)? 1'b1 : 1'b0) : 1'b0;
   generate
   for (genvar i = 0; i < num_inputs; i++) begin
      assign o_led[8-num_inputs+i] = (debug_mode) ? inputs[i] : 1'b0;
   end
   endgenerate

   // --- Input signal synchronization ---
   always_ff @(posedge i_clk) begin
      if (i_rstn) begin
         inputs_meta <= inputs;
         inputs_meta2 <= inputs_meta;
         inputs_buffer <= inputs_meta2;

         trigger_signal = ((((inputs_buffer ^ trigger_invert) & trigger_mask) == trigger_mask) == trigger_polarity) ?
                          1'b1 : 1'b0;
         if (counter_state == gatedCounting_waitForGateRise ||
             counter_state == gatedCounting_waitForGateFall) begin
            gate_signal = trigger_signal;
         end else begin
            gate_signal = 1'b1;
         end
     end
   end

   // --- Counter state machine ---
   always_ff @(posedge i_clk) begin
      if (~i_rstn) begin
         // Reset all state
         counter_state <= idle;
         control_command_ack <= 1'b0;
         counting_stopped <= 1'b1;
         counter_clock <= 32'b0;
         debug_clock <= 32'b0;
         bin_repetition_index <= 16'h0;
         cnt_counter_ram_addr <= 12'h0;
         for (int i = 0; i < num_counters; i++) begin
            counters_last_count[i] <= 32'b0;
            counters_reset[i] <= 1'b1;
         end
         for (int i = 0; i < num_inputs; i++) begin
            inputs_meta[i] <= 1'b0;
            inputs_meta2[i] <= 1'b0;
            inputs_buffer[i] <= 1'b0;
         end
         cnt_counter_ram_write_enable <= 1'b0;
         counters_last_duration <= 32'b0;
      end else begin
         debug_clock <= debug_clock + 1;
         // Check that current RAM address is within the limit of bins in use
         if (cnt_counter_ram_addr > counter_max_bin_address) begin
            cnt_counter_ram_addr = 12'h0;
         end

         if (control_command_signal) begin
            control_command_ack <= 1'b1;
            case (control_command)
              gotoIdle: begin counter_state = idle; end
              reset: begin
                 bin_repetition_index <= 16'h0;
                 cnt_counter_ram_addr <= 12'h0;
                 for (int i = 0; i < num_counters; i++)
                   counters_last_count[i] <= 32'b0;
                 counters_last_duration <= 32'b0;
                 counter_state = idle;
              end
              countImmediately: begin counter_state = immediateCounting_start; end
              countTriggered: begin counter_state = triggeredCounting_waitForTrigger; end
              countGated: begin counter_state = gatedCounting_waitForGateRise; end
              trigger: begin
                 if (counter_state == triggeredCounting_waitForTrigger) begin
                    counter_state = triggeredCounting_waitForTimeout;
                 end
              end
            endcase // case (control_command)
         end // if (control_command_signal)
         case (counter_state)
           idle: begin
              counting_stopped <= 1'b1;
              for (int i = 0; i < num_counters; i++) begin
                 counters_reset[i] <= 1'b1;
              end
              for (int i = 0; i < num_inputs; i++) begin
                 inputs_meta[i] <= 1'b0;
                 inputs_meta2[i] <= 1'b0;
                 inputs_buffer[i] <= 1'b0;
              end
              cnt_counter_ram_write_enable <= 1'b0;
           end
           immediateCounting_start: begin
              counter_clock = counter_timeout;
              counters_last_duration <= counter_timeout;
              counting_stopped <= 1'b0;
              for (int i = 0; i < num_counters; i++)
                counters_reset[i] <= 1'b0;
              counter_state = immediateCounting_waitForTimeout;
           end
           immediateCounting_waitForTimeout: begin
              if (counter_clock == 0) begin
                 counting_stopped <= 1'b1;
                 counters_last_count <= counters_current_count;
                 for (int i = 0; i < num_counters; i++)
                   counters_reset[i] <= 1'b1;
                 counter_state = idle;
              end else begin
                 counter_clock <= counter_clock - 1;
              end
           end
           triggeredCounting_waitForTrigger: begin
              if (trigger_signal) begin
                 if (counter_predelay != 0) begin
                    counter_clock = counter_predelay;
                    counter_state = triggeredCounting_predelay;
                 end else begin
                    counter_clock = counter_timeout;
                    counters_last_duration <= counter_timeout;
                    counting_stopped <= 1'b0;
                    for (int i = 0; i < num_counters; i++)
                      counters_reset[i] <= 1'b0;
                    counter_state = triggeredCounting_waitForTimeout;
                 end
              end // if (trigger_signal)
           end // case: triggeredCounting_waitForTrigger
           triggeredCounting_predelay: begin
              if (counter_clock == 0) begin
                 counter_clock = counter_timeout;
                 counters_last_duration <= counter_timeout;
                 counting_stopped <= 1'b0;
                 for (int i = 0; i < num_counters; i++)
                   counters_reset[i] <= 1'b0;
                 counter_state = triggeredCounting_waitForTimeout;
              end else begin
                 counter_clock <= counter_clock - 1;
              end
           end
           triggeredCounting_waitForTimeout: begin
              if (counter_clock == 0) begin
                 counting_stopped <= 1'b1;
                 counters_last_count <= counters_current_count;
                 for (int i = 0; i < num_counters; i++)
                   counters_reset[i] <= 1'b1;
                 counter_state = triggeredCounting_prestore;
              end else begin
                 counter_clock <= counter_clock - 1;
              end
           end
           gatedCounting_waitForGateRise: begin
              if (trigger_signal == 1'b1) begin
                 counting_stopped <= 1'b0;
                 counters_last_duration <= 32'h1;
                 for (int i = 0; i < num_counters; i++)
                   counters_reset[i] <= 1'b0;
                 counter_state = gatedCounting_waitForGateFall;
              end
           end
           gatedCounting_waitForGateFall: begin
              if (trigger_signal == 1'b0) begin
                 counting_stopped <= 1'b1;
                 counters_last_count <= counters_current_count;
                 for (int i = 0; i < num_counters; i++)
                   counters_reset[i] <= 1'b1;
                 counter_state = gatedCounting_prestore;
              end else begin
                 counters_last_duration <= counters_last_duration + 32'h1;
              end
           end
           triggeredCounting_prestore, gatedCounting_prestore: begin
              for (int i = 0; i < num_counters; i++) begin
                 cnt_counter_ram_wdata[i] <= counters_last_count[i];
              end
              cnt_counter_ram_write_enable <= 1'b1;
              cnt_duration_ram_wdata <= counters_last_duration;
              counter_state = (counter_state == triggeredCounting_prestore) ?
                                  triggeredCounting_store :
                                  gatedCounting_store;
           end
           triggeredCounting_store, gatedCounting_store: begin
              cnt_counter_ram_write_enable <= 1'b0;
              if (cnt_counter_ram_addr == counter_max_bin_address)
                cnt_counter_ram_addr <= 12'h0;
              else
                cnt_counter_ram_addr <= cnt_counter_ram_addr + 12'h1;
              counter_state = (counter_state == triggeredCounting_store) ?
                                  triggeredCounting_waitForTrigger :
                                  gatedCounting_waitForGateRise;
           end // case: triggeredCounting_store, gatedCounting_store
         endcase // case (counter_state)
      end
   end

   // --- System Bus write ---
   always_ff @(posedge i_clk) begin
      if (control_command_ack) begin
         control_command <= none;
         control_command_signal <= 1'b0;
      end

      for (int i = 0; i < num_counters; i++)
        sw_counter_ram_write_enable[i] <= 1'b0;
      sw_duration_ram_write_enable <= 1'b0;

      if (~i_rstn) begin
         control_command <= none;
         counter_timeout <= 32'd125; // 1µs default timeout
         counter_max_bin_address <= 12'hFFF;
         counter_number_of_bin_repetitions <= 16'h0;
         counter_predelay <= 32'h0;
         trigger_mask <= {num_inputs{1'b0}};
         trigger_invert <= {num_inputs{1'b0}};
         trigger_polarity <= 1'b1;
         debug_mode <= 1'b0;
      end else if (sys_wen) begin
         if(sys_addr[19-1:0] <= 19'h30) begin
            if (sys_addr[19-1:0] == 19'h0) begin
               case (sys_wdata)
                 32'h0: control_command <= none;
                 32'h1: control_command <= gotoIdle;
                 32'h2: control_command <= reset;
                 32'h3: control_command <= countImmediately;
                 32'h4: control_command <= countTriggered;
                 32'h5: control_command <= countGated;
                 32'h6: control_command <= trigger;
                 default: control_command <= none;
               endcase // case (sys_wdata)
               control_command_signal <= 1'b1;
            end // if (sys_addr[15:0] == 16'h0)
            if (sys_addr[19-1:0] == 19'h4) counter_timeout <= sys_wdata;
            if (sys_addr[19-1:0] == 19'h10) counter_max_bin_address <= sys_wdata[12-1:0];
            if (sys_addr[19-1:0] == 19'h14) counter_number_of_bin_repetitions <= sys_wdata[16-1:0];
            if (sys_addr[19-1:0] == 19'h18) counter_predelay <= sys_wdata;
            if (sys_addr[19-1:0] == 19'h1C) begin
               trigger_mask <= sys_wdata[num_inputs-1:0];
               trigger_invert <= sys_wdata[(2*num_inputs)-1:num_inputs];
               trigger_polarity <= sys_wdata[2*num_inputs];
               //counter_split_bins <= sys_wdata[2*num_inputs+1];
               //counter_gating_activated <= sys_wdata[num_inputs+2];
            end
            if (sys_addr[19-1:0] == 19'h30) debug_mode <= sys_wdata[0];
         end else if (sys_addr[19-1:0] >= 19'h10000 && sys_addr[19-1:0] < (19'h10000 + num_counters*19'h1000)) begin
            sw_counter_ram_wdata[sys_addr[14]] <= sys_wdata;
            sw_counter_ram_write_enable[sys_addr[14]] <= 1'b1;
         end else if (sys_addr[19-1:0] >= (19'h10000 + (num_counters*19'h1000)) && sys_addr[19-1:0] < (19'h10000 + ((num_counters+1)*19'h1000))) begin
            sw_duration_ram_wdata <= sys_wdata;
            sw_duration_ram_write_enable <= 1'b1;
         end
      end // if (sys_wen)
   end

   // --- System Bus read  ---
   wire sys_en;
   assign sys_en = sys_wen | sys_ren;
   always_ff @(posedge i_clk) begin
      if (~i_rstn) begin
         sys_err <= 1'b0;
         sys_ack <= 1'b0;
         sw_counter_ram_read_in_progress <= 16'h0;
         sw_duration_ram_read_in_progress <= 16'h0;
      end else begin
         // Reading from BRAM takes 2 clock cycles!
         if (sw_counter_ram_read_in_progress > 16'h1) begin
            sw_counter_ram_read_in_progress <= sw_counter_ram_read_in_progress - 16'h1;
            sys_err <= 1'b0;
            sys_ack <= 1'b0;
         end else if (sw_counter_ram_read_in_progress == 16'h1) begin
            sys_ack <= sys_en;
            sys_err <= 1'b0;
            sys_rdata <= sw_counter_ram_rdata[sw_counter_ram_id];
            sw_counter_ram_read_in_progress <= 16'h0;
         end else if (sw_duration_ram_read_in_progress > 16'h1) begin
            sw_duration_ram_read_in_progress <= sw_duration_ram_read_in_progress - 16'h1;
            sys_ack <= 1'b0;
            sys_err <= 1'b0;
         end else if (sw_duration_ram_read_in_progress == 16'h1) begin
            sys_ack <= sys_en;
            sys_err <= 1'b0;
            sys_rdata <= sw_duration_ram_rdata;
            sw_duration_ram_read_in_progress <= 16'h0;
         end else begin
             sys_err <= 1'b0;
             if (sys_addr[19-1:0] <= 19'h34) begin
                case (sys_addr[19-1:0])
                  19'h0: begin
                     sys_ack <= sys_en;
                     case (counter_state)
                       idle:
                         sys_rdata <= 32'h00;
                       immediateCounting_start:
                         sys_rdata <= 32'h1;
                       immediateCounting_waitForTimeout:
                         sys_rdata <= 32'h2;
                       triggeredCounting_waitForTrigger:
                         sys_rdata <= 32'h3;
                       triggeredCounting_store:
                         sys_rdata <= 32'h4;
                       triggeredCounting_predelay:
                         sys_rdata <= 32'h5;
                       triggeredCounting_prestore:
                         sys_rdata <= 32'h6;
                       triggeredCounting_waitForTimeout:
                         sys_rdata <= 32'h7;
                       gatedCounting_waitForGateRise:
                         sys_rdata <= 32'h8;
                       gatedCounting_waitForGateFall:
                         sys_rdata <= 32'h9;
                       gatedCounting_prestore:
                         sys_rdata <= 32'hA;
                       gatedCounting_store:
                         sys_rdata <= 32'hB;
                     endcase // case (counter_state)
                  end // case: 20'h0000
                  19'h4: begin sys_ack <= sys_en; sys_rdata <= counter_timeout; end
                  19'h8: begin sys_ack <= sys_en; sys_rdata <= counters_last_count[0]; end
                  19'hC: begin sys_ack <= sys_en; sys_rdata <= counters_last_count[1]; end
                  19'h10: begin sys_ack <= sys_en; sys_rdata <= {20'b0, counter_max_bin_address}; end
                  19'h14: begin sys_ack <= sys_en; sys_rdata <= {16'b0, counter_number_of_bin_repetitions}; end
                  19'h18: begin sys_ack <= sys_en; sys_rdata <= counter_predelay; end
                  19'h1C: begin sys_ack <= sys_en;
                     sys_rdata <= {{(32-(2*num_inputs+3)){1'b0}}, // padding
                                   1'b0, //counter_gating_activated,
                                   1'b0, //counter_split_bins,
                                   trigger_polarity,
                                   trigger_invert,
                                   trigger_mask};
                  end
                  19'h20: begin sys_ack <= sys_en; sys_rdata <= {20'b0, cnt_counter_ram_addr}; end
                  19'h24: begin sys_ack <= sys_en; sys_rdata <= {16'b0, bin_repetition_index}; end
                  19'h28: begin sys_ack <= sys_en; sys_rdata <= DNA; end
                  19'h2C: begin sys_ack <= sys_en; sys_rdata <= debug_clock; end
                  19'h30: begin sys_ack <= sys_en; sys_rdata <= debug_mode; end
                  19'h34: begin sys_ack <= sys_en; sys_rdata <= counters_last_duration; end
                  default: begin sys_ack <= sys_en; sys_rdata <= 32'h0; end
                endcase // case (sys_addr[19:0])
             end else if (sys_addr[19-1:0] >= 19'h10000 && sys_addr[19-1:0] < (19'h10000+num_counters*19'h4000)) begin // if (sys_addr[16] == 1'b0)
                // RAM request: Counter RAM is mapped to offset 0x10000 (CH1) 0x14000 (CH2)
                sw_counter_ram_addr <= sys_addr[13:2];
                sw_counter_ram_id <= sys_addr[14];
                sw_counter_ram_read_in_progress <= (sys_wen) ? 16'hA : 16'h8; // Wait some clock cycles for reading from RAM + some more for writing
                sys_ack <= 1'b0;
                sys_err <= 1'b0;
             end else if (sys_addr[19-1:0] >= (19'h10000+(num_counters*19'h4000)) && sys_addr[19-1:0] < (19'h10000+((num_counters+1)*19'h4000))) begin
                sw_counter_ram_addr <= sys_addr[13:2];
                sw_duration_ram_read_in_progress <= (sys_wen) ? 16'hA : 16'h8;
                sys_ack <= 1'b0;
                sys_err <= 1'b0;
             end else begin // if (sys_addr[15] == 1'b0)
                sys_ack <= sys_en;
                sys_err <= 1'b0;
                sys_rdata <= 32'h0;
             end
         end
      end // else: !if(~i_rstn)
   end // always @ (posedge i_clk)

endmodule
