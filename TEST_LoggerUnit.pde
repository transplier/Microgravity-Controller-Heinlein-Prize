#include "iSeries.h"

#define NUMBER_OF_TEMP_CONTROLLERS 5

const char LU_Menu_a[] PROGMEM = "Thermostat monitor";
const char LU_Menu_b[] PROGMEM = "Thermostat serial console";
const char LU_Menu_c[] PROGMEM = "uDrive-DOS tests";
const char LU_Menu_d[] PROGMEM = "All Automatic LU tests";

const menu_item_t lu_menu[] = {
  { '0', LU_Menu_a, &ThermostatMonitor },
  { '1', LU_Menu_b, &ThermostatSerialConsole },
  { '2', LU_Menu_c, &GoldeloxTests },
  { '3', LU_Menu_d, &AllAutoLUTests },
};

const char EnterLoggerUnitMenu_hardwarewarn[] PROGMEM = "WARNING: HARDWARE TYPE SET TO TIMER! Automatically changing to logger!";
boolean EnterLoggerUnitMenu() {
  if( hardware == HARDWARE_TIMER ) {
    printPSln(EnterLoggerUnitMenu_hardwarewarn);
    delay(1000);
    hardware = HARDWARE_LOGGER;
  }
  menu = lu_menu;
  menu_size = sizeof(lu_menu) / sizeof(menu_item_t);
  return true;
}

boolean AllAutoLUTests() {
  return GoldeloxTests();
}

const char ThermostatSerialConsole_instructions[] PROGMEM = "Press [ / ] to switch thermostat, ` to toggle echo, and ESC to quit.";
const char ThermostatSerialConsole_status[] PROGMEM = "Current thermostat: ";
const char ThermostatSerialConsole_echostatus[] PROGMEM = "Echo: ";
boolean ThermostatSerialConsole() {
  init_hardware_pins();
  init_comms();
  printPSln(ThermostatSerialConsole_instructions);
  
  byte in;
  byte currTS = 0;
  boolean echo = true;
  printPS(ThermostatSerialConsole_status);
  println(currTS, DEC);
  printPS(ThermostatSerialConsole_echostatus);
  println(echo, DEC);
  com_1.print('\r');
  com_1.print('\n');
  while(true) {
    if(Serial.available()) {
      in=Serial.read();
      switch(in) {
        case 0x1B /*escape*/: Serial.println(); return true;
        case '`':
          echo = !echo;
          printPS(ThermostatSerialConsole_echostatus);
          println(echo, DEC);
        break;
        case ']': if(currTS<NUMBER_OF_TEMP_CONTROLLERS-1) currTS+=2; else continue; /*no break!*/
        case '[':
          if(currTS!=0) 
            currTS--; 
          else
            continue;
          printPS(ThermostatSerialConsole_status);
          println(currTS, DEC);
          set_active_thermostat(currTS);
        break;
        default: 
          if(echo) { 
            Serial.print(in, BYTE);
            if(in=='\r') Serial.println();
          }
          com_1.print(in, BYTE);
        break;
      }
    }
    while(com_1.available()) {
      in=com_1.read();
      Serial.write(in);
    }
  }
}

const char GoldeloxTests_init[] PROGMEM = "Initializing GOLDELOX-DOS UDrive...";
const char GoldeloxTests_ok[] PROGMEM = "OK";
const char GoldeloxTests_error[] PROGMEM = "ERROR ";
const char GoldeloxTests_files[] PROGMEM = "Files on card: ";
const char GoldeloxTests_filetests[] PROGMEM = "File tests: ";
const char GoldeloxTests_filecreateerror[] PROGMEM = "[ERROR COULDNT CREATE FILE] ";
const char GoldeloxTests_fileeraseerror[] PROGMEM = "[ERROR COULDNT ERASE FILE] ";
const char GoldeloxTests_fileeraseerror2[] PROGMEM = "[ERROR ERASED NONEXISTENT FILE] ";
const char GoldeloxTests_done[] PROGMEM = "DONE!";

