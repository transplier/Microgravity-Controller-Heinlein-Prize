#include "Pins.h"

#include <NewSoftSerial.h>

#define COM1_SPEED 4800

NewSoftSerial com_1(COM1_RX, COM1_TX);

void InitComms() {
  com_1.begin(COM1_SPEED);
}

