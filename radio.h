/* Compatibility shim: K1-lineage sources include "radio.h" / "../radio.h".
 * The K5 tree keeps radio support in radio/ (radio/radio.h is the umbrella). */
#ifndef RADIO_SHIM_H
#define RADIO_SHIM_H
#include "radio/radio.h"
#endif /* RADIO_SHIM_H */