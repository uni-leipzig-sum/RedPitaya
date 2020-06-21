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
 * +------------+-----+------------------------------+
 * | ...        |     |                              |
 * +------------+-----+------------------------------+
 * | 0x00010000 | RW  | bin data ch1                 |
 * | ...        |     |                              |
 * +------------+-----+------------------------------+
 * | 0x00014000 | RW  | bin data ch2                 |
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
    input logic                  i_clk,
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

   logic [32-1:0]            debug_clock;
   logic                     debug_mode;

   /* Debug mode:
    * In debug mode, we map the input signals 1-4 onto leds 5-8 respectively.
    * This allows to visually debug the input signals.
    */
   generate
      for (genvar i = 0; i < 4; i++)
        assign o_led[4+i] = (debug_mode) ? inputs[i] : 1'b0;
   endgenerate

   // --- Counter logic ---
   // Clock for predelay and timeout
   logic [32-1:0]            counter_clock;
   // The current counts
   wire [32-1:0]             counters_current_count [num_counters-1:0];
   // The last completed count result
   logic [32-1:0]            counters_last_count [num_counters-1:0];
   // Reset the counters
   logic                     counters_reset [num_counters-1:0];

   // The number of cycles to count (immediate and trigger mode)
   logic [32-1:0]            counter_timeout;
   // The number of cycles to wait before counting (immediate and trigger mode)
   logic [32-1:0]            counter_predelay;
   // The number of bins to fill. Once the last bin is full, start over with first bin
   logic [12-1:0]            counter_number_of_bins_in_use;
   // Accumulate (sum) N counts per bin
   logic [16-1:0]            counter_number_of_bin_repetitions;
   // For general gating, works in every mode
   logic                     counter_gating_activated;

   // Index of current bin repetition
   logic [16-1:0]            bin_repetition_index;

   // Current state of the counter state machine
   counter_state_t           counter_state;
   counter_state_t           counter_state_buf;
   // Indicates that the counter is not counting
   logic                     counting_stopped;
   // The control command
   control_command_t         control_command;
   logic                     control_command_signal;
   logic                     control_command_ack;
   // Counter -> Counter RAM channel
   logic [12-1:0]            cnt_counter_ram_addr;
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
   // The gate signal
   logic                     gate_signal;

   // --- System BUS communication ---
   logic                     sw_counter_ram_id;
   logic                     sw_counter_ram_read_in_progress;
   logic [12-1:0]            sw_counter_ram_addr;
   logic [18-1:0]            sw_counter_ram_rdata [num_counters-1:0];
   logic [18-1:0]            sw_counter_ram_wdata [num_counters-1:0];
   logic                     sw_counter_ram_write_enable [num_counters-1:0];

   // Generate counting modules
   generate
      for (genvar i = 0; i < num_counters; i++) begin
         // Counter
         input_counter input_counter_inst (
           .i_signal(inputs[i]),
           .i_clk(i_clk),
           .i_gate(gate_signal),
           .i_reset(counters_reset[i]),
           .o_count(counters_current_count[i])
         );
         // Counter RAM
         counter_sram  #(
           .ADDR_WIDTH(12), .DATA_WIDTH(18), .DEPTH(4096)
         ) counter_sram_inst (
           .i_clk(i_clk),
           .i_addr_a(cnt_counter_ram_addr),
           .i_write_enable_a(cnt_counter_ram_write_enable[i]),
           .i_data_a(cnt_counter_ram_wdata[i]),
           .o_data_a(cnt_counter_ram_rdata[i]),
           .i_addr_b(sw_counter_ram_addr),
           .i_write_enable_b(sw_counter_ram_write_enable[i]),
           .i_data_b(sw_counter_ram_wdata[i]),
           .o_data_b(sw_counter_ram_rdata[i])
         );
      end
   endgenerate

   // ------ IMPLEMENTATION ------

   // --- Trigger logic ---
   assign trigger_signal = !(!((inputs ^ trigger_invert) & trigger_mask)) == trigger_polarity ?
                           '1 : '0;
   assign gate_signal = (counter_gating_activated ||
                  counter_state == gatedCounting_waitForGateRise ||
                  counter_state == gatedCounting_waitForGateFall) ?
                 trigger_signal : '1;

   // --- Counter state machine ---
   always_ff @(posedge i_clk) begin
      if (~i_rstn) begin
         counter_state <= idle;
         control_command_ack <= 1'b0;
         counting_stopped <= 1'b1;
         counter_clock <= 32'b0;
         counters_current_count <= {num_counters{32'b0}};
         counters_last_count <= {num_counters{32'b0}};
         counters_reset <= {num_counters{1'b1}};
         bin_repetition_index <= 16'h0;
         cnt_counter_ram_addr <= 12'h0;
         cnt_counter_ram_write_enable <= {num_counters{1'b0}};
      end else begin
         counter_state_buf = counter_state;
         if (control_command_signal) begin
            control_command_ack <= 1'b1;
            casez (control_command)
              gotoIdle: counter_state_buf = idle;
              reset: begin
                 bin_repetition_index <= 16'h0;
                 cnt_counter_ram_addr <= 12'h0;
                 counters_last_count <= {num_counters{32'b0}};
                 counter_state_buf = idle;
              end
              countImmediately: counter_state_buf = immediateCounting_start;
              countTriggered: counter_state_buf = triggeredCounting_waitForTrigger;
              countGated: counter_state_buf = gatedCounting_waitForGateRise;
              trigger: if (counter_state_buf == triggeredCounting_waitForTrigger) begin
                 counter_state_buf = triggeredCounting_waitForTimeout;
              end
            endcase // casez (control_command)
         end // if (control_command_signal)
         casez (counter_state_buf)
           idle: begin
              counting_stopped <= 1'b1;
              counters_reset <= {num_counters{1'b1}};
              cnt_counter_ram_write_enable <= {num_counters{1'b0}};
           end
           immediateCounting_start: begin
              counter_clock = counter_timeout;
              counting_stopped <= 1'b0;
              counters_reset <= {num_counters{1'b0}};
              counter_state_buf = immediateCounting_waitForTimeout;
           end
           immediateCounting_waitForTimeout: begin
              if (~counter_clock) begin
                 counting_stopped <= 1'b1;
                 counters_last_count <= counters_current_count;
                 counters_reset <= {num_counters{1'b1}};
                 counter_state_buf = idle;
              end else begin
                 counter_clock <= counter_clock - 1;
              end
           end
           triggeredCounting_waitForTrigger: begin
              if (trigger_signal) begin
                 if (counter_predelay != 0) begin
                    counter_clock = counter_predelay;
                    counter_state_buf = triggeredCounting_predelay;
                 end else begin
                    counter_clock = counter_timeout;
                    counting_stopped <= 1'b0;
                    counters_reset <= {num_counters{1'b0}};
                    counter_state_buf = triggeredCounting_waitForTimeout;
                 end
              end // if (trigger_signal)
           end // case: triggeredCounting_waitForTrigger
           triggeredCounting_waitForPredelay: begin
              if (counter_clock == 0) begin
                 counter_clock = counter_timeout;
                 counting_stopped <= 1'b0;
                 counters_reset <= {num_counters{1'b0}};
                 counter_state_buf = triggeredCounting_waitForTimeout;
              end else begin
                 counter_clock <= counter_clock - 1;
              end
           end
           triggeredCounting_waitForTimeout: begin
              if (counter_clock == 0) begin
                 counting_stopped <= 1'b1;
                 counters_last_count <= counters_current_count;
                 counters_reset <= {num_counters{1'b1}};
                 counter_state_buf = triggeredCounting_prestore;
              end else begin
                 counter_clock <= counter_clock - 1;
              end
           end
           gatedCounting_waitForGateRise: begin
              if (gate_signal) begin
                 counting_stopped <= 1'b0;
                 counters_reset <= {num_counters{1'b0}};
                 counter_state_buf = gatedCounting_waitForGateFall;
              end
           end
           gatedCounting_waitForGateFall: begin
              if (~gate_signal) begin
                 counting_stopped <= 1'b1;
                 counters_last_count <= counters_current_count;
                 counters_reset <= {num_counters{1'b1}};
              end
              counter_state_buf = gatedCounting_prestore;
           end
           triggeredCounting_prestore, gatedCounting_prestore: begin
              for (int i = 0; i < num_counters; i++)
                cnt_counter_ram_wdata[i] <= cnt_counter_ram_rdata[i] + counter_last_count[i][18-1:0];
              cnt_counter_ram_write_enable <= {num_counters{1'b1}};
              counter_state_buf = (counter_state_buffer == triggeredCounting_prestore) ?
                                  triggeredCounting_store :
                                  gatedCounting_store;
           end
           triggeredCounting_store, gatedCounting_store: begin
              cnt_counter_ram_write_enable <= {num_counters{1'b0}};
              if (bin_repetition_index == counter_number_of_bin_repetitions) begin
                 bin_repetition_index <= 16'h0;
                 if (cnt_counter_ram_addr == (counter_number_of_bins_in_use - 1))
                   cnt_counter_ram_addr <= 12'h0;
                 else
                   cnt_counter_ram_addr <= cnt_counter_ram_addr + 1;
              end else begin
                 bin_repetition_index <= bin_repetition_index + 1;
              end
              counter_state_buf = (counter_state_buffer == triggeredCounting_store) ?
                                  triggeredCounting_waitForTrigger :
                                  gatedCounting_waitForGateRise;
           end // case: triggeredCounting_store, gatedCounting_store
         endcase // casez (counter_state_buf)

         counter_state <= counter_state_buf;
      end
   end

   // --- System Bus write ---
   always_ff @(posedge i_clk) begin
      if (control_command_ack) begin
         control_command <= none;
         control_command_signal <= 1'b0;
      end
      sw_counter_ram_write_enable <= {1'b0, 1'b0};

      if (~i_rstn) begin
         control_command <= none;
         counter_timeout <= 32'd125; // 1µs default timeout
         counter_number_of_bins_in_use <= 12'h1000;
         counter_number_of_bin_repetitions <= 16'h0;
         counter_predelay <= 32'h0;
      end else if (sys_wen) begin
         if(sys_addr[19:16] == 4'b0) begin
            if (sys_addr[15:0] == 16'h0) begin
               casez (sys_wdata)
                 32'h0: control_command <= none;
                 32'h1: control_command <= gotoIdle;
                 32'h2: control_command <= reset;
                 32'h3: control_command <= countImmediately;
                 32'h4: control_command <= countTriggered;
                 32'h5: control_command <= countGated;
                 32'h6: control_command <= trigger;
                 default: control_command <= none;
               endcase // unique case (sys_wdata)
               control_command_signal <= 1'b1;
            end // if (sys_addr[15:0] == 16'h0)
            if (sys_addr[15:0] == 16'h4) counter_timeout <= sys_wdata;
            if (sys_addr[15:0] == 16'h10) counter_number_of_bins_in_use <= sys_wdata[12-1:0];
            if (sys_addr[15:0] == 16'h14) counter_number_of_bin_repetitions <= sys_wdata[16-1:0];
            if (sys_addr[15:0] == 16'h18) counter_predelay <= sys_wdata;
            if (sys_addr[15:0] == 16'h1C) begin
               trigger_mask <= sys_wdata[8-1:0];
               trigger_invert <= sys_wdata[16-1:8];
               trigger_polarity <= sys_wdata[16];
               //counter_split_bins <= sys_wdata[17];
               counter_gating_activated <= sys_wdata[18];
            end
            if (sys_addr[15:0] == 16'h30) debug_mode <= sys_wdata[0];
         end else if (sys_addr[15] == 1'b0) begin // if (sys_addr[19:16] == 4'b0)
            sw_counter_ram_wdata[sys_addr[14]] <= sys_wdata[18-1:0];
            sw_counter_ram_write_enable[sys_addr[14]] <= 1'b1;
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
         sw_counter_ram_read_in_progress <= 1'b0;
      end else begin
         if (sw_counter_ram_read_in_progress) begin
            sys_ack <= sys_en;
            sys_rdata <= {24{1'b0}, sw_counter_ram_rdata[sw_counter_ram_id]};
            sw_counter_ram_read_in_progress <= 1'b0;
         end

         sys_err <= 1'b0;
         if (sys_addr[19:16] == 4'b0) begin
            casez (sys_addr[19:0])
              20'h0000: begin
                 sys_ack <= sys_en;
                 case (counter_state)
                   idle:
                     sys_rdata_buf <= 32'h00;
                   immediateCounting_start:
                     sys_rdata_buf <= 32'h1;
                   immediateCounting_waitForTimeout:
                     sys_rdata_buf <= 32'h2;
                   triggeredCounting_waitForTrigger:
                     sys_rdata_buf <= 32'h3;
                   triggeredCounting_store:
                     sys_rdata_buf <= 32'h4;
                   triggeredCounting_predelay:
                     sys_rdata_buf <= 32'h5;
                   triggeredCounting_prestore:
                     sys_rdata_buf <= 32'h6;
                   triggeredCounting_waitForTimeout:
                     sys_rdata_buf <= 32'h7;
                   gatedCounting_waitForGateRise:
                     sys_rdata_buf <= 32'h8;
                   gatedCounting_waitForGateFall:
                     sys_rdata_buf <= 32'h9;
                   gatedCounting_prestore:
                     sys_rdata_buf <= 32'hA;
                   gatedCounting_store:
                     sys_rdata_buf <= 32'hB;
                 endcase // case (counter_state)
              end // case: 20'h0000
              20'h0004: begin sys_ack <= sys_en; sys_rdata <= counter_timeout; end
              20'h0008: begin sys_ack <= sys_en; sys_rdata <= counters_last_count[0]; end
              20'h000C: begin sys_ack <= sys_en; sys_rdata <= counters_last_count[1]; end
              20'h0010: begin sys_ack <= sys_en; sys_rdata <= {20{1'b0}, counter_number_of_bins_in_use}; end
              20'h0014: begin sys_ack <= sys_en; sys_rdata <= {16{1'b0}, counter_number_of_bin_repetitions}; end
              20'h0018: begin sys_ack <= sys_en; sys_rdata <= counter_predelay; end
              20'h001C: begin sys_ack <= sys_en;
                 sys_rdata <= {14'b0,
                               counter_gating_activated,
                               //counter_split_bins,
                               1'b0,
                               trigger_polarity,
                               trigger_invert,
                               trigger_mask};
              end
              20'h0020: begin sys_ack <= sys_en; sys_rdata <= {20{1'b0}, cnt_counter_ram_addr}; end
              20'h0024: begin sys_ack <= sys_en; sys_rdata <= {16{1'b0}, bin_repetition_index}; end
              20'h0028: begin sys_ack <= sys_en; sys_rdata <= DNA; end
              20'h002C: begin sys_ack <= sys_en; sys_rdata <= debug_clock; end
              20'h0030: begin sys_ack <= sys_en; sys_rdata <= debug_mode; end
              default: begin sys_ack <= sys_en; sys_rdata <= 32'h0; end
            endcase // casez (sys_addr[19:0])
         end else if (sys_addr[15] == 1'b0) begin // if (sys_addr[16] == 1'b0)
            // RAM request: Counter RAM is mapped to offset 0x10000 (CH1) 0x14000 (CH2)
            sw_counter_ram_addr <= sys_addr[13:2];
            sw_counter_ram_id <= sys_addr[14];
            sw_counter_ram_read_in_progress <= 1'b1;
         end else begin // if (sys_addr[15] == 1'b0)
            sys_ack <= sys_en;
            sys_rdata <= 32'h0;
         end
      end // else: !if(~i_rstn)
   end // always @ (posedge i_clk)



endmodule
