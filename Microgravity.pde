#include "Pins.h"
#include "Debug.h"
#include "EEPROMFormat.h"
#include "Goldelox.h"
#include "iSeries.h"

#include <SoftwareSerial.h>
#include <NewSoftSerial.h>

#define SAVE_INTERVAL 10000
#define GDLOX_SPEED 4800

unsigned long lastTime;

extern NewSoftSerial com_1;

Goldelox glox(GDLOX_RX, GDLOX_TX, GDLOX_RST);
boolean gloxActive;

iSeries iSeries1(&com_1);

boolean FindAndResetISeries();

void setup() {
  pinMode(LEDPIN, OUTPUT);
  pinMode(RSTPIN, INPUT);
  
  Serial.begin(9600);
  Serial.println("Controller V.01");

  CheckForReset();

  TimeSetup();
  lastTime = GetTime();
  Serial.print("Current time is: ");
  Serial.println(lastTime);
  
  DEBUG("Initializing serial ports...");
  InitComms();
  DEBUG("OK!\n");
  
  DEBUG("Initializing GOLDELOX-DOS...");
  GoldeloxStatus ret = glox.begin(GDLOX_SPEED);
  if(ret == OK) {
    DEBUG("OK!\n");
    gloxActive = true;
  } else {
    gloxActive = false;
    DEBUG("ERROR ");
    DEBUG(ret);
    DEBUG("!\n");
  }
  
  DEBUG("Resetting and finding iSeries on com1...");
  if(iSeries1.findAndReset())
    DEBUG("OK!\n");
  else
    DEBUG("FAIL!\n");
    
  //byte res[1];
  //glox.ls(res, 5);
  /*Serial.print("Result: ");
  for(int x=0;x<1;x++)
    Serial.print(res[x],HEX);
  Serial.println('|');*/

}

void loop() {
  unsigned long currentTime = GetTime();
  if(currentTime - lastTime >= SAVE_INTERVAL) {
    digitalWrite(LEDPIN, HIGH);
    DEBUG("Saving...\n");
    WriteTime();
    lastTime = currentTime;
    digitalWrite(LEDPIN, LOW);
    
    double reading = iSeries1.getReading();
    Serial.print("Reading: ");
    Serial.println(reading);
  }
}

void CheckForReset() {
  if(digitalRead(RSTPIN) == LOW) {
    Serial.print("Resetting...");
    WriteStatus(EEPROM_STATUS_RESET_VALUE);
    Serial.println("Done.");
  }
}
