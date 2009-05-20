#include "Pins.h"
#include "Debug.h"
#include "EEPROMFormat.h"

#define SAVE_INTERVAL 10000

unsigned long lastTime;

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
  if(digitalRead(RSTPIN) == HIGH) {
    Serial.print("Resetting...");
    WriteStatus(EEPROM_STATUS_RESET_VALUE);
    Serial.println("Done.");
  }
}
