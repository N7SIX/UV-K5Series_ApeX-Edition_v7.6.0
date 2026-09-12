/* Adapted from the K1 (PY32F071) tree: scheduler.h for DP32G030/CMSIS.
 * Provides the SysTick counter extern and enable/disable helpers used by
 * K1-lineage sources (app/spectrum.c, ui/mdc.c). */
#ifndef _SCHEDULER_H
#define _SCHEDULER_H

#include "ARMCM0.h"

/** Global system tick counter incremented by the SysTick handler. */
extern volatile uint32_t gGlobalSysTickCounter;

/** Enable the SysTick scheduler interrupt. */
static inline void SCHEDULER_Enable(void)
{
    NVIC_EnableIRQ(SysTick_IRQn);
}

/** Disable the SysTick scheduler interrupt. */
static inline void SCHEDULER_Disable(void)
{
    NVIC_DisableIRQ(SysTick_IRQn);
}

#endif /* _SCHEDULER_H */
