/**
 * @brief Red Pitaya counter module
 *
 * @author Roger John, roger.john@uni-leipzig.de
 * @author Robert Staacke, robert.staacke@physik.uni-leipzig.de
 * @author Lukas Botsch, lukas.botsch@uni-leipzig.de
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "counter.h"

const char *COUNTER_STATE_NAMES[] = {
	"idle",
	"immediateCountingStart",
	"immediateCountingWaitForTimeout",
	"triggeredCountingWaitForTrigger",
	"triggeredCountingStore",
	"triggeredCountingPredelay",
	"triggeredCountingPrestore",
	"triggeredCountingWaitForTimeout"
};

int Counter_GetState(int argc, char **argv, char **res, size_t *resLen)
{
	*res = NULL;
	*resLen = 0;

	rp_counterState_t state;
    int result = rp_CounterGetState(&state);

	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:STATE? Failed to get current state: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}
	if (!(RP_idle<=state && state<=RP_triggeredCountingWaitForTimeout)) {
		RP_LOG(LOG_ERR, "COUNTER:STATE? Counter is in unknown state: %d.\n", state);
		*resLen = safe_sprintf(res, "ERR: Unknown state %d", state);
		return 1;
	}

	*res = strdup(COUNTER_STATE_NAMES[state]);
	*resLen = strlen(*res);
	return 0;
}

int Counter_WaitForState(int argc, char **argv, char **res, size_t *resLen)
{
	*res = NULL;
	*resLen = 0;

	rp_counterState_t state = -1;
	if (argc < 1) {
		RP_LOG(LOG_ERR, "COUNTER:WAIT is missing first argument.\n");
		*resLen = safe_sprintf(res, "ERR: Specify the state to wait for");
		return 1;
	}
	for (int i = 0; i < sizeof(COUNTER_STATE_NAMES); i++) {
		if (strcmp(COUNTER_STATE_NAMES[i], argv[0]) == 0) {
			state = i;
			break;
		}
	}
	if (state < 0) {
		RP_LOG(LOG_ERR, "COUNTER:WAIT Unknown state to wait for: %s.\n", argv[0]);
		*resLen = safe_sprintf(res, "ERR: Unknown state '%s'", argv[0]);
		return 1;
	}

	// Check if we already are in the right state
	rp_counterState_t curstate;
    int result = rp_CounterGetState(&curstate);
	if (RP_OK != result) {
    	RP_LOG(LOG_ERR, "COUNTER:WAIT Failed to wait for state: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
    }
	if (curstate == state) {
		*resLen = safe_sprintf(res, "OK");
		return 0;
	}
	
	// If not, wait
	result = rp_CounterWaitForState(state);
    if (RP_OK != result) {
    	RP_LOG(LOG_ERR, "COUNTER:WAIT Failed to wait for state: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
    }
	*resLen = safe_sprintf(res, "OK");
	return 0;
}

int Counter_SetNumberOfBins(int argc, char **argv, char **res, size_t *resLen)
{
	*res = NULL;
	*resLen = 0;

	uint32_t numBins;
	if (argc < 1) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:NO is missing first argument.\n");
		*resLen = safe_sprintf(res, "ERR: Specify the number of bins");
		return 1;
	}
	numBins = atoi(argv[0]);
	if (numBins <= 0 || numBins > MAX_BIN_NUMBER) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:NO argument must be 1-%d: It is %s\n", MAX_BIN_NUMBER, argv[0]);
		*resLen = safe_sprintf(res, "ERR: Number of bins out of range: must be 1-%d", MAX_BIN_NUMBER);
		return 1;
	}
	int result = rp_CounterSetNumberOfBins(numBins);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:NO Failed to set number of bins: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}
	*resLen = safe_sprintf(res, "OK");
	return 0;
}

int Counter_GetNumberOfBins(int argc, char **argv, char **res, size_t *resLen)
{
	uint32_t numBins;
	int result = rp_CounterGetNumberOfBins(&numBins);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:NO? Failed to get number of bins: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}

	*resLen = safe_sprintf(res, "%d", numBins);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:NO? Failed to construct response. Out of memory?\n");
		*resLen = safe_sprintf(res, "ERR: OOM?");
		return 1;
	}
	return 0;
}

int Counter_SetRepetitions(int argc, char **argv, char **res, size_t *resLen)
{
	*res = NULL;
	*resLen = 0;

	uint32_t repetitions;
	if (argc < 1) {
		RP_LOG(LOG_ERR, "COUNTER:REP is missing first argument.\n");
		*resLen = safe_sprintf(res, "ERR: Specify number of repetitions");
		return 1;
	}
	repetitions = atoi(argv[0]);
	if (repetitions <= 0) {
		RP_LOG(LOG_ERR, "COUNTER:REP argument must be >= 1: It is %s\n", MAX_BIN_NUMBER, argv[0]);
		*resLen = safe_sprintf(res, "ERR: Number of repetitions must be >= 1");
		return 1;
	}
	int result = rp_CounterSetRepetitions(repetitions);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:REP Failed to set number of repetitions: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}
	*resLen = safe_sprintf(res, "OK");
	return 0;
}

int Counter_GetRepetitions(int argc, char **argv, char **res, size_t *resLen)
{
	uint32_t repetitions;
	int result = rp_CounterGetRepetitions(&repetitions);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:REP? Failed to get number of repetitions: %s.\n", rp_GetError(result));
		*resLen = 0;
		return 1;
	}

	*resLen = safe_sprintf(res, "%d", repetitions);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:REP? Failed to construct response. Out of memory?\n");
		*res = NULL;
		*resLen = 0;
		return 1;
	}
	return 0;
}

int Counter_SetPredelay(int argc, char **argv, char **res, size_t *resLen)
{
	*res = NULL;
	*resLen = 0;

	float predelay;
	if (argc < 1) {
		RP_LOG(LOG_ERR, "COUNTER:DELAY is missing first argument.\n");
		*resLen = safe_sprintf(res, "ERR: Specify the predelay");
		return 1;
	}
	predelay = atof(argv[0]);
	if (predelay < 0.0) {
		RP_LOG(LOG_ERR, "COUNTER:DELAY argument must be >= 0: It is %s\n", argv[0]);
		*resLen = safe_sprintf(res, "ERR: Predelay must be >= 0");
		return 1;
	}
	int result = rp_CounterSetPredelay(predelay);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:DELAY Failed to set predelay: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}
	*resLen = safe_sprintf(res, "OK");
	return 0;
}

int Counter_GetPredelay(int argc, char **argv, char **res, size_t *resLen)
{
	float predelay;
	int result = rp_CounterGetPredelay(&predelay);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:DELAY? Failed to get predelay: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}

	*resLen = safe_sprintf(res, "%g", predelay);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:DELAY? Failed to construct response. Out of memory?\n");
		*resLen = safe_sprintf(res, "ERR: OOM?");
		return 1;
	}
	*resLen = safe_sprintf(res, "OK");
	return 0;
}

int Counter_SetTriggerConfig(int argc, char **argv, char **res, size_t *resLen)
{
	uint32_t triggerMask, triggerInvert;
	bool triggerPolarity;
	if (argc < 3) {
		RP_LOG(LOG_ERR, "COUNTER:TRIG:CONF is missing arguments.\n");
		*resLen = safe_sprintf(res, "ERR: Specify trigger config 'trigMask,trigInvert,trigPolarity");
		return 1;
	}
	triggerMask = atoi(argv[0]);
	triggerInvert = atoi(argv[1]);
	triggerPolarity = (bool)atoi(argv[2]);
	int result = rp_CounterSetTriggerConfig(triggerMask, triggerInvert, triggerPolarity);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:TRIG:CONF Failed to set trigger conf: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}
	*resLen = safe_sprintf(res, "OK");
	return 0;
}

int Counter_GetTriggerConfig(int argc, char **argv, char **res, size_t *resLen)
{
	uint32_t triggerMask, triggerInvert;
	bool triggerPolarity;
	int result = rp_CounterGetTriggerConfig(&triggerMask, &triggerInvert, &triggerPolarity);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:TRIG:CONF? Failed to get trigger conf: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}

	*resLen = safe_sprintf(res, "%d,%d,%d", triggerMask, triggerInvert, triggerPolarity?1:0);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:TRIG:CONF? Failed to construct response. Out of memory?\n");
		*resLen = safe_sprintf(res, "ERR: OOM?");
		return 1;
	}
	return 0;
}

int Counter_SetBinsSplitted(int argc, char **argv, char **res, size_t *resLen)
{
	*res = NULL;
	*resLen = 0;

	bool splitted;
	if (argc < 1) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:SPLIT is missing first argument.\n");
		*resLen = safe_sprintf(res, "ERR: Specify whether to split bins (1 or 0)");
		return 1;
	}
	splitted = (bool)atoi(argv[0]);
	int result = rp_CounterSetBinsSplitted(splitted);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:SPLIT Failed to set bins splitted: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}
	*resLen = safe_sprintf(res, "OK");
	return 0;
}

int Counter_GetBinsSplitted(int argc, char **argv, char **res, size_t *resLen)
{
	bool splitted;
	int result = rp_CounterGetBinsSplitted(&splitted);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:SPLIT? Failed to get bins splitted: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}

	*resLen = safe_sprintf(res, "%d", splitted?1:0);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:REP? Failed to construct response. Out of memory?\n");
		*resLen = safe_sprintf(res, "ERR: OOM?");
		return 1;
	}
	return 0;
}

int Counter_SetGatedCounting(int argc, char **argv, char **res, size_t *resLen)
{
	*res = NULL;
	*resLen = 0;

	bool gatedCounting;
	if (argc < 1) {
		RP_LOG(LOG_ERR, "COUNTER:GATED is missing first argument.\n");
		*resLen = safe_sprintf(res, "ERR: Specify whether to use gating (0 or 1)");
		return 1;
	}
	gatedCounting = (bool)atoi(argv[0]);
	int result = rp_CounterSetGatedCounting(gatedCounting);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:GATED Failed to set gated counting: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}
	*resLen = safe_sprintf(res, "OK");
	return 0;
}

int Counter_GetGatedCounting(int argc, char **argv, char **res, size_t *resLen)
{
	bool gatedCounting;
	int result = rp_CounterGetGatedCounting(&gatedCounting);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:GATED? Failed to get gated counting: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}

	*resLen = safe_sprintf(res, "%d", gatedCounting?1:0);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:GATED? Failed to construct response. Out of memory?\n");
		*resLen = safe_sprintf(res, "ERR: OOM?");
		return 1;
	}
	return 0;
}

int Counter_GetBinAddress(int argc, char **argv, char **res, size_t *resLen)
{
	uint32_t binAddress;
    int result = rp_CounterGetBinAddress(&binAddress);
    if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:ADDR? Failed to get bin address: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}

	*resLen = safe_sprintf(res, "%d", binAddress);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:ADDR? Failed to construct response. Out of memory?\n");
		*resLen = safe_sprintf(res, "ERR: OOM?");
		return 1;
	}
	return 0;
}

int Counter_GetRepetitionCounter(int argc, char **argv, char **res, size_t *resLen)
{
	uint32_t repetitionCounter;
    int result = rp_CounterGetRepetitionCounter(&repetitionCounter);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:REP:COUNT? Failed to get repetition counter: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}

	*resLen = safe_sprintf(res, "%d", repetitionCounter);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:REP? Failed to construct response. Out of memory?\n");
		*resLen = safe_sprintf(res, "ERR: OOM?");
		return 1;
	}
	return 0;
}

int Counter_GetBinData(int argc, char **argv, char **res, size_t *resLen)
{
	int result;
	uint32_t numBins;
    if (argc < 1) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:DATA? is missing first argument.\n");
		*resLen = safe_sprintf(res, "ERR: Specify how many bins to read out.");
		return 1;
	}
	numBins = atoi(argv[0]);
	if (numBins < 1 || numBins > RP_COUNTER_BINS) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:DATA? number of bins out of range: %d (max = %d)\n", numBins, RP_COUNTER_BINS);
		*resLen = safe_sprintf(res, "ERR: Number of bins out of range: 1-%d", RP_COUNTER_BINS);
		return 1;
	}
	uint32_t *binData[RP_COUNTER_NUM_COUNTERS];
    for(int i=0;i<RP_COUNTER_NUM_COUNTERS;i++)
        binData[i] = malloc(sizeof(uint32_t)*numBins);
    result = rp_CounterGetBinData(binData,numBins);
    if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:DATA? Failed to get bin data: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		goto err;
	}

	size_t buflen;
	char *buf = malloc(buflen);
	int written = 0;
	for (int i = 0; i < RP_COUNTER_NUM_COUNTERS; i++) {
		if (i > 0) {
			if (buflen < written + 2) {
				buflen += 1024;
				buf = realloc(buf, buflen);
				if (buf == NULL) goto err;
			}
			buf[written] = ',';
			buf[written+1] = 0;
			written += 1;
		}
		result = join_uints(&buf, &buflen, written, binData[i], numBins);
		if (result < 0) {
			goto err;
		}
		written += result;
	}
	*res = buf;
	*resLen = written;

	return 0;
	
 err:
	for (int i = 0; i < RP_COUNTER_NUM_COUNTERS; i++)
		free(binData[i]);
	if (*res == NULL)
		*resLen = safe_sprintf(res, "ERR: OOM?");
	return 1;
}

int Counter_ResetBinDataPartially(int argc, char **argv, char **res, size_t *resLen)
{
	uint32_t numBins;
    if (argc < 1) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:RESET is missing first argument.\n");
		*resLen = safe_sprintf(res, "ERR: Specify how many bins to reset.");
		return 1;
	}
	numBins = atoi(argv[0]);
	if (numBins > RP_COUNTER_BINS) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:RESET number of bins out of range: %d (max = %d)\n", numBins, RP_COUNTER_BINS);
		*resLen = safe_sprintf(res, "ERR: Number of bins out of range: 1-%d", RP_COUNTER_BINS);
		return 1;
	}
	int result = rp_CounterResetBinDataPartially(numBins);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:RESET Failed to reset bins: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}
	*resLen = safe_sprintf(res, "OK");
	return 0;
}

int Counter_ResetBinData(int argc, char **argv, char **res, size_t *resLen)
{
	*resLen = 0;
	*res = NULL;
	int result = rp_CounterResetBinData();
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:RESET:ALL Failed to reset bins: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}
	*resLen = safe_sprintf(res, "OK");
	return 0;
}

int Counter_Reset(int argc, char **argv, char **res, size_t *resLen)
{
	*resLen = 0;
	*res = NULL;
	int result = rp_CounterReset();
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:RESET Failed to reset: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}
	*resLen = safe_sprintf(res, "OK");
	return 0;
}

int Counter_Count(int argc, char **argv, char **res, size_t *resLen)
{
	uint32_t numCounts;
    if (argc < 1) {
		RP_LOG(LOG_ERR, "COUNTER:COUNT? is missing first argument.\n");
		*resLen = safe_sprintf(res, "ERR: Specify how often to count.");
		return 1;
	}
	numCounts = atoi(argv[0]);
	uint32_t *counts[RP_COUNTER_NUM_COUNTERS];
    for(int i=0;i<RP_COUNTER_NUM_COUNTERS;i++)
        counts[i] = malloc(sizeof(uint32_t)*numCounts);
    int result = rp_CounterCount(counts,numCounts);
    if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:COUNT? Failed to count: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		goto err;
	}

	size_t buflen;
	char *buf = malloc(buflen);
	int written = 0;
	for (int i = 0; i < RP_COUNTER_NUM_COUNTERS; i++) {
		if (i > 0) {
			if (buflen < written + 2) {
				buflen += 1024;
				buf = realloc(buf, buflen);
				if (buf == NULL) goto err;
			}
			buf[written] = ',';
			buf[written+1] = 0;
			written += 1;
		}
		result = join_uints(&buf, &buflen, written, counts[i], numCounts);
		if (result < 0) {
			goto err;
		}
		written += result;
	}
	*res = buf;
	*resLen = written;

	return 0;
	
 err:
	for (int i = 0; i < RP_COUNTER_NUM_COUNTERS; i++)
		free(counts[i]);
	if (*res == NULL)
		*resLen = safe_sprintf(res, "ERR: OOM?");
	return 1;
}

int Counter_CountSingle(int argc, char **argv, char **res, size_t *resLen)
{
	uint32_t counts[RP_COUNTER_NUM_COUNTERS];

	int result = rp_CounterWaitForState(0/* 0 = idle state, see api/rpbase/src/counter.h */);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:COUNT:SING? Failed waiting for idle state: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: Failed waiting for idle: %s", rp_GetError(result));
		return 1;
	}
	result = rp_CounterCountSingle(counts);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:COUNT:SING? Failed counting: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}

	*resLen = join_uints(res, resLen, 0, counts, RP_COUNTER_NUM_COUNTERS);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:COUNT:SING? Failed to construct response. Out of memory?\n");
		*resLen = safe_sprintf(res, "ERR: OOM?");
		return 1;
	}
	
	return 0;
}

