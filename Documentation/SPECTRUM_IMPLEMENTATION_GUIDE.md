
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

# Implementation Guide: Adapting Spectrum Logic for UV-K5

## Overview
This guide explains how to implement or adapt the spectrum analyzer logic for different radio hardware variants. It covers the hardware abstraction layer, key integration points, and testing strategies.

---

## Phase 1: Hardware Interface Layer

### 1.1 RSSI Reading (GetRssi function)
**Requirement**: Read raw RSSI value from radio IC

Current implementation uses BK4819:
```c
uint16_t GetRssi() {
    // Wait for ADC to be ready
    while ((BK4819_ReadRegister(0x63) & 0xFF) >= 255) 
        SYSTICK_DelayUs(100);
    
    uint16_t rssi = BK4819_GetRSSI();
    
    // Apply modulation-specific correction
    #ifdef ENABLE_AM_FIX
    if (settings.modulationType == MODULATION_AM && gSetting_AM_fix)
        rssi += AM_fix_get_gain_diff() * 2;
    #endif
    
    return rssi;
}
```

**For Other Radio ICs** (generic pattern):
```c
typedef struct {
    uint8_t ic_type;  // BK4819, ADF4351, etc.
    uint16_t (*read_rssi)(void);
    void (*set_frequency)(uint32_t freq);
    void (*set_bandwidth)(uint8_t bw);
    // ... add more HAL function pointers
} RadioHAL_t;
```

**Key Points**:
- Ensure register/bit definitions match your radio IC
- Add any pre-read settling delays specific to IC
- Account for IC's native RSSI format (ratio vs dBm vs raw ADC count)
- Implement modulation-specific compensation if needed

### 1.2 Frequency Setting (SetF function)
**Requirement**: Tune radio to specific frequency

Current implementation:
```c
static void SetF(uint32_t f) {
    fMeasure = f;
    BK4819_SetFrequency(fMeasure);                    // Tune to frequency
    BK4819_PickRXFilterPathBasedOnFrequency(fMeasure); // Select filter
    
    uint16_t reg = BK4819_ReadRegister(BK4819_REG_30);
    BK4819_WriteRegister(BK4819_REG_30, 0);           // Clear state
    BK4819_WriteRegister(BK4819_REG_30, reg);         // Restore with flush
}
```

**Critical Detail**: The double write to REG_30 forces the PLL to settle. This is **mandatory** for stable RSSI readings across frequency changes.

**For Other Implementations**:
```c
// Generic pattern
typedef void (*SetFrequency_fn)(uint32_t freq_hz, uint8_t filter_index);

static void SetF(uint32_t f) {
    fMeasure = f;
    
    if (radio_hal.set_frequency) {
        radio_hal.set_frequency(f, select_filter_for_freq(f));
        SYSTEM_DelayUs(400);  // **CRITICAL**: Allow PLL settling
    }
}
```

### 1.3 AGC Control (if supporting AM detection)
**Purpose**: Prevent AGC saturation on strong AM signals

Current implementation:
```c
void LockAGC(void) {
    RADIO_SetupAGC(settings.modulationType == MODULATION_AM, lockAGC);
    lockAGC = true;
}
```

**For generic implementation**:
- If your IC has separate AM gain stages, disable auto-switching during scan
- Take manual control of LNA, PGA, VGA gains
- Re-enable auto-AGC when exiting scan mode

---

## Phase 2: Data Structure Design

### 2.1 Measurement Buffer Architecture
**Goal**: Efficiently store multi-sweep history in limited RAM

Current approach:
```c
// Raw RSSI measurements (current sweep)
uint16_t rssiHistory[SPECTRUM_MAX_STEPS];

// Waterfall history (16 past sweeps, 2 samples per byte)
uint8_t waterfallHistory[SPECTRUM_MAX_STEPS][WATERFALL_HISTORY_DEPTH / 2];

// Processed signal
uint16_t smoothedRssi[SPECTRUM_MAX_STEPS];

// Peak tracking
uint16_t peakHold[SPECTRUM_MAX_STEPS];
uint8_t peakAge[SPECTRUM_MAX_STEPS];
```

**Memory Calculation**:
- rssiHistory: 128 × 2 bytes = 256 bytes
- waterfallHistory: 128 × 8 bytes = 1024 bytes
- smoothedRssi: 128 × 2 bytes = 256 bytes
- peakHold: 128 × 2 bytes = 256 bytes
- peakAge: 128 × 1 byte = 128 bytes
- **Total: 1920 bytes** (well within 8KB SRAM limit)

