/**
 * @file
 * Contains C functions related to redundancy functions.
 * @author Giacomo Ferrari progman32@gmail.com
 * @author Kevin Plane kdplant@gmail.com
 */

#include "Pins.h"
#include "Debug.h"
#include "EEPROMFormat.h"

#define REDUNDANCY_TIMEOUT 1500 //msec to wait for pulse before corrective action taken.
#define REDUNDANCY_RESET_MAX 5 //times to try a reset of primary controller before initiating takeover.

#define REDUNDANCY_UNLOCK_CODE 0b11001101

boolean isSecondary() {
  byte val = ReadEEPROM(EEPROM_IS_PRIMARY);
  return val == EEPROM_IS_SECONDARY_VALUE; //Would rather both be primary!
}

void enterMonitorMode() {
  pinMode(TC_INOUT_REDUNDANCY, INPUT);
  pinMode(TC_IN_REDUN_TAKEOVER_CHECK, INPUT);
  
  pinMode(TC_OUT_RST_REQ, OUTPUT);
  pinMode(TC_OUT_REDUN_SR_D, OUTPUT);
  pinMode(TC_OUT_REDUN_SR_C, OUTPUT);
  
  long lastSawChange = millis();
  boolean lastPinState = digitalRead(TC_INOUT_REDUNDANCY);
  byte resetCount = 0;
  
  while(1) {
    if(digitalRead(TC_INOUT_REDUNDANCY) != lastPinState) {
      //Seems to be alive
      lastPinState = !lastPinState;
      resetCount = 0;
      DEBUG(".\n");
      lastSawChange = millis();
    } else if( (millis() - lastSawChange) > REDUNDANCY_TIMEOUT ) {
      if(resetCount > REDUNDANCY_RESET_MAX) {
        DEBUG("PRIMARY FAIL, TAKEOVER INITIATED... ");
        setupForTakeover();
        DEBUG("COMPETE\nEXECUTING MAIN PROGRAM.\n");
        return;
      }
      DEBUG("PRIMARY TIMEOUT, RESETTING\nRESET COUNT:");
      resetCount++;
      DEBUG(resetCount);
      resetPrimary();
      DEBUG("\n");
    }
  }
}

void unlockRedundancy() {
  byte attempts = 0;
  do {
    shiftOut(TC_OUT_REDUN_SR_D, TC_OUT_REDUN_SR_C, LSBFIRST, REDUNDANCY_UNLOCK_CODE);
    attempts++;
    if(attempts > 200) {
      DEBUG("UNABLE TO GET CONTROL! CONTINUING :(\n");
      return;
    }
    delay(10);
  } while(digitalRead(TC_IN_REDUN_TAKEOVER_CHECK) == HIGH);
}

void lockRedundancy() {
  shiftOut(TC_OUT_REDUN_SR_D, TC_OUT_REDUN_SR_C, LSBFIRST, 0);
}

void resetPrimary() {
  unlockRedundancy();
  digitalWrite(TC_OUT_RST_REQ, HIGH);
  delay(100);
  digitalWrite(TC_OUT_RST_REQ, LOW);
  lockRedundancy();
}

void setupForTakeover() {
  unlockRedundancy();
  digitalWrite(TC_OUT_RST_REQ, HIGH);
}