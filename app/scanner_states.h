#ifndef SCANNER_STATES_H
#define SCANNER_STATES_H

#include <stdint.h>
#include <stdbool.h>

enum ScanState {
    STATE_NONE = 0,
    STATE_LISTENING,
    STATE_STILL,
    STATE_FREQUENCY_INPUT,
    STATE_SCANNING,
    STATE_SCAN_RANGE,
    SCANNER_STATE_END,
};

typedef enum ScanState ScanState;

#endif // SCANNER_STATES_H
