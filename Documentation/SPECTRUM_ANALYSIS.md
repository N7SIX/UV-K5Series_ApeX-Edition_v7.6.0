
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

# Deep Study: UV-K5 Spectrum Analyzer Implementation

## Executive Summary
The spectrum.c for UV-K5 is a production-grade spectrum analyzer featuring:
- Real-time RSSI measurement with 128-step resolution
- Professional waterfall display (16-level grayscale)
- Peak hold with exponential decay
- Smart auto-trigger level optimization
- Multi-state UI (SPECTRUM, STILL, FREQ_INPUT)
- Persistent settings via EEPROM
- Advanced audio-reactive effects for listening mode

---

## Architecture Overview

### Core Components

#### 1. **State Machine (3 States)**
```
SPECTRUM      → Real-time band scanning with live waterfall
    ↓
STILL        → Tuned to peak frequency with detailed signal meter
    ↓
FREQ_INPUT   → Manual frequency entry (8 digits)
```

#### 2. **Data Flow Pipeline**
```
Hardware BK4819 RSSI
    ↓ (GetRssi)
Measure() → RSSI reading with 400µs PLL settling delay
    ↓ (SetRssiHistory)
rssiHistory[128] → Raw measurement buffer, max-hold per display bin
    ↓ (MapMeasurementToDisplay)
Decimation logic (handles multi-measurement to single display pixel)
    ↓ (ProcessSpectrumEnhancements)
smoothedRssi[128] → 3-tap exponential moving average filter
peakHold[128] → Peak tracking with adaptive decay
    ↓ (DrawSpectrumEnhanced)
Visual rendering: Wire + shaded area + peak dots
```

#### 3. **Key Data Structures**

**Peak Information (peak)**
- `rssi`: Current maximum RSSI in scan
- `f`: Centroid-calculated frequency of peak
- `i`: Raw measurement index of peak
- `t`: Age counter for timeout management

**Scan Information (scanInfo)**
- `f`: Current sweep frequency
- `i`: Current measurement index (0..127)
- `rssi`: RSSI at current frequency
- `rssiMin/Max`: Floor and ceiling from current scan
- `measurementsCount`: How many steps are in this scan
- `scanStep`: Frequency increment (10Hz units)

**Settings (settings)**
- `scanStepIndex`: S_STEP_25_0kHz to S_STEP_100_0kHz
- `stepsCount`: Resolution multiplier (STEPS_128 → STEPS_16)
- `frequencyChangeStep`: User-adjustable frequency offset
- `rssiTriggerLevel`: Detection threshold
- `dbMin/dbMax`: Display range in dBm
- `modulationType`: FM/AM/USB/LSB
- `listenBw`: RX audio bandwidth

---

## Core Functions Deep Dive

### 1. **Measurement Loop: Measure()**
**Purpose:** Read RSSI from BK4819 hardware
```
Key Steps:
1. SYSTEM_DelayUs(400) → Wait for PLL settling
2. GetRssi() → Read BK4819 register 0x63
3. AM_fix adjustment (if ENABLE_AM_FIX)
4. SetRssiHistory() → Record in history buffer
```

**Critical Detail:** 400µs delay is mandatory. Without it, frequency changes don't stabilize.

### 2. **Frequency Calculation: GetCentroidFrequency()**
**Purpose:** Pinpoint-accurate frequency from peak detection
```
Algorithm:
1. If already listening on peak → return locked frequency (prevents flutter)
2. If peak has valid neighbors → 3-point parabolic centroid
   - Uses rssiHistory[dIdx-1], [dIdx], [dIdx+1]
   - Calculates correction = (R_right - R_left) / (R_left + R_center + R_right)
   - Applies per-measurement scaling
3. Fallback to raw peak index if insufficient data
```

**Why It Works:** Interpolation between display pixels gives 10Hz-level precision.

### 3. **RSSI Display Conversion: Rssi2Y()**
**Purpose:** Convert RSSI to pixel Y coordinate
```
Process:
1. Rssi2DBm() → Convert raw RSSI (ratio) to dBm
2. Clamp to [dbMin, dbMax] display range
3. Rssi2PX() → Linear interpolation to pixels (0..39)
4. Add noise "grass" for aesthetic appeal:
   - Near noise floor (<25% range): Use LSBs for jitter
   - Strong signals (>25% range): 10% boost for crispness
5. Return final Y pixel (0=top, 39=bottom)
```

### 4. **Waterfall Management: UpdateWaterfall()**
**Purpose:** Store signal strength history for temporal visualization
```
Buffer Structure:
- waterfallHistory[128][8] → 128 frequencies × 16 depth (packed 2 per byte)
- waterfallIndex → Circular counter (0..15)
- Each column holds 16 historical snapshots

Process:
1. Advance circular buffer pointer
2. Analyze rssiHistory for min/max dynamic range
3. Map each RSSI to 0..15 grayscale level
4. Apply hysteresis (prevent flicker on weak signals)
5. Store in packed nibble format (4 bits per sample)
```

**Memory Optimization:** Uses 1 byte per 2 samples instead of 1 byte per sample.

