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
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "py25q16.h"
#include <string.h>

// NOTE: This is a stub. The UV-K5/K5(8)/K6 boards have no external SPI NOR
// flash wired to the MCU — the PY25Q16 driver in upstream trees talks to a
// chip this hardware does not have. Callers must therefore behave as if the
// storage is ERASED. A NOR flash chip in erased state reads back 0xFF, but
// every consumer of this driver (welcome strings, spectrum settings) treats
// the data as NUL-terminated C strings / numeric defaults, so returning 0xFF
// produces unterminated strings and garbage on screen. Filling with 0x00
// models "empty" correctly for all current callers.
void PY25Q16_ReadBuffer(uint32_t Address, void *pBuffer, uint32_t Size)
{
    (void)Address;
    memset(pBuffer, 0x00, Size);
}

void PY25Q16_WriteBuffer(uint32_t Address, const void *pBuffer, uint32_t Size, bool EraseFirst)
{
    (void)Address;
    (void)pBuffer;
    (void)Size;
    (void)EraseFirst;
}

void PY25Q16_FlushPendingWrite(void)
{
}
