#include "iSeries.h"

iSeries::iSeries(NewSoftSerial* com_) {
  com = com_;
}

boolean iSeries::issueCommand(const char* cmd, byte reply[], byte replyLength) {
  return issueCommand(cmd, reply, replyLength, ISERIES_CMD_DELAY);
}

boolean iSeries::issueCommand(const char* cmd, byte reply[], byte replyLength, int timeoutMillis) {
   com->print(ISERIES_RECOG_CHAR);
   com->print(cmd);
   com->print("\r\n");
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
}

boolean iSeries::findAndReset() {
  byte resp[3];
  issueCommand("Z02", resp, 3, 3000);
  return resp[0]=='Z' && resp[1]=='0' && resp[2]=='2';
}

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
  byte resp[9]; //extra null termination
  issueCommand("X01", resp, 8, 1000);
  if(resp[0]=='X' && resp[1]=='0' && resp[2]=='1') {
    //All OK
    resp[8]=0; //null for atoi
    return atof((char*)&(resp[3]));
  } else {
    //ERROR
    return NAN;
  }
}
