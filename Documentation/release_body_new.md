# N7SIX ApeX Edition v7.6.10

Firmware release **v7.6.10** for the Quansheng UV-K5 series.

- **Build commit:** `504e58f` (visible on the radio under `SysInf` → `BUILD`)
- **Memory usage:**

```
Memory Region      Used Size  Region Size   % Used
FLASH                61280        61440     99.74%
RAM                   3372         8192     41.16%
```

---

## What's New

### 1. UI/UX Enhancements
Adopted the UI/UX from the UV-K1's latest **Fusion** by Armel (F4HWN):
- Modernized interface patterns and improved menu navigation
- Paginated `SysInf` page (identity → BUILD info → battery status) with deterministic navigation
- Visual consistency across menus

### 2. 2-Point Battery Calibration
New battery calibration implementation for accurate state-of-charge estimation:
- **Low-point** and **high-point** reference calibration for accurate percentage mapping across the full discharge curve
- Curve-fitting approach provides precise voltage-to-percentage conversion at all battery levels
- Accessible via the **BatCal** menu in `SysInf`; persists in **EEPROM** across power cycles
- Improved battery voltage, health, and remaining-capacity reporting in the `SysInf` battery page

### 3. Waterfall Disabled (Temporary)
- **Reason:** FLASH space constraint — the image sits at 61,280 B against the 61,440 B flasher limit (99.74%)
- **Impact:** Only the temporal waterfall display layer is disabled; the **spectrum analyzer remains fully functional**
- **Future:** Will be re-enabled once ample FLASH space is reclaimed through further optimization

### 4. SysInf BUILD Page — Git Commit ID Now Embedded
- The `BUILD` page in `SysInf` now displays the **actual git commit hash** the firmware was built from (e.g. `504e58f`) instead of a hardcoded `N/A`
- Makes it easy to verify exactly which revision is flashed on the radio
- CI (`Build Firmware` workflow) and the Docker build scripts pass the hash automatically; builds without git metadata still compile and fall back to `N/A`

---

## Installation

1. Download `n7six.ApeX-k5.v7.6.10.packed.bin` below
2. Flash it with [UVTools](https://n7six.github.io/UVTools/) or your preferred flashing tool
3. Verify the installed revision under `SysInf` → `BUILD` (should show `504e58f`)

## Assets

| File | Description |
|------|-------------|
| `n7six.ApeX-k5.v7.6.10.packed.bin` | Packed firmware image — flash this |
| `n7six.ApeX-k5.v7.6.10.bin` | Raw binary image |

---

**Full changelog:** https://github.com/N7SIX/UV-K5Series_ApeX-Edition_v7.6.0/compare/v7.6.6...v7.6.10
