/**
 * @file
 * Contains C functions to handle time-related functions.
 */
#include <stdbool.h>
#include "Debug.h"
#include "Pins.h"
#include "EEPROMFormat.h"

#define UINT_MAX_VALUE 65535

typedef struct {
  long trigger_time;
  byte command;      //0x00 for power SR state change, 0x0C for cooldown request
  byte data1, data2; //for power SR state change, data1 is low byte, data2 is high byte. For cooldown, data1 is the ID of the heater to cool down.
} time_event_t;

time_event_t time_events[] = {
  {0, TIME_EVENT_COMMAND_SR_UPDATE, 0,0},
  {5000, TIME_EVENT_COMMAND_SR_UPDATE, 1,0},
  {10000, TIME_EVENT_COMMAND_SR_UPDATE, 2,0},
  {15000, TIME_EVENT_COMMAND_SR_UPDATE, 4,0},
  {20000, TIME_EVENT_COMMAND_SR_UPDATE, 8,0},
  {22000, TIME_EVENT_COMMAND_SR_UPDATE, 16,0},
  {24000, TIME_EVENT_COMMAND_SR_UPDATE, 32,0},
  {26000, TIME_EVENT_COMMAND_SR_UPDATE, 64,0},
  {28000, TIME_EVENT_COMMAND_SR_UPDATE, 128,0},
  {30000, TIME_EVENT_COMMAND_SR_UPDATE, 0,1},
  {31000, TIME_EVENT_COMMAND_SR_UPDATE, 255,255},
  {31100, TIME_EVENT_COMMAND_COOLDOWN, 0, 0},
  {31200, TIME_EVENT_COMMAND_SR_UPDATE, 1,1},
  {32000, TIME_EVENT_COMMAND_SR_UPDATE, 0, 0},
  {40000, TIME_EVENT_COMMAND_EXP_OFF, 0, 0}
  
  /*{0, TIME_EVENT_COMMAND_SR_UPDATE, 0,0},
  {5000, TIME_EVENT_COMMAND_SR_UPDATE, 255,255},
  {120000, TIME_EVENT_COMMAND_COOLDOWN, 0, 0},
  {120100, TIME_EVENT_COMMAND_SR_UPDATE, 255,255},
  {150000, TIME_EVENT_COMMAND_EXP_OFF, 0, 0}*/
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
    //Intentionally left blank.
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
 * Execute the most recent time event, even if it's already been executed.
 * Calls back to execute_event.
 */
void execute_last_time_event() {
  long mostRecent = 0;
  unsigned int indexOfMostRecent = UINT_MAX_VALUE;
  for(int x=0; x< sizeof(time_events)/sizeof(time_event_t); x++) {
    if(time_events[x].trigger_time <= get_time() && time_events[x].trigger_time > mostRecent) {
      indexOfMostRecent = x;
    }
  }
  if(indexOfMostRecent < UINT_MAX_VALUE) {
    execute_event(time_events[indexOfMostRecent].command, time_events[indexOfMostRecent].data1, time_events[indexOfMostRecent].data2);
  }
}
