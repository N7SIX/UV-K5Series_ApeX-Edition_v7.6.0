
# UV-K5Series ApeX Edition v7.6.0
#
# Copyright (c) Dual Tachyon, Egzumer, OneOfEleven, N7SIX, and contributors
# Enhancements, improvements, and reorganization by Sean, N7SIX
# Version: v7.6.0
# Date: March 24, 2026
#
# This file and all documentation in this repository have been updated to reflect the professional reorganization, build system improvements, and feature enhancements performed by Sean, N7SIX. All features are preserved, and the codebase is fully compatible with Quansheng UV-K5, K5(8)/K6 (Version 1 Only) hardware.

# Summary of Enhancements & Improvements
- Professional reorganization of all .c, .h, and .cfg files into logical folders
- All build and IntelliSense errors fixed after the move
- Makefile and Docker build system updated for new structure
- All features preserved, no code removed or commented out
- FLASH and RAM usage optimized and confirmed to fit hardware
- Documentation and dependency mapping improved
- Spectrum analyzer and UI enhancements
- All changes tracked via git for full history

# Spectrum Analyzer: Data Flow & Code Patterns

## Complete Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          APP_RunSpectrum()                                   │
│                      (Initialization routine)                                │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1. Load EEPROM settings (persistent state)                                  │
│ 2. Initialize scan parameters                                              │
│ 3. Backup hardware registers                                               │
│ 4. Reset buffers (rssiHistory, waterfallHistory)                           │
│ 5. Set BK4819 calibration registers (0x13, 0x14, 0x10)                    │
│ 6. Enter main loop: while (isInitialized) Tick()                          │
└────────────────┬────────────────────────────────────────────────────────────┘
                 │
                 ▼
    ┌────────────────────────────┐
    │      Tick() [Main Loop]     │
    │  (Executes ~16-20 Hz)       │
    └────────────┬────────────────┘
                 │
    ┌────────────┴───────┬──────────────┬─────────────┐
    │                    │              │             │
    ▼                    ▼              ▼             ▼
  Handle         Update Scan State   Render      Handle 
  User Input     (Spectrum/Still)    Display     Listening
    │                    │              │             │
    └────────────┬───────┴──────────┬───┴─────────────┘
                 │                  │
         ┌───────▼──────────┐       │
         │ HandleUserInput()│       │
         └───────┬──────────┘       │
                 │                  │
         ┌───────▼────────────────────────────┐
         │ Switch on currentState+key         │
         │ ├─ OnKeyDown (SPECTRUM mode)       │
         │ ├─ OnKeyDownStill (STILL mode)     │
         │ └─ OnKeyDownFreqInput              │
         └───────┬────────────────────────────┘
                 │
         ┌───────▼──────────────────┐
         │ State Update Functions   │
         │ ├─ UpdateCurrentFreq()   │
         │ ├─ UpdateScanStep()      │
         │ ├─ UpdateDBMax()         │
         │ └─ RelaunchScan()        │
         └──────────────────────────┘
                 │
         ┌───────▼────────────────────────────────────────┐
         │ Measurement Loop (if not listening/input)      │
         │                                                 │
         │ IF (currentState == SPECTRUM):                 │
         │   UpdateScan()  ───────────────────────┐       │
         │                                         │       │
         │ ELSE IF (currentState == STILL):        │       │
         │   UpdateStill() ──────────────────┐    │       │
         │                                    │    │       │
         │ ELSE IF (isListening):             │    │       │
         │   UpdateListening() ──────────┐    │    │       │
         └──────────────────────────────┬┬┬───┘───┘───────┘
                                        │││
         ┌──────────────────────────────┘││
         │                               │└─────────────────┐
         │                               │                 │
         ▼                               ▼                 ▼
    ┌─────────────────┐          ┌──────────────────┐  ┌────────────────────┐
    │  UpdateScan()   │          │ UpdateStill()    │  │ UpdateListening()  │
    │                 │          │                  │  │                    │
    │ ├─ Scan()       │          │ ├─ Measure()     │  │ ├─ Measure()      │
    │ │  ├SetF()      │          │ │  ├GetRssi()    │  │ │  ├GetRssi()     │
    │ │  └Measure()   │          │ │  └SetStill()   │  │ │  └UpdateWFQuick │
    │ │   └GetRssi()  │          │ └─ Render S-m.   │  │ ├─ UpdateWaterfall│
    │ ├─NextScanStep()│          │                  │  │ ├─Check Tail PKT  │
    │ └─On Complete:  │          └──────────────────┘  │ ├─Generate Grass  │
    │   UpdateWaterfall()                              │ └─Audio Reactive  │
    │   UpdatePeakInfo()                               │                    │
    │   AutoTriggerLevel()                             └────────────────────┘
    │   IsPeakOverLevel() →────╮
    │                          │ YES: Enter Listening
    └──────────────────────────┘

    ┌──────────────────────────────────────────────────────────────┐
    │  Measurement Functions (core RSSI acquisition)               │
    │                                                               │
    │  Measure()                                                   │
    │  ├─ SYSTEM_DelayUs(400)  ← **CRITICAL PLL settling**        │
    │  ├─ GetRssi()                                               │
    │  │  ├─ Wait for ADC ready (Reg 0x63)                        │
    │  │  ├─ BK4819_GetRSSI()                                     │
    │  │  └─ Apply AM-fix correction (if enabled)                 │
    │  └─ SetRssiHistory(scanInfo.i, rssi)                        │
    │     └─ MapMeasurementToDisplay(idx)  ← Decimation          │
    │        └─ Store max value in bin (rssiHistory[dIdx])        │
    └──────────────────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────────────────────────┐
    │  Peak Detection Pipeline                                     │
    │                                                               │
    │  UpdateScanInfo()                                            │
    │  ├─ Track rssiMax, rssiMin from current sweep                │
    │  └─ Update scanInfo.fPeak, scanInfo.iPeak                    │
    │                                                               │
    │  UpdatePeakInfo() [called once per sweep]                    │
    │  ├─ If peak.t >= 1024 OR rssi > peak.rssi:                  │
    │  │  └─ UpdatePeakInfoForce()                                │
    │  │     ├─ peak.rssi = scanInfo.rssiMax                      │
    │  │     ├─ peak.f = scanInfo.fPeak                           │
    │  │     └─ AutoTriggerLevel()                                │
    │  └─ Else: peak.t++ (aging)                                  │
    │                                                               │
    │  AutoTriggerLevel() [adaptive squelch]                       │
    │  ├─ First scan: trigger = 150 (default)                     │
    │  ├─ Signal stronger: +1 unit/scan (slow rise)               │
    │  ├─ Signal weaker: −3 units/scan (fast recovery)            │
    │  └─ Enforce 6dB margin above peak                           │
    │                                                               │
    │  GetCentroidFrequency() [pinpoint tuning]                    │
    │  ├─ If listening: return locked frequency                   │
    │  ├─ 3-point parabolic interpolation on rssiHistory          │
    │  ├─ Calculate fractional frequency offset                   │
    │  └─ Return frequency with ±10Hz precision                   │
    │                                                               │
    │  TuneToPeak()                                                │
    │  ├─ f = GetCentroidFrequency()                               │
    │  ├─ SetF(f)                                                 │
    │  └─ peak.f = f  (lock peak frequency)                       │
    └──────────────────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────────────────────────┐
    │  Signal Processing (smoothing, peak hold, waterfall)         │
    │                                                               │
    │  ProcessSpectrumEnhancements() [per sweep]                   │
    │  └─ For each frequency bin:                                  │
    │     ├─ smoothedRssi[i] = (old×3 + new) >> 2                │
    │     │                    (3-tap EMA filter)                 │
    │     ├─ if rssi > peakHold:                                  │
    │     │  └─ peakHold = rssi, peakAge = 20                    │
    │     └─ else:                                                 │
    │        └─ Decrement peakAge, decay peakHold                │
    │                                                               │
    │  UpdateWaterfall() [once per sweep]                          │
    │  ├─ Advance circular buffer index                            │
    │  ├─ Find dynamic range (minRssi..maxRssi)                   │
    │  └─ For each frequency:                                      │
    │     └─ Map RSSI to 0..15 grayscale level                   │
    │        └─ Store in packed nibble format                     │
    │                                                               │
    │  UpdateWaterfallQuick() [during listening, every tick]       │
    │  └─ Only advance circular buffer pointer (no recompute)     │
    └──────────────────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────────────────────────┐
    │  Rendering Pipeline (Render function)                        │
    │                                                               │
    │  1. Clear spectrum area (rows 1-5 in framebuffer)            │
    │  2. ProcessSpectrumEnhancements()  ← Apply filter first     │
    │  3. DrawGridBackground() OR DrawTicks()                      │
    │  4. DrawArrow(peak_x)  ← Cursor at peak frequency           │
    │  5. DrawSpectrumEnhanced()                                   │
    │     ├─ Draw wire line (Bresenham algorithm)                 │
    │     ├─ Fill below with diagonal hatch pattern               │
    │     └─ Draw peak-hold dots above wire                       │
    │  6. DrawRssiTriggerLevel()  ← Two triangles (L/R edges)     │
    │  7. DrawF()  ← Peak frequency display                        │
    │  8. DrawNums()  ← Step count, bandwidth info                │
    │  9. DrawWaterfall()  ← 16-row temporal history              │
    │     ├─ Bayer 4×4 dithering for grayscale                   │
    │     └─ Fade effect on older rows                            │
    │ 10. ST7565_BlitFullScreen()  ← Transfer to LCD               │
    │                                                               │
    │  Coordinate Transformation Chain:                            │
    │  ┌──────────────────────────────────────────────────────┐   │
    │  │ RSSI value                                           │   │
    │  │   ↓ Rssi2DBm()                                       │   │
    │  │ dBm value                                            │   │
    │  │   ↓ Clamp to [dbMin, dbMax]                          │   │
    │  │ Normalized dBm                                       │   │
    │  │   ↓ Linear scale to pixel range [0..39]              │   │
    │  │ Pixel height (before cosmetic adjustments)           │   │
    │  │   ↓ Add noise at low level / boost at high level     │   │
    │  │ Pixel height (with aesthetic effects)                │   │
    │  │   ↓ Rssi2Y() convert to Y position (0..63)           │   │
    │  │ Final Y pixel coordinate                             │   │
    │  └──────────────────────────────────────────────────────┘   │
    │                                                               │
    │  Index-to-Pixel Mapping:                                     │
    │  ┌──────────────────────────────────────────────────────┐   │
    │  │ Raw measurement index (0..127)                       │   │
    │  │   ↓ MapMeasurementToDisplay()                        │   │
    │  │ Display bin index (0..128 or 0..64 etc.)             │   │
    │  │   ↓ SpecIdxToX()                                     │   │
    │  │ Screen X pixel (0..127)                              │   │
    │  └──────────────────────────────────────────────────────┘   │
    └──────────────────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────────────────────────┐
    │  Listening Mode Enhancement (audio-reactive display)         │
    │                                                               │
    │  UpdateListening() [throttled every 6 ticks]                 │
    │  ├─ Sample RX audio envelope (0..63) from BK4819 AFT        │
    │  ├─ Smooth with EMA: rxAudioSmooth = (old×3 + new) >> 2     │
    │  ├─ Map to pulse amplitude: pulse = smooth >> 2               │
    │  ├─ pulseFactor = 1.0 + pulse/16.0  (1.0 to ~5.0)            │
    │  │                                                            │
    │  │ For each frequency bin:                                    │
    │  │   IF near peak:                                           │
    │  │     rssiHistory[i] = peak.rssi × pulseFactor              │
    │  │   ELSE:                                                   │
    │  │     Use noise persistence + random modulation             │
    │  │     rssiHistory[i] = noise × grassPulseFactor             │
    │  │                                                            │
    │  └─ UpdateWaterfall()  ← Refresh temporal display            │
    └──────────────────────────────────────────────────────────────┘

            │
            ▼
    ┌──────────────────────┐
    │ Render() → Display   │
    │                      │
    │ UI_DisplayClear()    │
    │ RenderSpectrum() OR  │
    │ RenderStill() OR     │
    │ RenderFreqInput()    │
    │ ST7565_BlitFullScreen()
    └──────────────────────┘
