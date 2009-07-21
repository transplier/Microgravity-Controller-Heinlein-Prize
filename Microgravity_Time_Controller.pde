#include "git_info.h"

#include "Pins.h"
#include "Debug.h"
#include "EEPROMFormat.h"
#include "SplitComm.h"

/**
 * Period at which to save current time to non-volatile memory.
 */
#define SAVE_INTERVAL_MSEC 20000

#define TIME_EVENT_COMMAND_SR_UPDATE 0x00
#define TIME_EVENT_COMMAND_COOLDOWN 0x0C
#define TIME_EVENT_COMMAND_EXP_OFF 0xDE

/* When executing a thermostat power cycle, amount of time to hold power off. */
#define TC_RESET_TIME_MSEC 100 

/* Amount of time to energize the experiment power coils. */
#define RELAY_ACTUATION_MSEC 50 //Datasheet specifies 30 msec.

/**
 * Holds the last (since power on, not experiment start) time we wrote
 * down the experiment time to non-volatile memory.
 */
unsigned long timeWroteTime;

/**
 * The current value believed to be in the power SR.
 */
byte power_sr_highbyte, power_sr_lowbyte;

/**
 * True if the experiment was interrupted by power loss and subsequently
 * resumed from non-volatile memory. Set in setup().
 */
boolean wasReset;

/**
 * The last-written state of the heartbeat pin. Used in loop() to toggle said pin.
 */
boolean redundancy_state = false;

/**
 * Initializes the pin directions for the TC.
 */
void setup_pins() {
  pinMode(TC_OUT_POWER_SR_L, OUTPUT);
  pinMode(TC_OUT_POWER_SR_D, OUTPUT);
  pinMode(TC_OUT_POWER_SR_C, OUTPUT);
  pinMode(TC_OUT_EXP_TRIGGER_RELAY_ON, OUTPUT);
  pinMode(TC_OUT_EXP_TRIGGER_RELAY_OFF, OUTPUT);

}

void setup() {
  Serial.begin(9600);        
  Serial.println("Controller V1.0");
  Serial.println("Compiled from GIT rev: " GIT_REVISION);

  pinMode(LEDPIN, OUTPUT);

  /* Must setup these pins before enterMonitorMode(), so that CheckForReset works properly. */
  pinMode(TC_IN_RSTPIN, INPUT);
  digitalWrite(TC_IN_RSTPIN, HIGH); //turn on built-in pullup on TC_IN_RSTPIN so we default to not resetting if nothing is connected.
  
  /* Check for reset request, act on it if necessary.  */
  if(isResetRequested()) {
    wasReset = true;
    resetEEPROM();
  } else {
    wasReset = false;
  }

  /* Initialize the experiment time source, possibly loading from non-volatile memory if wasReset == true*/
  time_setup(wasReset);
  
  /* Initialize the periodic experiment state saving code */
  timeWroteTime = get_time();
  
  DEBUG("Current time is: ");
  DEBUGF(timeWroteTime, DEC);
  
  /* Enter monitor mode if we're the secondary unit. */
  DEBUG("Checking redundancy role...");
  if(isSecondary()) {
    DEBUG("secondary.\n");
    pinMode(TC_INOUT_REDUNDANCY, INPUT);
    enterMonitorMode();
  } else {
    DEBUG("primary.\n");
    pinMode(TC_INOUT_REDUNDANCY, OUTPUT);
  }

  setup_pins();
  
  /* 
     Make sure the experiment power defaults to off
     to correct the case where the processors were reset without the power
     SR losing power, or if we're the secondary unit taking over.
   */
  set_exp_power_on(false);
  
  /* 
     If the non-volatile memory indicates that we have not been triggered yet,
     wait for the trigger. Otherwise, continue on.
   */
  if(!(GetStatus() & EEPROM_STATUS_TRIGGERED)) {
    DEBUG("WAITING FOR TRIGGER...");
    wait_for_trigger();
    DEBUG("OK\n");
    WriteStatus(GetStatus() | EEPROM_STATUS_TRIGGERED);
  }
  
  /* Turn on the rest of the experiment, it's time to begin! */
  set_exp_power_on(true);
}

void loop() {

  /* Execute the most recent time event (even if it's already run before). */
  execute_last_time_event();
  
  delay(10);
  
  /* If it's time we wrote the time down in non-volatile memory, do it. */
  if((millis() - timeWroteTime) > SAVE_INTERVAL_MSEC) {
    digitalWrite(LEDPIN, HIGH);
    write_time();
    timeWroteTime=millis();
    delay(10);
    digitalWrite(LEDPIN, LOW);
  }

  /* Check for incoming commands and act upon them. */
  byte incomingCommand[16];
  if(checkForCommand(incomingCommand)) {
    switch(incomingCommand[0]) {
    case SPLIT_COMM_COMMAND_RESET: 
      reset_tc(incomingCommand[1]);
      break;
    default: 
      DEBUG("UNKNOWN COMMAND\n"); 
      break;
    }
  }

  //Toggle the redundancy pin to let secondary know we're still alive (heartbeat).
  digitalWrite(TC_INOUT_REDUNDANCY, redundancy_state);
  redundancy_state = !redundancy_state;
}

