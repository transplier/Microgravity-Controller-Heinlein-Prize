/**
 * @file Main controller class for microgravity experiment.
 * @author Giacomo Ferrari progman32@gmail.com
 */
#include "Pins.h"
#include "Debug.h"
#include "EEPROMFormat.h"
#include "Goldelox.h"
#include "iSeries.h"
#include "SplitComm.h"

#include <NewSoftSerial.h>

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

Goldelox uDrive(&com_2, GDLOX_RST);
/**
 * True if the uDRIVE was found.
 */
boolean isUDriveActive;

iSeries iSeries1(&com_1);

void setup() {
  Serial.begin(9600);
  Serial.println("Microgravity Logger Module V.01");
  pinMode(LEDPIN, OUTPUT);

  DEBUG("Initializing serial ports...");
  init_comms();
  DEBUG("OK!\n");
  
  DEBUG("Initializing GOLDELOX-DOS...");
  GoldeloxStatus ret = uDrive.reinit();
  if(ret == OK) {
    DEBUG("OK!\n");
    isUDriveActive = true;
  } else {
    isUDriveActive = false;
    DEBUG("ERROR ");
    DEBUG(ret);
    DEBUG("!\n");
  }  

  #ifdef DODEBUG
  //GOLDELOX tests
  
  //List dir
  byte temp[255];
  uDrive.ls(temp, sizeof(temp));
  DEBUG("Files on card: \n");
  for(int x=0;x<sizeof(temp);x++) {
    if(temp[x]==0) break;
    DEBUG((char)temp[x]);
  }
  DEBUG("Sample file tests: ");
  //Write data
  byte abc[3] = {'a', 'b', 'c'};
  ret = uDrive.write("temp", true, abc, sizeof(abc));
  if(ret == OK) {
    DEBUG("[OK!] ");
  } else {
    DEBUG("[ERROR COULDNT CREATE FILE] ");
    DEBUG(ret);
    DEBUG("!\n");
  }
  
  //TODO: Verify contents
  
  //Erase
  ret = uDrive.del("temp");
  if(ret == OK) {
    DEBUG("[OK!] ");
  } else {
    DEBUG("[ERROR ");
    DEBUG(ret);
    DEBUG(" COULDNT CREATE FILE] ");
  }
  
  ret = uDrive.del("temp");
  if(ret == ERROR) {
    DEBUG("[OK!]");
  } else if (ret == OK){
    DEBUG("[ERROR DELETED NONEXISTENT FILE] ");
  }
  DEBUG(" DONE\n");
  #endif
  
  DEBUG("Resetting and finding iSeries on com1...");
  if(iSeries1.FindAndReset())
    DEBUG("OK!\n");
  else
    DEBUG("FAIL!\n");

  strcpy((char*)temp, "Time (msec), Temperature\n");
  uDrive.write("iSeries1", true, temp, sizeof("Time (msec), Temperature\n")-1);
  
  lastTimeMillis = millis();

}

byte timeString[12];
void loop() {
  byte temp[16];
  
  if(checkForCommand(temp)) { //temp contains reply
    switch(temp[0]) {
      case SPLIT_COMM_COMMAND_EXP_TRIGGER: exp_triggered(); break;
      case SPLIT_COMM_COMMAND_COOLDOWN: issue_cooldown_command(temp[1]); break;
      default: DEBUG("UNKNOWN COMMAND\n"); break;
    }
  }

  GoldeloxStatus ret1, ret2;
  unsigned long currentTime = millis();
  byte tempReading[6];
  
  if(currentTime - lastTimeMillis >= SAVE_INTERVAL) {
    lastTimeMillis = currentTime;
    
    //Get and write reading + time.
    ltoa(currentTime, (char*)timeString, 10);    //Get current time into first part of timeString.

    byte firstnull = strlen((char*)timeString);  //Find the first null, replace it with a comma and a space
    timeString[firstnull] = ',';
    timeString[firstnull+1] = ' ';
    
    iSeries1.GetReadingString(tempReading);      //Place the temperature reported by the temp. controller into tempReading.
                                                 //Will be 5 chars (tempReading is 6 chars, so 1 extra).
    tempReading[5]='\0';                         //Null-terminate the temp reading using extra space at end of tempReading, so we can print it.
    DEBUG("Reading: ");
    DEBUG((char*)tempReading);
    
    tempReading[5]='\n';                         //Replace null with newline
    DEBUG(" [");
    ret1 = uDrive.write("iSeries1", true, timeString, firstnull+1);            //Write timestamp (of form "<timestamp>, ").
    DEBUG(".");
    ret2 = uDrive.write("iSeries1", true, tempReading, sizeof(tempReading));   //Write temperature reading (of form <reading>\n).
    DEBUG(".] ");
    
    if(ret1 != OK || ret2 != OK) {
      DEBUG("ERROR WRITING TO GOLDILOX!");
      uDrive.reinit();
    } else {
      DEBUG("OK!");
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
  iSeries1.IssueCommand("D03", reply, 3);
}

void exp_triggered() {
  DEBUG("EXPERIMENT TRIGGERED");
}