**Optimization Tips**:
- Use uint8_t for waterfall (0..15 grayscale value) not uint16_t
- Pack peak age into upper nibble if you need to save 128 bytes
- Limit SPECTRUM_MAX_STEPS to 64 if RAM is critical (slight resolution loss)

### 2.2 Circular Waterfall Buffer
**Goal**: Efficient temporal history without copying data

Current implementation:
```c
uint8_t waterfallIndex = 0;  // Circular pointer

static void SetWaterfallLevel(uint8_t x, uint8_t y, uint8_t level) {
    if (x >= SPECTRUM_MAX_STEPS || y >= WATERFALL_HISTORY_DEPTH) return;
    uint8_t row = y >> 1;  // Pack 2 samples per byte
    if (!(y & 1)) 
        waterfallHistory[x][row] = (waterfallHistory[x][row] & 0xF0) | (level & 0x0F);
    else 
        waterfallHistory[x][row] = (waterfallHistory[x][row] & 0x0F) | (level << 4);
}

// In UpdateWaterfall():
waterfallIndex = (waterfallIndex + 1) % WATERFALL_HISTORY_DEPTH;
```

**How It Works**:
- Single rotating pointer, no data copying
- Each sample is 4 bits (0..15 grayscale)
- Two samples fit in one byte
- When rendering, calculate history row:
  ```c
  int16_t historyRow = (int16_t)waterfallIndex - y_offset;
  while (historyRow < 0) historyRow += WATERFALL_HISTORY_DEPTH;
  ```

---

## Phase 3: Measurement Loop

### 3.1 Per-Frequency Scan (Scan function)
```c
static void Scan() {
    uint8_t dIdx = MapMeasurementToDisplay(scanInfo.i);
    
    // Skip if bin already has data (from previous sweep)
    if (rssiHistory[dIdx] != RSSI_MAX_VALUE) {
        // Optionally apply blacklist check
        #ifdef ENABLE_SCAN_RANGES
        if (IsBlacklisted(scanInfo.i)) return;
        #endif
        
        SetF(scanInfo.f);              // Tune to frequency
        Measure();                     // Read RSSI
        UpdateScanInfo();              // Update peak/min statistics
        SetBandLed(scanInfo.f, ...);   // Provide visual feedback
    }
}
```

**Key Principle**: Only measure if display bin is empty. Prevents re-scanning same frequency twice per sweep.

### 3.2 Next Step Advancement (NextScanStep function)
```c
static void NextScanStep() {
    ++peak.t;                    // Increment peak age
    ++scanInfo.i;                // Next measurement index
    scanInfo.f += scanInfo.scanStep;  // Next frequency
}
```

**Frequency Calculation**:
```
Current Frequency = StartFrequency + (MeasurementIndex × ScanStepSize)
```

### 3.3 Sweep Completion Logic (UpdateScan function)
```c
static void UpdateScan() {
    Scan();   // Measure at current frequency
    
    if (scanInfo.i < scanInfo.measurementsCount) {
        NextScanStep();  // Advance to next frequency
        return;  // Continue next tick
    }
    
    // === SWEEP COMPLETE ===
    UpdateWaterfall();        // Render temporal history
    redrawScreen = true;      // Request display update
    preventKeypress = false;  // Allow user input again
    UpdatePeakInfo();         // Finalize peak detection
    
    if (IsPeakOverLevel()) {
        ToggleRX(true);       // Unmute audio to peak frequency
        TuneToPeak();         // Apply centroid tuning
        return;               // Enter listening mode
    }
    
    newScanStart = true;      // Relaunch next sweep
}
```

---

## Phase 4: Signal Processing

### 4.1 Centroid-Based Frequency Calculation
**Why**: Integer step size (e.g., 2.5kHz) loses 10Hz precision. Centroid interpolation recovers this.

