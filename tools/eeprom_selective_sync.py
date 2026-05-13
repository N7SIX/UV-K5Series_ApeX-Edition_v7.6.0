import sys

# EEPROM region definitions (from repo)
REGIONS = [
    (0x0E00, 0x40),   # Config block
    (0x0E40, 0x60),   # FM presets
    (0x1C00, 0x7D0),  # DTMF contacts
    (0x1F40, 0x08),   # ANI DTMF ID
    (0x1F80, 0x80),   # Calibration
    (0x1F88, 0x10),   # Custom AES (if used)
]
EEPROM_SIZE = 0x2000

def load_bin(path):
    with open(path, 'rb') as f:
        data = f.read()
    if len(data) < EEPROM_SIZE:
        data += b'\xFF' * (EEPROM_SIZE - len(data))
    return bytearray(data[:EEPROM_SIZE])

def save_bin(path, data):
    with open(path, 'wb') as f:
        f.write(data)

def selective_sync(repo_bin, backup_bin):
    out = bytearray(repo_bin)
    for start, size in REGIONS:
        for i in range(size):
            addr = start + i
            if addr >= EEPROM_SIZE:
                continue  # Prevent overflow
            if repo_bin[addr] != backup_bin[addr]:
                out[addr] = backup_bin[addr]
    return out

def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <repo_eeprom.bin> <backup_eeprom.bin> <output_synced.bin>")
        sys.exit(1)
    repo_bin = load_bin(sys.argv[1])
    backup_bin = load_bin(sys.argv[2])
    synced = selective_sync(repo_bin, backup_bin)
    save_bin(sys.argv[3], synced)
    print("Sync complete. Output written to:", sys.argv[3])

if __name__ == "__main__":
    main()
