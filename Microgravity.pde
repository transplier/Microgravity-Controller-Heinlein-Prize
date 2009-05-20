#include "Pins.h"
#include "Debug.h"
#include "EEPROMFormat.h"
#include "Goldelox.h"

#define SAVE_INTERVAL 10000
#define GDLOX_SPEED 9600

unsigned long lastTime;

Goldelox glox(GDLOX_RX, GDLOX_TX);
boolean gloxActive;

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
}

void loop() {
  unsigned long currentTime = GetTime();
  if(currentTime - lastTime >= SAVE_INTERVAL) {
    digitalWrite(LEDPIN, HIGH);
    DEBUG("Saving...\n");
    WriteTime();
    lastTime = currentTime;
    digitalWrite(LEDPIN, LOW);
  }
}

void CheckForReset() {
  if(digitalRead(RSTPIN) == LOW) {
    Serial.print("Resetting...");
    WriteStatus(EEPROM_STATUS_RESET_VALUE);
    Serial.println("Done.");
  }
}
