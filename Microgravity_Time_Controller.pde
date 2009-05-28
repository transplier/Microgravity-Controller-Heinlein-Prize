#include "Pins.h"
#include "Debug.h"
#include "EEPROMFormat.h"

#define SAVE_INTERVAL 3000

unsigned long lastTime;

boolean wasReset;

byte temp[256];

void setup() {
  pinMode(LEDPIN, OUTPUT);
  pinMode(RSTPIN, INPUT);
  
  Serial.begin(9600);
  Serial.println("Controller V.01");

  CheckForReset();

  time_setup(wasReset);
  
  lastTime = get_time();
  Serial.print("Current time is: ");
  Serial.println(lastTime);
  
  if(!(GetStatus() & EEPROM_STATUS_TRIGGERED)) {
    DEBUG("WAITING FOR TRIGGER...");
    wait_for_trigger();
    DEBUG("OK\n");

    WriteStatus(GetStatus() | EEPROM_STATUS_TRIGGERED);
  }
}

void loop() {
  digitalWrite(LEDPIN, HIGH);
  execute_time_events();
  digitalWrite(LEDPIN, LOW);
  delay(10);
}

void execute_event(byte command, byte data) {
  Serial.print("Trying to execute event of type: ");
  Serial.print(command, HEX);
  Serial.println();
}

void CheckForReset() {
  if(digitalRead(RSTPIN) == LOW) {
    wasReset = true;
    Serial.print("Resetting...");
    WriteStatus(EEPROM_STATUS_RESET_VALUE);
    Serial.println("Done.");
  } else wasReset = false;
}

void wait_for_trigger() {
  delay(100);
}
