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

char log_temp[5];
#define LOG(x) {DEBUG(x); uDrive.append("DEBUG.LOG", (byte*)x, strlen(x));}
#define LOG_INT(x) {DEBUGF(x, DEC); snprintf(log_temp, sizeof(log_temp), "%d", x); uDrive.append("DEBUG.LOG", (byte*)log_temp, strlen(log_temp));}
  
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
 * Interval at which state is saved
 */
#define SAVE_INTERVAL 3000

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
boolean isUDriveActive;

iSeries iSeries(&com_1);

void setup_pins() {
  pinMode(LEDPIN, OUTPUT);
  pinMode(LU_IN_COM1_RX, INPUT);
  pinMode(LU_IN_GDLOX_RX, INPUT);
  pinMode(LU_OUT_GDLOX_TX, OUTPUT);
  pinMode(LU_OUT_GDLOX_RST, OUTPUT);
  pinMode(LU_OUT_COM1_TX, OUTPUT);
}

void setup() {
  Serial.begin(9600);
  Serial.println("Microgravity Logger Module V.01");

  setup_pins();

  DEBUG("Initializing serial ports...");
  init_comms();
  DEBUG("OK!\n");

  LOG("Initializing GOLDELOX-DOS...");
  GoldeloxStatus ret = uDrive.reinit();
  if(ret == OK) {
    LOG("OK!\n");
    isUDriveActive = true;
  } 
  else {
    isUDriveActive = false;
    LOG("ERROR ");
    LOG_INT(ret);
    LOG("!\n");
  }  

#ifdef DODEBUG
  //GOLDELOX tests

  //List dir
  byte temp[255];
  uDrive.ls(temp, sizeof(temp));
  LOG("Files on card: \n");
  LOG((char*)temp);
  LOG("Sample file tests: ");
  //Write data
  byte abc[3] = {
    'a', 'b', 'c'  };
  ret = uDrive.append("temp", abc, sizeof(abc));
  if(ret == OK) {
    LOG("[OK!] ");
  } 
  else {
    LOG("[ERROR COULDNT CREATE FILE] ");
    LOG_INT(ret);
    LOG("!\n");
  }

  //TODO: Verify contents

  //Erase
  ret = uDrive.del("temp");
  if(ret == OK) {
    LOG("[OK!] ");
  } 
  else {
    LOG("[ERROR ");
    LOG_INT(ret);
    LOG(" COULDNT CREATE FILE] ");
  }

  ret = uDrive.del("temp");
  if(ret == ERROR) {
    LOG("[OK!]");
  } 
  else if (ret == OK){
    LOG("[ERROR DELETED NONEXISTENT FILE] ");
  }
  LOG(" DONE\n");
#endif

  LOG("Resetting and finding ");
  LOG_INT(NUMBER_OF_TEMP_CONTROLLERS);
  LOG(" iSeries on com1... [");
  for(byte id=0; id<NUMBER_OF_TEMP_CONTROLLERS; id++) {
    set_active_thermostat(id);
    LOG_INT(id);
    if(iSeries.FindAndReset()) {
        LOG(":OK ");
    } else {
        LOG(":XX ");
    }
  }
  LOG("] Done\n");

  init_logfiles();

  lastTimeMillis = millis();

}

void init_logfiles() {
  char filename[12];
  char header[100];
  LOG("Initializing logfiles...\n");
  strcpy(header, LOG_FILE_HEADER);
  for(byte id = 0; id<NUMBER_OF_TEMP_CONTROLLERS; id++) {
    snprintf(filename, sizeof(filename), LOG_FILE_NAME_FMT, id);
    LOG(filename);
    LOG("\n");
    uDrive.append(filename, (byte*)header, strlen(header));
  }
  LOG("Done\n");
}

byte timeString[12];
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
      LOG("UNKNOWN COMMAND\n"); 
      break;
    }
  }

  GoldeloxStatus ret1, ret2;
  unsigned long currentTime = millis();
  byte tempReading[6];
  char filename[12];

  if(currentTime - lastTimeMillis >= SAVE_INTERVAL) {
    lastTimeMillis = currentTime;

    for(byte id = 0; id<NUMBER_OF_TEMP_CONTROLLERS; id++) {
      //Activate the temp controller we're interested in.
      set_active_thermostat(id);

      //Get and write reading + time.
      ltoa(currentTime, (char*)timeString, 10);    //Get current time into first part of timeString.

      byte firstnull = strlen((char*)timeString);  //Find the first null, replace it with a comma and a space
      timeString[firstnull] = ',';
      timeString[firstnull+1] = ' ';

      iSeries.GetReadingString(tempReading);      //Place the temperature reported by the temp. controller into tempReading.
      //Will be 5 chars (tempReading is 6 chars, so 1 extra).
      tempReading[5]='\0';                         //Null-terminate the temp reading using extra space at end of tempReading, so we can print it.
      LOG("Reading: ");
      LOG((char*)tempReading);

      tempReading[5]='\n';                         //Replace null with newline

      //Get filename
      snprintf(filename, sizeof(filename), LOG_FILE_NAME_FMT, id);

      LOG(" [");
      ret1 = uDrive.append(filename, timeString, firstnull+1);            //Write timestamp (of form "<timestamp>, ").
      LOG(".");
      ret2 = uDrive.append(filename, tempReading, sizeof(tempReading));   //Write temperature reading (of form <reading>\n).
      LOG(".] ");

      if(ret1 != OK || ret2 != OK) {
        DEBUG("ERROR WRITING TO GOLDILOX!\n");
        uDrive.reinit();
      } 
      else {
        LOG("OK!\n");
      }
    }
  }
}

void set_active_thermostat(byte ts_id) {
  DEBUG("Setting active thermostat: ");
  DEBUGF(ts_id, DEC);
  DEBUG("\n");
  //TODO implement
}

void issue_cooldown_command(byte ts_id) {
  set_active_thermostat(ts_id);
  byte reply[3];
  iSeries.IssueCommand("D03", reply, 3);
}

void exp_triggered() {
  LOG("EXPERIMENT TRIGGERED");
}
