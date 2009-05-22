#ifndef GOLDELOX_H
#define GOLDELOX_H

#define GDLOX_DEVICE_TYPE 3
#define GDLOX_ACK 0x06
#define GDLOX_NAK 0x15

#define GDLOX_POWERUP_DELAY 500
#define GDLOX_CMD_DELAY 500

#include <SoftwareSerial.h>

enum GoldeloxStatus{ OK, TIMED_OUT, ERROR, NO_CARD };

class Goldelox
{
private:
  SoftwareSerial gdlox;
  byte rxPin, txPin, rstPin;
  boolean issueCommand(const char* cmd, byte len, byte minReplyLength);
public:
  Goldelox(byte rx, byte tx, byte rst);
  GoldeloxStatus begin(int speed);
  GoldeloxStatus initializeNewCard();
  GoldeloxStatus ls(byte* result, int len);
  GoldeloxStatus write(const char* filename, boolean append, byte* data, int len);
  GoldeloxStatus del(const char* filename);
  GoldeloxStatus read(const char* filename, byte* data, int len);
};
#endif
