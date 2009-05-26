#include "Goldelox.h"

#include <SoftwareSerial.h>

Goldelox::Goldelox(SoftwareSerial* serial, byte rst) {
  gdlox = serial;
  rstPin = rst;
  mStatus=reinit();
}

GoldeloxStatus Goldelox::reinit() {
  byte b1, b2, b3, b4, b5;

  pinMode(rstPin, OUTPUT);
  digitalWrite(rstPin, HIGH);
  delay(100);
  digitalWrite(rstPin, LOW);
  //Wait for settle.
  delay(500);
  digitalWrite(rstPin, HIGH);
  delay(1000);
  //Auto-baud the device.
  if(!issueCommand("U", 1, 1)) return TIMED_OUT; //Timed out!
  while((b1 = gdlox->read()) != GDLOX_ACK);
  if(b1 == GDLOX_ACK){
    //Found device! Ask for info.
    if(!issueCommand("V", 1, 5)) return TIMED_OUT; //Timed out!
    b1 = gdlox->read(); //Device type
    b2 = gdlox->read(); //Silicon rev
    b3 = gdlox->read(); //pmmc rev
    b4 = gdlox->read(); //Reserved (==0)
    b5 = gdlox->read(); //Reserved (==0)
    if( b1 == GDLOX_DEVICE_TYPE && b4 == 0 && b5 == 0) return OK;
    else return ERROR;
  } else { Serial.println(b1, HEX); return ERROR; }
}

GoldeloxStatus Goldelox::initializeNewCard() {
  if(!issueCommand("@i", 2, 1)) return TIMED_OUT; //Timed out!
  byte in = gdlox->read();
  if(in == GDLOX_ACK) return OK;
  else if(in == GDLOX_NAK) return NO_CARD;
  else return ERROR;
}

boolean Goldelox::issueCommand(const char* cmd, byte len, byte minReplyLength) {
  for(int x=0;x<len;x++)
    gdlox->print((byte)cmd[x]);
  return true;
}

GoldeloxStatus Goldelox::ls(byte* result, int len) {
  if(!issueCommand("@d*\0", 4, 5)) return TIMED_OUT; //Timed out!  
  byte in;
  for(int x=0;x<len;x++) {
    in=gdlox->read();
    if(in != GDLOX_ACK) result[x]=in;
    else { 
      result[x]=0;
      break;
    }
  }
  return OK;
}

GoldeloxStatus Goldelox::write(const char* filename, boolean append, byte* data, int len) {
  //TODO: this bypasses issueCommand!
  gdlox->print("@t");
  gdlox->print((char)(append ? 0x80 : 0x00));
  gdlox->print(filename);
  gdlox->print('\0');
  //Write len (big-endian)
  gdlox->print((char)((len>>24)&0xFF));
  gdlox->print((char)((len>>16)&0xFF));
  gdlox->print((char)((len>>8)&0xFF));
  gdlox->print((char)((len)&0xFF));
  for(int x=0; x<len; x++) {
    gdlox->print((char)data[x]);
  }
  return gdlox->read()==GDLOX_ACK ? OK:ERROR;
}

GoldeloxStatus Goldelox::del(const char* filename) {
  //TODO: this bypasses issueCommand!
  gdlox->print("@e");
  gdlox->print(filename);
  gdlox->print('\0');
  return gdlox->read()==GDLOX_ACK ? OK:ERROR;
}

GoldeloxStatus Goldelox::read(const char* filename, byte* data, int len) {
  return ERROR;
}

GoldeloxStatus Goldelox::status() {
  return mStatus;
}
