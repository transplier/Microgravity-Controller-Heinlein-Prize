#ifndef ISERIES_H
#define ISERIES_H

#include <SoftwareSerial.h>

#define ISERIES_RECOG_CHAR '*'
#define ISERIES_CMD_DELAY 100

class iSeries
{
private:
  SoftwareSerial* com;
public:
  iSeries(SoftwareSerial* com);
  boolean issueCommand(const char* cmd, byte reply[], byte replyLength);
  boolean issueCommand(const char* cmd, byte reply[], byte replyLength, int timeoutMillis);
};
#endif
