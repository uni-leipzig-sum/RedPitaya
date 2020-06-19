/**
 * The redpitaya counter module.
 * 
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
    input logic               i_clk,
    input logic               i_rstn,
    input logic [NINPUTS-1:0] inputs,

    // System bus
    input logic [ 32-1: 0]    sys_addr, // bus saddress
    input logic [ 32-1: 0]    sys_wdata, // bus write data
    input logic               sys_wen, // bus write enable
    input logic               sys_ren, // bus read enable
    output logic [ 32-1: 0]   sys_rdata, // bus read data
    output logic              sys_err, // bus error indicator
    output logic              sys_ack   // bus acknowledge signal
    );

   enum {
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
         gatedCounting_store,                // 11
         } counter_state_t;
   enum {
         none,                 // 0
         gotoIdle,             // 1
         reset,                // 2
         countImmediately,     // 3
         countTriggered,       // 4
         countGated,           // 5
         trigger               // 6
         } control_commands_t;

   logic [32-1:0]            debug_clock;

   // --- Counter logic ---
   // The current counts
   logic [32-1:0]            counters_current_count [num_counters-1:0];
   // The last completed count result
   logic [32-1:0]            counters_last_count [num_counters-1:0];
   // Reset the counters
   logic                     counters_reset [num_counters-1:0];

   // The number of cycles to count (immediate and trigger mode)
   logic [32-1:0]            counter_timeout;
   // The number of cycles to wait before counting (immediate and trigger mode)
   logic [32-1:0]            counter_predelay;
   // The number of bins to fill. Once the last bin is full, start over with first bin
   logic [32-1:0]            counter_number_of_bins_in_use;
   // Accumulate (sum) N counts per bin
   logic [32-1:0]            counter_number_of_bin_repetitions;
   // For general gating, works in every mode
   logic                     counter_gating_activated;

   // Index of current bin repetition
   logic [16-1:0]            bin_repetition_index;

   // Current state of the counter state machine
   counter_state_t           counter_state;
   counter_state_t           counter_state_buffer;
   // Indicates that the counter is not counting
   logic                     counting_stopped;
   // The control command we just received
   conrol_command_t          control_command;
   logic                     conrol_command_signal;
   logic                     control_command_signal_ack;
   logic                     control_command_signal_buffer;
   logic                     control_command_signal_valid;
   // Counter -> Counter RAM channel
   logic [12-1:0]            cnt_counter_ram_addr [num_counters-1:0];
   logic [18-1:0]            cnt_counter_ram_rdata [num_counters-1:0];
   logic [18-1:0]            cnt_counter_ram_wdata [num_counters-1:0];
   logic                     cnt_counter_ram_write_enable [num_counters-1:0];


   // --- Trigger logic ---
   // trigger_signal = !!((inputs ^ trigger_invert) & trigger_mask) == trigger_polarity
   logic                     trigger_signal;
   // Trigger input mask
   logic [8-1:0]             trigger_mask;
   // Trigger input inversion mask
   logic [8-1:0]             trigger_invert;
   // The polarity of the trigger signal
   logic                     trigger_polarity;
   // ???
   logic                     trigger_ack;
   // Buffer for trigger signal
   logic                     trigger_buffer;
   // Whether a trigger signal just came in
   logic                     trigger_edge_detected;
   // The gate signal
   logic                     gate_signal;
   //
   logic                     gate_ack;
   //
   logic                     gate_buffer;

   // --- System BUS communication ---
   logic                     sw_counter_ram_id;
   logic                     sw_counter_ram_read_in_progress;
   logic [12-1:0]            sw_counter_ram_addr [num_counters-1:0];
   logic [18-1:0]            sw_counter_ram_rdata [num_counters-1:0];
   logic [18-1:0]            sw_counter_ram_wdata [num_counters-1:0];
   logic                     sw_counter_ram_write_enable [num_counters-1:0];
   logic [32-1:0]            sys_rdata_buf;

   // Generate counting modules
   generate
      for (genvar i = 0; i < num_counters; i++) begin
         // Counter
         input_counter input_counter_inst (
           .i_signal(inputs[i]),
           .i_clk(i_clk),
           .i_gate(gate_signal),
           .i_reset(counters_reset[i]),
           .o_count(counters_last_count[i])
         );
         // Counter RAM
         counter_sram  #(
           .ADDR_WIDTH(12), .DATA_WIDTH(18), .DEPTH(4096)
         ) counter_sram_inst (
           .i_clk(i_clk),
           .i_addr_a(cnt_counter_ram_addr),
           .i_write_enable_a(cnt_counter_ram_write_enable),
           .i_data_a(cnt_counter_ram_wdata),
           .o_data_a(cnt_counter_ram_rdata),
           .i_addr_b(sw_counter_ram_addr),
           .i_write_enable_b(sw_counter_ram_write_enable),
           .i_data_b(sw_counter_ram_wdata),
           .o_data_b(sw_counter_ram_rdata)
         );
      end
   endgenerate

   // ------ IMPLEMENTATION ------

   // --- Trigger logic ---
   assign trigger_signal = !!((inputs ^ trigger_invert) & trigger_mask) == trigger_polarity;
   assign gate_signal = (counter_gating_activated ||
                  counter_state == gatedCounting_waitForGateRise ||
                  counter_state == gatedCounting_waitForGateFall) ?
                 trigger_signal : '1;

   always_ff @(trigger_signal, trigger_ack) begin
      if (trigger_ack) trigger_buffer <= '0;
      else if (trigger_signal) trigger_buffer <= '1;
   end

   always_ff @(gate_ack) begin
      if (gate_ack) gate_buffer <= '0;
   end

   always_ff @(gate_signal) begin
      gate_buffer <= '1;
   end

   always_ff @(posedge i_clk) begin
      if (~i_rstn) begin
         trigger_ack <= '0;
         trigger_edge_detected <= '0;
         trigger_buffer <= '0;
         trigger_mask <= (8'1 << (default_trigger_input-1));
         trigger_invert <= 8'0;
         trigger_polarity <= '1;
      end else begin
         if (trigger_ack) begin
            trigger_ack <= '0;
            trigger_edge_detected <= '1;
         end else begin
            trigger_ack <= trigger_buffer;
            trigger_edge_detected <= '0;
         end
      end
   end

   // --- Counter logic ---
   always_ff @(posedge control_command_singal, control_command_signal_ack) begin
      if (control_command_signal_ack) control_command_signal_buffer <= '0;
      else if (control_command_signal) control_command_signal_buffer <= '1;
   end

   always_ff @(posedge i_clk) begin
      if (~i_rstn) begin
         counter_timeout <= '0;
         counter_predelay <= '0;
         counter_number_of_bins_in_use <= '0;
         counter_number_of_bin_repetitions <= '0;
         counter_gating_activated <= '0;
         bin_repetition_counter <= '0;

         counter_state <= idle;
         control_command <= none;
      end else begin // if (~i_rstn)
         if (trigger_ack) begin
            trigger_ack <= '0;
            trigger_edge_detected = '1;
         end else begin
            trigger_ack <= trigger_buffer;
            trigger_edge_detected = '0;
         end
         if (gate_ack) begin
            gate_ack <= '0;
            gate_edge_detected = '1;
         end else begin
            gate_ack <= gate_buffer;
            gate_edge_detected = '0;
         end
         if (control_command_signal_ack) begin
            control_command_signal <= '0;
            control_command_signal_valid = '1;
         end else begin
            control_command_signal <= control_command_signal_buffer;
            control_command_signal_valid = '0;
         end
         counter_state_buffer = counter_state;
         debug_clock <= debug_clock + 1;

         if (control_command_signal_valid) begin
            case (control_command)
              gotoIdle:
                counter_state_buffer = idle;
              reset: begin
                 cnt_counter_ram_addr <= '0;
                 bin_repetition_index <= '0;
                 counter_state_buffer = idle;
                 debug_clock <= '0;
              end
              countImmediately:
                counter_state_buffer = immediateCounting_start;
              countTriggered:
                counter_state_buffer = triggeredCounting_waitForTrigger;
              countGated:
                counter_state_buffer = gatedCounting_waitForGateRise;
              trigger:
                trigger_edge_detected = '1;
            endcase // case (control_command)
            control_command <= none;
         end // if (control_command_signal_valid)
         counter_state = counter_state_buffer;
         case (counter_state_buffer)
            idle: begin
               counting_stopped <= '1;
               for (i = 0; i < num_counters; i++) begin
                  counters_reset[i] <= '1;
                  cnt_counter_ram_write_enable[i] <= '0;
               end
            end
           immediateCounting_start: begin
              counter_clock <= counter_timeout;
              counting_stopped <= '0;
              for (i = 0; i < num_counters; i++) begin
                 counters_reset[i] <= '0;
              end
           end
           immediateCounting_waitForTimeout: begin
              if (counter_clock == '0) begin
                 counting_stopped <= '1;
                 for (i = 0; i < num_counters; i++) begin
                    counters_last_count <= counters_current_count;
                    counters_reset[i] <= '1;
                 end
                 counter_state <= idle;
              end else begin
                 counter_clock <= counter_clock - 1;
              end
           end
           triggeredCounting_waitForTrigger: begin
              if (trigger_edge_detected) begin
                 if (counter_predelay != '0) begin
                    counter_clock <= predelay - 1;
                    counter_state <= triggeredCounting_predelay;
                 end else begin
                    counter_clock <= counter_timeout;
                    counting_stopped <= '0;
                    for (i = 0; i < num_counters; i++)
                      counters_reset[i] <= '0;
                    counter_state <= triggeredCounting_waitForTimeout;
                 end
              end // if (trigger_edge_detected)
           end // case: triggeredCounting_waitForTrigger
           triggeredCounting_predelay: begin
              if (counter_clock == 0) begin
                 counter_clock <= counter_timeout;
                 counting_stopped <= '0;
                 for (i = 0; i < num_counters; i++)
                   counters_reset[i] <= '0;
                 counter_state <= triggeredCounting_waitForTimeout;
              end else begin
                 counter_clock <= counter_clock - 1;
              end
           end // case: triggeredCounting_predelay
           triggeredCounting_waitForTimeout: begin
              if (counter_clock == '0) begin
                 counting_stopped <= '1;
                 for (i = 0; i < num_counters; i++) begin
                    counters_last_count <= counters_current_count;
                    counters_reset[i] <= '1;
                 end
                 counter_state <= triggeredCounting_prestore;
              end else begin
                 counter_clock <= counter_clock - 1;
              end
           end // case: triggeredCounting_waitForTimeout
           gatedCounting_waitForGateRise: begin
              if (gate_edge_detected) begin
                 counting_stopped <= '0;
                 for (i = 0; i < num_counters; i++)
                   counters_reset[i] <= '0;
                 counter_state <= gatedCounting_waitForGateFall;
              end
           end
           gatedCounting_waitForGateFall: begin
              if (gate_edge_detected) begin
                 counting_stopped <= '1;
                 for (i = 0; i < num_counters; i++) begin
                    counters_last_count <= counters_current_count;
                    counters_reset[i] <= '1;
                 end
                 counter_state <= gatedCounting_prestore;
              end
           end
           triggeredCounting_prestore, gatedCounting_prestore: begin
              for (i = 0; i < num_counters; i++) begin
                 cnt_counter_ram_wdata[i] <= cnt_counter_ram_rdata[i] +
                       counters_last_count[i][18-1:0];
                 cnt_counter_ram_write_enable[i] <= '1;
              end
              counter_state <= (counter_state_buffer == triggeredCounting_prestore) ?
                               triggeredCounting_store :
                               gatedCounting_store;
           end
           triggeredCounting_store, gatedCounting_store: begin
              for (i = 0; i < num_counters; i++) begin
                 cnt_counter_ram_write_enable[i] <= '0;
              end
              if (bin_repetition_index == counter_number_of_bin_repetitions) begin
                 bin_repetition_index <= '0;
                 if (cnt_counter_ram_addr == counter_number_of_bins_in_use - 1)
                   cnt_counter_ram_addr <= '0;
                 else
                   cnt_counter_ram_addr <= cnt_counter_ram_addr + 1;
              end else begin
                 bin_repetition_index <= bin_repetition_index + 1;
              end
              counter_state <= (counter_state_buffer == triggeredCounting_store) ?
                               triggeredCounting_waitForTrigger :
                               gatedCounting_waitForGateRise;
           end // case: triggeredCounting_store, gatedCounting_store
           default:
             counter_state <= idle;
         endcase // case (counter_state_buffer)
      end // else: !if(~i_rstn)
   end // always_ff @ (posedge i_clk)

   // System BUS communication
   assign sys_rdata = (sw_counter_ram_read_in_progress) ?
                      {(32-18)'0, sw_counter_ram_rdata[sw_counter_ram_id]} :
                      sys_rdata_buf;

   always_ff @(posedge i_clk) begin
      control_command_signal <= '0;
      if (~i_rstn) begin
         sys_ack <= '0;
         sys_err <= '0;
         sw_counter_ram_id <= '0;
         sw_counter_ram_read_in_progress <= '0;
         sw_counter_ram_addr <= '0;
         sw_counter_ram_write_enable <= '0;
         sw_counter_ram_wdata <= '0;
      end else begin
         sys_ack <= sys_wen or sys_ren;
         sys_err <= '0;
         sys_rdata_buf <= '0;
         sw_counter_ram_write_enable <= {'0,'0};
         sw_counter_ram_read_in_progress <= '0;

         unique if(sys_addr[19:16] == '0) begin
            // Command request: All addresses below 0x10000 are command requests
            if (sys_wen) begin
               sys_ack <= '1;
               unique case (sys_addr[15:0])
                 'h0000: begin // Control command
                    unique case (sys_wdata)
                      0: control_command <= none;
                      1: control_command <= goto_idle;
                      2: control_command <= reset;
                      3: control_command <= count_immediately;
                      4: control_command <= count_triggered;
                      5: control_command <= countGated;
                      6: control_command <= trigger;
                      default: control_command <= none;
                    endcase // unique case (sys_wdata)
                    control_command_signal <= '1;
                 end // case: 'h0000
                 'h0004: counter_timeout <= sys_wdata; // Set timeout
                 'h0010: counter_number_of_bins_in_use <= sys_wdata;
                 'h0014: counter_number_of_bin_repetitions <= sys_wdata;
                 'h0018: counter_predelay <= sys_wdata;
                 'h001C: begin // trigger and gating settings
                    trigger_mask <= sys_wdata[8-1:0];
                    trigger_invert <= sys_wdata[16-1:8];
                    trigger_polarity <= sys_wdata[16];
                    //counter_split_bins <= sys_wdata[17];
                    counter_gating_activated <= sys_wdata[18];
                 end
                 default: begin
                    sys_ack <= '0;
                    sys_err <= '1;
                 end
               endcase
            end else if (sys_ren) begin // if (sys_wen)
               sys_ack <= '1;
               unique case (sys_addr[15:0])
                 'h0000: begin
                    case (counter_state)
                      idle:
                        sys_rdata_buf <= 'h00000000;
                      immediateCounting_start:
                        sys_rdata_buf <= 'h00000001;
                      immediateCounting_waitForTimeout:
                        sys_rdata_buf <= 'h00000002;
                      triggeredCounting_waitForTrigger:
                        sys_rdata_buf <= 'h00000003;
                      triggeredCounting_store:
                        sys_rdata_buf <= 'h00000004;
                      triggeredCounting_predelay:
                        sys_rdata_buf <= 'h00000005;
                      triggeredCounting_prestore:
                        sys_rdata_buf <= 'h00000006;
                      triggeredCounting_waitForTimeout:
                        sys_rdata_buf <= 'h00000007;
                      gatedCounting_waitForGateRise:
                        sys_rdata_buf <= 'h00000008;
                      gatedCounting_waitForGateFall:
                        sys_rdata_buf <= 'h00000009;
                      gatedCounting_prestore:
                        sys_rdata_buf <= 'h0000000A;
                      gatedCounting_store:
                        sys_rdata_buf <= 'h0000000B;
                    endcase // case (counter_state)
                 end // case: 'h0000
                 'h0004: sys_rdata_buf <= counter_timeout;
                 'h0008: sys_rdata_buf <= counters_last_count[0];
                 'h000C: sys_rdata_buf <= counters_last_count[1];
                 'h0010: sys_rdata_buf <= counter_number_of_bins_in_use;
                 'h0014: sys_rdata_buf <= counter_number_of_bin_repetitions;
                 'h0018: sys_rdata_buf <= counter_predelay;
                 'h001C: sys_rdata_buf <= {14'b0,
                                           counter_gating_activated,
                                           //counter_split_bins,
                                           1b0,
                                           trigger_polarity,
                                           trigger_invert,
                                           trigger_mask};
                 'h0020: sys_rdata_buf <= {20'b0, counter_ram_addr[0]};
                 'h0024: sys_rdata_buf <= {16'b0, bin_repetition_counter};
                 'h0028: sys_rdata_buf <= DNA;
                 'h002C: sys_rdata_buf <= debug_clock;
                 default: sys_rdata_buf <= 'h00000000;
               endcase
            end // if (sys_ren)
         end else if (sys_addr[19:16] == '1) begin // if (sys_addr[19:16] == '0)
            // RAM request: Counter RAM is mapped to offset 0x10000 (CH1) 0x14000 (CH2)
            if (sys_addr[15] == '0 and (sys_ren == '1 or sys_wen == '1)) begin
               sw_counter_ram_addr <= sys_addr[13:2];
               sw_counter_ram_id <= sys_addr[14];
               if (sys_wen) begin
                  sw_counter_ram_wdata[sw_counter_ram_id] <= sys_wdata[18-1:0];
                  sw_counter_ram_write_enable[sw_counter_ram_id] <= '1;
                  sys_ack <= '1;
               end else if (sys_ren) begin
                  sw_counter_ram_read_in_progress <= '1;
                  sys_ack <= '1;
               end
            end // if (sys_addr[15] == '0 and (sys_ren == '1 or sys_wen == '1))
         end // if (sys_addr[19:16] == '1)
      end // else: !if(i_rstn == 0)
   end // always_ff @ (posedge i_clk)

endmodule
