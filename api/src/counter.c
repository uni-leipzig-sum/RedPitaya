/**
 * $Id: $
 *
 * @brief Red Pitaya library counter module implementation
 *
 * @Author Roger John, roger.john@uni-leipzig.de
 * @Author Lukas Botsch, lukas.botsch@uni-leipzig.de
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in C programming language.
 * Please visit http://en.wikipedia.org/wiki/C_(programming_language)
 * for more details on the language used herein.
 */

#include "common.h"
#include "counter.h"

static volatile counter_control_t *counter_reg = NULL;
static volatile uint32_t *counter_bin_data[COUNTER_NUM_COUNTERS];
static volatile uint32_t *duration_bin_data;

int counter_Init() {
	ECHECK(cmn_Map(COUNTER_BASE_SIZE, COUNTER_BASE_ADDR, (void** )&counter_reg));
	counter_bin_data[0] = (uint32_t*) ((void*) counter_reg + COUNTER_BINS_CH1_OFFSET);
	counter_bin_data[1] = (uint32_t*) ((void*) counter_reg + COUNTER_BINS_CH2_OFFSET);
  duration_bin_data = (uint32_t*) ((void*) counter_reg + DURATION_BINS_OFFSET);
	return RP_OK;
}

int counter_Release() {
	ECHECK(cmn_Unmap(COUNTER_BASE_SIZE, (void** )&counter_reg));
	counter_bin_data[0] = NULL;
	counter_bin_data[1] = NULL;
	return RP_OK;
}