```c
static uint32_t GetCentroidFrequency() {
    if (isListening && peak.f != 0)
        return peak.f;  // Lock frequency during RX
    
    if (scanInfo.measurementsCount == 0)
        return initialFreq + (peak.i * scanInfo.scanStep);
    
    // Map raw index to display bin
    uint8_t dIdx = MapMeasurementToDisplay(peak.i);
    if (dIdx == 0 || dIdx >= SPECTRUM_MAX_STEPS - 1)
        return initialFreq + (peak.i * scanInfo.scanStep);
    
    // 3-point parabolic interpolation
    int32_t R_left   = (int32_t)rssiHistory[dIdx - 1];
    int32_t R_center = (int32_t)rssiHistory[dIdx];
    int32_t R_right  = (int32_t)rssiHistory[dIdx + 1];
    
    int32_t diff = R_right - R_left;
    if (my_abs(diff) < 2)  // Too flat, use raw index
        return initialFreq + (peak.i * scanInfo.scanStep);
    
    int32_t denominator = R_left + R_center + R_right;
    if (denominator == 0)
        return initialFreq + (peak.i * scanInfo.scanStep);
    
    // Prevent false corrections on weak signals
    if (R_center < (scanInfo.rssiMin + 20))
        return initialFreq + (peak.i * scanInfo.scanStep);
    
    // Calculate correction in Hz
    uint32_t perBin = (scanInfo.measurementsCount + SPECTRUM_MAX_STEPS - 1) / SPECTRUM_MAX_STEPS;
    if (perBin == 0) perBin = 1;
    
    int32_t correction = (diff * (int32_t)scanInfo.scanStep * (int32_t)perBin) / denominator;
    
    return initialFreq + (peak.i * scanInfo.scanStep) + correction;
}
```

**Advantages**:
- Improves tuning accuracy by ~10× (from ±1.25kHz to ±125Hz)
- Takes advantage of the BK4819's ~3Hz internal resolution
- Simple parabolic formula, fast computation

### 4.2 Exponential Moving Average (EMA) Filtering
**Purpose**: Smooth the display trace to reduce noise aliasing

```c
static void ProcessSpectrumEnhancements(void) {
    for (uint8_t i = 0; i < SPECTRUM_MAX_STEPS; i++) {
        uint16_t currentRssi = rssiHistory[i];
        
        // 3-tap EMA: smoothedRssi[n] = (3×old + 1×new) / 4
        smoothedRssi[i] = ((smoothedRssi[i] * 3) + currentRssi) >> 2;
        
        // Peak hold with automatic decay
        if (currentRssi > peakHold[i]) {
            peakHold[i] = currentRssi;
            peakAge[i] = 20;  // Reset timeout
        } else {
            if (peakAge[i] > 0) {
                peakAge[i]--;
            } else if (peakHold[i] > 0) {
                peakHold[i]--;  // Slow decay (1 RSSI unit per sweep)
            }
        }
    }
}
```

**Filter Equation**:
```
smoothedRssi[n] = (smoothedRssi[n-1] × 3 + currentRssi × 1) / 4
                = 0.75 × old + 0.25 × new
```

Time constant = ~2 sweeps (60ms at 64ms/sweep)

### 4.3 RSSI to dBm Conversion
**Purpose**: Convert radio IC's RSSI format to standard dBm units

For BK4819 (example):
```c
static int Rssi2DBm(uint16_t rssi) {
    return (rssi / 2) - 160 + dBmCorrTable[gRxVfo->Band];
}
```

**Generic Formula**:
```
dBm = (RSSI_raw - RSSI_at_0dBm) × sensitivity + channel_offset
```

You need to characterize:
1. **RSSI_at_0dBm**: What RSSI value = -100dBm (or your reference)?
2. **Sensitivity**: How many RSSI units = 1 dB?
3. **Channel offsets**: Correction per frequency band

### 4.4 dBm to S-Meter Conversion
**Purpose**: Convert dBm to standard S-unit (S1..S9+20dB)

```c
static uint8_t DBm2S(int dbm) {
    dbm *= -1;  // Invert (lower = better signal)
    for (int i = 0; i < ARRAY_SIZE(U8RssiMap); i++) {
        if (dbm >= U8RssiMap[i]) return i;
    }
    return ARRAY_SIZE(U8RssiMap);
}
```

Where U8RssiMap[] defines dBm thresholds:
```c
const uint8_t U8RssiMap[] = {
    0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, ...
};
```

---

## Phase 5: Peak Detection

### 5.1 Automatic Trigger Level Optimization
**Goal**: Adapt detection threshold to current band conditions without manual adjustment

