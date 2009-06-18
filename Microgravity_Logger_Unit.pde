/**
 * @file Main controller class for microgravity experiment.
 * @author Giacomo Ferrari progman32@gmail.com
 */
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
 * Period at which to write log data.
 */
#define SAVE_INTERVAL_MSEC 3000

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

iSeries iSeries(&com_1);

/**
 * Contains the total number of commands missed in a row by each
 * iSeries.
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
  GoldeloxStatus ret = uDrive.reinit();
  if(ret == OK) {
    DEBUG("OK!\n");
    isUDriveActive = true;
    log("GOLDELOX-DOS UDrive up.\n");
  } 
  else {
    isUDriveActive = false;
    log("ERROR ");
    log_int(ret);
    log("!\n");
  }  

#ifdef DODEBUG
  //GOLDELOX tests
  if(isUDriveActive) {
    //List dir
    byte temp[255];
    uDrive.ls(temp, sizeof(temp));
    log("Files on card: \n");
    log((char*)temp);
    log("Sample file tests: ");
    //Write data
    byte abc[3] = {
      'a', 'b', 'c'  };
    ret = uDrive.append("temp", abc, sizeof(abc));
    if(ret == OK) {
      log("[OK!] ");
    } 
    else {
      log("[ERROR COULDNT CREATE FILE] ");
      log_int(ret);
      log("!\n");
    }

    //TODO: Verify contents

    //Erase
    ret = uDrive.del("temp");
    if(ret == OK) {
      log("[OK!] ");
    } 
    else {
      log("[ERROR ");
      log_int(ret);
      log(" COULDNT CREATE FILE] ");
    }

    ret = uDrive.del("temp");
    if(ret == ERROR) {
      log("[OK!]");
    } 
    else if (ret == OK){
      log("[ERROR DELETED NONEXISTENT FILE] ");
    }
    log(" DONE\n");
  }
#endif

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
      log("UNKNOWN COMMAND\n"); 
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

      if(ret1 != OK || ret2 != OK) {
        DEBUG("ERROR WRITING TO GOLDILOX!\n");
        uDrive.reinit();
        log("uDRIVE: Had to reset!\n");
      } 
      else {
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

