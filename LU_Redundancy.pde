/**
 * @file
 * Contains C functions related to LU redundancy functions.
 * @author Giacomo Ferrari progman32@gmail.com
 * @author Kevin Plant kdplant@gmail.com
 */

#include "Pins.h"

extern void log(char* x);
extern void log_int(int x);

void initRedundancyPins() {
  /* Configure secondary-only pins */  
  pinMode(LU_OUT_RST_REQ, OUTPUT);
  pinMode(LU_OUT_REDUN_SR_D, OUTPUT);
  pinMode(LU_OUT_REDUN_SR_C, OUTPUT);

}

boolean getHeartbeatState() {
  return digitalRead(LU_INOUT_REDUNDANCY);
}

boolean queryHardwareTakeoverEnabled() {
  return ( analogRead(LU_ANALOG_REDUN_TAKEOVER_CHECK) <= 400 );
}

void setPrimaryResetState(boolean resetOn) {
  digitalWrite(LU_OUT_RST_REQ, resetOn?HIGH:LOW);
}

void writeToControlSR(byte value) {
  shiftOut(LU_OUT_REDUN_SR_D, LU_OUT_REDUN_SR_C, LSBFIRST, value);
}

void doDuringMonitorMode() {
  do_idle_logging();
}

///////////////////////////////////////////////////////////////////////////////
int current_tc_id = -1;
void do_idle_logging() {
  //Is something on the buffer?
  char in;
  if(com_1.available() > 0) {
    in = com_1.read();
    if(in == REDUNDANT_LOG_START_CHAR) {
        //Capture until REDUNDANT_LOG_STOP_CHAR is received.
        byte pos=0;
        byte data[35];
        while((in=com_1.read()) != REDUNDANT_LOG_STOP_CHAR) {
          data[pos++] = in;
          if(pos >= 35) {
            //Buffer overrun.
            //TODO: write buffer and keep reading? Warning: doing this opens potential for infinite wait and failure of redundancy code.
            break;
          }
        }
        //Write to log.
        uDrive.append(REDUNDANT_LOG_FILE_NAME, data, pos);
    }
  }
}


