/**
 * @file
 * Contains C functions to handle time-related functions.
 */
#include <stdbool.h>
#include "Debug.h"
#include "Pins.h"
#include "EEPROMFormat.h"

typedef struct {
  long trigger_time;
  byte command;
  byte data;
} time_event_t;

time_event_t time_events[] = {
  {2000,70,80}, {180000,65,75}, {200000,100,106}
};

/**
 * Holds time offset (used in case we were reset and loaded the last time reading).
 */
unsigned long time_offset;

/**
 * Gets the current time.
 * @return Time since start of experiment, in milliseconds.
 */
unsigned long get_time() {
  return millis() + time_offset; 
}

/**
 * Initializes timekeeping code. Attempts to load last time value from EEPROM if it is marked valid.
 */
void time_setup(boolean wasReset) {
  DEBUG("TimeSetup: start\n");
  time_offset = 0;
  DEBUG("TimeSetup: attempting to resume\n");
  if(check_for_interrupted()) {
    DEBUG("TimeSetup: resume data loaded\n");
  } else {
    DEBUG("TimeSetup: no resume data to load\n");
  }
  if(wasReset) {
    DEBUG("TimeSetup: Clearing time event state...");
    for(int x=0;x<EEPROM_TIME_EVENT_STATUS_LIMIT; x++) {
      WriteEEPROM(EEPROM_TIME_EVENT_STATUS_BASE + x, 0);
    }
    DEBUG("OK\n");
  }
}

/**
 * Checks the internal EEPROM for a valid time signature if RSTPIN is low.
 * If RSTPIN is high or no valid signature is found, initialize time to 0.
 * @return true if a valid time signature was found and loaded.
 */
boolean check_for_interrupted() {
  byte statusByte = ReadEEPROM(EEPROM_STATUS);
  DEBUG("check_for_interrupted: status byte: ");
  DEBUGF(statusByte, BIN);
  DEBUG("\n");
  if(statusByte & EEPROM_STATUS_TIME_VALID) { //If time signature valid bit is set
    DEBUG("check_for_interrupted: Time signature was marked valid\n");
    //OPTIMIZATION: read values directly into time_offset.
    byte b1, b2, b3, b4; //Store pieces of time (it's a 4-byte long).
    //Read in the 4 bytes.
    b1 = ReadEEPROM(EEPROM_TIME_1);
    b2 = ReadEEPROM(EEPROM_TIME_2);
    b3 = ReadEEPROM(EEPROM_TIME_3);
    b4 = ReadEEPROM(EEPROM_TIME_4);
    if((b1 ^ b2 ^ b3 ^ b4) == ReadEEPROM(EEPROM_TIME_CHECK)) { //If the check value matches
      //Load in the values.
      time_offset = b1;
      time_offset |= (b2<<8);
      time_offset |= (b3<<16);
      time_offset |= (b4<<24);
      DEBUG("check_for_interrupted: Time signature: ");
      DEBUGF(time_offset, DEC);
      DEBUG("\n");
      return true;
    } else {
      DEBUG("check_for_interrupted: WARN: Time signature was marked valid but was corrupted! Default to 0\n");
      time_offset = 0;
      return false;
    }
  } else {
    DEBUG("check_for_interrupted: Time signature was marked invalid\n");
    return false;
  }
}

/**
 * Write elapsed time to EEPROM (in case power is interrupted).
 */
void write_time() {
  byte statusByte = ReadEEPROM(EEPROM_STATUS);
  DEBUG("WriteTime: status byte: ");
  DEBUGF(statusByte, BIN);
  DEBUG("\n");
  statusByte |= EEPROM_STATUS_TIME_VALID;
  DEBUG("WriteTime: new status byte: ");
  DEBUGF(statusByte, BIN);
  DEBUG("\n");
  
  unsigned long time = get_time();
  
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

/**
 * Execute any pending time events whose trigger time has passed.
 * Calls back to execute_event.
 */
void execute_time_events() {
  for(int x=0; x< 2; x++) {
    if(get_executed_bit(x)) continue;
    if(time_events[x].trigger_time <= get_time()) {
      set_executed_bit(x);
      execute_event(time_events[x].command, time_events[x].data);
    }
  }
}

/**
 * Gets the flag representing if time event i has been executed
 */
boolean get_executed_bit(int i) {
  byte offset = i / 8;
  if(offset > EEPROM_TIME_EVENT_STATUS_LIMIT) { return false; } //Bad addr.
  byte val = ReadEEPROM(EEPROM_TIME_EVENT_STATUS_BASE + offset);
  offset = i % 8;
  return (val & (1 << offset)) > 0;
}

/**
 * Sets the flag representing if time event i has been executed to true.
 */
void set_executed_bit(int i) {
  byte offset = i / 8;
  if(offset > EEPROM_TIME_EVENT_STATUS_LIMIT) { return; } //Bad addr.
  byte val = ReadEEPROM(EEPROM_TIME_EVENT_STATUS_BASE + offset);
  WriteEEPROM(EEPROM_TIME_EVENT_STATUS_BASE + offset, val | (1 << i % 8));
}