boolean GoldeloxTests() {
  init_hardware_pins();
  init_comms();
  Goldelox uDrive(&com_2, LU_OUT_GDLOX_RST);
  printPS(GoldeloxTests_init);
  GoldeloxStatus ret;
  ret = uDrive.reinit();
  if(ret == OK) {
    printPSln(GoldeloxTests_ok);
  } else {
    printPS(GoldeloxTests_error);
    println(ret, DEC);
    return false;
  }

  //GOLDELOX tests
  //List dir
  byte temp[255];
  byte c, i=0;
  uDrive.ls(temp, sizeof(temp));
  printPSln(GoldeloxTests_files);
  //Print, converting \n to \r\n.
  while( temp[i] != '\0' ) {
    if(temp[i] == '\n') Serial.write('\r');
    if(temp[i] == '\r') Serial.write('\n');
    Serial.write(temp[i++]);
  }
  print((char*)temp);
  printPS(GoldeloxTests_filetests);
  //Write data
  byte abc[3] = {
    'a', 'b', 'c'  };
  ret = uDrive.append("temp", abc, sizeof(abc));
  if(ret == OK) {
    printPS(GoldeloxTests_ok);
    print(' ');
  } 
  else {
    printPS(GoldeloxTests_filecreateerror);
    println(ret, DEC);
    return false;
  }
  //TODO: Verify contents

  //Erase
  ret = uDrive.del("temp");
  if(ret == OK) {
    printPS(GoldeloxTests_ok);
    print(' ');
  } 
  else {
    printPS(GoldeloxTests_fileeraseerror);
    println(ret, DEC);
    return false;
  }

  ret = uDrive.del("temp");
  if(ret == ERROR) {
    printPS(GoldeloxTests_ok);
    print(' ');
  } 
  else if (ret == OK){
    printPS(GoldeloxTests_fileeraseerror2);
    println(ret, DEC);
    return false;
  }
  printPSln(GoldeloxTests_done);
  return true;
}

const char ThermostatMonitor_number[] PROGMEM = "Number of thermostats: ";
const char ThermostatMonitor_reptemp[] PROGMEM = "Reported temperatures:";
const char ThermostatMonitor_howtoquit[] PROGMEM = "ESC to quit.";
boolean ThermostatMonitor() {  
  init_hardware_pins();
  init_comms();
  iSeries iSeries(&com_1);
  
  /* Clear screen*/
  write(0x1B);
  write('[');
  write('2');
  write('J');
  /*Initialize the display*/
  printPS(ThermostatMonitor_number);
  println(NUMBER_OF_TEMP_CONTROLLERS);
  for(byte i = 0; i < NUMBER_OF_TEMP_CONTROLLERS; i++) {
    if(i<10) print('0');
    print(i, DEC);
    println(':');
  }
  printPSln(ThermostatMonitor_howtoquit);
    
  byte tempReading[6];
  tempReading[5]='\0';    //Put a null at the end, for printing.
  boolean isOK;
  while(Serial.read() != 0x1B) {
    for(byte i = 0; i < NUMBER_OF_TEMP_CONTROLLERS; i++) {
      set_active_thermostat(i);
      isOK = iSeries.GetReadingString(tempReading);      //Place the temperature reported by the temp. controller into tempReading.
      moveCursor(i+2, 5);
      /* Clear rest of line */
      write(0x1B);
      write('[');
      write('K');      

      if(isOK) {
        print((char*)tempReading);
      } else {
        write('X');
      }
    }
  }
  /* Clear screen*/
  write(0x1B);
  write('[');
  write('2');
  write('J');
  return true;
}

/* screen starts at (1,1), not (0,0), beware */
void moveCursor(byte row, byte col) {
  write(0x1B);
  write('[');
  print(row, DEC);
  write(';');
  print(col, DEC);
  write('H');
}

/**
 * Selects the active thermostat by writing tc_id into the serial port selector SR.
 */
void set_active_thermostat(byte tc_id) {
  //Load id into SR.
  shiftOut(LU_OUT_SADDR_D, LU_OUT_SADDR_C, MSBFIRST, tc_id);
}
