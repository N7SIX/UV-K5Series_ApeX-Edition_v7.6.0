/**
 * =====================================================================================
 * @file        validation.h
 * @brief       Centralized Input Validation Library for UV-K5 Firmware
 * @author      N7SIX (Professional Enhancements, 2025-2026)
 * @version     v7.6.0 (ApeX Edition)
 * @license     Apache License, Version 2.0
 * * "Bringing professional signal analysis to the palm of your hand."
 * =====================================================================================
 * * ARCHITECTURAL OVERVIEW:
 * This header provides a comprehensive validation library for all user inputs and
 * critical system parameters in the UV-K5 firmware. It centralizes validation logic
 * that was previously scattered throughout the codebase, ensuring consistent error
 * handling and preventing invalid states that could crash the radio or produce
 * undefined behavior. The library covers frequency validation, EEPROM access
 * protection, DTMF format validation, and safe memory operations.
 *
 * MAJOR FEATURES/ENHANCEMENTS:
 * ----------------------------
 * - FREQUENCY VALIDATION: TX/RX band checking with hardware range protection
 * - EEPROM SAFETY: Address alignment, boundary checking, protected region detection
 * - DTMF VALIDATION: Format checking for tone generation and contact matching
 * - INPUT PARSING: Safe frequency parsing from strings with overflow prevention
 * - MEMORY SAFETY: Inline safe string and memory copy functions with bounds
 * - CENTRALIZED LOGIC: Single source of truth for validation rules across all modules
 *
 * TECHNICAL SPECIFICATIONS:
 * -------------------------
 * - FREQUENCY RANGE: 136-520 MHz with per-band TX/RX capability validation
 * - EEPROM CONSTRAINTS: 8-byte alignment enforcement, 8KB total addressing (0x0000-0x1FFF)
 * - PROTECTED REGIONS: Detection of system areas that must not be modified
 * - DTMF FORMAT: Support for 0-9, A-D, *, # characters with length validation
 * - MEMORY FOOTPRINT: Header-only library (~2KB) with inline functions for efficiency
 * - API FUNCTIONS: 9+ validation functions covering all critical input types
 *
 * =====================================================================================
 */

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
 * Validate frequency is in allowed TX band
 * @param freq Frequency in Hz
 * @return true if TX permitted, false otherwise
 */
bool Frequency_IsTxAllowed(uint32_t freq);

/**
 * Validate frequency is in allowed RX band
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
 * @param size   Number of bytes
 * @return true if valid, false if would cause issues
 */
bool EEPROM_IsValidAccess(uint16_t offset, uint16_t size);

/**
 * Check if EEPROM region is protected
 * @param offset Starting address
 * @param size   Number of bytes
 * @return true if in protected region
 */
bool EEPROM_IsProtected(uint16_t offset, uint16_t size);

// ============================================================================
// INPUT VALIDATION
// ============================================================================

/**
 * Validate DTMF string format
 * Valid characters: 0-9, A-D, *, #
 * @param str    DTMF string
 * @param len    String length
 * @return true if valid format
 */
bool Input_DTMFIsValid(const char *str, size_t len);

/**
 * Parse frequency string safely
 * Format: "XXX.XXXXX" MHz
 * @param str        Input string  
 * @param out_freq   Pointer to output frequency (Hz)
 * @return true if successfully parsed
 */
bool Input_FrequencyParse(const char *str, uint32_t *out_freq);

// ============================================================================
// BUFFER VALIDATION
// ============================================================================

/**
 * Safe string copy with bounds checking
 * @param dest       Destination buffer
 * @param dest_size  Size of destination buffer
 * @param src        Source string
 * @param src_len    Max bytes to copy from source
 * @return Number of bytes copied (not including null terminator)
 */
static inline size_t StringCopy_Safe(char *dest, size_t dest_size,
                                     const char *src, size_t src_len)
{
    if (!dest || !src || dest_size == 0) return 0;
    
    size_t copy_len = (src_len < (dest_size - 1)) ? src_len : (dest_size - 1);
    memcpy(dest, src, copy_len);
    dest[copy_len] = '\0';
    return copy_len;
}

/**
 * Safe memory copy with bounds checking
 * @param dest      Destination buffer
 * @param dest_size Size of destination
 * @param src       Source buffer
 * @param src_len   Number of bytes to copy
 * @return true if successful, false if would overflow
 */
static inline bool MemCopy_Safe(void *dest, size_t dest_size,
                                const void *src, size_t src_len)
{
    if (!dest || !src || src_len > dest_size)
        return false;
    memcpy(dest, src, src_len);
    return true;
}

#endif // CORE_VALIDATION_H
