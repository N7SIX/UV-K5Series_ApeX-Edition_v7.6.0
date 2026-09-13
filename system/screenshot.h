/* Copyright 2024 Armel F4HWN N7SIX
 * https://github.com/armel f4hwn
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

#ifndef SCREENSHOT_H
#define SCREENSHOT_H

#include <stdbool.h>

void getScreenShot(bool force);

// Compatibility wrappers: HEAD spectrum.c / welcome.c call these when
// ENABLE_FEAT_N7SIX_SCREENSHOT=1, but only getScreenShot() exists.
static inline void SCREENSHOT_Update(bool force) { getScreenShot(force); }
static inline void SCREENSHOT_ParseInput(void) {}

#endif