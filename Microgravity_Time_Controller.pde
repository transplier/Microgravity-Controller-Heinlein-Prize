#include "Pins.h"
#include "Debug.h"
#include "EEPROMFormat.h"

#define SAVE_INTERVAL 3000

unsigned long lastTime; //relative time only

boolean wasReset;

void setup() {
  Serial.begin(9600);
  pinMode(LEDPIN, OUTPUT);
      
  pinMode(TC_IN_RSTPIN, INPUT);
  digitalWrite(TC_IN_RSTPIN, HIGH); //turn on built-in pullup on TC_IN_RSTPIN.
  
  Serial.println("Controller V0.5");

  CheckForReset();

  time_setup(wasReset);
  
  lastTime = get_time();
  Serial.print("Current time is: ");
  Serial.println(lastTime);
  
  if(isSecondary()) {
    pinMode(TC_INOUT_REDUNDANCY, INPUT);
    enterMonitorMode();
  } else {
    pinMode(TC_INOUT_REDUNDANCY, OUTPUT);
    DEBUG("Determined we're primary.\n");
  }

  
  if(!(GetStatus() & EEPROM_STATUS_TRIGGERED)) {
    DEBUG("WAITING FOR TRIGGER...");
    wait_for_trigger();
    DEBUG("OK\n");

    WriteStatus(GetStatus() | EEPROM_STATUS_TRIGGERED);
  }
}

boolean redundancy_state = false;
void loop() {
  digitalWrite(LEDPIN, HIGH);
  execute_last_time_event();
  digitalWrite(LEDPIN, LOW);
  delay(10);
  if((millis() - lastTime) > SAVE_INTERVAL) {
    write_time();
    lastTime=millis();
  }
  digitalWrite(TC_INOUT_REDUNDANCY, redundancy_state);
  redundancy_state = !redundancy_state;
}

byte msg_buffer[8];
void execute_event(byte command, byte data1, byte data2) {
  Serial.print("Trying to execute event of type: ");
  Serial.print(command, HEX);
  Serial.println();
  msg_buffer[0] = command;
  msg_buffer[1] = data1;
  msg_buffer[3] = 'X';
  //transmitCommand(msg_buffer);
}

void CheckForReset() {
  if(digitalRead(TC_IN_RSTPIN) == LOW) {
    wasReset = true;
    Serial.print("Resetting...");
    WriteStatus(EEPROM_STATUS_RESET_VALUE);
    Serial.println("Done.");
  } else wasReset = false;
}

void wait_for_trigger() {
  delay(100);
}
