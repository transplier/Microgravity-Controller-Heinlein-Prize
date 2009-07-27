/**
 * @file Main controller class for microgravity experiment.
 * @author Giacomo Ferrari progman32@gmail.com
 */
 
#include "git_info.h"
 
#include <stdio.h>

#include "Pins.h"
#include "Debug.h"
#include "EEPROMFormat.h"
#include "Goldelox.h"
#include "iSeries.h"
#include "SplitComm.h"

#include <NewSoftSerial.h>
  
/**
 * Format of log file name in printf format. First argument is temp controller id.
 */
#define LOG_FILE_NAME_FMT "temps%02d.log"

/**
 * Name of redundant logfile.
 */
#define REDUNDANT_LOG_FILE_NAME "redun.log"

/**
 * Appended to the logfiles whenever power is switched on.
 */
#define LOG_FILE_HEADER "Time (msec), Temperature\n"

/**
 * Number of temperature controllers (addresses assumed to start from zero and end at this value minus one.
 */
#define NUMBER_OF_TEMP_CONTROLLERS 1

/**
 * After a Temperature Controller fails to respond this many times, it is reset.
 */
#define ISERIES_MAX_MISSED_COMMANDS 4

/**
 * After the UDrive misses these many commands, we give up.
 */
#define UDRIVE_MAX_MISSED_COMMANDS 10

/**
 * Delay between querying and logging data provided by the last thermostat and restarting from the first.
 */
#define SAVE_INTERVAL_MSEC 3000

/**
 * Character printed on the iSeries line to make the secondary start/stop logging whatever appears on the iSeries line.
 */
#define REDUNDANT_LOG_START_CHAR '^'
#define REDUNDANT_LOG_STOP_CHAR '$'

/**
 * last time we saved state.
 */
unsigned long lastTimeMillis;

extern NewSoftSerial com_1;
extern NewSoftSerial com_2;

Goldelox uDrive(&com_2, LU_OUT_GDLOX_RST);
/**
 * True if the uDRIVE was found.
 */
boolean isUDriveActive = false;

byte udriveResets = 0;

/**
 * Single, shared iSeries instance (used for all thermostats, assumed to be stateless.
 */
iSeries iSeries(&com_1);

/**
 * Contains the total number of commands missed in a row by each
 * iSeries. Reset to zero every time a reply is received.
 */
byte iSeriesMissedCommandCount[NUMBER_OF_TEMP_CONTROLLERS];

void setup_pins() {
  pinMode(LEDPIN, OUTPUT);
  pinMode(LU_IN_COM1_RX, INPUT);
  pinMode(LU_IN_GDLOX_RX, INPUT);
  pinMode(LU_OUT_GDLOX_TX, OUTPUT);
  pinMode(LU_OUT_GDLOX_RST, OUTPUT);
  pinMode(LU_OUT_COM1_TX, OUTPUT);
  pinMode(LU_OUT_SADDR_D, OUTPUT);
  pinMode(LU_OUT_SADDR_C, OUTPUT);
  pinMode(LU_OUT_RST_REQ, OUTPUT);
  pinMode(LU_OUT_REDUN_SR_D, OUTPUT);
  pinMode(LU_OUT_REDUN_SR_C, OUTPUT);
}

void setup() {
  Serial.begin(9600);
  Serial.println("Microgravity Logger Module V1.0");
  Serial.println("Compiled from GIT commit: " GIT_REVISION); 

  setup_pins();

  /* If we're the secondary, make sure the primary
   * has control in case the processors were reset
   * without the redundancy code SR losing power.
   */
  if(isSecondary()) {
    lockRedundancy();
  }
  
  DEBUG("Initializing serial ports...");
  init_comms();
  DEBUG("OK!\n");

  log("Initializing GOLDELOX-DOS UDrive...");
  GoldeloxStatus ret;
  /* Loop forever until uDrive is up. Without the uDrive, we are nothing. */
  while(true) {
    ret = uDrive.reinit();
    if(ret == OK) {
      isUDriveActive = true;
      break;
    } else {
      isUDriveActive = false;
      log("ERROR ");
      log_int(ret);
      log("!\n");
      delay(100);
    }
  }
  udriveResets = 0;

  log("Compiled from GIT commit: " GIT_REVISION); 

  init_logfiles();
  lastTimeMillis = millis();
  
  log("Checking redundancy role...");
  if(isSecondary()) {
    log("secondary.\n");
    pinMode(LU_INOUT_REDUNDANCY, INPUT);
    enterMonitorMode();
  } else {
    log("primary.\n");
    pinMode(LU_INOUT_REDUNDANCY, OUTPUT);
  }

  log("Resetting and finding ");
  log_int(NUMBER_OF_TEMP_CONTROLLERS);
  log(" iSeries on com1... [");
  for(byte id=0; id<NUMBER_OF_TEMP_CONTROLLERS; id++) {
    set_active_thermostat(id);
    log_int(id);
    if(iSeries.FindAndReset()) {
        log(": OK ");
    } else {
        log(":ERR ");
    }
  }
  log("] Done\n");

  init_logfiles();

  lastTimeMillis = millis();

}

