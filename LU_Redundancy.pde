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

/*
 * Determines if the Arduino we're running on has been configured as a primary or secondary unit.
 * This is determined by looking for a certain value previously burned in EEPROM.
 */
boolean isSecondary() {
  byte val = ReadEEPROM(EEPROM_IS_PRIMARY);
  return val == EEPROM_IS_SECONDARY_VALUE; //Would rather both be primary!
}

void enterMonitorMode() {
  log("ENTERING MONITOR MODE...\n");
  //LU_INOUT_REDUNDANCY direction is set up in Microgravity_Time_Controller.pde.

  /* Configure secondary-only pins */  
  pinMode(LU_OUT_RST_REQ, OUTPUT);
  pinMode(LU_OUT_REDUN_SR_D, OUTPUT);
  pinMode(LU_OUT_REDUN_SR_C, OUTPUT);
  
  //The code shift register may have the code already in it if we were reset. Make sure it is cleared.
  lockRedundancy();
  
  /* last relative time we saw a change in the primary's heartbeat line. */
  long lastSawChange = millis();
  
  /* ... and the last known state of the heartbeat line. */
  boolean lastPinState = digitalRead(LU_INOUT_REDUNDANCY);
  
  /* Number of times we've tried to reset the primary unit without success. */
  byte resetCount = 0;
  
  long lastTime = 0;
  
  while(1) {
    do_idle_logging();
    /* Was there a change in the heartbeat line? */
    if(digitalRead(LU_INOUT_REDUNDANCY) != lastPinState) {
      //Yes, seems to be alive
      lastPinState = !lastPinState;
      if(resetCount != 0) {
        log("PRIMARY BACK UP!\n");
        resetCount = 0;
      }
      
      lastSawChange = millis();
      
    } else if( (millis() - lastSawChange) > REDUNDANCY_TIMEOUT ) {
      //Oh no! We have no pulse!
      
      //Have we tried the paddles (reset) too many times?
      if(resetCount >= REDUNDANCY_RESET_MAX) {
        //He's dead, doctor.
        log("PRIMARY FAIL, TAKEOVER INITIATED...\n");
        log("TIME OF DEATH: ");
        log_int(lastSawChange);
        log(" :(\n");
        setupForTakeover();
        log("EXECUTING MAIN PROGRAM.\n");
        return;
      } else {
        //Administer a reset.
        resetCount++;
        lastSawChange = millis(); //cause another delay interval.
        log("PRIMARY TIMEOUT, RESETTING\nRESET COUNT:");
        log_int(resetCount);
        log("\n");
        resetPrimary();
        log("\n");
      }
    }
  }
}

void do_idle_logging() {
  //TODO implement
}

void unlockRedundancy() {
  byte attempts = 0;
  log("GETTING CONTROL...");
  do {
    shiftOut(LU_OUT_REDUN_SR_D, LU_OUT_REDUN_SR_C, LSBFIRST, REDUNDANCY_UNLOCK_CODE);
    attempts++;
    if(attempts > 200) {
      log("UNABLE TO GET CONTROL! CONTINUING :(\n");
      return;
    }
    delay(10);
  } while(analogRead(LU_ANALOG_REDUN_TAKEOVER_CHECK) >= 400);
  log("GOT IT\n");
}

void lockRedundancy() {
  byte attempts = 0;
  log("RELEASING CONTROL...");
  do {
    shiftOut(LU_OUT_REDUN_SR_D, LU_OUT_REDUN_SR_C, LSBFIRST, 0);
    attempts++;
    if(attempts > 200) {
      log("UNABLE TO RELEASE CONTROL! CONTINUING :(\n");
      return;
    }
    delay(10);
  } while(analogRead(LU_ANALOG_REDUN_TAKEOVER_CHECK) <= 400);
  log("RELEASED IT\n");
}

/**
 * Resets the primary processor by holding its reset line low for a bit.
 */
void resetPrimary() {
  unlockRedundancy();
  digitalWrite(LU_OUT_RST_REQ, HIGH);
  delay(100);
  digitalWrite(LU_OUT_RST_REQ, LOW);
  lockRedundancy();
}

/**
 * Takes the steps necessary to perform a full takeover in case of primary unit failure.
 * THIS COMPLETELY DISABLES THE PRIMARY UNIT AND HOLDS IT IN PERMANENT RESET!
 */
void setupForTakeover() {
  unlockRedundancy();
  digitalWrite(LU_OUT_RST_REQ, HIGH);
}