```

---

## Code Pattern Reference

### Pattern 1: Circular Buffer (Waterfall History)
```c
// Initialization
uint8_t waterfallIndex = 0;
uint8_t waterfallHistory[SPECTRUM_MAX_STEPS][WATERFALL_HISTORY_DEPTH / 2];

// Advance pointer
waterfallIndex = (waterfallIndex + 1) % WATERFALL_HISTORY_DEPTH;

// Set value (2 samples per byte)
static void SetWaterfallLevel(uint8_t x, uint8_t y, uint8_t level) {
    uint8_t row = y >> 1;
    if (!(y & 1)) {
        waterfallHistory[x][row] = 
            (waterfallHistory[x][row] & 0xF0) | (level & 0x0F);
    } else {
        waterfallHistory[x][row] = 
            (waterfallHistory[x][row] & 0x0F) | (level << 4);
    }
}

// Get value
static uint8_t GetWaterfallLevel(uint8_t x, uint8_t y) {
    uint8_t row = y >> 1;
    if (!(y & 1)) return waterfallHistory[x][row] & 0x0F;
    return (waterfallHistory[x][row] >> 4) & 0x0F;
}

// Retrieve history (with circular indexing)
for (uint8_t y_offset = 0; y_offset < WATERFALL_HISTORY_DEPTH; y_offset++) {
    int16_t historyRow = (int16_t)waterfallIndex - y_offset;
    while (historyRow < 0) historyRow += WATERFALL_HISTORY_DEPTH;
    uint8_t level = GetWaterfallLevel(x, historyRow);
    // Render level...
}
```

**Key Point**: No data copying. The pointer rotates through the buffer, automatically overwriting oldest data.

### Pattern 2: Exponential Moving Average (EMA)
```c
// Parameters
#define EMA_NUMERATOR   3    // Weight of old value
#define EMA_DENOMINATOR 4    // Total weight

