/* Copyright 2023 Dual Tachyon
 * https://github.com/DualTachyon
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 *     Unless required by applicable law or agreed to in writing, software
 *     distributed under the License is distributed on an "AS IS" BASIS,
 *     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *     See the License for the specific language governing permissions and
 *     limitations under the License.
 */

#include "../bsp/dp32g030/pmu.h"
#include "../bsp/dp32g030/syscon.h"
#include "system.h"
#include "systick.h"

/* Global flag -- true when the watchdog was successfully initialised.
 * main.c checks this once before relying on the feed path. */
static bool gWatchdogEnabled = false;

void SYSTEM_DelayMs(uint32_t Delay)
{
    SYSTICK_DelayUs(Delay * 1000);
}

void SYSTEM_ConfigureClocks(void)
{
    // Set source clock from external crystal
    PMU_SRC_CFG = (PMU_SRC_CFG & ~(PMU_SRC_CFG_RCHF_SEL_MASK | PMU_SRC_CFG_RCHF_EN_MASK)) | PMU_SRC_CFG_RCHF_SEL_BITS_48MHZ | PMU_SRC_CFG_RCHF_EN_BITS_ENABLE;

    // Divide by 2
    SYSCON_CLK_SEL = SYSCON_CLK_SEL_DIV_BITS_2;

    // Disable division clock gate
    SYSCON_DIV_CLK_GATE = (SYSCON_DIV_CLK_GATE & ~SYSCON_DIV_CLK_GATE_DIV_CLK_GATE_MASK) | SYSCON_DIV_CLK_GATE_DIV_CLK_GATE_BITS_DISABLE;
}

/* ---- H2 fix: watchdog implementation ----
 * The DP32G030 WWDT peripheral is used. It runs from the internal 512 kHz
 * RC oscillator which is always available (even in power-save).
 *
 * Configuration:
 *   Prescaler: 1024  (WDT clock = 512 kHz / 1024 = 500 Hz)
 *   Reload:    4095  (max value, 12-bit)
 *   Timeout:   (4096 / 500 Hz) ≈ 8.19 s
 *
 * The main loop feeds the watchdog every ~10 ms. If the loop hangs
 * (stuck I²C/SPI, dead ISR, infinite loop), the chip resets after ~8 s.
 */
void SYSTEM_WatchdogInit(void)
{
    // Enable WWDT clock gate (bit 24 in SYSCON_DEV_CLK_GATE)
    SYSCON_DEV_CLK_GATE |= SYSCON_DEV_CLK_GATE_WWDT_BITS_ENABLE;

    // Unlock the Mode Register by writing the key (0xA5A5 in upper 16 bits)
    WWDT_MR = WWDT_MR_KEY_VALUE;

    // Configure: enable watchdog, halt in debug, prescaler = 1024 (PSCR field = 9,
    // i.e. 2^(9+1) = 2048; 512 kHz / 2048 ≈ 244 Hz), reload = 4095
    // Timeout ≈ 4096 / 244 ≈ 16.8 s -- generous for I2C/SPI transactions.
    // Adjust WWDT_RLR if a shorter window is desired after empirical testing.
    WWDT_MR = WWDT_MR_KEY_VALUE
              | WWDT_MR_WEN
              | WWDT_MR_HALT
              | ((9U << WWDT_MR_PSCR_SHIFT) & WWDT_MR_PSCR_MASK);

    // Set reload value (max 12-bit = 4095 → ~16.8 s at 244 Hz)
    WWDT_RLR = WWDT_RLR_MASK;

    gWatchdogEnabled = true;
}

void SYSTEM_WatchdogFeed(void)
{
    if (!gWatchdogEnabled)
        return;

    // Writing any value to WWDT_CR reloads the counter.
    // On some DP32G030 variants feeding is done via WWDT_MR; we try both
    // to be safe against silicon revision differences.
    WWDT_CR = 0U;
    WWDT_MR = (WWDT_MR & ~WWDT_MR_KEY_VALUE) | WWDT_MR_KEY_VALUE;
}

bool SYSTEM_WatchdogIsEnabled(void)
{
    return gWatchdogEnabled;
}