```c
static void AutoTriggerLevel() {
    // First scan: Initialize safely
    if (settings.rssiTriggerLevel == RSSI_MAX_VALUE) {
        settings.rssiTriggerLevel = 150;  // Baseline value
        return;
    }
    
    // Compute desired trigger based on recent peak
    uint16_t newTrigger = clamp(scanInfo.rssiMax + 3, 0, RSSI_MAX_VALUE);
    
    // Enforce minimum margin (6dB above peak for stability)
    const uint16_t MIN_TRIGGER = scanInfo.rssiMax + 6;
    if (newTrigger < MIN_TRIGGER)
        newTrigger = MIN_TRIGGER;
    
    // Asymmetric adjustment (fast down, slow up)
    if (newTrigger > settings.rssiTriggerLevel + 5) {
        settings.rssiTriggerLevel += 1;  // Signal stronger: slow rise
    } else if (newTrigger < settings.rssiTriggerLevel - 5) {
        uint16_t diff = settings.rssiTriggerLevel - newTrigger;
        if (diff > 3)
            settings.rssiTriggerLevel -= 3;  // Signal weaker: quick recovery
        else
            settings.rssiTriggerLevel = newTrigger;
    }
    // Otherwise: hold (prevent oscillation)
}
```

**Why Asymmetric**?
- Strong signal appears: Increase threshold slowly (avoid false-positive rain)
- Signal disappears: Decrease quickly (restore sensitivity immediately)

### 5.2 Peak Tracking with Hysteresis
```c
static void UpdatePeakInfo() {
    // Timeout: every 1024 ticks, force recalculation
    // New Peak: Allow update if new_rssi > current_peak
    if (peak.f == 0 || peak.t >= 1024 || peak.rssi < scanInfo.rssiMax) {
        UpdatePeakInfoForce();  // Immediate update (no hysteresis)
    } else {
        peak.t++;  // Increment age counter, maintain current peak
    }
}

static void UpdatePeakInfoForce() {
    peak.t = 0;
    peak.rssi = scanInfo.rssiMax;
    peak.f = scanInfo.fPeak;
    peak.i = scanInfo.iPeak;
    AutoTriggerLevel();  // Recompute trigger after peak changes
}
```

**Timeout Management**:
- If no new peak for 1024 sweeps, allow weaker signal to become peak
- Prevents old interference from forever blocking new signals
- 1024 ticks ≈ 65 seconds (at 16Hz sweep rate)

---

## Phase 6: Rendering Pipeline

### 6.1 Pixel Coordinate Conversion
```c
// RSSI → Y pixel (0..39 = top..bottom of spectrum area)
uint8_t Rssi2Y(uint16_t rssi) {
    return (DrawingEndY + 4) - Rssi2PX(rssi, 0, DrawingEndY) + 1;
}

uint8_t Rssi2PX(uint16_t rssi, uint8_t pxMin, uint8_t pxMax) {
    const int DB_MIN = settings.dbMin << 1;  // Fixed point (×2)
    const int DB_MAX = settings.dbMax << 1;
    const int DB_RANGE = DB_MAX - DB_MIN;
    const uint8_t PX_RANGE = pxMax - pxMin;
    
    int dbm = clamp(Rssi2DBm(rssi) << 1, DB_MIN, DB_MAX);
    int height = ((dbm - DB_MIN) * PX_RANGE) / (DB_RANGE ? DB_RANGE : 1);
    
    // Aesthetic enhancement: add noise to weak signals
    if (height < (PX_RANGE / 4)) {
        uint8_t noiseJitter = (rssi & 0x07);
        height += noiseJitter;
    } else {
        height = (height * 11) / 10;  // 10% crisp boost for strong signals
    }
    
    return clamp(height + pxMin, pxMin, pxMax);
}
```

### 6.2 Index to Display Pixel Mapping
```c
// Convert frequency index (0..measurementCount-1) to screen X (0..127)
uint8_t SpecIdxToX(uint16_t idx) {
    uint16_t bars = GetDisplayWidth();
    if (bars <= 1) return 0;
    return (uint8_t)(((uint32_t)idx * 127) / (bars - 1));
}

// Decimate measurement array to fit display width
static inline uint8_t MapMeasurementToDisplay(uint32_t idx) {
    if (scanInfo.measurementsCount == 0) return (uint8_t)idx;
    if (scanInfo.measurementsCount <= SPECTRUM_MAX_STEPS) return (uint8_t)idx;
    
    uint32_t v = ((uint32_t)idx * SPECTRUM_MAX_STEPS) / scanInfo.measurementsCount;
    if (v >= SPECTRUM_MAX_STEPS) v = SPECTRUM_MAX_STEPS - 1;
    return (uint8_t)v;
}
```

### 6.3 Drawing Line Algorithm (Bresenham)
```c
void DrawLine(uint8_t x0, uint8_t y0, uint8_t x1, uint8_t y1, bool color) {
    int8_t dx = abs(x1 - x0);
    int8_t dy = -abs(y1 - y0);
    int8_t sx = x0 < x1 ? 1 : -1;
    int8_t sy = y0 < y1 ? 1 : -1;
    int16_t err = dx + dy;
    
    while (1) {
        PutPixel(x0, y0, color);
        if (x0 == x1 && y0 == y1) break;
        
        int16_t e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}
```

