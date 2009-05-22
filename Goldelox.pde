#include "Goldelox.h"

#include <SoftwareSerial.h>

Goldelox::Goldelox(byte rx, byte tx, byte rst) : gdlox(rx, tx) {
  rxPin = rx;
  txPin = tx;
  rstPin = rst;
}

GoldeloxStatus Goldelox::begin(int speed) {
  byte b1, b2, b3, b4, b5;

  pinMode(rstPin, OUTPUT);
  pinMode(txPin, OUTPUT);
  digitalWrite(txPin, HIGH);
  digitalWrite(rstPin, HIGH);
  delay(100);
  digitalWrite(rstPin, LOW);
  gdlox.begin(speed);
  //Wait for settle.
  delay(500);
  digitalWrite(rstPin, HIGH);
  delay(1000);
  //Auto-baud the device.
  if(!issueCommand("U", 1, 1)) return TIMED_OUT; //Timed out!
  while((b1 = gdlox.read()) != GDLOX_ACK);
  if(b1 == GDLOX_ACK){
    //Found device! Ask for info.
    if(!issueCommand("V", 1, 5)) return TIMED_OUT; //Timed out!
    b1 = gdlox.read(); //Device type
    b2 = gdlox.read(); //Silicon rev
    b3 = gdlox.read(); //pmmc rev
    b4 = gdlox.read(); //Reserved (==0)
    b5 = gdlox.read(); //Reserved (==0)
    if( b1 == GDLOX_DEVICE_TYPE && b4 == 0 && b5 == 0) return OK;
    else return ERROR;
  } else { Serial.println(b1, HEX); return ERROR; }
}

GoldeloxStatus Goldelox::initializeNewCard() {
  if(!issueCommand("@i", 2, 1)) return TIMED_OUT; //Timed out!
  byte in = gdlox.read();
  if(in == GDLOX_ACK) return OK;
  else if(in == GDLOX_NAK) return NO_CARD;
  else return ERROR;
}

boolean Goldelox::issueCommand(const char* cmd, byte len, byte minReplyLength) {
  for(int x=0;x<len;x++)
    gdlox.print((byte)cmd[x]);
  return true;
}

GoldeloxStatus Goldelox::ls(byte* result, int len) {
  if(!issueCommand("@d*\0", 4, 5)) return TIMED_OUT; //Timed out!  
  byte in;
  for(int x=0;x<len;x++) {
    in=gdlox.read();
    if(in != GDLOX_ACK) result[x]=in;
    else { 
      result[x]=0;
      break;
    }
  }
  return OK;
}
