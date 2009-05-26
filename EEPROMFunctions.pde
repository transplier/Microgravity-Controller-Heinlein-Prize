/**
 * @file
 * Contains C functions to abstract away EEPROM functions. See definitions in EEPROMFormat.h.
 */
#include "EEPROMFormat.h"

#include <EEPROM.h>

void WriteEEPROM(int addr, byte data) {
  //TODO write in multiple locations
  EEPROM.write(addr, data);
}

byte ReadEEPROM(int addr) {
  //TODO do redundant read and compare
  return EEPROM.read(addr);
}

inline void WriteStatus(byte status) {
  WriteEEPROM(EEPROM_STATUS, status);
}

inline byte GetStatus() {
  return ReadEEPROM(EEPROM_STATUS);
}