// Apply filter
smoothedValue = ((smoothedValue * EMA_NUMERATOR) + newValue) / EMA_DENOMINATOR;

// Equivalent to:
// smoothedValue = smoothedValue * 0.75 + newValue * 0.25

// Shortcut using bit shift (faster)
smoothedValue = ((smoothedValue * 3) + newValue) >> 2;
```

**Time Constant**: ~2-3 samples at this ratio. Adjust numerator/denominator for different response.

### Pattern 3: Fixed-Point Arithmetic (avoid floating-point)
```c
// Problem: frequency_vco = frequency_target / 47.6
// If we use float, it's slow and adds bloat

// Solution: Pre-multiply by 1000 (fixed-point)
#define FIXED_POINT_SCALE 1000
uint32_t frequency_vco_fp = (frequency_target_hz * FIXED_POINT_SCALE) / 476;
uint32_t frequency_vco = frequency_vco_fp / (FIXED_POINT_SCALE / 10);

// Or: Right-shift to extract integer part
uint32_t frequency_vco_fp = (frequency_target_hz * 1000) / 476;
uint32_t frequency_vco = frequency_vco_fp >> 10;  // Divide by 1024 ≈ 1000
```

### Pattern 4: Table-Based Lookup (avoids expensive math)
```c
// Pre-calculate all possible output values
static const uint8_t sMeterTable[] = {
    0, 1, 1, 2, 2, 2, 3, 3, 3, 4, // dBm -120 to -110
    ...
};

