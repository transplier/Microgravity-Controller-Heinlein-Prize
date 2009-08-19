/**
 * @file
 * iSeries class implementation.
 * @author Giacomo Ferrari progman32@gmail.com
 */
#include "iSeries.h"

iSeries::iSeries(NewSoftSerial* com) {
  mpCom = com;
}

boolean iSeries::IssueCommand(const char* cmd, byte reply[], byte replyLength) {
  return IssueCommand(cmd, reply, replyLength, ISERIES_CMD_DELAY);
}

boolean iSeries::IssueCommand(const char* cmd, byte reply[], byte replyLength, int timeoutMillis) {
   //Pre-drain buffer of any junk. May be redundant if we have been using another serial device
   //(NewSoftSerial clears the buffer on device switch), but let's be safe.
   while(mpCom->available()) mpCom->read();
   //Get the device's attention.
   mpCom->print(ISERIES_RECOG_CHAR);
   //Send the command
   mpCom->print(cmd);
   //End the command
   mpCom->print("\r\n");
   //Wait for the appropriate number of chars, respecting the timeout.
   unsigned long startTime = millis();
   while(mpCom->available() < replyLength) {
     if( (millis()-startTime) >=timeoutMillis ) {
       //Timed out!
       return false;
     }
   }
   //Read in the chars.
   for(uint8_t x=0; x<replyLength; x++) {
     reply[x]=mpCom->read();
   }
   //Drain buffer.
   while(mpCom->available()) mpCom->read();
   return true;
}

boolean iSeries::FindAndReset() {
  byte resp[3];
  IssueCommand("Z02", resp, 3, 3000);
  return resp[0]=='Z' && resp[1]=='0' && resp[2]=='2';
}

//TODO: Consolidate GetReadingString and GetReading implementations. They should share code.

boolean iSeries::GetReadingString(byte* buffer) {
  byte resp[8];
  boolean rv = IssueCommand("X01", resp, 8, 1000);
  if(rv && resp[0]=='X' && resp[1]=='0' && resp[2]=='1') {
    //All OK
    for(uint8_t x=3;x<8;x++)
      buffer[x-3] = resp[x];
    return true;
  } else {
    //ERROR
    return false;
  }
}

double iSeries::GetReading() {
  byte resp[9]; //one extra byte for null termination 
  boolean rv = IssueCommand("X01", resp, 8, 1000);
  if(rv && resp[0]=='X' && resp[1]=='0' && resp[2]=='1') {
    //All OK
    resp[8]=0; //insert null termination for atof
    return atof((char*)&(resp[3]));
  } else {
    //ERROR
    return NAN;
  }
}
