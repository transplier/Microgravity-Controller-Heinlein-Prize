/**
 * @file Main controller class for microgravity experiment.
 * @author Giacomo Ferrari progman32@gmail.com
 */
#include "Pins.h"
#include "Debug.h"
#include "EEPROMFormat.h"
#include "Goldelox.h"
#include "iSeries.h"

#include <SoftwareSerial.h>
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
extern SoftwareSerial com_2;

Goldelox uDrive(&com_2, GDLOX_RST);
/**
 * True if the uDRIVE was found.
 */
boolean isUDriveActive;

/**
 * True if state was loaded on reset.
 */
boolean wasReset;

byte temp[256];

iSeries iSeries1(&com_1);

boolean find_and_reset_iseries();

void setup() {
  pinMode(LEDPIN, OUTPUT);
  pinMode(RSTPIN, INPUT);
  
  Serial.begin(9600);
  Serial.println("Controller V.01");

  check_for_reset();

  time_setup();
  lastTimeMillis = get_time();
  Serial.print("Current time is: ");
  Serial.println(lastTimeMillis);
  
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

  //TODO: Maybe copy them over to an alternate location?
  DEBUG("Experiment reset- erasing logs.\n");
  if(wasReset) ret = uDrive.del("iSeries1");
  strcpy((char*)temp, "Time (msec), Temperature\n");
  uDrive.write("iSeries1", true, temp, sizeof("Time (msec), Temperature\n")-1);

}

byte timeString[12];
void loop() {
  //TODO: This function is simply a placeholder that simply reads the temperature and appends it to the log. This WILL be replaced.
  unsigned long currentTime = get_time();
  byte tempReading[6];
  if(currentTime - lastTimeMillis >= SAVE_INTERVAL) {
    digitalWrite(LEDPIN, HIGH);
    DEBUG("Saving...\n");
    write_time();
    lastTimeMillis = currentTime;
    digitalWrite(LEDPIN, LOW);
    
    //Get and write reading + time.
    ltoa(currentTime, (char*)timeString, 10);
    byte firstnull = strlen((char*)timeString);
    timeString[firstnull] = ',';
    timeString[firstnull+1] = ' ';
    uDrive.write("iSeries1", true, timeString, firstnull+1);
    iSeries1.GetReadingString(tempReading);
    Serial.print("Reading: ");
    tempReading[5]='\0'; //kind of a hack, but...
    Serial.println((char*)tempReading);
    tempReading[5]='\n';
    uDrive.write("iSeries1", true, tempReading, sizeof(tempReading));
    
  }
}

/**
 * If RSTPIN is low, invalidates time signature and sets wasReset.
 */
void check_for_reset() {
  if(digitalRead(RSTPIN) == LOW) {
    wasReset = true;
    Serial.print("Resetting...");
    WriteStatus(EEPROM_STATUS_RESET_VALUE);
    Serial.println("Done.");
  } else wasReset = false;
}