// At runtime, just index
uint8_t sMeter = sMeterTable[clamp(dbm + 120, 0, 141)];
// Much faster than doing logarithm!
```

### Pattern 5: Clamp Function
```c
static int clamp(int v, int min, int max) {
    return v <= min ? min : (v >= max ? max : v);
}

// Usage
int16_t pixel_y = clamp(calculated_y, 0, 63);
uint16_t rssi = clamp(rssi_raw, 0, RSSI_MAX_VALUE);
```

### Pattern 6: Array Index Wrapping
```c
// Problem: Circular buffer needs to wrap index
// Bad approach (branches):
if (++index >= MAX_SIZE) index = 0;

// Better approach (no branch):
index = (index + 1) % MAX_SIZE;

// Best approach (if MAX_SIZE is power-of-2):
#define MAX_SIZE 16
index = (index + 1) & 0x0F;  // Equivalent to % 16, but branchless
```

### Pattern 7: Bit Manipulation
```c
// Set specific bit in register
uint16_t reg = BK4819_ReadRegister(BK4819_REG_30);
reg |= (1 << 9);  // Set bit 9
BK4819_WriteRegister(BK4819_REG_30, reg);

// Clear specific bit
reg &= ~(1 << 9);  // Clear bit 9
BK4819_WriteRegister(BK4819_REG_30, reg);