int Counter_SetTriggeredCounting(int argc, char **argv, char **res, size_t *resLen)
{
	*res = NULL;
	*resLen = 0;
	bool triggeredCounting;

	if (argc < 1) {
		RP_LOG(LOG_ERR, "COUNTER:TRIG is missing first argument.\n");
		*resLen = safe_sprintf(res, "ERR: Specify whether to use triggered counting (0 or 1)");
		return 1;
	}
	triggeredCounting = (bool)!!atoi(argv[0]);
	
	int result = rp_CounterSetTriggeredCounting(triggeredCounting);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:TRIG Failed to set triggered counting: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}
	*resLen = safe_sprintf(res, "OK");
	return 0;
}

int Counter_GetTriggeredCounting(int argc, char **argv, char **res, size_t *resLen)
{
	bool triggeredCounting;
	int result = rp_CounterGetGatedCounting(&triggeredCounting);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:TRIG? Failed to get triggered counting: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}

	*resLen = safe_sprintf(res, "%d", triggeredCounting?1:0);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:TRIG? Failed to construct response. Out of memory?\n");
		*resLen = safe_sprintf(res, "ERR: OOM?");
		return 1;
	}
	return 0;
}

int Counter_Trigger(int argc, char **argv, char **res, size_t *resLen)
{
	*resLen = 0;
	*res = NULL;
	int result = rp_CounterTrigger();
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:TRIG:IMM Failed to trigger: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}
	*resLen = safe_sprintf(res, "OK");
	return 0;
}

