#include "Pins.h"
#include "Debug.h"
#include "EEPROMFormat.h"
#include "SplitComm.h"

#define SAVE_INTERVAL 3000

#define TIME_EVENT_COMMAND_SR_UPDATE 0x00
#define TIME_EVENT_COMMAND_COOLDOWN 0x0C

unsigned long lastTime; //relative time only

boolean wasReset;

void setup_pins() {
  pinMode(TC_OUT_POWER_SR_L, OUTPUT);
  pinMode(TC_OUT_POWER_SR_D, OUTPUT);
  pinMode(TC_OUT_POWER_SR_C, OUTPUT);
}

void setup() {
  Serial.begin(9600);        
  Serial.println("Controller V0.5");

  //Must do these before enterMonitorMode();
  pinMode(TC_IN_RSTPIN, INPUT);
  digitalWrite(TC_IN_RSTPIN, HIGH); //turn on built-in pullup on TC_IN_RSTPIN.
  pinMode(LEDPIN, OUTPUT);

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

  setup_pins();
  
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

void execute_event(byte command, byte data1, byte data2) {
  DEBUG("Trying to execute event of type: ");
  DEBUGF(command, HEX);
  DEBUG("\n");
  switch(command) {
    case TIME_EVENT_COMMAND_SR_UPDATE:
      update_power_sr(data1, data2);
    break;
    case TIME_EVENT_COMMAND_COOLDOWN:
      send_cooldown_request(data1);
    break;
    default:
      DEBUG("Invalid command.\n");
  }
}

void update_power_sr(byte lowbyte, byte highbyte) {
  digitalWrite(TC_OUT_POWER_SR_L, LOW);
  shiftOut(TC_OUT_POWER_SR_D, TC_OUT_POWER_SR_C, LSBFIRST, highbyte);
  shiftOut(TC_OUT_POWER_SR_D, TC_OUT_POWER_SR_C, LSBFIRST, lowbyte);
  digitalWrite(TC_OUT_POWER_SR_L, HIGH);
}

void send_cooldown_request(byte tc_id) {
  byte msg_buffer[8];
  msg_buffer[0] = SPLIT_COMM_COMMAND_COOLDOWN;
  msg_buffer[1] = tc_id;
  transmitCommand(msg_buffer);  
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
