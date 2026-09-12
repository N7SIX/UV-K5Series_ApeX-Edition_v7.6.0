/* Compatibility shim: K1-lineage sources include "settings.h" / "../settings.h"
 * (flat layout). The K5 tree keeps settings in core/. */
#ifndef SETTINGS_SHIM_H
#define SETTINGS_SHIM_H
#include "core/settings.h"
#endif /* SETTINGS_SHIM_H */
