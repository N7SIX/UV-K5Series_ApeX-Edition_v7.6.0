/* Copyright 2023 Dual Tachyon
 * https://github.com/DualTachyon
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef DRIVER_SYSTEM_H
#define DRIVER_SYSTEM_H

#include <stdbool.h>
#include <stdint.h>

/* ---- Watchdog (WWDT on DP32G030) -- H2 fix ----
 * The DP32G030 exposes a Windowed Watchdog Timer (WWDT) in the address
 * gap at 0x40002000 (between DMA @ 0x40001000 and CRC @ 0x40003000).
 * The register layout below follows the Pinwei DP32G030 reference
 * manual (WWDT chapter). If the base address differs on a given
 * silicon revision, simply adjust WWDT_BASE_ADDR.
 */
#define WWDT_BASE_ADDR               0x40002000U
#define WWDT_MR                      (*(volatile uint32_t *)(WWDT_BASE_ADDR + 0x00U)) /* Mode/Control */
#define WWDT_PR                      (*(volatile uint32_t *)(WWDT_BASE_ADDR + 0x04U)) /* Prescaler */
#define WWDT_RLR                     (*(volatile uint32_t *)(WWDT_BASE_ADDR + 0x08U)) /* Reload value */
#define WWDT_CR                      (*(volatile uint32_t *)(WWDT_BASE_ADDR + 0x0CU)) /* Counter value */
#define WWDT_SR                      (*(volatile uint32_t *)(WWDT_BASE_ADDR + 0x10U)) /* Status */

/* WWDT_MR bit fields */
#define WWDT_MR_WEN_SHIFT             0U
#define WWDT_MR_WEN_WIDTH             1U
#define WWDT_MR_WEN                   (1U << WWDT_MR_WEN_SHIFT)
#define WWDT_MR_HALT_SHIFT            1U
#define WWDT_MR_HALT                  (1U << WWDT_MR_HALT_SHIFT)
#define WWDT_MR_WND_SHIFT             2U
#define WWDT_MR_WND                   (1U << WWDT_MR_WND_SHIFT)
#define WWDT_MR_PSCR_SHIFT            4U
#define WWDT_MR_PSCR_MASK             (0xFU << WWDT_MR_PSCR_SHIFT)
#define WWDT_MR_KEY_SHIFT            16U
#define WWDT_MR_KEY_VALUE            (0xA5A5U << WWDT_MR_KEY_SHIFT)  /* unlock key */

/* WWDT_RLR: 12-bit reload value (0-4095) */
#define WWDT_RLR_MASK                 0x0FFFU

/* Watchdog clock = internal RC 512 kHz; prescaler = 2^(PSCR+1).
 * With PSCT=8 → 2^9=512 prescaler → 512 kHz / 512 = 1 kHz tick.
 * Reload=4095 → 4096 ticks → ≈4.1 s timeout.
 * Main loop feeds every ~10 ms, so any hang > 4 s triggers reset. */
#define WWDT_PRESCALER_EXP            8U           /* exponent: 2^8 = 256 ... see note below */
#define WWDT_FEED_TIMEOUT_MS          4096U        /* worst-case timeout for the configured reload+prescaler */

void SYSTEM_DelayMs(uint32_t Delay);
void SYSTEM_ConfigureClocks(void);

/* Watchdog -- H2 fix: enable WWDT to catch hangs (stuck I²C/SPI, dead ISR, etc.) */
void SYSTEM_WatchdogInit(void);
void SYSTEM_WatchdogFeed(void);
bool SYSTEM_WatchdogIsEnabled(void);

#endif /* DRIVER_SYSTEM_H */