/**
 * Writes the header (LOG_FILE_HEADER) to the top of NUMBER_OF_TEMP_CONTROLLERS
 * log files. Names are formatted according to LOG_FILE_NAME_FMT.
 */
void init_logfiles() {
  char filename[12];
  char header[100];
  log("Initializing logfiles...\n");
  strcpy(header, LOG_FILE_HEADER);
  for(byte id = 0; id<NUMBER_OF_TEMP_CONTROLLERS; id++) {
    snprintf(filename, sizeof(filename), LOG_FILE_NAME_FMT, id);
    log(filename);
    log("\n");
    uDrive.append(filename, (byte*)header, strlen(header));
  }
  log("Done\n");
}

/* Last known state of redundancy input pin */
boolean redundancy_state = false;
void loop() {
  byte temp[16];

  if(checkForCommand(temp)) { //temp contains reply
    switch(temp[0]) {
    case SPLIT_COMM_COMMAND_EXP_TRIGGER: 
      exp_triggered(); 
      break;
    case SPLIT_COMM_COMMAND_COOLDOWN: 
      issue_cooldown_command(temp[1]); 
      break;
    default: 
      log("UNKNOWN COMMAND: "); 
      log_int(temp[0]);
      log("\n");
      break;
    }
  }

  GoldeloxStatus ret1, ret2;
  unsigned long currentTime = millis();
  byte tempReading[6];
  char filename[12];
  byte timeString[12];

  //Is it time to write the log entries?
  if(currentTime - lastTimeMillis >= SAVE_INTERVAL_MSEC) {
    lastTimeMillis = currentTime;

    //Loop through all temperature controllers, logging their temperature data to their respective log files.
    for(byte id = 0; id<NUMBER_OF_TEMP_CONTROLLERS; id++) {
      //Activate the temp controller we're interested in.
      set_active_thermostat(id);

      //Get and write reading + time.
      ltoa(currentTime, (char*)timeString, 10);    //Get current time into first part of timeString.

      byte firstnull = strlen((char*)timeString);  //Find the first null, replace it with a comma and a space
      timeString[firstnull] = ',';
      timeString[firstnull+1] = ' ';

      boolean isOK = iSeries.GetReadingString(tempReading);      //Place the temperature reported by the temp. controller into tempReading.
      
      //Did the iSeries fail to reply?
      if(!isOK) {
        log("iSERIES ");
        log_int(id);
        log(": NO REPY! MISSED COMMANDS: ");
        log_int(iSeriesMissedCommandCount[id]);
        log("\n");
        iSeriesMissedCommandCount[id]++;
        
        //Did we miss too many commands?
        if(iSeriesMissedCommandCount[id] > ISERIES_MAX_MISSED_COMMANDS) {
          issue_reset_command(id);
          iSeriesMissedCommandCount[id] = 0; //give TC a little more time to reboot.
        }
      } else {
        if(iSeriesMissedCommandCount[id] > 0) {
          log("iSERIES ");
          log_int(id);
          log(": Back!\n");
        }
        iSeriesMissedCommandCount[id] = 0;
      }
      
      //Temp. reading will be 5 chars (tempReading itself is 6 chars, so we have 1 extra byte).
      tempReading[5]='\n';    //Put a newline at the end, for prettiness purposes.

      //Get filename
      snprintf(filename, sizeof(filename), LOG_FILE_NAME_FMT, id);

      //Write the log point.
      ret1 = uDrive.append(filename, timeString, firstnull+1);            //Write timestamp (of form "<timestamp>, ").
      ret2 = uDrive.append(filename, tempReading, sizeof(tempReading));   //Write temperature reading (of form <reading>\n).

      //Get the secondary's attention.
      com_1.print(REDUNDANT_LOG_START_CHAR);
      //Send the stuff to log.
      com_1.print(filename);
      com_1.print('|');
      for(byte x=0; x < firstnull +1; x++)
        com_1.print((char)timeString[x]); //TODO check location of nulls for this string...
      com_1.print('|');
      for(byte x=0; x < sizeof(tempReading); x++)
        com_1.print((char)tempReading[x]);
      com_1.print(REDUNDANT_LOG_STOP_CHAR);


      if(ret1 != OK || ret2 != OK) {
        DEBUG("ERROR WRITING TO GOLDILOX!\n");
        udriveResets++;
        uDrive.reinit();
        log("uDRIVE: Had to reset!\nReset count: ");
        log_int(udriveResets);
        log("\n");
        if(udriveResets > UDRIVE_MAX_MISSED_COMMANDS) {
          //UDrive seems dead. We have no more reason to keep using this microcontroller. Attempt to give command back to other microcontroller.
          if(isSecondary()) {
            //We seem to have a dead uDrive, so we're useless.
            //Bring primary back up (it may be dead) and re-enter monitor mode by issuing a reset.
            //TODO: this jmp is a hack, it's not really a reset. Beware.
            asm volatile ("jmp 0x0000");
          } else {
            //We're the primary. Enter infinite loop so that the secondary will attempt a reset.
            //Heartbeat line won't be pulsed until main loop is entered, which won't happen unless the uDrive
            //is detected in setup().
            //If the uDrive is really dead, this will cause the secondary to take over eventually.
            log("uDRIVE is dead. Entering infinite loop.\n");
            while(true){}
          }
        }
      } 
      else {
        udriveResets=0;
        log("OK!\n");
      }
    }
  }
  
  //Toggle the redundancy pin to let secondary know we're still alive (heartbeat).
  digitalWrite(LU_INOUT_REDUNDANCY, redundancy_state);
  redundancy_state = !redundancy_state;
}