// Read field from register (mask and shift)
uint8_t bw_field = (BK4819_ReadRegister(BK4819_REG_30) >> 5) & 0x07;
// Extracts 3-bit bandwidth field starting at bit 5

// Write field to register
reg = BK4819_ReadRegister(BK4819_REG_30);
reg &= ~(0x07 << 5);              // Clear 3-bit field
reg |= (new_bw & 0x07) << 5;      // Set new value
BK4819_WriteRegister(BK4819_REG_30, reg);

// Pack two 4-bit values into one byte
uint8_t packed = ((high_nibble & 0x0F) << 4) | (low_nibble & 0x0F);
```

### Pattern 8: State Machine with Guard Conditions
```c
void Tick() {
    // Guard: Don't allow user input if scanning
    if (!preventKeypress) {
        HandleUserInput();
    }
    
    // Guard: Allow initialization on first tick
    if (newScanStart) {
        InitScan();
        newScanStart = false;
    }
    
    // Multi-branch state dispatch
    if (isListening && currentState != FREQ_INPUT) {
        UpdateListening();
    } else {
        switch (currentState) {
            case SPECTRUM: UpdateScan();   break;
            case STILL:    UpdateStill();  break;
            case FREQ_INPUT: /* handle in UpdateListening */ break;
        }
    }
    
    // Guard: Only render if dirty
    if (redrawScreen) {
        Render();
        redrawScreen = false;
    }
}
```

### Pattern 9: Asymmetric Hysteresis (auto-level adjustment)
```c
int32_t target = calculate_desired_level();
int32_t current = get_current_level();
int32_t threshold = 5;  // Deadband

if (target > current + threshold) {
    // Target is higher: adjust slowly (high = good signal)
    current += 1;
} else if (target < current - threshold) {
    // Target is lower: adjust quickly (recover sensitivity)
    current -= 3;
}
// Otherwise: hold current value (prevent oscillation)
```

**Why Asymmetric**?
- Sensitivity to sudden changes (fast down-adjust) mimics human operator
- Stability on constant signal (slow up-adjust) avoids chasing noise

### Pattern 10: Prevent-Keypress Guard
```c
// In RelaunchScan()
preventKeypress = true;

// In main Tick()
if (!preventKeypress) {
    HandleUserInput();  // Skipped during scan
}

// After scan completes
preventKeypress = false;  // Allow input again

