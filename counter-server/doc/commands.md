# SUPPORTED COMMANDS

| Command          | Description                                |
|------------------|--------------------------------------------|
| `ANALOG:RST`     | Resets all analog io pins                  |
| `ANALOG:PIN?`    | Gets the current value of an analog io pin |
| `ANALOG:PIN`     | Sets the value of an analog output pin     |
| `DIG:RST`        | Resets all digital io pins                 |
| `DIG:PIN?`       | Gets the current state of a digital io pin |
| `DIG:PIN`        | Sets the current state of a digital io pin |
| `DIG:PIN:DIR?`   | Gets the direction of a digital io pin     |
| `DIG:PIN:DIR`    | Sets the direction of a digital io pin     |
| `COUNTER:TIME?`  | Gets the counting duration                 |
| `COUNTER:TIME`   | Sets the counting duration                 |
| `COUNTER:COUNT?` | Gets a fresh count                         |
| `COUNTER:WRSC?`  | Gets the last counts and starts counting   |


## Analog IO

### ANALOG:RST

```
ANALOG:RST\r\n
```

Resets the value of all analog IO pins.

### ANALOG:PIN?

```
ANALOG:PIN? PIN_NAME\r\n
```

Gets the value of an analog IO Pin. PIN_NAME can be one of:

| PIN_NAME |
|----------|
| `AOUT0`  |
| `AOUT1`  |
| `AOUT2`  |
| `AOUT3`  |
| `AIN0`   |
| `AIN1`   |
| `AIN2`   |
| `AIN3`   |

Returns: `VOLTAGE\r\n` where VOLTAGE is a number (e.g. `1.0\r\n`)

### ANALOG:PIN

```
ANALOG:PIN PIN_NAME VOLTAGE\r\n
```

Sets the value of an analog IO Pin.

Arguments:
- `PIN_NAME` can be one of:

| PIN_NAME |
|----------|
| `AOUT0`  |
| `AOUT1`  |
| `AOUT2`  |
| `AOUT3`  |
| `AIN0`   |
| `AIN1`   |
| `AIN2`   |
| `AIN3`   |

- `VOLTAGE` should be a number, e.g. `1.0`

## Digital IO

### DIG:RST

```
DIG:RST\r\n
```

Resets all digital IO pins.

### DIG:PIN?

```
DIG:PIN? PIN_NAME\r\n
```

Gets the state of a digital IO pin.

Arguments:
- `PIN_NAME` can be one of

| PIN_NAME |
|----------|
| LED1     |
| LED2     |
| LED3     |
| LED4     |
| LED5     |
| LED6     |
| LED7     |
| DIO0_P   |
| DIO1_P   |
| DIO2_P   |
| DIO3_P   |
| DIO4_P   |
| DIO5_P   |
| DIO6_P   |
| DIO7_P   |
| DIO0_N   |
| DIO1_N   |
| DIO2_N   |
| DIO3_N   |
| DIO4_N   |
| DIO5_N   |
| DIO6_N   |
| DIO7_N   |

Returns: `0\r\n` or `1\r\n`


### DIG:PIN

```
DIG:PIN PIN_NAME STATE\r\n
```

Sets the state of a digital IO pin.

Arguments:
- `PIN_NAME` can be one of

| PIN_NAME |
|----------|
| LED1     |
| LED2     |
| LED3     |
| LED4     |
| LED5     |
| LED6     |
| LED7     |
| DIO0_P   |
| DIO1_P   |
| DIO2_P   |
| DIO3_P   |
| DIO4_P   |
| DIO5_P   |
| DIO6_P   |
| DIO7_P   |
| DIO0_N   |
| DIO1_N   |
| DIO2_N   |
| DIO3_N   |
| DIO4_N   |
| DIO5_N   |
| DIO6_N   |
| DIO7_N   |

- `STATE` is eigher `1` or `0`


### DIG:PIN:DIR?

```
DIG:PIN:DIR? PIN_NAME\r\n
```

Gets the current direction of a digital IO pin.

Arguments:
- `PIN_NAME` can be one of

| PIN_NAME |
|----------|
| LED1     |
| LED2     |
| LED3     |
| LED4     |
| LED5     |
| LED6     |
| LED7     |
| DIO0_P   |
| DIO1_P   |
| DIO2_P   |
| DIO3_P   |
| DIO4_P   |
| DIO5_P   |
| DIO6_P   |
| DIO7_P   |
| DIO0_N   |
| DIO1_N   |
| DIO2_N   |
| DIO3_N   |
| DIO4_N   |
| DIO5_N   |
| DIO6_N   |
| DIO7_N   |

Returns: `IN\r\n` or `OUT\r\n`

### DIG:PIN:DIR

```
DIG:PIN:DIR PIN_NAME DIR\r\n
```

Sets the current direction of a digital IO pin.

Arguments:
- `PIN_NAME` can be one of

| PIN_NAME |
|----------|
| LED1     |
| LED2     |
| LED3     |
| LED4     |
| LED5     |
| LED6     |
| LED7     |
| DIO0_P   |
| DIO1_P   |
| DIO2_P   |
| DIO3_P   |
| DIO4_P   |
| DIO5_P   |
| DIO6_P   |
| DIO7_P   |
| DIO0_N   |
| DIO1_N   |
| DIO2_N   |
| DIO3_N   |
| DIO4_N   |
| DIO5_N   |
| DIO6_N   |
| DIO7_N   |

- `DIR` is one of `IN` or `OUT`

## Counter

### COUNTER:TIME?

```
COUNTER:TIME?\r\n
```

Gets the counting duration in seconds.

Returns: `DURATION\r\n` where DURATION is a number (e.g. `0.002\r\n`)

### COUNTER:TIME

```
COUNTER:TIME DURATION\r\n
```

Sets the counting duration in seconds.

Arguments:
- `DURATION` is the counting duration in seconds (e.g. `0.002`)

### COUNTER:COUNT?

```
COUNTER:COUNT?\r\n
```

Waits for the counter to be idle, starts counting and waits for the counting procedure to finish.
Then returns the fresh counts.

Returns: `COUNTS1,COUNTS2` a comma-separated list of counts, one item per APD.
The counts are plain integer numbers and are not normalized.

Note: This is what you want most of the time when you are using the counter!

### COUNTER:WRSC?

```
COUNTER:WRSC?\r\n
```

Waits for the counter to be idle, reads the counts and starts counting again.
Returns the counts from the *previous* counting process.

Returns: `COUNTS1,COUNTS2` a comma-separated list of counts, one item per APD.
The counts are plain integer numbers and are not normalized.

*WARNING*: This is probably *NOT* what you want! This command was left here for
backwards compatibility, as it was used all over the place. Only use it if you
have a good reason! Otherwise use `COUNTER:COUNT?`