### 5. **Peak Tracking: UpdatePeakInfo()**
**Purpose:** Maintain current peak with intelligent hold and timeout
```
Decay Strategy:
1. If timeout ≥ 1024 ticks → Allow new peak detection
2. If (new RSSI) > (current peak) → Immediate update
3. Otherwise → Increment age counter (prevents flutter on noise)

AutoTriggerLevel() Behavior:
- First scan: Set trigger = 150 RSSI units
- Subsequent scans: 
  - If signal stronger: Increment by 1 unit/scan (slow rise)
  - If signal weaker: Decrement by 3 units/scan (fast recovery)
  - Maintains minimum 6dB margin above peak
```

---

## UI/Control Flow

### State Transitions
```
APP_RunSpectrum()
    ↓ (Enter SPECTRUM mode)
Tick() [Main Loop]
    ├─ HandleUserInput()
    │   ├─ KEY_5 short → Frequency input OR toggle grid
    │   ├─ KEY_5 long (>16 ticks) → Toggle grid display
    │   ├─ KEY_UP/DOWN → Adjust center frequency
    │   ├─ KEY_1/7 → Change scan step (finer/coarser)
    │   ├─ KEY_2/8 → Adjust frequency offset
    │   ├─ KEY_3/9 → Zoom in/out (dbMax adjustments)
    │   ├─ KEY_0 → Cycle modulation (FM/AM/USB/LSB)
    │   ├─ KEY_6 → Change RX bandwidth
    │   ├─ KEY_PTT → Lock to peak (enter STILL mode)
    │   ├─ KEY_SIDE1 → Blacklist current peak
    │   └─ KEY_EXIT → Return to main radio
    │
    ├─ UpdateScan() [SPECTRUM mode]
    │   ├─ Scan() [per-frequency measurement]
    │   ├─ NextScanStep() [advance to next frequency]
    │   ├─ UpdateWaterfall() [after complete sweep]
    │   └─ UpdatePeakInfo() → AutoTriggerLevel()
    │
    ├─ UpdateStill() [STILL mode]
    │   ├─ Measure() [continuous RSSI reading]
    │   └─ Display S-meter and dBm
    │
    ├─ UpdateListening() [Active RX reception]
    │   ├─ Measure() every tick
    │   ├─ UpdateWaterfallQuick() [buffering only, no recompute]
    │   └─ Every 6 ticks: Render with audio-reactive pulsing
    │
    ├─ Tick() → Render() → ST7565_BlitFullScreen()
    │
    └─ Loop until isInitialized = false (EXIT pressed)
```

### Key Handlers
**OnKeyDown()** - Spectrum mode controls (adjust scan, zoom, frequency offset)
**OnKeyDownStill()** - Lock-mode controls (register tuning for advanced users)
**OnKeyDownFreqInput()** - Numeric entry (0-9, backspace, commit)

---

## Drawing Pipeline

### Render Order (RenderSpectrum)

1. **Clear Rows 1-5** (memset to 0, removes old data)

2. **ProcessSpectrumEnhancements()**
   - Apply 3-tap EMA smoothing to rawRSSI → smoothedRssi
   - Perform peak-hold decay (90% retention per sweep)
   - Increment peak age counter

3. **Grid/Ruler** (DrawTicks or DrawGridBackground)
   - Frequency tick marks at 16-pixel intervals
   - Center mode: Vertical line at pixel 64
   - Span mode: Start/stop frequency markers

4. **Arrow Marker** (DrawArrow)
   - 5×3 solid triangle at peak frequency position

5. **Spectrum Wire + Shade** (DrawSpectrumEnhanced)
   - Line from peak to peak using Bresenham algorithm
   - Diagonal hatch fill below wire (dither pattern)
   - Peak-hold dots as individual pixels above trace

6. **Trigger Level Indicator** (DrawRssiTriggerLevel)
   - Two 5-pixel right-pointing triangles (left/right edges)
   - Indicates squelch threshold

7. **Frequency Display** (DrawF)
   - Peak frequency (8 digits: MHz.KHz format)
   - Modulation type (FM/AM/USB/LSB)
   - RX audio bandwidth

8. **Numeric Info** (DrawNums)
   - Step count (128x, 64x, etc.)
   - Scan step size
   - Center frequency or start/stop (mode-dependent)
   - Frequency offset (±600.00k)

9. **Waterfall** (DrawWaterfall)
   - 16 rows of history, fading toward top
   - Bayer 4×4 matrix dithering for grayscale effect

10. **Status Bar** DrawStatus (separate render call)
    - dBm range display
    - Battery indicator

---

## Advanced Features

### 1. **Calibration Table**
```c
CalibrationPoint calTable[] = {
    {13600000, -2},  // 136 MHz: -2dB correction
    {14400000,  0},  // 144 MHz: Reference (0dB)
    {20000000,  3},  // 200 MHz: +3dB boost
    ...
}
```
Applied in UpdateStill() to correct hardware gain variation across bands.

