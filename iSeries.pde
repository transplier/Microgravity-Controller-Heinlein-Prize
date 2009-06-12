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
   //Get the device's attention.
   mpCom->print(ISERIES_RECOG_CHAR);
   //Send the command
   mpCom->print(cmd);
   //End the command
   mpCom->print("\r\n");
   
   
   //BEGIN HACK//////////////////////////////////////////
   //TODO: DON'T DO THIS! THIS IS A HACK TO MAKE THE SERIAL LIBRARIES WORK!
   //I don't really get why this delay must be here, but it stays for now.
   delay(timeoutMillis);
   if(mpCom->available() >= replyLength) {
     for(byte x=0; x<replyLength; x++) {
       reply[x]=mpCom->read();
     }
     //Drain buffer.
     while(mpCom->available()) mpCom->read();
     return true;
   } else {
     //something went wrong...
     return false;
   }
   //END HACK////////////////////////////////////////////
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
    for(int x=3;x<8;x++)
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
