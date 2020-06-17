#ifndef IO_H
#define IO_H

#include "common.h"

typedef struct {
  const char *name;
  int32_t id;
} name_to_id_map_t;

#define NAME_TO_ID_MAP_END {NULL, 0}

int Analog_PinReset(int argc, char **argv, char **res, size_t *resLen);
int Analog_GetPinValue(int argc, char **argv, char **res, size_t *resLen);
int Analog_SetPinValue(int argc, char **argv, char **res, size_t *resLen);

int Digital_PinReset(int argc, char **argv, char **res, size_t *resLen);
int Digital_GetPinState(int argc, char **argv, char **res, size_t *resLen);
int Digital_SetPinState(int argc, char **argv, char **res, size_t *resLen);
int Digital_GetPinDirection(int argc, char **argv, char **res, size_t *resLen);
int Digital_SetPinDirection(int argc, char **argv, char **res, size_t *resLen);

#endif /* IO_H */
