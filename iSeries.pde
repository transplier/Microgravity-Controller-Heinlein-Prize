#include "iSeries.h"

iSeries::iSeries(SoftwareSerial* com_) {
  com = com_;
}

boolean iSeries::issueCommand(const char* cmd, byte reply[], byte replyLength) {
  return issueCommand(cmd, reply, replyLength, ISERIES_CMD_DELAY);
}

boolean iSeries::issueCommand(const char* cmd, byte reply[], byte replyLength, int timeoutMillis) {
   com->print(ISERIES_RECOG_CHAR);
   com->print(cmd);
   com->print("\r\n");
   /* OLD INTERRUPT DRIVEN SERIAL CODE
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
   }*/
   /**TEMPORARY HACK FOR SOFTWARE SERIAL**/
   for(byte x=0; x<replyLength; x++) {
       reply[x]=com->read();
   }
}