int counter_SendCmd(counter_control_cmd cmd) {
	return cmn_SetValue(&counter_reg->control, cmd, COUNTER_REG_CONTROL_MASK);
}
int counter_GetState(counter_control_state *state) {
	return cmn_GetValue(&counter_reg->control, state, COUNTER_REG_CONTROL_MASK);
}
int counter_SetCountingTime(uint32_t time) {
	return cmn_SetValue(&counter_reg->timeout, time, COUNTER_REG_TIMEOUT_MASK);
}
int counter_GetCountingTime(uint32_t *time) {
	return cmn_GetValue(&counter_reg->timeout, time, COUNTER_REG_TIMEOUT_MASK);
}
int counter_GetCounts(double buffer[COUNTER_NUM_COUNTERS]) {
	int r = RP_OK;

  uint32_t duration;
  r = cmn_GetValue(&counter_reg->duration, &duration,
                   COUNTER_REG_DURATION_MASK);
  if (r != RP_OK) return r;
  // Don't divide by 0
  if (duration == 0) {
    for (int i = 0; i < COUNTER_NUM_COUNTERS; i++) buffer[i] = 0.0;
    return r;
  }

  for (int i = 0; i < COUNTER_NUM_COUNTERS; i++) {
    uint32_t counts;
		r = cmn_GetValue(&counter_reg->counts[i], &counts,
				COUNTER_REG_COUNTS_MASK);
    if (r != RP_OK)
			break;
    buffer[i] = (double)counts/((double)duration)*(double)COUNTER_CLOCK_FREQUENCY;
	}
	return r;
}
int counter_SetNumberOfBins(uint32_t numBins) {
        if (numBins < 1) numBins = 0;
        else if (numBins > COUNTER_BINS) numBins = COUNTER_BINS-1;
        else numBins--;
	return cmn_SetValue(&counter_reg->numberOfBins, numBins,
			COUNTER_REG_NUMBINS_MASK);
}
int counter_GetNumberOfBins(uint32_t *numBins) {
        int res = cmn_GetValue(&counter_reg->numberOfBins, numBins,
			       COUNTER_REG_NUMBINS_MASK);
        (*numBins)++;
        return res;
}
int counter_SetRepetitions(uint32_t repetitions) {
	return cmn_SetValue(&counter_reg->repetitions, repetitions,
			COUNTER_REG_REPETITIONS_MASK);
}
int counter_GetRepetitions(uint32_t *repetitions) {
	return cmn_GetValue(&counter_reg->repetitions, repetitions,
			COUNTER_REG_REPETITIONS_MASK);
}
int counter_SetPredelay(uint32_t predelay) {
	return cmn_SetValue(&counter_reg->predelay, predelay,
			COUNTER_REG_PREDELAY_MASK);
}
int counter_GetPredelay(uint32_t *predelay) {
	return cmn_GetValue(&counter_reg->predelay, predelay,
			COUNTER_REG_PREDELAY_MASK);
}
int counter_SetTriggerMask(uint32_t triggerMask) {
	return cmn_SetShiftedValue(&counter_reg->config, triggerMask,
			COUNTER_CONFIG_TRIGGER_MASK_MASK
					>> COUNTER_CONFIG_TRIGGER_MASK_BIT_OFFSET,
			COUNTER_CONFIG_TRIGGER_MASK_BIT_OFFSET);
}
int counter_GetTriggerMask(uint32_t *triggerMask) {
	return cmn_GetShiftedValue(&counter_reg->config, triggerMask,
			COUNTER_CONFIG_TRIGGER_MASK_MASK
					>> COUNTER_CONFIG_TRIGGER_MASK_BIT_OFFSET,
			COUNTER_CONFIG_TRIGGER_MASK_BIT_OFFSET);
}
int counter_SetTriggerInvertMask(uint32_t triggerInvertMask) {
	return cmn_SetShiftedValue(&counter_reg->config, triggerInvertMask,
			COUNTER_CONFIG_TRIGGER_INVERT_MASK
					>> COUNTER_CONFIG_TRIGGER_INVERT_BIT_OFFSET,
			COUNTER_CONFIG_TRIGGER_INVERT_BIT_OFFSET);
}
int counter_GetTriggerInvertMask(uint32_t *triggerInvertMask) {
	return cmn_GetShiftedValue(&counter_reg->config, triggerInvertMask,
			COUNTER_CONFIG_TRIGGER_INVERT_MASK
					>> COUNTER_CONFIG_TRIGGER_INVERT_BIT_OFFSET,
			COUNTER_CONFIG_TRIGGER_INVERT_BIT_OFFSET);
}
int counter_SetTriggerPolarity(bool triggerPolarityInverted) {
	return cmn_SetShiftedValue(&counter_reg->config,
			triggerPolarityInverted ? 1 : 0,
			COUNTER_CONFIG_TRIGGER_POLARITY_MASK
					>> COUNTER_CONFIG_TRIGGER_POLARITY_BIT_OFFSET,
			COUNTER_CONFIG_TRIGGER_POLARITY_BIT_OFFSET);
}
int counter_GetTriggerPolarity(bool *triggerPolarityInverted) {
	return cmn_GetShiftedValue(&counter_reg->config,
			(uint32_t*) triggerPolarityInverted,
			COUNTER_CONFIG_TRIGGER_POLARITY_MASK
					>> COUNTER_CONFIG_TRIGGER_POLARITY_BIT_OFFSET,
			COUNTER_CONFIG_TRIGGER_POLARITY_BIT_OFFSET);
}
int counter_SetBinsSplitted(bool binsSplitted) {
	return cmn_SetShiftedValue(&counter_reg->config, binsSplitted ? 1 : 0,
			COUNTER_CONFIG_SPLIT_BINS_MASK
					>> COUNTER_CONFIG_SPLIT_BINS_BIT_OFFSET,
			COUNTER_CONFIG_SPLIT_BINS_BIT_OFFSET);
}
int counter_GetBinsSplitted(bool *binsSplitted) {
	return cmn_GetShiftedValue(&counter_reg->config, (uint32_t*) binsSplitted,
			COUNTER_CONFIG_SPLIT_BINS_MASK
					>> COUNTER_CONFIG_SPLIT_BINS_BIT_OFFSET,
			COUNTER_CONFIG_SPLIT_BINS_BIT_OFFSET);
}
int counter_SetGating(bool enabled) {
	return cmn_SetShiftedValue(&counter_reg->config, enabled ? 1 : 0,
			COUNTER_CONFIG_GATED_COUNTING_MASK
					>> COUNTER_CONFIG_GATED_COUNTING_BIT_OFFSET,
			COUNTER_CONFIG_GATED_COUNTING_BIT_OFFSET);
}
int counter_GetGating(bool *enabled) {
	return cmn_GetShiftedValue(&counter_reg->config, (uint32_t*) enabled,
			COUNTER_CONFIG_GATED_COUNTING_MASK
					>> COUNTER_CONFIG_GATED_COUNTING_BIT_OFFSET,
			COUNTER_CONFIG_GATED_COUNTING_BIT_OFFSET);
}
int counter_GetBinAddress(uint32_t *binAddress) {
	return cmn_GetValue(&counter_reg->address, binAddress,
			COUNTER_REG_PREDELAY_MASK);
}
int counter_GetRepetitionCounter(uint32_t *repetitionCounter) {
	return cmn_GetValue(&counter_reg->repetition, repetitionCounter,
			COUNTER_REG_PREDELAY_MASK);
}
int counter_GetBinData(
		double *buffers[COUNTER_NUM_COUNTERS], uint32_t numBins) {
	if (numBins > COUNTER_BINS)
		numBins = COUNTER_BINS;
	for (int i = 0; i < COUNTER_NUM_COUNTERS; i++)
		for(int j = 0; j < numBins; j++) {
      double duration = (double)duration_bin_data[j]/(double)COUNTER_CLOCK_FREQUENCY;
      if (duration == 0.0)
        buffers[i][j] = 0.0;
      else
        buffers[i][j] = (double)counter_bin_data[i][j]/duration;
    }
	return RP_OK;
}
int counter_ResetBinDataPartially(uint32_t numBins) {
	if (numBins > COUNTER_BINS)
		numBins = COUNTER_BINS;
	for (int i = 0; i < COUNTER_NUM_COUNTERS; i++)
		for (int j = 0; j < numBins; j++) {
			counter_bin_data[i][j] = 0;
      if (i == 0) duration_bin_data[j] = 0;
    }
	return RP_OK;
}
int counter_ResetBinData() {
	return counter_ResetBinDataPartially(COUNTER_BINS);
}
int counter_WaitForState(counter_control_state state) {
	counter_control_state currentState;
	do {
		ECHECK(counter_GetState(&currentState));
	} while (currentState != state);
	return RP_OK;
}
int counter_Reset() {
	ECHECK(counter_SendCmd(reset));
	return counter_WaitForState(idle);
}
int counter_CountSingle(double counts[COUNTER_NUM_COUNTERS]) {
	double *buffer[COUNTER_NUM_COUNTERS];
	for (int i = 0; i < COUNTER_NUM_COUNTERS; i++)
		buffer[i] = &counts[i];
	return counter_Count(buffer, 1);
}
int counter_Count(double *counts[COUNTER_NUM_COUNTERS], uint32_t numCounts) {
	double lastCounts[COUNTER_NUM_COUNTERS];
	for (uint32_t j = 0; j < numCounts; j++) {
		ECHECK(counter_SendCmd(countImmediately));
		ECHECK(counter_WaitForState(idle));
		ECHECK(counter_GetCounts(lastCounts));
		for (int i = 0; i < COUNTER_NUM_COUNTERS; i++)
			counts[i][j] = lastCounts[i];
	}
	return RP_OK;
}
int counter_SetTriggeredCounting(bool enabled) {
	return counter_SendCmd(enabled ? countTriggered : gotoIdle);
}
int counter_GetTriggeredCounting(bool *enabled) {
	counter_control_state state;
	ECHECK(counter_GetState(&state));
	switch (state) {
	case idle:
	case immediateCounting_start:
	case immediateCounting_waitForTimeout:
  case gatedCounting_waitForGateRise:
  case gatedCounting_waitForGateFall:
  case gatedCounting_prestore:
  case gatedCounting_store:
		*enabled = false;
		return RP_OK;
	case triggeredCounting_waitForTrigger:
	case triggeredCounting_store:
	case triggeredCounting_predelay:
	case triggeredCounting_prestore:
	case triggeredCounting_waitForTimeout:
		*enabled = true;
		return RP_OK;
	default:
		return RP_EOOR;
	}
}
int counter_SetGatedCounting(bool enabled) {
	return counter_SendCmd(enabled ? countGated : gotoIdle);
}
int counter_GetGatedCounting(bool *enabled) {
	counter_control_state state;
	ECHECK(counter_GetState(&state));
	switch (state) {
	case idle:
	case immediateCounting_start:
	case immediateCounting_waitForTimeout:
	case triggeredCounting_waitForTrigger:
	case triggeredCounting_store:
	case triggeredCounting_predelay:
	case triggeredCounting_prestore:
	case triggeredCounting_waitForTimeout:
		*enabled = false;
		return RP_OK;
	case gatedCounting_waitForGateRise:
  case gatedCounting_waitForGateFall:
  case gatedCounting_prestore:
  case gatedCounting_store:
    *enabled = true;
		return RP_OK;
	default:
		return RP_EOOR;
	}
}
int counter_Trigger() {
	return counter_SendCmd(trigger);
}
int counter_GetDNA(uint32_t *dna) {
	return cmn_GetValue(&counter_reg->dna, dna, COUNTER_REG_DNA_MASK);
}
int counter_GetClock(uint32_t *clock) {
	return cmn_GetValue(&counter_reg->clock, clock, COUNTER_REG_CLOCK_MASK);
}
int counter_WaitAndReadAndStartCounting(double counts[COUNTER_NUM_COUNTERS]) {
	ECHECK(counter_WaitForState(idle));
	ECHECK(counter_GetCounts(counts));
	return counter_SendCmd(countImmediately);
}

int counter_ReadMemory(uint32_t addr, uint32_t *result) {
	return cmn_GetValue((uint32_t*)(((void*)counter_reg)+addr), result, 0xFFFFFFFFL);
}

int counter_SetDebugMode(bool enabled) {
  return cmn_SetValue(&counter_reg->debug_mode, enabled ? 1 : 0,
                      COUNTER_REG_DEBUG_MODE_MASK);
}
int counter_GetDebugMode(bool *enabled) {
  return cmn_GetValue(&counter_reg->debug_mode, (uint32_t*) enabled,
                      COUNTER_REG_DEBUG_MODE_MASK);
}
