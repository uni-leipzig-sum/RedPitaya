
#include "io.h"

name_to_id_map_t Apins[] = {
  {"AOUT0", 0},
  {"AOUT1", 1},
  {"AOUT2", 2},
  {"AOUT3", 3},
  {"AIN0", 4},
  {"AIN1", 5},
  {"AIN2", 6},
  {"AIN3", 7},
  NAME_TO_ID_MAP_END
};

name_to_id_map_t Dpins[] = {
  {"LED0",    0},
  {"LED1",    1},
  {"LED2",    2},
  {"LED3",    3},
  {"LED4",    4},
  {"LED5",    5},
  {"LED6",    6},
  {"LED7",    7},
  {"DIO0_P",  8},
  {"DIO1_P",  9},
  {"DIO2_P",  10},
  {"DIO3_P",  11},
  {"DIO4_P",  12},
  {"DIO5_P",  13},
  {"DIO6_P",  14},
  {"DIO7_P",  15},
  {"DIO0_N",  16},
  {"DIO1_N",  17},
  {"DIO2_N",  18},
  {"DIO3_N",  19},
  {"DIO4_N",  20},
  {"DIO5_N",  21},
  {"DIO6_N",  22},
  {"DIO7_N",  23},
  NAME_TO_ID_MAP_END
};

name_to_id_map_t DpinDirs[] = {
  {"IN", 0},
  {"OUT", 1},
  NAME_TO_ID_MAP_END
};

static int32_t name_to_id(name_to_id_map_t *map, const char *name)
{
  while(map->name != NULL) {
    if (strcmp(map->name, name) == 0)
      return map->id;
    map++;
  }
  return -1;
}

int Analog_PinReset(int argc, char **argv, char **res, size_t *resLen)
{
  int result = rp_ApinReset();
  if (RP_OK != result) {
    RP_LOG(LOG_ERR, "ANALOG:RST Failed to reset Red "
           "Pitaya analog resources: %s\n" , rp_GetError(result));
    return 1;
  }
  *resLen = 0;
  *res = NULL;
  return 0;
}
int Analog_GetPinValue(int argc, char **argv, char **res, size_t *resLen)
{
  int32_t ipin = -1;
  if (argc < 1 || (ipin = name_to_id(Apins, argv[0])) < 0) {
    RP_LOG(LOG_ERR, "ANALOG:PIN? is missing first parameter.\n");
    return 1;
  }
  rp_apin_t pin = ipin;
  // Get pin value
  float value;
  int result = rp_ApinGetValue(pin, &value);

  if (RP_OK != result) {
    RP_LOG(LOG_ERR, "ANALOG:PIN? Failed to get pin value: %s\n", rp_GetError(result));
    return 1;
  }
  *resLen = safe_sprintf(res, "%g", value);
	if (*resLen < 0) {
		// Error
		RP_LOG(LOG_ERR, "*unknown error.\n");
		*resLen = 0;
		return 1;
	}
  return 0;
}
int Analog_SetPinValue(int argc, char **argv, char **res, size_t *resLen)
{
  int32_t ipin;
  double value;

  RP_LOG(LOG_INFO, "ANALOG:PIN handler called.\n");
  
  if (argc < 1 || (ipin = name_to_id(Apins, argv[0])) < 0) {
    RP_LOG(LOG_ERR, "ANALOG:PIN is missing first parameter.\n");
    return 1;
  }
  if (argc < 2) {
    RP_LOG(LOG_ERR, "ANALOG:PIN is missing second parameter.\n");
    return 1;
  }
  RP_LOG(LOG_INFO, "Value string %s.\n", argv[1]);
  value = atof(argv[1]);
  rp_apin_t pin = ipin;

  // Set pin value
  RP_LOG(LOG_INFO, "Calling API function rp_ApinSetValue (value is %f).\n", value);
  int result = rp_ApinSetValue(pin, (float)value);
  if (RP_OK != result) {
    RP_LOG(LOG_ERR, "ANALOG:PIN Failed to set pin value: %s", rp_GetError(result));
    return 1;
  }
  *resLen = 0;
  *res = NULL;
	return 0;
}

