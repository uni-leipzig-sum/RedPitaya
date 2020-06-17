#ifndef COMMON_H
#define COMMON_H

#include <stddef.h>
#include <stdint.h>
#include <syslog.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "redpitaya/rp.h"

typedef uint32_t size_t;

// Define debug output to system log if COUNTER_DEBUG is defined in the Makefile
#ifdef COUNTER_DEBUG
#define RP_LOG(...) syslog(__VA_ARGS__);
#else
#define RP_LOG(...)
#endif

int join_uints(char **buf, size_t *bufsize, size_t offset, unsigned int *uints, size_t num_uints);

// Safe implementation of sprintf. buffer will be allocated by the function
// and must be freed by the caller.
int safe_sprintf(char **buf, const char *format, ...);


#endif /* COMMON_H */