int Counter_GetNumCounters(int argc, char **argv, char **res, size_t *resLen)
{
	*resLen = safe_sprintf(res, "%d", RP_COUNTER_NUM_COUNTERS);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:NO? Failed to construct response. Out of memory?\n");
		*resLen = safe_sprintf(res, "ERR: OOM?");
		return 1;
	}
	return 0;
}

int Counter_GetMaxBins(int argc, char **argv, char **res, size_t *resLen)
{
	*resLen = safe_sprintf(res, "%d", RP_COUNTER_BINS);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:BINS:MAX? Failed to construct response. Out of memory?\n");
		*resLen = safe_sprintf(res, "ERR: OOM?");
		return 1;
	}
	return 0;
}

int Counter_GetDNA(int argc, char **argv, char **res, size_t *resLen)
{
	uint32_t dna;
	int result = rp_CounterGetDNA(&dna);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:DNA? Failed to get DNA: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}

	*resLen = safe_sprintf(res, "%u", dna);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:DNA? Failed to construct response. Out of memory?\n");
		*resLen = safe_sprintf(res, "ERR: OOM?");
		return 1;
	}
	return 0;
}

int Counter_GetClock(int argc, char **argv, char **res, size_t *resLen)
{
	uint32_t clock;
	int result = rp_CounterGetClock(&clock);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:CLOCK? Failed to get clock: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}

	*resLen = safe_sprintf(res, "%u", clock);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:CLOCK? Failed to construct response. Out of memory?\n");
		*resLen = safe_sprintf(res, "ERR: OOM?");
		return 1;
	}
	return 0;
}

