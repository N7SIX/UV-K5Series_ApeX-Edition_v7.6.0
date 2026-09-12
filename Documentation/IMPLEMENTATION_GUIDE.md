# UV-K5 Performance & Stability - Implementation Guide

## Quick-Start Code Examples

### 1. Fix: UART Buffer Overflow (S1)

**File:** `app/uart.c`  
**Change:** SendVersion() buffer overflow

```c
// BEFORE (Vulnerable)
static void SendVersion(void)
{
    REPLY_0514_t Reply;
    Reply.Header.ID = 0x0515;
    Reply.Header.Size = sizeof(Reply.Data);
    strcpy(Reply.Data.Version, Version);  // ❌ NO BOUNDS CHECK
    // ...
}

// AFTER (Safe)
static void SendVersion(void)
{
    REPLY_0514_t Reply;
    Reply.Header.ID = 0x0515;
    Reply.Header.Size = sizeof(Reply.Data);
    
    // Safe string copy with explicit size
    const size_t max_len = sizeof(Reply.Data.Version) - 1;
    strncpy(Reply.Data.Version, Version, max_len);
    Reply.Data.Version[max_len] = '\0';
    // ...
}
```

---

### 2. Fix: Interrupt State Management (S2)

**File:** `app/app.c`  
**Change:** Proper interrupt restoration

```c
// BEFORE (Unsafe)
#ifdef ENABLE_UART
    if (UART_IsCommandAvailable()) {
        __disable_irq();           // ❌ Global disable
        UART_HandleCommand();
        __enable_irq();            // ❌ Unconditional enable
    }
#endif

// AFTER (Safe)
#ifdef ENABLE_UART
    if (UART_IsCommandAvailable()) {
        // Save current interrupt state
        uint32_t irq_state = __get_PRIMASK();
        __disable_irq();
        
        // Critical section
        if (!UART_HandleCommand_Safe()) {
            // Log error if command processing fails
            gUART_ErrorCount++;
        }
        
        // Restore previous state
        if (!irq_state) {
            __enable_irq();
        }
    }
#endif
```

---

### 3. Fix: Frequency Input Validation (S3)

**File:** `app/main.c`  
**Change:** Prevent overflow in frequency scaling

```c
// BEFORE (Unsafe)
{
    uint32_t inputFreq = StrToUL(inputStr);
    uint8_t zerosToAdd = totalDigits - inputLength;
    for (uint8_t i = 0; i < zerosToAdd; i++) {
        inputFreq *= 10;  // ❌ Can overflow
    }
    uint32_t Frequency = inputFreq * 100;  // ❌ Can overflow
    // ... clamp to band ...
}

// AFTER (Safe)
{
    uint32_t inputFreq = StrToUL(inputStr);
    uint8_t zerosToAdd = totalDigits - inputLength;
    
    // Pre-validation: reject values that will overflow during scaling
    if (inputFreq > 999999) {
        gBeepToPlay = BEEP_500HZ_60MS_DOUBLE_BEEP_OPTIONAL;
        return;
    }
    
    // Safe scaling with overflow check
    for (uint8_t i = 0; i < zerosToAdd; i++) {
        if (inputFreq > 99999999) {  // UINT32_MAX / 10
            gBeepToPlay = BEEP_500HZ_60MS_DOUBLE_BEEP_OPTIONAL;
            return;
        }
        inputFreq *= 10;
    }
    
    // Final frequency in Hz
    uint32_t Frequency = inputFreq * 100;
    
    // Strict band validation
    if (!Frequency_IsTxAllowed(Frequency)) {
        gBeepToPlay = BEEP_500HZ_60MS_DOUBLE_BEEP_OPTIONAL;
        return;
    }
    
    // Configure with validated frequency
    gTxVfo->pTX->Frequency = Frequency;
}
```

---

### 4. New: Validation Library Header

**File:** `core/validation.h`

