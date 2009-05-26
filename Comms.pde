#include "Pins.h"

#include <NewSoftSerial.h>

#define COM1_SPEED 4800
#define GDLOX_SPEED 4800

NewSoftSerial com_1(COM1_RX, COM1_TX);
SoftwareSerial com_2(GDLOX_RX, GDLOX_TX);

void InitComms() {
  com_1.begin(COM1_SPEED);
  com_2.begin(GDLOX_SPEED);
}