int Digital_PinReset(int argc, char **argv, char **res, size_t *resLen)
{
  int result = rp_DpinReset();

  if (RP_OK != result) {
    RP_LOG(LOG_ERR, "DIG:RST Failed to reset Red Pitaya digital pins: %s", rp_GetError(result));
    return 1;
  }

  *res = NULL;
  *resLen = 0;
  return 0;
}
int Digital_GetPinState(int argc, char **argv, char **res, size_t *resLen)
{
  int32_t ipin;
  if (argc < 1 || (ipin = name_to_id(Dpins, argv[0])) < 0) {
    RP_LOG(LOG_ERR, "DIG:PIN? is missing first parameter.\n");
    return 1;
  }
  rp_dpin_t pin = ipin;

  // get pin state
  rp_pinState_t state;
  int result = rp_DpinGetState(pin, &state);

  if (RP_OK != result) {
    RP_LOG(LOG_ERR, "DIG:PIN? Failed to get pin state: %s", rp_GetError(result));
    return 1;
  }

  *resLen = safe_sprintf(res, "%u", state);
	if (*resLen < 0) {
		// Error
		RP_LOG(LOG_ERR, "*unknown error.\n");
		*resLen = 0;
		return 1;
	}
  return 0;
}
int Digital_SetPinState(int argc, char **argv, char **res, size_t *resLen)
{
  int32_t ipin;
  uint32_t state;

  if (argc < 1 || (ipin = name_to_id(Dpins, argv[0])) < 0) {
    RP_LOG(LOG_ERR, "DIG:PIN is missing first parameter.\n");
    return 1;
  }
  if (argc < 2) {
    RP_LOG(LOG_ERR, "DIG:PIN is missing second parameter.\n");
    return 1;
  }
  state = (uint32_t)atoi(argv[1]);
  rp_dpin_t pin = ipin;

  // set pin state
  int result = rp_DpinSetState(pin, state);

  if (RP_OK != result) {
    RP_LOG(LOG_ERR, "DIG:PIN Failed to set pin state: %s", rp_GetError(result));
    return 1;
  }

  *res = NULL;
  *resLen = 0;
  return 0;
}
int Digital_GetPinDirection(int argc, char **argv, char **res, size_t *resLen)
{
  int32_t ipin;
  if (argc < 1 || (ipin = name_to_id(Dpins, argv[0])) < 0) {
    RP_LOG(LOG_ERR, "DIG:PIN:DIR? is missing first parameter.\n");
    return 1;
  }
  rp_dpin_t pin = ipin;

  // get pin direction
  rp_pinDirection_t direction;
  int result = rp_DpinGetDirection(pin, &direction);

  if (RP_OK != result) {
    RP_LOG(LOG_ERR, "DIG:PIN:DIR? Failed to get pin direction: %s", rp_GetError(result));
    return 1;
  }

  const char *dir_s = DpinDirs[direction].name;

  *resLen = safe_sprintf(res, "%s", dir_s);
	if (*resLen < 0) {
		// Error
		RP_LOG(LOG_ERR, "*unknown error.\n");
		*resLen = 0;
		return 1;
	}
  return 0;
}
int Digital_SetPinDirection(int argc, char **argv, char **res, size_t *resLen)
{
  int32_t ipin;
  if (argc < 1 || (ipin = name_to_id(Dpins, argv[0])) < 0) {
    RP_LOG(LOG_ERR, "DIG:PIN:DIR is missing first parameter.\n");
    return 1;
  }
  if (argc < 2) {
    RP_LOG(LOG_ERR, "DIG:PIN:DIR is missing second parameter.\n");
    return 1;
  }
  rp_dpin_t pin = ipin;
  rp_pinDirection_t direction = name_to_id(DpinDirs, argv[1]);

  // set pin direction
  int result = rp_DpinSetDirection(pin, direction);

  if (RP_OK != result) {
    RP_LOG(LOG_ERR, "DIG:PIN:DIR Failed to set pin direction: %s", rp_GetError(result));
    return 1;
  }

  *res = NULL;
  *resLen = 0;
  return 0;
}