```c
#ifndef CORE_VALIDATION_H
#define CORE_VALIDATION_H

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

// ============================================================================
// FREQUENCY VALIDATION
// ============================================================================

/**
 * Check if frequency is within valid hardware range
 * @param freq Frequency in Hz
 * @return true if within supported range (136-520 MHz)
 */
static inline bool Frequency_IsInRange(uint32_t freq)
{
    return (freq >= 13600000) && (freq <= 52000000);
}

/**
 * Check if frequency is in an allowed TX band
 * @param freq Frequency in Hz
 * @return true if TX permitted, false otherwise
 */
bool Frequency_IsTxAllowed(uint32_t freq);

/**
 * Check if frequency is valid for RX
 * @param freq Frequency in Hz
 * @return true if RX permitted, false otherwise
 */
bool Frequency_IsRxAllowed(uint32_t freq);

// ============================================================================
// EEPROM VALIDATION
// ============================================================================

/**
 * Validate EEPROM access parameters
 * @param offset Starting address (must be 8-byte aligned)
 * @param size   Number of bytes (must be 8, 16, 32, etc.)
 * @return true if valid, false if would cause out-of-bounds access
 */
bool EEPROM_IsValidAccess(uint16_t offset, uint16_t size);

/**
 * Validate EEPROM region is not protected
 * @param offset Starting address
 * @param size   Number of bytes
 * @return true if not in protected region
 */
bool EEPROM_IsUnprotected(uint16_t offset, uint16_t size);

// ============================================================================
// INPUT VALIDATION
// ============================================================================

/**
 * Validate DTMF string format
 * Valid characters: 0-9, A-D, *, #
 * @param str    DTMF string
 * @param maxlen Maximum length allowed
 * @return true if valid format
 */
bool Input_DTMFIsValid(const char *str, size_t maxlen);

/**
 * Validate frequency input string
 * Format: "XXX.XXXXX" MHz
 * @param str Input string
 * @return true if valid format
 */
bool Input_FrequencyIsValid(const char *str);

/**
 * Parse frequency string safely with bounds checking
 * @param str        Input string (e.g., "146.520")
 * @param out_freq   Pointer to output frequency (Hz)
 * @return true if successfully parsed, false on error
 */
bool Input_FrequencyParse(const char *str, uint32_t *out_freq);

// ============================================================================
// BUFFER VALIDATION
// ============================================================================

/**
 * Safe string copy with template and automatic null termination
 * @param dest       Destination buffer
 * @param dest_size  Size of destination buffer
 * @param src        Source string/buffer
 * @param src_size   Maximum bytes to copy from source
 * @return Number of bytes copied (not including null terminator)
 */
static inline size_t StringCopy_Safe(char *dest, size_t dest_size,
                                     const char *src, size_t src_size)
{
    if (!dest || dest_size == 0 || !src) return 0;
    
    size_t copy_len = (src_size < (dest_size - 1)) ? src_size : (dest_size - 1);
    memcpy(dest, src, copy_len);
    dest[copy_len] = '\0';
    return copy_len;
}

#endif // CORE_VALIDATION_H
```

---

### 5. New: Atomic Access Helper

**File:** `core/atomic.h`

