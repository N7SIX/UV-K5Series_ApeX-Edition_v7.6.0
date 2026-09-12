/* Compatibility shim: K1-lineage sources include "version.h" / "../version.h".
 * The K5 tree keeps the version strings in system/. */
#ifndef VERSION_SHIM_H
#define VERSION_SHIM_H
#include "system/version.h"
#endif /* VERSION_SHIM_H */
