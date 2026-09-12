# UV-K5 ApeX Edition - Professional File Header Standard

**Effective:** March 24, 2026 10:00 PM onwards  
**Applies To:** All new .c and .h files  
**Status:** MANDATORY

---

## Standard Header Template

All newly created C source and header files must include this professional header. Use the example below as your template.

### Template Structure

```c
/**
 * =====================================================================================
 * @file        {FILENAME}
 * @brief       {ONE_LINE_DESCRIPTION}
 * @author      N7SIX (Professional Enhancements, 2025-2026)
 * @version     v7.6.0 (ApeX Edition)
 * @license     Apache License, Version 2.0
 * * "Bringing professional signal analysis to the palm of your hand."
 * =====================================================================================
 * * ARCHITECTURAL OVERVIEW:
 * {DETAILED_MODULE_DESCRIPTION}
 *
 * MAJOR FEATURES/ENHANCEMENTS:
 * ----------------------------
 * - {FEATURE_1}: Concise description
 * - {FEATURE_2}: Concise description
 * - {FEATURE_3}: Concise description
 *
 * TECHNICAL SPECIFICATIONS:
 * -------------------------
 * - {SPEC_1}: Details (units, ranges, performance metrics)
 * - {SPEC_2}: Details (units, ranges, performance metrics)
 * - {SPEC_3}: Details (units, ranges, performance metrics)
 *
 * =====================================================================================
 */
```

---

## Field Reference

### Required Fields

| Field | Format | Rules | Example |
|-------|--------|-------|---------|
| @file | `{filename}` | Exact filename with extension | `waterfall.c` |
| @brief | One sentence | ≤80 chars, professional tone | `Advanced Waterfall Display with Persistence` |
| @author | Fixed text | Always: "N7SIX (Professional Enhancements, 2025-2026)" | Copy as-is |
| @version | Fixed text | Always: "v7.6.0 (ApeX Edition)" | Copy as-is |
| @license | Fixed text | Always: "Apache License, Version 2.0" | Copy as-is |
| Tagline | Fixed text | "Bringing professional signal analysis to the palm of your hand." | Copy as-is |

### Content Sections

#### ARCHITECTURAL OVERVIEW
- **Purpose:** Explain what this module does and how it fits into the system
- **Length:** 3-6 sentences
- **Tone:** Technical but accessible
- **Include:** Primary responsibilities, key algorithms, integration points

**Example:**
```
This module implements a high-performance waterfall display with 16-level 
grayscale rendering and temporal persistence for signal history visualization. 
It processes RSSI data in real-time without interrupting RX reception and 
adapts the color palette based on signal strength.
```

#### MAJOR FEATURES/ENHANCEMENTS
- **Purpose:** Highlight key capabilities and improvements
- **Count:** Minimum 3 features
- **Format:** Bullet list with feature name and brief description
- **Details:** What makes this implementation special/optimized

**Example:**
```
- GRAYSCALE RENDERING: 16-level visual depth for professional signal texture
- TEMPORAL PERSISTENCE: Signal history retention across frame updates
- BACKGROUND PROCESSING: Non-blocking RSSI sample collection during RX
- ADAPTIVE COLORING: Dynamic palette adjustment based on signal strength
```

#### TECHNICAL SPECIFICATIONS
- **Purpose:** Document hardware/software details, metrics, constraints
- **Count:** Minimum 3 specifications
- **Format:** Bullet list with spec name and detailed metric
- **Include:** Memory usage, performance, resolution, precision, constraints

**Example:**
```
- DISPLAY RESOLUTION: 128x64 ST7565 LCD with bank-based memory mapping
- COLOR DEPTH: 16 grayscale levels per pixel for visual fidelity
- REFRESH RATE: 30Hz at 10Hz step scanning for fluid updates
- MEMORY FOOTPRINT: ~512 bytes SRAM for history buffer
- DYNAMIC RANGE: 16-bit RSSI processing with EMA filtering
```

---

## Complete Example: New Module (waterfall.c)

```c
/**
 * =====================================================================================
 * @file        waterfall.c
 * @brief       Advanced Waterfall Display Engine with Temporal Signal History
 * @author      N7SIX (Professional Enhancements, 2025-2026)
 * @version     v7.6.0 (ApeX Edition)
 * @license     Apache License, Version 2.0
 * * "Bringing professional signal analysis to the palm of your hand."
 * =====================================================================================
 * * ARCHITECTURAL OVERVIEW:
 * This module implements a high-performance waterfall display with 16-level grayscale
 * rendering and temporal persistence for advanced signal visualization. It processes
 * RSSI data collected from the BK4819 in real-time without interrupting active RX
 * reception. The waterfall maintains a scrolling history of signal activity with
 * adaptive color mapping based on signal strength dynamics.
 *
 * MAJOR FEATURES/ENHANCEMENTS:
 * ----------------------------
 * - ADVANCED VISUALS: 16-level grayscale waterfall with temporal persistence
 * - BACKGROUND PROCESSING: Non-blocking RSSI collection with automatic buffering
 * - ADAPTIVE RENDERING: Dynamic color palette based on signal strength histogram
 * - HISTORY MANAGEMENT: Circular buffer with configurable retention window
 * - INTEGRATION: Seamless coordination with spectrum analyzer and RX pipeline
 *
 * TECHNICAL SPECIFICATIONS:
 * -------------------------
 * - DISPLAY ARCHITECTURE: 128x64 ST7565 LCD with bank-based memory mapping
 * - COLOR DEPTH: 16 grayscale levels per pixel for professional visualization
 * - REFRESH RATE: 30Hz waterfall scrolling at 10Hz frequency step scanning
 * - MEMORY FOOTPRINT: ~512 bytes SRAM for history buffer (compatible with UV-K5/K6)
 * - RSSI PROCESSING: 16-bit dynamic range with exponential moving average filtering
 * - TEMPORAL WINDOW: Configurable history depth (default: 64 frames = ~2.1 seconds)
 *
 * =====================================================================================
 */
```