```c
#ifndef CORE_ATOMIC_H
#define CORE_ATOMIC_H

#include <stdint.h>
#include "ARMCM0.h"

// ============================================================================
// ATOMIC OPERATIONS FOR SHARED STATE
// ============================================================================

/**
 * Read value from volatile variable with interrupt protection
 * Use this for flags that might be written in ISR
 * @param ptr Pointer to volatile variable
 * @return Current value, safely read
 */
static inline uint32_t Atomic_Read32(volatile uint32_t *ptr)
{
    uint32_t state = __get_PRIMASK();
    __disable_irq();
    uint32_t value = *ptr;
    if (!state) __enable_irq();  // Restore previous state
    return value;
}

/**
 * Write value to volatile variable with interrupt protection
 * Use this for flags updated in multiple contexts
 * @param ptr   Pointer to volatile variable
 * @param value Value to write
 */
static inline void Atomic_Write32(volatile uint32_t *ptr, uint32_t value)
{
    uint32_t state = __get_PRIMASK();
    __disable_irq();
    *ptr = value;
    if (!state) __enable_irq();  // Restore previous state
}

/**
 * Atomic set bit in variable
 * @param ptr  Pointer to variable
 * @param mask Bitmask to set
 */
static inline void Atomic_SetBits(volatile uint32_t *ptr, uint32_t mask)
{
    uint32_t state = __get_PRIMASK();
    __disable_irq();
    *ptr |= mask;
    if (!state) __enable_irq();
}

/**
 * Atomic clear bits in variable
 * @param ptr  Pointer to variable
 * @param mask Bitmask to clear
 */
static inline void Atomic_ClearBits(volatile uint32_t *ptr, uint32_t mask)
{
    uint32_t state = __get_PRIMASK();
    __disable_irq();
    *ptr &= ~mask;
    if (!state) __enable_irq();
}

/**
 * Atomic compare-and-swap operation
 * @param ptr      Pointer to variable
 * @param expected Expected current value
 * @param new_val  Value to write if match
 * @return true if swap succeeded, false if value didn't match
 */
static inline bool Atomic_CompareSet(volatile uint32_t *ptr, uint32_t expected, uint32_t new_val)
{
    uint32_t state = __get_PRIMASK();
    __disable_irq();
    
    bool success = false;
    if (*ptr == expected) {
        *ptr = new_val;
        success = true;
    }
    
    if (!state) __enable_irq();
    return success;
}

#endif // CORE_ATOMIC_H
```

---

### 6. New: EEPROM Layout Header

**File:** `core/eeprom_layout.h`

```c
#ifndef CORE_EEPROM_LAYOUT_H
#define CORE_EEPROM_LAYOUT_H

#include <stdint.h>

// ============================================================================
// EEPROM MEMORY MAP - UV-K5 Radio
//
// Total EEPROM: 8KB (0x0000 - 0x1FFF)
// All multi-byte accesses must be 8-byte aligned
// ============================================================================

#define EEPROM_TOTAL_SIZE       0x2000   // 8192 bytes
#define EEPROM_PAGE_SIZE        8        // Write granularity
#define EEPROM_PAGE_MASK        (~(EEPROM_PAGE_SIZE - 1))

// ============================================================================
// PROTECTED REGIONS
// ============================================================================

#define EEPROM_RESERVED_0000    0x0000   // Start
#define EEPROM_SIZE_0000        0x0E40   // 3648 bytes

#define EEPROM_PROTECTED_0E98   0x0E98   // Protected calibration
#define EEPROM_SIZE_PROTECTED   0x0008   // 8 bytes

// ============================================================================
// USER CHANNELS & VFO
// ============================================================================

#define EEPROM_ADDR_MR_CHANNELS 0x0E40   // Memory channels
#define EEPROM_SIZE_MR_CHANNEL  16       // Per channel
#define EEPROM_MAX_MR_CHANNELS  200

// ============================================================================
// FM RADIO CHANNELS (if ENABLE_FMRADIO)
// ============================================================================

#define EEPROM_ADDR_FM_CHANNELS 0x0E40   // FM presets
#define EEPROM_SIZE_FM_CHANNEL  8
#define EEPROM_MAX_FM_CHANNELS  20

// ============================================================================
// DTMF CONTACTS & AUTO-ID
// ============================================================================

#define EEPROM_ADDR_DTMF_CONTACTS  0x1C00   // 200 contacts × 16 bytes
#define EEPROM_SIZE_DTMF_CONTACT   16
#define EEPROM_MAX_DTMF_CONTACTS   200

#define EEPROM_ADDR_DTMF_ID     0x1F40   // DTMF ID (emergency codes)
#define EEPROM_SIZE_DTMF_ID     8

// ============================================================================
// SETTINGS & CALIBRATION
// ============================================================================

#define EEPROM_ADDR_CALIBRATION 0x1F80   // RF calibration data
#define EEPROM_SIZE_CALIBRATION 128

#define EEPROM_ADDR_CUSTOM_AES  0x1F88   // Custom AES key (if enabled)
#define EEPROM_SIZE_CUSTOM_AES  16

// ============================================================================
// VALIDATION & SAFETY
// ============================================================================

/**
 * Check if EEPROM address and size are valid
 * @return true if parameters are valid for access
 */
static inline bool EEPROM_IsValid(uint16_t addr, uint16_t size)
{
    // Must not exceed bounds
    if (addr + size > EEPROM_TOTAL_SIZE)
        return false;
    
    // Must be properly aligned (8-byte boundary)
    if ((addr & (EEPROM_PAGE_SIZE - 1)) != 0)
        return false;
    
    // Size must be multiple of page size
    if ((size & (EEPROM_PAGE_SIZE - 1)) != 0)
        return false;
    
    return true;
}

/**
 * Check if address is in protected region
 * @return true if in protected area
 */
static inline bool EEPROM_IsProtected(uint16_t addr, uint16_t size)
{
    // Check against known protected regions
    if (addr >= EEPROM_PROTECTED_0E98 && 
        addr < (EEPROM_PROTECTED_0E98 + EEPROM_SIZE_PROTECTED))
        return true;
    
    // Check for overlap
    if ((addr + size) > EEPROM_PROTECTED_0E98 &&
        addr < (EEPROM_PROTECTED_0E98 + EEPROM_SIZE_PROTECTED))
        return true;
    
    return false;
}

// ============================================================================
// HELPER MACROS
// ============================================================================

#define EEPROM_MR_CHANNEL_ADDR(channel) \
    ((EEPROM_ADDR_MR_CHANNELS) + ((channel) * EEPROM_SIZE_MR_CHANNEL))

#define EEPROM_FM_CHANNEL_ADDR(channel) \
    ((EEPROM_ADDR_FM_CHANNELS) + ((channel) * EEPROM_SIZE_FM_CHANNEL))

#define EEPROM_DTMF_CONTACT_ADDR(index) \
    ((EEPROM_ADDR_DTMF_CONTACTS) + ((index) * EEPROM_SIZE_DTMF_CONTACT))

#endif // CORE_EEPROM_LAYOUT_H
```

