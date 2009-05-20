#include "Goldelox.h"

#include <NewSoftSerial.h>

Goldelox::Goldelox(byte rx, byte tx) : gdlox(rx, tx) {
}

GoldeloxStatus Goldelox::begin(int speed) {
  gdlox.begin(speed);
  //Wait for settle.
  delay(GDLOX_POWERUP_DELAY);
  //Auto-baud the device.
  gdlox.print('U');
  unsigned long timer = millis();
  while(millis()-timer <= GDLOX_CMD_DELAY) {
    if(gdlox.available() > 0) { 
      timer = 0;
      break;
    }
  }
  if(timer != 0) return TIMED_OUT; //Timed out!
  
  byte b1, b2, b3, b4, b5;
  b1 = gdlox.read();
  if(b1 == GDLOX_ACK){
    //Found device! Ask for info.
    gdlox.print('V');
    timer = millis();
    while(millis()-timer <= GDLOX_CMD_DELAY) {
      if(gdlox.available() >= 5) { 
        timer = 0;
        break;
      }
    }
    if(timer != 0) return TIMED_OUT; //Bad reply?
    b1 = gdlox.read(); //Device type
    b2 = gdlox.read(); //Silicon rev
    b3 = gdlox.read(); //pmmc rev
    b4 = gdlox.read(); //Reserved (==0)
    b5 = gdlox.read(); //Reserved (==0)
    if( b1 == GDLOX_DEVICE_TYPE && b4 == 0 && b5 == 0) return OK;
    else return ERROR;
  }
}
