
#include "io.h"
#include "counter.h"
#include "command.h"


static command_map_t counter_commands[] = {
  /* Analog IO */
  /* Reset all analog pins */
  { .cmd = "ANALOG:RST",         .handler = Analog_PinReset},
  /* Get the value of an analog pin in volt.
     Arg1: one of AOUT0, AOUT1, AOUT2, AOUT3, AIN0, AIN1, AIN2, AIN3 */
  { .cmd = "ANALOG:PIN?",        .handler = Analog_GetPinValue},
  /* Set the value of an analog pin in volt.
     Arg1: one of AOUT0, AOUT1, AOUT2, AOUT3, AIN0, AIN1, AIN2, AIN3
     Arg2: the value in volt */
  { .cmd = "ANALOG:PIN",         .handler = Analog_SetPinValue},

  /* Digital IO */
  /* Reset all digital pins */
  { .cmd = "DIG:RST",            .handler = Digital_PinReset},
  /* Get the state of a digital pin.
     Arg1: one of LED0, LED1, LED2, LED3, LED4, LED5, LED6, LED7,
                  DIO0_P, DIO1_P, DIO2_P, DIO3_P, DIO4_P, DIO5_P, DIO6_P, DIO7_P,
                  DIO0_N, DIO1_N, DIO2_N, DIO3_N, DIO4_N, DIO5_N, DIO6_N, DIO7_N */
  { .cmd = "DIG:PIN?",           .handler = Digital_GetPinState},
  { .cmd = "DIG:PIN",            .handler = Digital_SetPinState},
  { .cmd = "DIG:PIN:DIR?",           .handler = Digital_GetPinDirection},
  { .cmd = "DIG:PIN:DIR",            .handler = Digital_SetPinDirection},

  /* Counter */

  // Not Implemented! Use the specific commands instead
  //{ .cmd = "COUNTER:CMD",        .handler = Counter_SendCmd,},
  /* Get the state the counter is currently in.
	 Possible states are:
        "idle"
		"immediateCountingStart"
		"immediateCountingWaitForTimeout"
		"triggeredCountingWaitForTrigger"
		"triggeredCountingStore"
		"triggeredCountingPredelay"
		"triggeredCountingPrestore"
		"triggeredCountingWaitForTimeout"
   */
  { .cmd = "COUNTER:STATE?",      .handler = Counter_GetState,},
  /* Wait for the counter to change into a certain state */
  { .cmd = "COUNTER:WAIT",        .handler = Counter_WaitForState,},
  /* Reset the counter */
  { .cmd = "COUNTER:RESET",       .handler = Counter_Reset,},
  /* Get the number of counter channels */
  { .cmd = "COUNTER:NO?",         .handler = Counter_GetNumCounters,},
  { .cmd = "COUNTER:DNA?",        .handler = Counter_GetDNA,},
  
  { .cmd = "COUNTER:CLOCK?",      .handler = Counter_GetClock,},
  /* Set how often the counter repeats counting */
  { .cmd = "COUNTER:REP",         .handler = Counter_SetRepetitions,},
  /* How often are we repeating counting? */
  { .cmd = "COUNTER:REP?",        .handler = Counter_GetRepetitions,},
  /* Get the current repetition counter */
  { .cmd = "COUNTER:REP:COUNT?",  .handler = Counter_GetRepetitionCounter,},
  /* Set the counter predelay */
  { .cmd = "COUNTER:DELAY",       .handler = Counter_SetPredelay,},
  /* Get the counter predelay */
  { .cmd = "COUNTER:DELAY?",      .handler = Counter_GetPredelay,},
  /* Set wether or not the counter should be gated */
  { .cmd = "COUNTER:GATED",       .handler = Counter_SetGatedCounting,},
  /* Is the counter using gating? */
  { .cmd = "COUNTER:GATED?",      .handler = Counter_GetGatedCounting,},
  /* Set the number of bins the counter is using */
  { .cmd = "COUNTER:BINS:NO",     .handler = Counter_SetNumberOfBins,},
  /* Get the number of bins the counter is using */
  { .cmd = "COUNTER:BINS:NO?",    .handler = Counter_GetNumberOfBins,},
  /* Get current bin address (i.e. the index)*/
  { .cmd = "COUNTER:BINS:ADDR?",  .handler = Counter_GetBinAddress,},
  /* Get max number of bins */
  { .cmd = "COUNTER:BINS:MAX?",   .handler = Counter_GetMaxBins,},
  /* Get the data of the first N bins */
  { .cmd = "COUNTER:BINS:DATA?",  .handler = Counter_GetBinData,},
  /* Set the first N bins to 0 */
  { .cmd = "COUNTER:BINS:RESET",  .handler = Counter_ResetBinDataPartially,},
  /* Set all bins to 0 */
  { .cmd = "COUNTER:BINS:RESET:ALL", .handler = Counter_ResetBinData,},
  /* Set wether or not we split bins? */
  { .cmd = "COUNTER:BINS:SPLIT",  .handler = Counter_SetBinsSplitted,},
  /* Are we splitting bins? */
  { .cmd = "COUNTER:BINS:SPLIT?", .handler = Counter_GetBinsSplitted,},
  /* Set the trigger configuration.
	 Expects triggerMask,triggerInvert,triggerPolarity
	 triggerMask=Bit Mask:
       1 -> 0001 input channel pin 1
	   2 -> 0010 input channel pin 2
	   4 -> 0100 input channel pin 3
	   8 -> 1000 input channel pin 4
	 Invert:
	   inverts input if 1
     Polarity (makes only sense for more than one inputs):
       inverts inputs after triggerInvert + "or" over all trigger inputs
  */
  { .cmd = "COUNTER:TRIG:CONF",   .handler = Counter_SetTriggerConfig,},
  /* Get the trigger configuration.
	 Returns triggerMask,triggerInvert,triggerPolarity
   */
  { .cmd = "COUNTER:TRIG:CONF?",  .handler = Counter_GetTriggerConfig,},
  /* Set counter in triggered mode. */
  { .cmd = "COUNTER:TRIG",        .handler = Counter_SetTriggeredCounting,},
  /* Are we in triggered counting mode? */
  { .cmd = "COUNTER:TRIG?",       .handler = Counter_GetTriggeredCounting,},
  /* Trigger immediately. No args needed */
  { .cmd = "COUNTER:TRIG:IMM",    .handler = Counter_Trigger,},
  /* This returns the currently set counting duration (in seconds). */
  { .cmd = "COUNTER:TIME?",       .handler = Counter_GetCountingTime },
  /* This sets the counting duration. Format: "COUNTER:TIME 0.002" (time in seconds) */
  { .cmd = "COUNTER:TIME",        .handler = Counter_SetCountingTime },
  /* This command waits for any running counting processes to end and starts counting n times.
     Once the fresh counting process ends, it returns the counts.
     Response format: "1,2,3,4,5,...,1,2,3,4,5,..." (List of n counts, one for each APD) */
  { .cmd = "COUNTER:COUNT?",      .handler = Counter_Count },
  /* This command waits for any running counting processes to end and starts counting.
     Once the fresh counting process ends, it returns the counts. This is probably what
     you want most of the time!
     Response format: "700,702" (List of counts, one for each APD) */
  { .cmd = "COUNTER:COUNT:SING?", .handler = Counter_CountSingle,},
  /* Alias for COUNTER:COUNT:SING? for reverse compatibility*/
  { .cmd = "COUNTER:COUNTS?", .handler = Counter_CountSingle,},
  /* WARNING: This might not do what you want.
     This command waits for the current counting process to end, then returns the
     counts and starts counting again. This means, you might get out of date counts.
     Response format: "700,702" (List of counts, one for each APD) */
  { .cmd = "COUNTER:WRSC?",       .handler = Counter_WaitAndReadAndStartCounting },
  /* DEPRECATED! Not implemented anymore. (Was used for the laser diode) */
  { .cmd = "COUNTER:OUTPUT",      .handler = Counter_AnalogOutput,},
  /* Reads from the counter mapped memory. Needs the address as unsigned int as argument. */
  { .cmd = "COUNTER:READMEM?",     .handler = Counter_ReadMemory,},
  COMMAND_MAP_END
};

counter_context_t counter_context = {
  .cmdlist = counter_commands
};