---

### 7. Optimization: Non-Blocking EEPROM Write

**File:** `driver/eeprom.c`  
**Change:** Queue-based async writes

```c
// ============================================================================
// ASYNCHRONOUS EEPROM WRITE QUEUE
// ============================================================================

#include <string.h>
#include "eeprom.h"

typedef struct {
    uint16_t address;
    uint8_t  data[8];
} EEPROM_WriteRequest_t;

#define WRITE_QUEUE_SIZE 16

static struct {
    EEPROM_WriteRequest_t queue[WRITE_QUEUE_SIZE];
    uint8_t head;
    uint8_t tail;
    bool busy;
    uint32_t busy_timer_ms;
} write_context = {0};

/**
 * Queue EEPROM write request (non-blocking)
 * @return true if queued, false if queue full
 */
bool EEPROM_WriteBufferAsync(uint16_t Address, const void *pBuffer)
{
    if (!pBuffer || Address >= 0x2000)
        return false;
    
    // Check queue space
    uint8_t next_head = (write_context.head + 1) % WRITE_QUEUE_SIZE;
    if (next_head == write_context.tail)
        return false;  // Queue full
    
    // Add to queue
    EEPROM_WriteRequest_t *req = &write_context.queue[write_context.head];
    req->address = Address;
    memcpy(req->data, pBuffer, 8);
    
    write_context.head = next_head;
    return true;
}

/**
 * Process one queued write (call from scheduler)
 * Returns immediately if no work or write in progress
 */
void EEPROM_ProcessWriteQueue(void)
{
    // Check if write in progress
    if (write_context.busy) {
        if (write_context.busy_timer_ms > 0) {
            write_context.busy_timer_ms--;
            return;
        }
        write_context.busy = false;
    }
    
    // Check if queue has work
    if (write_context.head == write_context.tail)
        return;  // Queue empty
    
    // Process next write
    EEPROM_WriteRequest_t *req = &write_context.queue[write_context.tail];
    writeContext.tail = (write_context.tail + 1) % WRITE_QUEUE_SIZE;
    
    // Start write (non-blocking)
    I2C_Start();
    I2C_Write(0xA0);
    I2C_Write((req->address >> 8) & 0xFF);
    I2C_Write((req->address >> 0) & 0xFF);
    I2C_WriteBuffer(req->data, 8);
    I2C_Stop();
    
    write_context.busy = true;
    write_context.busy_timer_ms = 8;  // Wait for EEPROM burn time
}
```

