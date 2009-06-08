#include "Pins.h"
#include "Debug.h"
#include "EEPROMFormat.h"

#define SAVE_INTERVAL 3000

unsigned long lastTime; //relative time only

boolean wasReset;

void setup() {
  Serial.begin(9600);
  pinMode(LEDPIN, OUTPUT);
  
  if(isSecondary()) {
    enterMonitorMode();
  } else {
    DEBUG("Determined we're primary.\n");
  }
  
  pinMode(TC_INOUT_REDUNDANCY, OUTPUT);
  
  pinMode(RSTPIN, INPUT);
  
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
