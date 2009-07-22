#include "EEPROMFormat.h"

menu_item_t eeprom_menu[] = {
  { 'f', "Show/Edit values", &EditEEPROMValues },
};

boolean EnterEEPROMMenu() {
  menu = eeprom_menu;
  menu_size = sizeof(eeprom_menu) / sizeof(menu_item_t);
  return true;
}

/**
 * Read the time signature from EEPROM, regardless of valid bit.
 * In case of checksum error, returns false.
 * TODO: merge with Time.pde.
 */
boolean ReadTimeFromEEPROM(unsigned long* time) {
  byte b1, b2, b3, b4; //Store pieces of time (it's a 4-byte long).
  //Read in the 4 bytes.
  b1 = ReadEEPROM(EEPROM_TIME_1);
  b2 = ReadEEPROM(EEPROM_TIME_2);
  b3 = ReadEEPROM(EEPROM_TIME_3);
  b4 = ReadEEPROM(EEPROM_TIME_4);
  if((b1 ^ b2 ^ b3 ^ b4) == ReadEEPROM(EEPROM_TIME_CHECK)) { //If the check value matches
    //Load in the values.
    *time = b1;
    *time |= ((unsigned long)b2<<8);
    *time |= ((unsigned long)b3<<16);
    *time |= ((unsigned long)b4<<24);
    return true;
  }
  return false;
}

/**
 * Write elapsed time to EEPROM. Don't touch flags.
 */
void write_time(unsigned long* time) {
  byte b1, b2, b3, b4, c; //Store bits of time
  b1 = *time & 0x000000FF;
  b2 = (*time & 0x0000FF00) >> 8;
  b3 = (*time & 0x00FF0000) >> 16;
  b4 = (*time & 0xFF000000) >> 24;
  c = b1 ^ b2 ^ b3 ^ b4;
  WriteEEPROM(EEPROM_TIME_1, b1);
  WriteEEPROM(EEPROM_TIME_2, b2);
  WriteEEPROM(EEPROM_TIME_3, b3);
  WriteEEPROM(EEPROM_TIME_4, b4);
  WriteEEPROM(EEPROM_TIME_CHECK, c);
}

boolean EditEEPROMValues() {
  byte statusByte = GetStatus();
  byte redunRoleByte = ReadEEPROM(EEPROM_IS_PRIMARY);
  boolean isSecdry = isSecondary();
  unsigned long time;
  boolean timeChksumOK = ReadTimeFromEEPROM(&time);
  
  int hours, minutes, seconds;

  while(true) {
    /* Status byte */
    print("\tStatus byte: ");
    println((int)statusByte, BIN);
    print("\t\t(T)ime signature is: ");
    if(statusByte & EEPROM_STATUS_TIME_VALID)
      println("valid.");
    else
      println("invalid.");
    print("\t\tExperiment (S)tatus: ");
    if(statusByte & EEPROM_STATUS_TRIGGERED)
      println("triggered.");
    else
       println("untriggered.");
    
    /* Redundancy role */
    print("\tRedundancy r(O)le byte: ");
    println(redunRoleByte, HEX);
    print("\t\tInterpretation: ");
    if(isSecdry)
      println("secondary.");
    else
      println("primary.");
    print("\tTime signature: ");
    if(timeChksumOK) {
      hours = time/3600000;
      minutes = (time - hours*3600000)/60000;
      seconds = (time - hours*3600000 - minutes*60000)/1000;
      print("valid. T=");
      print(time);
      print(' ');
      print(hours);
      print(':');
      print(minutes);
      print('.');
      println(seconds);
      println("\t\t+/-: add/subtract 1 second.");
      println("\t\tM/m: add/subtract 1 minute.");
      println("\t\tH/h: add/subtract 1 hour.");
      println("\t\tZ: zero.");
      println("\t\tD: delete.");
    } else {
      println("invalid (bad checksum). (Z)ero.");
    }
    println("W: Save and exit\r\nX: Exit without saving\r\nR: Reload from EEPROM");
    println("Select an option:");
    print("> ");
    char in = read_char_nice();
    switch(in) {
      case 't': 
        if(statusByte & EEPROM_STATUS_TIME_VALID) statusByte &= ~(EEPROM_STATUS_TIME_VALID);
        else statusByte |= EEPROM_STATUS_TIME_VALID;
      break;
      case 's':
        if(statusByte & EEPROM_STATUS_TRIGGERED) statusByte &= ~(EEPROM_STATUS_TRIGGERED);
        else statusByte |= EEPROM_STATUS_TRIGGERED;
      break;
      case 'o':
        isSecdry = !isSecdry;
        redunRoleByte = isSecdry ? EEPROM_IS_SECONDARY_VALUE : 0xDE;
      break;
      case 'z':
        timeChksumOK = true;
        time = 0;
      break;
      case '-': if(timeChksumOK) time -= 1000; break;
      case '+': if(timeChksumOK) time += 1000; break;
      case 'm': if(timeChksumOK) time -= 60000; break;
      case 'M': if(timeChksumOK) time += 60000; break;
      case 'h': if(timeChksumOK) time -= 3600000; break;
      case 'H': if(timeChksumOK) time += 3600000; break;
      case 'd': timeChksumOK=false; break;
      case 'w':
        WriteStatus(statusByte);
        WriteEEPROM(EEPROM_IS_PRIMARY, redunRoleByte);
        if(timeChksumOK)
          write_time(&time);
        else {
          //trash time.
          WriteEEPROM(EEPROM_TIME_1, 0);
          WriteEEPROM(EEPROM_TIME_2, 0);
          WriteEEPROM(EEPROM_TIME_3, 0);
          WriteEEPROM(EEPROM_TIME_4, 0);
          WriteEEPROM(EEPROM_TIME_CHECK, 0b10101);
        }
        return true;
      case 'x':
        return true;
      case 'r':
        statusByte = GetStatus();
        redunRoleByte = ReadEEPROM(EEPROM_IS_PRIMARY);
        isSecdry = isSecondary();
        timeChksumOK = ReadTimeFromEEPROM(&time);
        break;
      default:
        println("No such command!");
    }
  }
}