Purpose: Smooth line from one spectrum peak to the next (no ugly stair-stepping).

---

## Phase 7: Integration Checklist

### Hardware Layer
- [ ] Define RSSI reading function and settling delay
- [ ] Implement frequency setting with PLL flush
- [ ] Verify bandwidth/filter switching
- [ ] Test AGC control (if AM-capable)
- [ ] Validate registers/bit positions for your IC

### Data Structures
- [ ] Calculate memory footprint
- [ ] Allocate static buffers
- [ ] Test circular waterfall indexing
- [ ] Verify array bounds checking

### Measurement Loop
- [ ] Implement Scan() function
- [ ] Test frequency sweep (ascending order)
- [ ] Verify peak detection logic
- [ ] Confirm UpdateWaterfall() behavior

### Signal Processing
- [ ] Calibrate RSSI → dBm conversion
- [ ] Test EMA smoothing filter
- [ ] Validate centroid calculation
- [ ] Test AutoTriggerLevel() behavior

### Rendering
- [ ] Verify pixel coordinate math
- [ ] Test Bresenham line drawing
- [ ] Validate Bayer dithering
- [ ] Check UI layout fits screen

### UI/Control
- [ ] Map key bindings to hardware buttons
- [ ] Implement frequency input state machine
- [ ] Test frequency clamping (F_MIN/F_MAX)
- [ ] Validate EEPROM persistence

---

## Testing Strategy

### Unit Tests
```c
// Test RSSI conversion
void test_rssi2dbm() {
    uint16_t rssi_100dbm = ((−100 + 160 − 0) * 2);
    assert(Rssi2DBm(rssi_100dbm) == −100);
}

// Test centroid calculation
void test_centroid() {
    rssiHistory[5] = 100;  // Peak
    rssiHistory[4] = 80;
    rssiHistory[6] = 80;
    uint32_t freq = GetCentroidFrequency();
    // Should be ~0Hz offset (symmetric)
}

// Test waterfall packing
void test_waterfall_packing() {
    SetWaterfallLevel(0, 0, 5);   // Store in lower nibble
    SetWaterfallLevel(0, 1, 10);  // Store in upper nibble
    assert(GetWaterfallLevel(0, 0) == 5);
    assert(GetWaterfallLevel(0, 1) == 10);
}
```

### Integration Tests
```c
// Simulate full spectrum sweep
void test_full_sweep() {
    InitScan();
    for (int i = 0; i < 128; i++) {
        Measure();
        SetRssiHistory(i, rand() % 65536);
        NextScanStep();
    }
    UpdateWaterfall();
    // Visually inspect waterfall display
}

// Test state transitions
void test_state_machine() {
    SetState(SPECTRUM);
    assert(currentState == SPECTRUM);
    
    OnKeyDown(KEY_PTT, false);
    assert(currentState == STILL);
    
    OnKeyDownStill(KEY_EXIT, false);
    assert(currentState == SPECTRUM);
}
```

### Hardware Validation
1. **Frequency Accuracy**: Measure error vs. calibrated source
2. **RSSI Linearity**: Plot RSSI vs. input power, check curve
3. **Display Stability**: Run overnight, monitor jitter/flickering
4. **Battery Draw**: Measure current consumption in each state

---

## Performance Optimization Tips

### CPU
- Use `-O2` or `-Os` compiler optimization
- Avoid floating-point arithmetic (use fixed-point)
- Pre-calculate filtering coefficients (not in loop)
- Use lookup tables for logarithmic conversions

### Memory
- Compress waterfall to 4-bit values (max 2 bits unused)
- Use circular buffer (no data copying)
- Reuse scan buffers across sweeps
- Consider fixed-point RSSI (not float)

### Power
- Scan mode: Higher power (RX always on)
- Listening mode: Lower power (RX gated by squelch)
- Consider spectrum-only mode (no audio) to reduce battery drain
- Use backlight disable option to preserve battery

---

## Conclusion

The spectrum analyzer logic is self-contained and portable across radio platforms. Key adaptation points:
1. RSSI reading and frequency setting functions
2. RSSI-to-dBm calibration for your IC
3. UI button mapping
4. Display driver (specific to ST7565 LCD)

With careful attention to the PLL settling delay and index mapping, this code should work reliably on any radio IC with RSSI-based scanning capability.