// This prevents user from changing frequency mid-scan
// which would corrupt the measurement
```

---

## Enum and Define Reference

### States
```c
typedef enum {
    SPECTRUM,     // Real-time scanning mode
    STILL,        // Locked to single peak frequency
    FREQ_INPUT    // Manual frequency entry
} State;
```

### Scan Step Options
```c
typedef enum {
    S_STEP_2_5kHz,      // 2.5 kHz (center mode only)
    S_STEP_5_0kHz,      // 5.0 kHz
    S_STEP_6_25kHz,     // 6.25 kHz (standard 25k narrow)
    S_STEP_10_0kHz,     // 10 kHz
    S_STEP_12_5kHz,     // 12.5 kHz
    S_STEP_25_0kHz,     // 25 kHz (default)
    S_STEP_50_0kHz,     // 50 kHz
    S_STEP_100_0kHz     // 100 kHz
} ScanStepIndex_t;
```

### Display Resolution
```c
typedef enum {
    STEPS_128,  // 128 bars (full resolution)
    STEPS_64,   // 64 bars (zoom 2×)
    STEPS_32,   // 32 bars (zoom 4×)
    STEPS_16    // 16 bars (zoom 8×)
} StepsCount_t;
```

### Modulation Types
```c
typedef enum {
    MODULATION_FM,          // FM
    MODULATION_AM,          // AM
    MODULATION_USB,         // USB
    MODULATION_LSB,         // LSB
    MODULATION_UKNOWN       // (placeholder for iteration)
} Modulation_t;
```

---

## Performance Profiling

### Function Call Counts (per tick at 16Hz)
| Function | Spectrum | Still | Listening |
|----------|----------|-------|-----------|
| Measure() | 128× | 1× | 1× |
| Render() | 15× | 15× | 2× (throttled) |
| UpdateWaterfall() | 15× (1/sweep) | — | 2× (throttled) |
| HandleUserInput() | 1× | 1× | 1× |

### CPU Load Estimate (48MHz ARM Cortex-M0)
- **Scan mode**: 50-70% (RSSI reads are expensive)
- **Still mode**: 20-30% (one RSSI read, display rendering)
- **Listening mode**: 10-15% (minimal computation, mostly I/O waiting)

Cost Breakdown (per tick):
- BK4819 SPI reads: ~1000 cycles × 128 measurements = 128,000 cycles/sweep
- Display rendering: ~5,000 cycles
- Math (EMA, centroid): ~1,000 cycles
- **Total per sweep (~64ms)**: ~135,000 cycles = 2% of 48MHz CPU

---

## Debugging Tips

### Issue: Spectrum is jittery / unstable
**Likely Cause**: PLL settling delay too short or missing
**Fix**: Ensure SYSTEM_DelayUs(400) in Measure() is present

### Issue: Peak detection doesn't lock to signal
**Likely Cause**: AutoTriggerLevel() threshold too high
**Fix**: Check if settings.rssiTriggerLevel == RSSI_MAX_VALUE (reset trigger)

### Issue: Waterfall appears frozen
**Likely Cause**: rssiHistory not cleared when exiting listening mode
**Fix**: Add memset(rssiHistory, 0, sizeof(rssiHistory)) in UpdateListening()

### Issue: Frequency off by 5-10 kHz
**Likely Cause**: Centroid calculation needs calibration
**Fix**: Test GetCentroidFrequency() with known 3-peak pattern

### Issue: Out-of-memory / crash during operation
**Likely Cause**: Buffer overflow (too many SPECTRUM_MAX_STEPS)
**Fix**: Reduce SPECTRUM_MAX_STEPS from 128 to 64, or optimize other buffers

---

## Conclusion

This spectrum analyzer uses well-established patterns:
- Circular buffers for memory efficiency
- EMA filters for noise rejection
- Fixed-point math for performance
- Lookup tables to avoid expensive computations
- Guard conditions to maintain state consistency

These patterns are portable across embedded projects and can be adapted for different hardware platforms and constraints.
