#include "Pins.h"

#include <SoftwareSerial.h>

#define COM1_SPEED 4800

SoftwareSerial com_1(COM1_RX, COM1_TX);

void InitComms() {
  com_1.begin(COM1_SPEED);
  /*while(1) {
    Serial.print((char)com_1.read());
    com_1.print("*");
  }*/
}

