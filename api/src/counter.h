/**
 * $Id: $
 *
 * @brief Red Pitaya library counter module interface
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

#ifndef SRC_COUNTER_H_
#define SRC_COUNTER_H_

#include <stdint.h>
#include <stdbool.h>

// Base counter address
static const int COUNTER_BASE_ADDR = 0x00300000;
static const int COUNTER_BASE_SIZE = 0x00100000;

static const int COUNTER_CLOCK_FREQUENCY = 125000000;
static const int COUNTER_BINS = 4096;
//static const int COUNTER_NUM_COUNTERS = 2;
#define COUNTER_NUM_COUNTERS 2
static const int COUNTER_BINS_CH1_OFFSET = 0x00010000;
static const int COUNTER_BINS_CH2_OFFSET = 0x00014000;
static const int DURATION_BINS_OFFSET = 0x00018000;
static const int COUNTER_BINS_BYTE_SIZE = 4;

static const int COUNTER_REG_CONTROL_OFFSET		= 0x0000;
static const int COUNTER_REG_TIMEOUT_OFFSET		= 0x0004;
static const int COUNTER_REG_COUNTS_CH1_OFFSET	= 0x0008;	// read-only
static const int COUNTER_REG_COUNTS_CH2_OFFSET	= 0x000C;	// read-only
static const int COUNTER_REG_NUMBINS_OFFSET		= 0x0010;
static const int COUNTER_REG_REPETITIONS_OFFSET	= 0x0014;
static const int COUNTER_REG_PREDELAY_OFFSET	= 0x0018;
static const int COUNTER_REG_CONFIG_OFFSET		= 0x001C;
static const int COUNTER_REG_ADDRESS_OFFSET		= 0x0020;		// read-only
static const int COUNTER_REG_REPETITION_OFFSET	= 0x0024;			// read-only
static const int COUNTER_REG_DEBUG_MODE_OFFSET = 0x0030;
static const int COUNTER_REG_DURATION_OFFSET = 0x0034;

static const int COUNTER_REG_CONTROL_MASK		= 0x0000000F;
static const int COUNTER_REG_TIMEOUT_MASK		= 0xFFFFFFFF;
static const int COUNTER_REG_COUNTS_MASK		= 0xFFFFFFFF;
static const int COUNTER_REG_NUMBINS_MASK		= 0x00000FFF;
static const int COUNTER_REG_REPETITIONS_MASK	= 0x0000FFFF;
static const int COUNTER_REG_PREDELAY_MASK		= 0xFFFFFFFF;
static const int COUNTER_REG_CONFIG_MASK		= 0x00070F0F;
static const int COUNTER_REG_ADDRESS_MASK		= 0x00001FFF;
static const int COUNTER_REG_REPETITION_MASK	= 0x0000FFFF;
static const int COUNTER_REG_DNA_MASK			= 0xFFFFFFFF;
static const int COUNTER_REG_CLOCK_MASK			= 0xFFFFFFFF;
static const int COUNTER_REG_DEBUG_MODE_MASK = 0x00000001;
static const int COUNTER_REG_DURATION_MASK		= 0xFFFFFFFF;

static const int COUNTER_CONFIG_TRIGGER_MASK_MASK			= 0x0000000F;
static const int COUNTER_CONFIG_TRIGGER_MASK_BIT_OFFSET		= 0;
static const int COUNTER_CONFIG_TRIGGER_INVERT_MASK			= 0x00000F00;
static const int COUNTER_CONFIG_TRIGGER_INVERT_BIT_OFFSET	= 8;
static const int COUNTER_CONFIG_TRIGGER_POLARITY_MASK		= 0x00010000;
static const int COUNTER_CONFIG_TRIGGER_POLARITY_BIT_OFFSET	= 16;
static const int COUNTER_CONFIG_SPLIT_BINS_MASK				= 0x00020000;
static const int COUNTER_CONFIG_SPLIT_BINS_BIT_OFFSET		= 17;
static const int COUNTER_CONFIG_GATED_COUNTING_MASK			= 0x00040000;
static const int COUNTER_CONFIG_GATED_COUNTING_BIT_OFFSET	= 18;

typedef struct counter_control_s {
	uint32_t control;
	uint32_t timeout;
	uint32_t counts[COUNTER_NUM_COUNTERS];		// read-only
	uint32_t numberOfBins;
	uint32_t repetitions;
	uint32_t predelay;
	uint32_t config;
	uint32_t address;							// read-only
	uint32_t repetition;					// read-only
	uint32_t dna;								  // read-only
	uint32_t clock;								// read-only
  uint32_t debug_mode;
  uint32_t duration;            // read-only
} counter_control_t;

typedef enum {
	none = 0, gotoIdle, reset,
	countImmediately, countTriggered, countGated, trigger
} counter_control_cmd;

typedef enum {
	idle = 0,
  immediateCounting_start,
	immediateCounting_waitForTimeout,
	triggeredCounting_waitForTrigger,
	triggeredCounting_store,
	triggeredCounting_predelay,
	triggeredCounting_prestore,
	triggeredCounting_waitForTimeout,
  gatedCounting_waitForGateRise,
  gatedCounting_waitForGateFall,
  gatedCounting_prestore,
  gatedCounting_store
} counter_control_state;

int counter_Init();
int counter_Release();

int counter_SendCmd(counter_control_cmd cmd);
int counter_GetState(counter_control_state *state);
int counter_SetCountingTime(uint32_t time);
int counter_GetCountingTime(uint32_t *time);
int counter_GetCounts(double buffer[COUNTER_NUM_COUNTERS]);
int counter_SetNumberOfBins(uint32_t numBins);
int counter_GetNumberOfBins(uint32_t *numBins);
int counter_SetRepetitions(uint32_t repetitions);
int counter_GetRepetitions(uint32_t *repetitions);
int counter_SetPredelay(uint32_t predelay);
int counter_GetPredelay(uint32_t *predelay);
int counter_SetTriggerMask(uint32_t triggerMask);
int counter_GetTriggerMask(uint32_t *triggerMask);
int counter_SetTriggerInvertMask(uint32_t triggerInvertMask);
int counter_GetTriggerInvertMask(uint32_t *triggerInvertMask);
int counter_SetTriggerPolarity(bool triggerPolarityInverted);
int counter_GetTriggerPolarity(bool *triggerPolarityInverted);
int counter_SetBinsSplitted(bool binsSplitted);
int counter_GetBinsSplitted(bool *binsSplitted);
int counter_SetTriggeredCounting(bool enabled);
int counter_GetTriggeredCounting(bool *enabled);
int counter_Trigger();
int counter_SetGatedCounting(bool enabled);
int counter_GetGatedCounting(bool *enabled);
int counter_SetGating(bool enabled);
int counter_GetGating(bool *enabled);
int counter_GetBinAddress(uint32_t *binAddress);
int counter_GetRepetitionCounter(uint32_t *repetitionCounter);
int counter_GetBinData(double *buffers[COUNTER_NUM_COUNTERS], uint32_t numBins);
int counter_ResetBinDataPartially(uint32_t numBins);
int counter_ResetBinData();
int counter_CountSingle(double counts[COUNTER_NUM_COUNTERS]);
int counter_Count(double *counts[COUNTER_NUM_COUNTERS], uint32_t numCounts);
int counter_Reset();
int counter_GetDNA(uint32_t *dna);
int counter_GetClock(uint32_t *clock);
int counter_WaitForState(counter_control_state state);
int counter_WaitAndReadAndStartCounting(double counts[COUNTER_NUM_COUNTERS]);

int counter_ReadMemory(uint32_t addr, uint32_t *result);
int counter_SetDebugMode(bool enabled);
int counter_GetDebugMode(bool *enabled);

#endif