/**
 * Set the state of the experiment power relay.
 * @param isOn True if the rest of the experiment should be turned on, false otherwise.
 */
void set_exp_power_on(boolean isOn) {
  digitalWrite(TC_OUT_EXP_TRIGGER_RELAY_ON, isOn);
  digitalWrite(TC_OUT_EXP_TRIGGER_RELAY_OFF, !isOn);
  delay(RELAY_ACTUATION_MSEC);
  digitalWrite(TC_OUT_EXP_TRIGGER_RELAY_ON, LOW);
  digitalWrite(TC_OUT_EXP_TRIGGER_RELAY_OFF, LOW);
}

/**
 * Execute a time event.
 * @param command The command code.
 * @data1 The first byte of data in the time event.
 * @data2 The second byte of data in the time event.
 */
void execute_event(byte command, byte data1, byte data2) {
  switch(command) {
    case TIME_EVENT_COMMAND_SR_UPDATE:
      update_power_sr(data1, data2);
    break;
    case TIME_EVENT_COMMAND_COOLDOWN:
      send_cooldown_request(data1);
    break;
    case TIME_EVENT_COMMAND_EXP_OFF:
      set_exp_power_on(false);
    break;
    default:
    DEBUG("Trying to execute event of type: ");
      DEBUGF(command, HEX);
      DEBUG("\n");
      DEBUG("Invalid command.\n");
  }
}

/**
 * Writes two bytes to the power status shift register.
 * SIDE EFFECT: updates power_sr_lowbyte and power_sr_highbyte with the provided
 * values.
 */
void update_power_sr(byte lowbyte, byte highbyte) {
  power_sr_lowbyte = lowbyte;
  power_sr_highbyte = highbyte;
  write_power_sr();
}

/**
 * Writes the contents of power_sr_lowbyte and power_sr_highbyte to the
 * power status shift register.
 */
void write_power_sr() {
  digitalWrite(TC_OUT_POWER_SR_L, LOW);
  shiftOut(TC_OUT_POWER_SR_D, TC_OUT_POWER_SR_C, MSBFIRST, power_sr_highbyte);
  shiftOut(TC_OUT_POWER_SR_D, TC_OUT_POWER_SR_C, MSBFIRST, power_sr_lowbyte);
  digitalWrite(TC_OUT_POWER_SR_L, HIGH);
}

/**
 * Resets the thermostat specified. Assumes contents of power status SR is the
 * same as the data in power_sr_lowbyte and power_sr_highbyte.
 * @param tc_id the thermostat's ID.
 */
void reset_tc(byte tc_id) {
  /* Create a mask with a zero at the (tc_id % 8)'th position. */
  byte mask = ~(1 << (tc_id % 8));
  byte oldValue;
  
  if(tc_id >= 8) {
    oldValue = power_sr_highbyte;
    update_power_sr(power_sr_lowbyte, power_sr_highbyte & mask);
    delay(TC_RESET_TIME_MSEC);
    update_power_sr(power_sr_lowbyte, oldValue);
  } else {
    oldValue = power_sr_lowbyte;
    update_power_sr(power_sr_lowbyte & mask, power_sr_highbyte);
    delay(TC_RESET_TIME_MSEC);
    update_power_sr(oldValue, power_sr_highbyte);
  }
}

/**
 * Send a message to the Logger Unit requesting it to send a cooldown command
 * to a given thermostat.
 * @param tc_id the thermostat's id.
 */
void send_cooldown_request(byte tc_id) {
  byte msg_buffer[8];
  msg_buffer[0] = SPLIT_COMM_COMMAND_COOLDOWN;
  msg_buffer[1] = tc_id;
  transmitCommand(msg_buffer);  
}

/**
 * @return true if the experiment should be restarted.
 */
boolean isResetRequested() {
  return digitalRead(TC_IN_RSTPIN) == LOW;
}

/**
 * Erases experiment state, and resets status byte to EEPROM_STATUS_RESET_VALUE.
 */
void resetEEPROM() {
  DEBUG("Resetting...");
  WriteStatus(EEPROM_STATUS_RESET_VALUE);
  DEBUG("Done.");
}

/**
 * Block until microgravity is established!
 */
void wait_for_trigger() {
  //TODO implement
  delay(100);
}

/*
 * Logs a null-terminated string to the debug console.
 */
inline void log(char* x) {
  DEBUG(x);
}

/*
 * Logs an integer to the debug console.
 */
inline void log_int(int x) {
  DEBUGF(x, DEC);
}
