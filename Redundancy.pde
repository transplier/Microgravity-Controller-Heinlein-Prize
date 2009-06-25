/**
 * @file
 * Contains C functions related to redundancy functions.
 * Common to both units. Expects these functions to be defined:
 * void log(char*)
 * void log_int(int)
 * void initRedundancyPins()
 * boolean getHeartbeatState()
 * boolean queryHardwareTakeoverEnabled()
 * void setPrimaryResetState(boolean resetOn)
 * void writeToControlSR(byte value)
 * void doDuringMonitorMode()
 *
 * @author Giacomo Ferrari progman32@gmail.com
 * @author Kevin Plant kdplant@gmail.com
 */

#include "Debug.h"
#include "EEPROMFormat.h"

#define REDUNDANCY_TIMEOUT 20000 //msec to wait for pulse before corrective action taken.
#define REDUNDANCY_RESET_MAX 5 //times to try a reset of primary controller before initiating takeover.

#define REDUNDANCY_UNLOCK_CODE 0b11001101

extern void log(char* x);
extern void log_int(int x);
extern void initRedundancyPins();
extern boolean getHeartbeatState();
extern boolean queryHardwareTakeoverEnabled();
extern void setPrimaryResetState(boolean resetOn);
extern void doDuringMonitorMode();

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

  initRedundancyPins();
  
  //The code shift register may have the code already in it if we were reset. Make sure it is cleared.
  lockRedundancy();
  
  /* last relative time we saw a change in the primary's heartbeat line. */
  long lastSawChange = millis();
  
  /* ... and the last known state of the heartbeat line. */
  boolean lastPinState = getHeartbeatState();

  /* Number of times we've tried to reset the primary unit without success. */
  byte resetCount = 0;
    
  while(1) {
    doDuringMonitorMode();
    
    if(getHeartbeatState() != lastPinState) {
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
        log("TIME OF DEATH (min): ");
        log_int(lastSawChange/60000l);
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

void unlockRedundancy() {
  byte attempts = 0;
  log("GETTING CONTROL...");
  do {
    writeToControlSR(REDUNDANCY_UNLOCK_CODE);
    attempts++;
    if(attempts > 200) {
      log("UNABLE TO GET CONTROL! CONTINUING :(\n");
      return;
    }
    delay(10);
  } while(!queryHardwareTakeoverEnabled());
  log("GOT IT\n");
}

void lockRedundancy() {
  byte attempts = 0;
  log("RELEASING CONTROL...");
  do {
    writeToControlSR(0);
    attempts++;
    if(attempts > 200) {
      DEBUG("UNABLE TO RELEASE CONTROL! CONTINUING :(\n");
      return;
    }
    delay(10);
  } while(queryHardwareTakeoverEnabled());
  log("RELEASED IT\n");
}

/**
 * Resets the primary processor by holding its reset line low for a bit.
 */
void resetPrimary() {
  unlockRedundancy();
  setPrimaryResetState(true);
  delay(100);
  setPrimaryResetState(false);
  lockRedundancy();
}

/**
 * Takes the steps necessary to perform a full takeover in case of primary unit failure.
 * THIS COMPLETELY DISABLES THE PRIMARY UNIT AND HOLDS IT IN PERMANENT RESET!
 */
void setupForTakeover() {
  unlockRedundancy();
  setPrimaryResetState(true);
}
