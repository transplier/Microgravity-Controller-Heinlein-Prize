#include <stdbool.h>
#include "Debug.h"
#include "Pins.h"
#include "EEPROMFormat.h"

//Holds time offset (in case we were reset)
unsigned long time_offset;

unsigned long GetTime() {
  return millis() + time_offset; 
}

void TimeSetup() {
  DEBUG("TimeSetup: start\n");
  time_offset = 0;
  DEBUG("TimeSetup: attempting to resume\n");
  if(CheckForInterrupted()) {
    DEBUG("TimeSetup: resume data loaded\n");
  } else {
    DEBUG("TimeSetup: no resume data to load\n");
  }
}

/* Check the internal EEPROM for a valid time signature if RSTPIN is low.
 * If RSTPIN is high or no valid signature is found, initialize time to 0.
 */
boolean CheckForInterrupted() {
  byte statusByte = ReadEEPROM(EEPROM_STATUS);
  DEBUG("CheckForInterrupted: status byte: ");
  DEBUGF(statusByte, BIN);
  DEBUG("\n");
  if(statusByte & EEPROM_STATUS_TIME_VALID) {
    DEBUG("CheckForInterrupted: Time signature was marked valid\n");
    byte b1, b2, b3, b4; //Store bits of time
    b1 = ReadEEPROM(EEPROM_TIME_1);
    b2 = ReadEEPROM(EEPROM_TIME_2);
    b3 = ReadEEPROM(EEPROM_TIME_3);
    b4 = ReadEEPROM(EEPROM_TIME_4);
    if((b1 ^ b2 ^ b3 ^ b4) == ReadEEPROM(EEPROM_TIME_CHECK)) {
      time_offset = b1;
      time_offset |= (b2<<8);
      time_offset |= (b3<<16);
      time_offset |= (b4<<24);
      DEBUG("CheckForInterrupted: Time signature: ");
      DEBUGF(time_offset, DEC);
      DEBUG("\n");
      return true;
    } else {
      DEBUG("CheckForInterrupted: WARN: Time signature was marked valid but was corrupted! Default to 0\n");
      time_offset = 0;
      return false;
    }
  } else {
    DEBUG("CheckForInterrupted: Time signature was marked invalid\n");
    return false;
  }
}

//Write elapsed time to EEPROM in case power is interrupted.
void WriteTime() {
  byte statusByte = ReadEEPROM(EEPROM_STATUS);
  DEBUG("WriteTime: status byte: ");
  DEBUGF(statusByte, BIN);
  DEBUG("\n");
  statusByte |= EEPROM_STATUS_TIME_VALID;
  DEBUG("WriteTime: new status byte: ");
  DEBUGF(statusByte, BIN);
  DEBUG("\n");
  
  unsigned long time = GetTime();
  
  byte b1, b2, b3, b4, c; //Store bits of time
  b1 = time & 0x000000FF;
  b2 = (time & 0x0000FF00) >> 8;
  b3 = (time & 0x00FF0000) >> 16;
  b4 = (time & 0xFF000000) >> 24;
  c = b1 ^ b2 ^ b3 ^ b4;
  WriteEEPROM(EEPROM_STATUS, statusByte);
  WriteEEPROM(EEPROM_TIME_1, b1);
  WriteEEPROM(EEPROM_TIME_2, b2);
  WriteEEPROM(EEPROM_TIME_3, b3);
  WriteEEPROM(EEPROM_TIME_4, b4);
  WriteEEPROM(EEPROM_TIME_CHECK, c);
  DEBUG("WriteTime: done. New time:");
  DEBUG(time);
  DEBUG("\n");
}