### 2. **AM-Fix Integration (ENABLE_AM_FIX)**
If modulation is AM, applies additional gain compensation from am_fix_get_gain_diff() to account for BK4819's AM demodulation loss.

### 3. **Audio-Reactive Display (Listening Mode)**
When a signal is detected:
- Sample RX audio envelope (0..63) from BK4819 AFT register
- Scale to pulse amplitude (0..16)
- Apply multiplicative boost to peak region (1.0 to ~5.0×)
- Apply smaller boost to noise grass (1.0 to ~3.0×)
- Creates "heartbeat" visual effect synced to signal modulation

### 4. **Persistent Settings (EEPROM)**
- Address: 0x1E80 (16 bytes, SPECTRUM_EEPROM_ADDR)
- Stores: scanStepIndex, stepsCount, listenBw, frequencyChangeStep, dbMin/dbMax
- Auto-loads on startup, auto-saves on EXIT
- Includes CRC verification to detect corruption

---

## Performance Characteristics

### CPU Cycles per Tick
- **Spectrum Scan**: ~500µs per frequency (including 400µs PLL delay)
  - With 128 steps = 64ms per complete sweep
- **Listening**: Negligible (just RSSI reads + quick waterfall advance)
- **Display Render**: ~50ms (ST7565 SPI transfer is the bottleneck)

### Memory Profile
- **Static Buffers**: 
  - rssiHistory[128]: 256 bytes
  - waterfallHistory[128×8]: 1024 bytes
  - peakHold[128] + peakAge[128]: 384 bytes
  - Register backup stack: 14 bytes
  - **Total ≈ 1.7 KB** (comfortable on UV-K5's 8KB SRAM)

### Battery Impact
- Peak power draw: 150mA (radio RX + backlight)
- Scan mode drains faster due to continuous RX
- Listening mode minimal overhead (idle waiting for squelch)

---

## Key Implementation Decisions

### 1. **Why 400µs PLL Delay?**
BK4819 needs ~400µs for VCO to stabilize after frequency change. Shorter delays produce unstable RSSI readings.

### 2. **Why 3-Point Centroid?**
More accurate than simple peak detection and avoids integer frequency rounding errors. Provides ~10Hz resolution.

### 3. **Why Adaptive Peak Hold Decay?**
- 90% retention per sweep prevents false peak memory
- Slow exponential decay creates natural "trail" effect
- Timeout at 1024 ticks allows weak signals to build up without old peaks interfering

### 4. **Why Two Waterfall Update Paths?**
- Full UpdateWaterfall() during scans (recomputes dynamic range, applies hysteresis)
- Quick UpdateWaterfallQuick() during listening (only advances buffer pointer, preserves last good data)
- Prevents waterfall from "freezing" while listening but reduces CPU load

### 5. **Why Scan-Step-Based Auto-Adjust?**
AutoTriggerLevel() is called once per complete sweep, not per tick. This prevents:
- Chasing noise (threshold wouldn't have time to settle)
- Fighting manual adjustments (user changes don't get immediately overridden)
- CPU thrashing (math only runs 15× per second, not 1000× per second)

---

## Critical Bugs to Watch For

1. **Peak Index Mapping**: raw peak.i must be mapped through MapMeasurementToDisplay() before using in display coordinates
2. **Waterfall Circular Buffer**: historyRow must be adjusted with modulo arithmetic or index wraps incorrectly
3. **Frequency Stability**: Without SYSTEM_DelayUs(400), spectrum becomes jittery
4. **EEPROM Checksum**: Failure to verify CRC allows corrupted settings to persist
5. **rssiHistory Clearing**: When exiting listening mode, must clear rssiHistory or spectrum appears frozen

---

## Extension Points for Future Improvements

### 1. **Intelligent Noise Floor Estimation**
Current approach: uses minimum RSSI from last scan. Could implement:
- Kalman filter for moving average
- Spectral subtraction for noise removal
- Adaptive thresholding per frequency band

### 2. **Signal Classification**
- Detect FM modulation tail (CxCSS)
- Distinguish CTCSS/DCS encoded signals
- Auto-identify APRS packets

### 3. **Memory Recording**
- Store waterfall history to flash (EEPROM)
- Analyze signal patterns over time
- Generate spectral reports

### 4. **Multi-Band Monitoring**
- Sequential monitoring of multiple VFO regions
- Automated band-switching
- Priority queue for detected signals

### 5. **Dual-Display Mode**
- Split-screen spectrum + waterfall
- Real-time frequency-domain information on one side
- Real-time amplitude on the other

---

## Conclusion

This spectrum analyzer represents a significant engineering effort:
- **Real-time performance**: Balances precision (10Hz tuning) with speed (64ms full sweep)
- **Memory efficiency**: Uses only 1.7KB despite 128-step history
- **User experience**: Intelligent automation (auto-trigger) with manual override (frequency offset, threshold adjustment)
- **Professional features**: Centroid tuning, peak hold decay, waterfall visualization, audio-reactive display

The code is well-structured, with clear separation of concerns (measurement vs. rendering vs. UI handling), making it maintainable and extensible.
