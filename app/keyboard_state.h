#ifndef APP_KEYBOARD_STATE_H
#define APP_KEYBOARD_STATE_H

#include "../driver/keyboard.h"

typedef struct KeyboardState
{
    KEY_Code_t current;
    KEY_Code_t prev;
    uint8_t counter;
} KeyboardState;

#endif // APP_KEYBOARD_STATE_H
