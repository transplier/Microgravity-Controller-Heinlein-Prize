/**
 * @file
 * Contains C functions related to TC redundancy functions.
 * @author Giacomo Ferrari progman32@gmail.com
 * @author Kevin Plant kdplant@gmail.com
 */

#include "Pins.h"

void initRedundancyPins() {
  //TC_INOUT_REDUNDANCY direction is set up in Microgravity_Time_Controller.pde.
  pinMode(TC_IN_REDUN_TAKEOVER_CHECK, INPUT);
  
  pinMode(TC_OUT_RST_REQ, OUTPUT);
  pinMode(TC_OUT_REDUN_SR_D, OUTPUT);
  pinMode(TC_OUT_REDUN_SR_C, OUTPUT);
}

boolean getHeartbeatState() {
  return digitalRead(TC_INOUT_REDUNDANCY);
}

boolean queryHardwareTakeoverEnabled() {
  return ( digitalRead(TC_IN_REDUN_TAKEOVER_CHECK) == LOW );
}

void setPrimaryResetState(boolean resetOn) {
  digitalWrite(TC_OUT_RST_REQ, resetOn?HIGH:LOW);
}

void writeToControlSR(byte value) {
  shiftOut(TC_OUT_REDUN_SR_D, TC_OUT_REDUN_SR_C, LSBFIRST, value);
}

long lastTimeSavedTime = 0;
void doDuringMonitorMode() {
  /* If it's time we wrote the experiment time to nonvolatile memory, do it. */
  if((millis() - lastTimeSavedTime) > SAVE_INTERVAL_MSEC) {
      write_time();
      lastTimeSavedTime=millis();
    }
}