int Counter_GetCountingTime(int argc, char **argv, char **res, size_t *resLen)
{
	float countingTime;
	int result = rp_CounterGetCountingTime(&countingTime);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:TIME? Failed to get counting time: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}

	*resLen = safe_sprintf(res, "%g", countingTime);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:TIME? Failed to construct response. Out of memory?\n");
		*resLen = safe_sprintf(res, "ERR: OOM?");
		return 1;
	}
	return 0;
}

int Counter_SetCountingTime(int argc, char **argv, char **res, size_t *resLen)
{
	*res = NULL;
	*resLen = 0;

	float countingTime;
	if (argc < 1) {
		RP_LOG(LOG_ERR, "COUNTER:TIME is missing first argument.\n");
		*resLen = safe_sprintf(res, "ERR: Specify the counting duration.");
		return 1;
	}
	countingTime = atof(argv[0]);
	if (countingTime <= 0.0) {
		RP_LOG(LOG_ERR, "COUNTER:TIME invalid first argument: %s.\n", argv[0]);
		*resLen = safe_sprintf(res, "ERR: Invalid counting duration %f", argv[0]);
		return 1;
	}
	int result = rp_CounterSetCountingTime(countingTime);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:TIME Failed to set counting time: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}
	*resLen = safe_sprintf(res, "OK");
	return 0;
}


