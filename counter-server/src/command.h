#ifndef COMMAND_H
#define COMMAND_H

#include "common.h"

typedef int (*cmd_handler_t)(int argc, char **argv, char **res, size_t *resLen);

typedef struct {
  const char *cmd;
  cmd_handler_t handler;
} command_map_t;

typedef struct {
  command_map_t *cmdlist;
} counter_context_t;

#define COMMAND_MAP_END {NULL, NULL}

extern counter_context_t counter_context;

#endif /*COMMAND_H*/
