/**
 * @file
 * iSeries class implementation.
 * @author Giacomo Ferrari progman32@gmail.com
 */
#include "iSeries.h"

iSeries::iSeries(NewSoftSerial* com_) {
  com = com_;
}

boolean iSeries::issueCommand(const char* cmd, byte reply[], byte replyLength) {
  return issueCommand(cmd, reply, replyLength, ISERIES_CMD_DELAY);
}

boolean iSeries::issueCommand(const char* cmd, byte reply[], byte replyLength, int timeoutMillis) {
   //Get the device's attention.
   com->print(ISERIES_RECOG_CHAR);
   //Send the command
   com->print(cmd);
   //End the command
   com->print("\r\n");
   
   
   //BEGIN HACK//////////////////////////////////////////
   //TODO: DON'T DO THIS! THIS IS A HACK TO MAKE THE SERIAL LIBRARIES WORK!
   //I don't really get why this delay must be here, but it stays for now.
   delay(timeoutMillis);
   if(com->available() >= replyLength) {
     for(byte x=0; x<replyLength; x++) {
       reply[x]=com->read();
     }
     //Drain buffer.
     while(com->available()) com->read();
     return true;
   } else {
     //something went wrong...
     return false;
   }
   //END HACK////////////////////////////////////////////
}

boolean iSeries::findAndReset() {
  byte resp[3];
  issueCommand("Z02", resp, 3, 3000);
  return resp[0]=='Z' && resp[1]=='0' && resp[2]=='2';
}

//TODO: Consolidate getReadingString and getReading implementations. They should share code.

boolean iSeries::getReadingString(byte* buffer) {
  byte resp[8];
  issueCommand("X01", resp, 8, 1000);
  if(resp[0]=='X' && resp[1]=='0' && resp[2]=='1') {
    //All OK
    for(int x=3;x<8;x++)
      buffer[x-3] = resp[x];
    return true;
  } else {
    //ERROR
    return false;
  }
}

double iSeries::getReading() {
  byte resp[9]; //one extra byte for null termination 
  issueCommand("X01", resp, 8, 1000);
  if(resp[0]=='X' && resp[1]=='0' && resp[2]=='1') {
    //All OK
    resp[8]=0; //insert null termination for atof
    return atof((char*)&(resp[3]));
  } else {
    //ERROR
    return NAN;
  }
}