---

## Another Example: Header File (waterfall.h)

```c
/**
 * =====================================================================================
 * @file        waterfall.h
 * @brief       Waterfall Display Engine - Public Interface and Types
 * @author      N7SIX (Professional Enhancements, 2025-2026)
 * @version     v7.6.0 (ApeX Edition)
 * @license     Apache License, Version 2.0
 * * "Bringing professional signal analysis to the palm of your hand."
 * =====================================================================================
 * * ARCHITECTURAL OVERVIEW:
 * This header defines the public interface for the waterfall display subsystem,
 * including data structures for waterfall state management, rendering parameters,
 * and API functions for initialization, updates, and configuration. It provides
 * clear abstraction between the rendering engine and calling modules.
 *
 * MAJOR FEATURES/ENHANCEMENTS:
 * ----------------------------
 * - TYPE DEFINITIONS: Structured waterfall configuration and state management
 * - API EXPORTS: Clear public interface for display control and data updates
 * - MEMORY MAPPING: Optimized buffer structures for SRAM efficiency
 * - CONFIGURATION: Runtime-adjustable persistence, color, and refresh parameters
 *
 * TECHNICAL SPECIFICATIONS:
 * -------------------------
 * - MAX_HISTORY_DEPTH: 64 frames for temporal signal retention
 * - COLOR_LEVELS: 16 distinct grayscale values for visual representation
 * - BUFFER_SIZE: 512 bytes for waterfall frame storage
 * - API FUNCTIONS: 8+ public functions for complete display control
 * - DATA STRUCTURES: 5+ optimized types for efficient memory usage
 *
 * =====================================================================================
 */
```

---

## Implementation Checklist

When creating a new file, complete these steps:

- [ ] Copy the entire header template
- [ ] Replace `{FILENAME}` with actual filename (e.g., `waterfall.c`)
- [ ] Write a concise @brief (≤80 characters)
- [ ] Write ARCHITECTURAL OVERVIEW specific to this module (3-6 sentences)
- [ ] List 3+ MAJOR FEATURES/ENHANCEMENTS with specific descriptions
- [ ] List 3+ TECHNICAL SPECIFICATIONS with actual metrics/values
- [ ] Keep @author as "N7SIX (Professional Enhancements, 2025-2026)" (fixed)
- [ ] Keep @version as "v7.6.0 (ApeX Edition)" (fixed)
- [ ] Keep @license as "Apache License, Version 2.0" (fixed)
- [ ] Keep tagline exactly: "Bringing professional signal analysis to the palm of your hand."
- [ ] Verify no placeholder text remains
- [ ] Proofread for professional tone and accuracy

---

## Quality Standards

### Tone and Style
- **Professional:** Use industry-standard terminology
- **Precise:** Technical descriptions should be specific and measurable
- **Concise:** Eliminate unnecessary words while maintaining clarity
- **Complete:** Cover what, why, and how without being verbose

### Content Validation
- ✅ @brief is action-oriented and specific
- ✅ ARCHITECTURAL OVERVIEW explains system integration
- ✅ MAJOR FEATURES highlight competitive advantages/optimizations
- ✅ TECHNICAL SPECIFICATIONS include actual metrics (KB, Hz, etc.)
- ✅ All data matches actual implementation
- ✅ No generic or templated language remains

### Red Flags (Fix Before Deployment)
- ❌ Placeholder text like {FEATURE_X} remaining
- ❌ Generic descriptions that could apply to any module
- ❌ Missing metric units (memory: "few KB" instead of "512 bytes")
- ❌ Inconsistent author or version information
- ❌ Tone inconsistency (casual mixed with technical)

---

## Integration with IDE/CI

### VS Code Configuration
Add to `.vscode/settings.json` or workspace settings:
```json
{
  "files.templates": {
    "c_header": "FILE_HEADER_TEMPLATE.md"
  }
}
```

### Git Hooks (Optional)
Create `.git/hooks/pre-commit`:
```bash
#!/bin/bash
# Check for proper header in new C/H files
for file in $(git diff --cached --name-only --diff-filter=A | grep -E '\.[ch]$'); do
  if ! grep -q "@file" "$file"; then
    echo "Error: $file missing professional header"
    exit 1
  fi
done
```

---

## Questions & Answers

**Q: Can I modify the fixed fields (version, license, authors)?**  
A: No. These are standardized across ApeX Edition. Keep them exactly as specified.

**Q: What if my module doesn't have 3+ features?**  
A: Every well-designed module has at least 3 significant features. If struggling, break down capabilities more granularly.

**Q: Should the header match the file's actual implementation?**  
A: Yes, absolutely. The header must accurately describe what's in the file—no overpromising or misleading claims.

**Q: How detailed should TECHNICAL SPECIFICATIONS be?**  
A: Include metrics that a developer would need to understand constraints and capabilities. Examples: memory usage, performance targets, precision, compatibility limits.

**Q: Can I use the spectrum.c header as-is for another file?**  
A: No. Each file needs its own specific content in OVERVIEW, FEATURES, and SPECS. Only the fixed fields (@author, @version, @license, tagline) are identical across all files.

---

## Version History

| Date | Change | Effective From |
|------|--------|-----------------|
| 2026-03-24 | Standard established | 10:00 PM onwards |

---

**Status:** ACTIVE - All new files must comply with this standard.
