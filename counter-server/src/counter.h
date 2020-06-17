
#ifndef COUNTER_H
#define COUNTER_H

#include "common.h"

#define MAX_BIN_NUMBER 4096

int Counter_SendCmd(int argc, char **argv, char **res, size_t *resLen);
int Counter_GetState(int argc, char **argv, char **res, size_t *resLen);
int Counter_WaitForState(int argc, char **argv, char **res, size_t *resLen);

int Counter_SetNumberOfBins(int argc, char **argv, char **res, size_t *resLen);
int Counter_GetNumberOfBins(int argc, char **argv, char **res, size_t *resLen);

int Counter_SetRepetitions(int argc, char **argv, char **res, size_t *resLen);
int Counter_GetRepetitions(int argc, char **argv, char **res, size_t *resLen);

int Counter_SetPredelay(int argc, char **argv, char **res, size_t *resLen);
int Counter_GetPredelay(int argc, char **argv, char **res, size_t *resLen);
/*triggerMask=Bit Mask:
    1 -> 0001 input channel pin 1
    2 -> 0010 input channel pin 2
	4 -> 0100 input channel pin 3
	8 -> 1000 input channel pin 4
  Invert:
    inverts input if 1
  Polarity (makes only sense for more than one inputs):
    inverts inputs after triggerInvert + "or" over all trigger inputs
*/
int Counter_SetTriggerConfig(int argc, char **argv, char **res, size_t *resLen);
int Counter_GetTriggerConfig(int argc, char **argv, char **res, size_t *resLen);

int Counter_SetBinsSplitted(int argc, char **argv, char **res, size_t *resLen);
int Counter_GetBinsSplitted(int argc, char **argv, char **res, size_t *resLen);

int Counter_SetGatedCounting(int argc, char **argv, char **res, size_t *resLen);
int Counter_GetGatedCounting(int argc, char **argv, char **res, size_t *resLen);

int Counter_GetBinAddress(int argc, char **argv, char **res, size_t *resLen);
int Counter_GetRepetitionCounter(int argc, char **argv, char **res, size_t *resLen);
int Counter_GetBinData(int argc, char **argv, char **res, size_t *resLen);
int Counter_ResetBinDataPartially(int argc, char **argv, char **res, size_t *resLen);
int Counter_ResetBinData(int argc, char **argv, char **res, size_t *resLen);
int Counter_Reset(int argc, char **argv, char **res, size_t *resLen);
int Counter_Count(int argc, char **argv, char **res, size_t *resLen);
int Counter_CountSingle(int argc, char **argv, char **res, size_t *resLen);
int Counter_SetTriggeredCounting(int argc, char **argv, char **res, size_t *resLen);
int Counter_GetTriggeredCounting(int argc, char **argv, char **res, size_t *resLen);
int Counter_Trigger(int argc, char **argv, char **res, size_t *resLen);
int Counter_GetNumCounters(int argc, char **argv, char **res, size_t *resLen);
int Counter_GetMaxBins(int argc, char **argv, char **res, size_t *resLen);
int Counter_GetDNA(int argc, char **argv, char **res, size_t *resLen);
int Counter_GetClock(int argc, char **argv, char **res, size_t *resLen);
int Counter_GetCountingTime(int argc, char **argv, char **res, size_t *resLen);
int Counter_SetCountingTime(int argc, char **argv, char **res, size_t *resLen);
int Counter_Count(int argc, char **argv, char **res, size_t *resLen);
int Counter_WaitAndReadAndStartCounting(int argc, char **argv, char **res, size_t *resLen);

/* Not implemented! */
int Counter_AnalogOutput(int argc, char **argv, char **res, size_t *resLen);

/* For debugging purposes only! */
int Counter_ReadMemory(int argc, char **argv, char **res, size_t *resLen);

#endif /* COUNTER_H */
