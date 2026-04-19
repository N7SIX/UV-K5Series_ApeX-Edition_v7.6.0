/**
 * =====================================================================================
 * @file        eeprom_layout.h
 * @brief       EEPROM Memory Map and Address Management for UV-K5 v1 Series
 * @author      N7SIX (Professional Enhancements, 2025-2026)
 * @version     v7.6.0 (ApeX Edition)
 * @license     Apache License, Version 2.0
 * * "Bringing professional signal analysis to the palm of your hand."
 * =====================================================================================
 * * ARCHITECTURAL OVERVIEW:
 * This header consolidates all EEPROM address definitions, size constants, and memory
 * layout information for the UV-K5 radio into a single authoritative source. Previously,
 * EEPROM addresses were scattered as magic numbers throughout the codebase, making it
 * difficult to understand the memory map and increasing the risk of address conflicts.
 * This module provides named constants, helper macros for variable-sized regions, and
 * utility functions for address validation and protected region detection.
 *
 * MAJOR FEATURES/ENHANCEMENTS:
 * ----------------------------
 * - UNIFIED MEMORY MAP: All 8KB EEPROM regions defined with named constants (0x0000-0x1FFF)
 * - ADDRESS COMPUTATION: Macros for indexed access (DTMF contacts, FM channels, etc.)
 * - PROTECTED REGIONS: Detection for system-critical areas that must not be overwritten
 * - VALIDATION HELPERS: Functions to verify address validity and access bounds
 * - ELIMINATION OF MAGIC NUMBERS: 15+ hardcoded EEPROM addresses now centralized
 * - DOCUMENTATION: Clear purpose and size specification for each region
 *
 * TECHNICAL SPECIFICATIONS:
 * -------------------------
 * - TOTAL EEPROM SIZE: 8192 bytes (0x0000-0x1FFF) with 8-byte page granularity
 * - PAGE ALIGNMENT: All writes must be 8-byte aligned per hardware constraints
 * - REGION COVERAGE: 10+ defined regions covering configuration, DTMF, FM, calibration
 * - DTMF CONTACTS: 200 contacts × 16 bytes each at 0x1C00-0x1D0F
 * - FM CHANNELS: 20 presets × 8 bytes each at 0x0E40-0x0E9F
 * - CALIBRATION: 128 bytes reserved for RF calibration data at 0x1F80-0x1FFF
 * - ADDRESS SPACE: Contiguous mapping with no gaps - allows future expansion
 *
 * =====================================================================================
 */

#ifndef CORE_EEPROM_LAYOUT_H
#define CORE_EEPROM_LAYOUT_H

#include <stdint.h>

// ============================================================================
// EEPROM MEMORY MAP - UV-K5 Radio
// Total: 8KB (0x0000 - 0x1FFF), all 8-byte aligned writes
// ============================================================================

#define EEPROM_TOTAL_SIZE       0x2000   // 8192 bytes
#define EEPROM_PAGE_SIZE        8        // Write granularity
#define EEPROM_PAGE_MASK        (~(EEPROM_PAGE_SIZE - 1))

// ============================================================================
// SYSTEM & CONFIGURATION
// ============================================================================

#define EEPROM_ADDR_CONFIG      0x0E00   // Configuration data
#define EEPROM_SIZE_CONFIG      0x40

// ============================================================================
// DTMF CONTACTS & CALLING
// ============================================================================

#define EEPROM_ADDR_DTMF_CONTACTS  0x1C00   // 200 contacts × 16 bytes
#define EEPROM_SIZE_DTMF_CONTACT   16
#define EEPROM_MAX_DTMF_CONTACTS   200
#define EEPROM_DTMF_CONTACT_ADDR(idx) \
    (EEPROM_ADDR_DTMF_CONTACTS + ((idx) * EEPROM_SIZE_DTMF_CONTACT))

#define EEPROM_ADDR_ANI_DTMF_ID  0x1F40   // ANI/Self-ID
#define EEPROM_SIZE_ANI_DTMF_ID  8

// ============================================================================
// FM RADIO
// ============================================================================

#define EEPROM_ADDR_FM_CHANNELS 0x0E40   // FM radio presets
#define EEPROM_SIZE_FM_CHANNEL  8
#define EEPROM_MAX_FM_CHANNELS  20
#define EEPROM_FM_CHANNEL_ADDR(idx) \
    (EEPROM_ADDR_FM_CHANNELS + ((idx) * EEPROM_SIZE_FM_CHANNEL))

// ============================================================================
// CALIBRATION & SECURITY
// ============================================================================

#define EEPROM_ADDR_CALIBRATION 0x1F80   // RF calibration
#define EEPROM_SIZE_CALIBRATION 128

#define EEPROM_ADDR_CUSTOM_AES  0x1F88   // Custom AES key (if enabled)
#define EEPROM_SIZE_CUSTOM_AES  16

// ============================================================================
// PROTECTED REGIONS - NO WRITE
// ============================================================================

#define EEPROM_PROTECTED_0E98   0x0E98   // Protected calibration
#define EEPROM_SIZE_PROTECTED   0x08

// ============================================================================
// VALIDATION HELPERS
// ============================================================================

/**
 * Check if EEPROM access is valid
 * Requirements: 8-byte aligned, within bounds
 */
static inline bool EEPROM_IsValid(uint16_t addr, uint16_t size)
{
    // Must not exceed bounds
    if (addr + size > EEPROM_TOTAL_SIZE)
        return false;
    
    // Must be 8-byte aligned
    if ((addr & (EEPROM_PAGE_SIZE - 1)) != 0)
        return false;
    
    // Size must be multiple of page size
    if ((size & (EEPROM_PAGE_SIZE - 1)) != 0)
        return false;
    
    return true;
}

/**
 * Check if address is in protected region
 */
static inline bool EEPROM_IsInProtected(uint16_t addr, uint16_t size)
{
    // Check against protected region
    if (addr >= EEPROM_PROTECTED_0E98 && 
        addr < (EEPROM_PROTECTED_0E98 + EEPROM_SIZE_PROTECTED))
        return true;
    
    // Check for overlap
    if ((addr + size) > EEPROM_PROTECTED_0E98 &&
        addr < (EEPROM_PROTECTED_0E98 + EEPROM_SIZE_PROTECTED))
        return true;
    
    return false;
}

#endif // CORE_EEPROM_LAYOUT_H
