/**
 * @file
 * Contains C functions to abstract away EEPROM functions. See definitions in EEPROMFormat.h.
 * @author Giacomo Ferrari progman32@gmail.com
 */
#include "EEPROMFormat.h"

#include <EEPROM.h>

void WriteEEPROM(int addr, byte data) {
  //TODO: verify wrote OK?
  EEPROM.write(addr, data);
  EEPROM.write(addr+EEPROM_2ND_COPY_START, data);
  EEPROM.write(addr+EEPROM_3D_COPY_START, data);
}

byte ReadEEPROM(int addr) {
  byte a, b, c;
  a = EEPROM.read(addr);
  b = EEPROM.read(addr+EEPROM_2ND_COPY_START);
  c = EEPROM.read(addr+EEPROM_3D_COPY_START);
  if(a==b || b==c) return b;
  if(c==a) return a;
  else /* WTF none match! Guess a, simply because we don't have any clue.*/ return a;
}

inline void WriteStatus(byte status) {
  WriteEEPROM(EEPROM_STATUS, status);
}

inline byte GetStatus() {
  return ReadEEPROM(EEPROM_STATUS);
}
