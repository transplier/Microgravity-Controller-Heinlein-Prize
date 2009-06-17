/**
 * @file
 * Contains C functions related to LU redundancy functions.
 * @author Giacomo Ferrari progman32@gmail.com
 * @author Kevin Plant kdplant@gmail.com
 */

#include "Pins.h"
#include "Debug.h"
#include "EEPROMFormat.h"

#define REDUNDANCY_TIMEOUT 20000 //msec to wait for pulse before corrective action taken.
#define REDUNDANCY_RESET_MAX 5 //times to try a reset of primary controller before initiating takeover.

#define REDUNDANCY_UNLOCK_CODE 0b11001101

boolean isSecondary() {
  byte val = ReadEEPROM(EEPROM_IS_PRIMARY);
  return val == EEPROM_IS_SECONDARY_VALUE; //Would rather both be primary!
}

void enterMonitorMode() {
  DEBUG("ENTERING MONITOR MODE...\n");
  //LU_INOUT_REDUNDANCY direction is set up in Microgravity_Time_Controller.pde.
  //pinMode(TC_IN_REDUN_TAKEOVER_CHECK, INPUT);
  
  pinMode(LU_OUT_RST_REQ, OUTPUT);
  pinMode(LU_OUT_REDUN_SR_D, OUTPUT);
  pinMode(LU_OUT_REDUN_SR_C, OUTPUT);
  
  lockRedundancy(); //The code shift register may have the code already in it if we were reset. Make sure it is cleared.
  
  long lastSawChange = millis();
  boolean lastPinState = digitalRead(LU_INOUT_REDUNDANCY);
  byte resetCount = 0;
  long lastTime = 0;
  
  while(1) {
    do_idle_logging();
    if(digitalRead(LU_INOUT_REDUNDANCY) != lastPinState) {
      //Seems to be alive
      lastPinState = !lastPinState;
      resetCount = 0;
      lastSawChange = millis();
    } else if( (millis() - lastSawChange) > REDUNDANCY_TIMEOUT ) {
      if(resetCount >= REDUNDANCY_RESET_MAX) {
        LOG("PRIMARY FAIL, TAKEOVER INITIATED...\n");
        setupForTakeover();
        LOG("COMPETE\nEXECUTING MAIN PROGRAM.\n");
        return;
      }
      LOG("PRIMARY TIMEOUT, RESETTING\nRESET COUNT:");
      resetCount++;
      lastSawChange = millis(); //cause another delay interval.
      LOG_INT(resetCount);
      resetPrimary();
      LOG("\n");
    }
  }
}

void do_idle_logging() {
  //TODO implement
}

void unlockRedundancy() {
  byte attempts = 0;
  LOG("GETTING CONTROL\n");
  do {
    shiftOut(LU_OUT_REDUN_SR_D, LU_OUT_REDUN_SR_C, LSBFIRST, REDUNDANCY_UNLOCK_CODE);
    attempts++;
    if(attempts > 200) {
      LOG("UNABLE TO GET CONTROL! CONTINUING :(\n");
      return;
    }
    delay(10);
  } while(analogRead(LU_ANALOG_REDUN_TAKEOVER_CHECK) >= 400);
}

void lockRedundancy() {
  byte attempts = 0;
  LOG("RELEASING CONTROL\n");
  do {
    shiftOut(LU_OUT_REDUN_SR_D, LU_OUT_REDUN_SR_C, LSBFIRST, 0);
    attempts++;
    if(attempts > 200) {
      LOG("UNABLE TO RELEASE CONTROL! CONTINUING :(\n");
      return;
    }
    delay(10);
  } while(analogRead(LU_ANALOG_REDUN_TAKEOVER_CHECK) <= 400);
}

void resetPrimary() {
  unlockRedundancy();
  digitalWrite(LU_OUT_RST_REQ, HIGH);
  delay(100);
  digitalWrite(LU_OUT_RST_REQ, LOW);
  lockRedundancy();
}

void setupForTakeover() {
  unlockRedundancy();
  digitalWrite(LU_OUT_RST_REQ, HIGH);
}
