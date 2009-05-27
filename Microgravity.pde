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
extern NewSoftSerial com_2;

Goldelox uDrive(&com_2, GDLOX_RST);
/**
 * True if the uDRIVE was found.
 */
boolean isUDriveActive;

byte temp[256];

iSeries iSeries1(&com_1);

boolean find_and_reset_iseries();

void setup() {
  pinMode(LEDPIN, OUTPUT);
  pinMode(RSTPIN, INPUT);
  
  Serial.begin(9600);
  Serial.println("Microgravity Logger Module V.01");

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
  if(digitalRead(RSTPIN) == LOW) ret = uDrive.del("iSeries1");
  strcpy((char*)temp, "Time (msec), Temperature\n");
  uDrive.write("iSeries1", true, temp, sizeof("Time (msec), Temperature\n")-1);
  
  lastTimeMillis = millis();

}

byte timeString[12];
void loop() {
  GoldeloxStatus ret1, ret2;
  unsigned long currentTime = millis();
  byte tempReading[6];
  if(currentTime - lastTimeMillis >= SAVE_INTERVAL) {
    digitalWrite(LEDPIN, HIGH);
    lastTimeMillis = currentTime;
    digitalWrite(LEDPIN, LOW);
    
    //Get and write reading + time.
    ltoa(currentTime, (char*)timeString, 10);
    byte firstnull = strlen((char*)timeString);
    timeString[firstnull] = ',';
    timeString[firstnull+1] = ' ';
    iSeries1.GetReadingString(tempReading);
    Serial.print("Reading: ");
    tempReading[5]='\0'; //kind of a hack, but...
    Serial.print((char*)tempReading);
    tempReading[5]='\n';
    Serial.print(" [");
    ret1 = uDrive.write("iSeries1", true, timeString, firstnull+1);
    Serial.print(".");
    ret2 = uDrive.write("iSeries1", true, tempReading, sizeof(tempReading));
    Serial.print(".] ");
    if(ret1 != OK || ret2 != OK) {
      Serial.println("ERROR!");
    } else {
      Serial.println("OK!");
    }
  }
}

