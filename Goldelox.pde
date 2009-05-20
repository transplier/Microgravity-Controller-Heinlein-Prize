#include "Goldelox.h"

Goldelox::Goldelox(byte rx, byte tx, int speed) : gdlox(rx, tx) {
  gdlox.begin(speed);
  //Wait for settle.
  delay(GDLOX_POWERUP_DELAY);
  //Auto-baud the device.
  gdlox.print('U');
  delay(100);
  byte b = gdlox.read();
  while(true) {
    Serial.println(b, HEX);
  }
}