int Counter_WaitAndReadAndStartCounting(int argc, char **argv, char **res, size_t *resLen)
{
	uint32_t counts[RP_COUNTER_NUM_COUNTERS];

	int result = rp_CounterWaitAndReadAndStartCounting(counts);
	if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:WRSC? Failed counting: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}

	*resLen = join_uints(res, resLen, 0, counts, RP_COUNTER_NUM_COUNTERS);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:WRSC? Failed to construct response. Out of memory?\n");
		*resLen = safe_sprintf(res, "ERR: OOM?");
		return 1;
	}
	
	return 0;
}

int Counter_AnalogOutput(int argc, char **argv, char **res, size_t *resLen)
{
	//  Not implemented!
	RP_LOG(LOG_ERR, "COUNTER:OUTPUT is not implemented!\n");
	*resLen = safe_sprintf(res, "ERR: This command is deprecated!");
	return 1;
}

int Counter_ReadMemory(int argc, char **argv, char **res, size_t *resLen)
{
	
	uint32_t addr, value;
    if (argc < 1) {
		RP_LOG(LOG_ERR, "COUNTER:READMEM? is missing first argument.\n");
		*resLen = safe_sprintf(res, "ERR: Specify memory address.");
		return 1;
	}
	addr = atoi(argv[0]);
	int result = rp_CounterReadMemory(addr, &value);
    if (RP_OK != result) {
		RP_LOG(LOG_ERR, "COUNTER:READMEM? Failed to read memory: %s.\n", rp_GetError(result));
		*resLen = safe_sprintf(res, "ERR: %s", rp_GetError(result));
		return 1;
	}
	*resLen = safe_sprintf(res, "%u", value);
	if (*resLen < 0) {
		RP_LOG(LOG_ERR, "COUNTER:READMEM? Failed to construct response. Out of memory?\n");
		*resLen = safe_sprintf(res, "ERR: OOM?");
		return 1;
	}
	return 0;

	/*
	//  Not implemented!
	RP_LOG(LOG_ERR, "COUNTER:READMEM is not implemented!\n");
	*resLen = safe_sprintf(res, "ERR: This command is not implemented!");
	return 1;
	*/
}
