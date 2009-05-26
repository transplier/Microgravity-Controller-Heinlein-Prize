/**
 * @file
 * Goldelox class implementation.
 * @author Giacomo Ferrari progman32@gmail.com
 */
 
#include "Goldelox.h"


///////////HERE THERE BE DRAGONS. THIS FILE HAS MANY UGLY THINGS/////////////////////

//Major TODO: Find out why the heck NewSoftSerial likes to die here, and switch to it.
//After doing so, make issueCommand() respect minimum reply length parameter.

#include <SoftwareSerial.h>

Goldelox::Goldelox(SoftwareSerial* serial, byte rst) {
  mpGdlox = serial;
  mRstPin = rst;
  mStatus=reinit();
}

GoldeloxStatus Goldelox::reinit() {
  //Hold response of device to version request.
  byte b1, b2, b3, b4, b5;

  //Reset the device
  //TODO: Find out which delays can be eliminated/shortened.
  pinMode(mRstPin, OUTPUT);
  digitalWrite(mRstPin, HIGH);
  delay(100);
  digitalWrite(mRstPin, LOW);
  //Wait for settle.
  delay(500);
  digitalWrite(mRstPin, HIGH);
  delay(1000);
  
  //Auto-baud the device.
  if(!issueCommand("U", 1, 1)) return TIMED_OUT; //Timed out!
  
  //Read (garbage) until the device sends an ACK.
  //TODO: timeout gracefully instead of infini-looping if device does something funny.
  while((b1 = mpGdlox->read()) != GDLOX_ACK);
  
  if(b1 == GDLOX_ACK){
    //Found device! Ask for info.
    if(!issueCommand("V", 1, 5)) return TIMED_OUT; //Timed out!
    b1 = mpGdlox->read(); //Device type (should be GDLOX_DEVICE_TYPE)
    b2 = mpGdlox->read(); //Silicon rev
    b3 = mpGdlox->read(); //pmmc rev
    b4 = mpGdlox->read(); //Reserved (==0)
    b5 = mpGdlox->read(); //Reserved (==0)
    if( b1 == GDLOX_DEVICE_TYPE && b4 == 0 && b5 == 0) return OK;
    else return ERROR;
  } else { return ERROR; }
}

GoldeloxStatus Goldelox::initializeNewCard() {
  if(!issueCommand("@i", 2, 1)) return TIMED_OUT; //Timed out!
  //Check for ACK.
  byte in = mpGdlox->read();
  if(in == GDLOX_ACK) return OK;
  else if(in == GDLOX_NAK) return NO_CARD;
  else return ERROR;
}

//HACK: Totally ignores minReplyLength! FIX!
boolean Goldelox::issueCommand(const char* cmd, byte len, byte minReplyLength) {
  for(int x=0;x<len;x++)
    mpGdlox->print((byte)cmd[x]);
  return true;
}

GoldeloxStatus Goldelox::ls(byte* result, int len) {
  if(!issueCommand("@d*\0", 4, 5)) return TIMED_OUT; //Timed out!  
  byte in;
  for(int x=0;x<len;x++) {
    in=mpGdlox->read();
    if(in != GDLOX_ACK) result[x]=in;
    else { 
      result[x]=0;
      break;
    }
  }
  //TODO: discard extra bytes still in buffer (when switched to NewSoftSerial).
  return OK;
}

GoldeloxStatus Goldelox::write(const char* filename, boolean append, byte* data, int len) {
  //HACK: this bypasses issueCommand in the name of efficiency (don't want to build a new string).
  //Rethink the API and fix it.
  mpGdlox->print("@t");
  mpGdlox->print((char)(append ? 0x80 : 0x00));
  mpGdlox->print(filename);
  mpGdlox->print('\0');
  //Write len (big-endian)
  mpGdlox->print((char)((len>>24)&0xFF));
  mpGdlox->print((char)((len>>16)&0xFF));
  mpGdlox->print((char)((len>>8)&0xFF));
  mpGdlox->print((char)((len)&0xFF));
  for(int x=0; x<len; x++) {
    mpGdlox->print((char)data[x]);
  }
  return mpGdlox->read()==GDLOX_ACK ? OK:ERROR;
}

GoldeloxStatus Goldelox::del(const char* filename) {
  //HACK: this bypasses issueCommand in the name of efficiency (don't want to build a new string).
  //Rethink the API and fix it.
  mpGdlox->print("@e");
  mpGdlox->print(filename);
  mpGdlox->print('\0');
  return mpGdlox->read()==GDLOX_ACK ? OK:ERROR;
}

GoldeloxStatus Goldelox::read(const char* filename, byte* data, int len) {
  //TODO: Implement.
  return ERROR;
}

GoldeloxStatus Goldelox::status() {
  return mStatus;
}
