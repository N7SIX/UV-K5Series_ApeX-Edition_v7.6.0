/* Compatibility shim: K1-lineage sources include "board.h" / "../board.h".
 * The K5 tree keeps board support in core/. */
#ifndef BOARD_SHIM_H
#define BOARD_SHIM_H
#include "core/board.h"
#endif /* BOARD_SHIM_H */
