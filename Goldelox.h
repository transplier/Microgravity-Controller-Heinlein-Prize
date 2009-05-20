#ifndef GOLDELOX_H
#define GOLDELOX_H

#define GDLOX_ACK = 0x06
#define GDLOX_NAK = 0x15

#define GDLOX_POWERUP_DELAY 500

#include <NewSoftSerial.h>

#include "Pins.h"

class Goldelox
{
private:
  NewSoftSerial gdlox;
public:
  Goldelox(byte rx, byte tx, int speed);
};
#endif
