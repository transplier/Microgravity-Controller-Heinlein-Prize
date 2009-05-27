#include "SplitComm.h"

/**
 * Checks the serial buffer for an incoming command.
 * Will wait a maximum of SPLIT_COMM_TIMEOUT_MSEC milliseconds.
 * @param buffer The message contents will be written into this. Must be at least SPLIT_COMM_MSG_LENGTH in length. Will not be touched if no command was found.
 * @return true if a command was received, false otherwise.
 */
boolean checkForCommand(byte* buffer) {
  long start_time = millis();
  
  //Read garbage until we find the attention character.
  while(Serial.available()) {
    if(Serial.read() == SPLIT_COMM_ATTN_CHAR) {
      
      while(Serial.available() < SPLIT_COMM_MSG_LENGTH) {
         //Busy wait, with timeout.
        if(millis() - start_time >= SPLIT_COMM_TIMEOUT_MSEC) {
          //We waited too long for full packet, give up.
          return false;
        } 
      }
      //We have at least SPLIT_COMM_MSG_LENGTH byte available - this is a full packet.
      for(int x = 0; x<SPLIT_COMM_MSG_LENGTH; x++) {
        buffer[x] = Serial.read();
      }
      return true;
      
    } else { //Got garbage. 
      if(millis() - start_time >= SPLIT_COMM_TIMEOUT_MSEC) {
          //We waited too long start of packet, give up.
          return false;
      } 
    }
  }
}

/**
 * Transmit a command.
 * @param buffer The command to send. Must be SPLIT_COMM_MSG_LENGTH in length.
 */
void transmitCommand(byte* buffer) {
  for(int x = 0; x<SPLIT_COMM_MSG_LENGTH; x++) {
        Serial.print(buffer[x]);
  }
}
