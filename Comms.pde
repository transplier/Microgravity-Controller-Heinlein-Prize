/**
 * @file
 * C functions to initialize serial comms..
 * @author Giacomo Ferrari progman32@gmail.com
 */
#include "Pins.h"

#include <NewSoftSerial.h>
//#include <SoftwareSerial.h>

#define COM1_SPEED 4800
#define GDLOX_SPEED 4800

NewSoftSerial com_1(COM1_RX, COM1_TX);
NewSoftSerial com_2(GDLOX_RX, GDLOX_TX);

void init_comms() {
  com_1.begin(COM1_SPEED);
  com_2.begin(GDLOX_SPEED);
}