---

### 8. Optimization: Ring Buffer Macro

**File:** `driver/uart.c`  
**Change:** Faster wraparound using bitwise operations

```c
// BEFORE: Modulo is expensive in tight loops
#define DMA_INDEX(x, y) (((x) + (y)) % sizeof(UART_DMA_Buffer))

// AFTER: Since buffer is 256 bytes (power of 2), use bitwise AND
//        This is a 10-100x speedup for tight loops
#define DMA_INDEX(x, y) (((x) + (y)) & 0xFF)

// Usage remains identical:
gUART_WriteIndex = DMA_INDEX(gUART_WriteIndex, 1);  // ✓ Much faster now
```

---

## Performance Benchmarking Template

**File:** `test/perf_test.c`

```c
#include <stdint.h>
#include "systick.h"

typedef struct {
    const char *name;
    uint32_t start_ticks;
    uint32_t end_ticks;
    uint32_t min_ticks;
    uint32_t max_ticks;
    uint32_t total_ticks;
    uint32_t count;
} PerfBench_t;

// Helpers
static inline void PerfBench_Start(PerfBench_t *b)
{
    b->start_ticks = SysTick->VAL;
}

static inline void PerfBench_End(PerfBench_t *b)
{
    b->end_ticks = SysTick->VAL;
    uint32_t elapsed = (b->start_ticks > b->end_ticks) ? 
        (b->start_ticks - b->end_ticks) :
        (SysTick->LOAD - b->end_ticks + b->start_ticks);
    
    if (elapsed < b->min_ticks) b->min_ticks = elapsed;
    if (elapsed > b->max_ticks) b->max_ticks = elapsed;
    b->total_ticks += elapsed;
    b->count++;
}

static inline uint32_t PerfBench_Average(const PerfBench_t *b)
{
    return b->count ? (b->total_ticks / b->count) : 0;
}

// Example usage:
// PerfBench_t bench = {0};
// PerfBench_Start(&bench);
// EEPROM_WriteBuffer(0x1C00, &data);
// PerfBench_End(&bench);
// uint32_t avg = PerfBench_Average(&bench);  // microseconds
```

---

## Testing Checklist

### Unit Tests

- [ ] `test_validation_frequency()` - All bands
- [ ] `test_validation_eeprom()` - Address limits, alignment
- [ ] `test_string_copy_safe()` - Overflow conditions
- [ ] `test_atomic_operations()` - Race conditions
- [ ] `test_frequency_parse()` - Error cases

### Integration Tests

- [ ] UART command with CRC error
- [ ] EEPROM write during RX/TX
- [ ] Frequency input with invalid MHz
- [ ] Spectrum load with corrupted EEPROM
- [ ] Scanning with all channels invalid

### Performance Tests

- [ ] EEPROM write queue throughput
- [ ] I2C access latency (target: <10ms)
- [ ] UART throughput (target: 115200 stable)
- [ ] Display refresh rate (target: 20+ FPS)
- [ ] Memory usage (target: <30KB dynamic)

---

## GIT Workflow for Changes

```bash
# Create feature branches for each improvement
git checkout -b fix/s1-uart-buffer-overflow
# ... make changes ...
git commit -m "Fix: Add bounds checking to strcpy in UART SendVersion()"

git checkout -b fix/s2-interrupt-state
# ... make changes ...
git commit -m "Fix: Properly save/restore interrupt state in UART handler"

# Continue for other fixes...

# Merge to main with testing verification
git checkout main
git merge fix/s1-uart-buffer-overflow
git merge fix/s2-interrupt-state
```

---

End of Implementation Guide