/**
 * Selects the active thermostat by writing tc_id into the serial port selector SR.
 */
void set_active_thermostat(byte tc_id) {
  DEBUG("Setting active thermostat: ");
  DEBUGF(tc_id, DEC);
  DEBUG("\n");
  //Load id into SR.
  shiftOut(LU_OUT_SADDR_D, LU_OUT_SADDR_C, MSBFIRST, tc_id);
}

/**
 * Sends a standby command to a thermostat.
 */
void issue_cooldown_command(byte tc_id) {
  log("Cooldown request to ");
  log_int(tc_id);
  log("\n");
  set_active_thermostat(tc_id);
  byte reply[3];
  iSeries.IssueCommand("D03", reply, 3);
}

/**
 * Sends a reset thermostat request to the time controller.
 */
void issue_reset_command(byte tc_id) {
  log("Reset request to ");
  log_int(tc_id);
  log("\n");
  byte msg_buffer[8];
  msg_buffer[0] = SPLIT_COMM_COMMAND_RESET;
  msg_buffer[1] = tc_id;
  transmitCommand(msg_buffer);  
}

/*
 * Hook that will be called when the experiment is triggered.
 */
void exp_triggered() {
  log("EXPERIMENT TRIGGERED");
}

/*
 * Logs a null-terminated string to the debug console, and, if
 * the uDrive is active, DEBUG.LOG.
 */
void log(char* x) {
  DEBUG(x);
	if(isUDriveActive) {
	  uDrive.append("DEBUG.LOG", (byte*)x, strlen(x));
	}
}

/*
 * Logs an integer to the debug console, and, if
 * the uDrive is active, DEBUG.LOG.
 */
void log_int(int x) {
  char log_temp[5];
  DEBUGF(x, DEC);
  if(isUDriveActive) {
    snprintf(log_temp, sizeof(log_temp), "%d", x);
    uDrive.append("DEBUG.LOG", (byte*)log_temp, strlen(log_temp));
  }
}

