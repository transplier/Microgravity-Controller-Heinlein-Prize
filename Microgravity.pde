#include "Pins.h"
#include "Debug.h"
#include "EEPROMFormat.h"
#include "Goldelox.h"
#include "iSeries.h"

#include <SoftwareSerial.h>
#include <NewSoftSerial.h>

#define SAVE_INTERVAL 3000
#define GDLOX_SPEED 4800

unsigned long lastTime;

extern NewSoftSerial com_1;

Goldelox glox(GDLOX_RX, GDLOX_TX, GDLOX_RST);
boolean gloxActive;

boolean wasReset;

byte temp[256];

iSeries iSeries1(&com_1);

boolean FindAndResetISeries();

void setup() {
  pinMode(LEDPIN, OUTPUT);
  pinMode(RSTPIN, INPUT);
  
  Serial.begin(9600);
  Serial.println("Controller V.01");

  CheckForReset();

  TimeSetup();
  lastTime = GetTime();
  Serial.print("Current time is: ");
  Serial.println(lastTime);
  
  DEBUG("Initializing serial ports...");
  InitComms();
  DEBUG("OK!\n");
  
  DEBUG("Initializing GOLDELOX-DOS...");
  GoldeloxStatus ret = glox.begin(GDLOX_SPEED);
  if(ret == OK) {
    DEBUG("OK!\n");
    gloxActive = true;
  } else {
    gloxActive = false;
    DEBUG("ERROR ");
    DEBUG(ret);
    DEBUG("!\n");
  }  

  #ifdef DODEBUG
  //GOLDELOX tests
  
  //List dir
  glox.ls(temp, sizeof(temp));
  DEBUG("Files on card: \n");
  for(int x=0;x<sizeof(temp);x++) {
    if(temp[x]==0) break;
    DEBUG((char)temp[x]);
  }
  DEBUG("Sample file tests: ");
  //Write data
  byte abc[3] = {'a', 'b', 'c'};
  ret = glox.write("temp", true, abc, sizeof(abc));
  if(ret == OK) {
    DEBUG("[OK!] ");
  } else {
    DEBUG("[ERROR COULDNT CREATE FILE] ");
    DEBUG(ret);
    DEBUG("!\n");
  }
  
  //Verify contents
  
  //Erase
  ret = glox.del("temp");
  if(ret == OK) {
    DEBUG("[OK!] ");
  } else {
    DEBUG("[ERROR ");
    DEBUG(ret);
    DEBUG(" COULDNT CREATE FILE] ");
  }
  
  ret = glox.del("temp");
  if(ret == ERROR) {
    DEBUG("[OK!]");
  } else if (ret == OK){
    DEBUG("[ERROR DELETED NONEXISTENT FILE] ");
  }
  DEBUG(" DONE\n");
  #endif
  
  DEBUG("Resetting and finding iSeries on com1...");
  if(iSeries1.findAndReset())
    DEBUG("OK!\n");
  else
    DEBUG("FAIL!\n");

  DEBUG("Experiment reset- erasing logs.\n");
  if(wasReset) ret = glox.del("iSeries1");
  strcpy((char*)temp, "Time (msec), Temperature\n");
  glox.write("iSeries1", true, temp, sizeof("Time (msec), Temperature\n")-1);

}

byte timeString[12];
void loop() {
  unsigned long currentTime = GetTime();
  byte tempReading[6];
  if(currentTime - lastTime >= SAVE_INTERVAL) {
    digitalWrite(LEDPIN, HIGH);
    DEBUG("Saving...\n");
    WriteTime();
    lastTime = currentTime;
    digitalWrite(LEDPIN, LOW);
    
    //Get and write reading + time.
    ltoa(currentTime, (char*)timeString, 10);
    byte firstnull = strlen((char*)timeString);
    timeString[firstnull] = ',';
    timeString[firstnull+1] = ' ';
    glox.write("iSeries1", true, timeString, firstnull+1);
    iSeries1.getReadingString(tempReading);
    Serial.print("Reading: ");
    tempReading[5]='\0'; //kind of a hack, but...
    Serial.println((char*)tempReading);
    tempReading[5]='\n';
    glox.write("iSeries1", true, tempReading, sizeof(tempReading));
    
  }
}

void CheckForReset() {
  if(digitalRead(RSTPIN) == LOW) {
    wasReset = true;
    Serial.print("Resetting...");
    WriteStatus(EEPROM_STATUS_RESET_VALUE);
    Serial.println("Done.");
  } else wasReset = false;
}
