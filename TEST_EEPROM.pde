#include "EEPROMFormat.h"

const char EEPROM_Menu_edit[] PROGMEM = "Show/Edit values";
const menu_item_t eeprom_menu[] = {
  { '0', EEPROM_Menu_edit, &EditEEPROMValues },
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

const char EditEEPROMValues_statbyte[] PROGMEM = "\tStatus byte: ";
const char EditEEPROMValues_timesigis[] PROGMEM = "\t\t(T)ime signature is: ";
const char EditEEPROMValues_expstat[] PROGMEM = "\t\tExperiment (S)tatus: ";
const char EditEEPROMValues_redunrolebyte[] PROGMEM = "\tRedundancy r(O)le byte: ";
const char EditEEPROMValues_interp[] PROGMEM = "\t\tInterpretation: ";
const char EditEEPROMValues_adsub_second[] PROGMEM = "\t\t+/-: add/subtract 1 second.";
const char EditEEPROMValues_adsub_minute[] PROGMEM = "\t\tM/m: add/subtract 1 minute.";
const char EditEEPROMValues_adsub_hour[] PROGMEM = "\t\tH/h: add/subtract 1 hour.";
const char EditEEPROMValues_zero[] PROGMEM = "\t\tZ: zero.";
const char EditEEPROMValues_delete[] PROGMEM = "\t\tD: delete.";
const char EditEEPROMValues_bdchksum[] PROGMEM = "invalid (bad checksum). (Z)ero.";
const char EditEEPROMValues_miscopts[] PROGMEM = "w: Save and exit\r\nx: Exit without saving\r\nr: Reload from EEPROM";
const char EditEEPROMValues_selectopt[] PROGMEM = "Select an option:";
const char EditEEPROMValues_valid[] PROGMEM = "valid.";
const char EditEEPROMValues_invalid[] PROGMEM = "invalid.";
const char EditEEPROMValues_trig[] PROGMEM = "triggered.";
const char EditEEPROMValues_untrig[] PROGMEM = "untriggered.";
const char EditEEPROMValues_pri[] PROGMEM = "primary.";
const char EditEEPROMValues_sec[] PROGMEM = "secondary.";
const char EditEEPROMValues_timesig[] PROGMEM = "\tTime signature: ";
const char EditEEPROMValues_validT[] PROGMEM = "valid. T=";
extern const char STR_NOSUCHCOMMAND[] PROGMEM;
boolean EditEEPROMValues() {
  byte statusByte = GetStatus();
  byte redunRoleByte = ReadEEPROM(EEPROM_IS_PRIMARY);
  boolean isSecdry = isSecondary();
  unsigned long time;
  boolean timeChksumOK = ReadTimeFromEEPROM(&time);
  
  int hours, minutes, seconds;

  while(true) {
    /* Status byte */
    printPS(EditEEPROMValues_statbyte);
    println((int)statusByte, BIN);
    if(hardware == HARDWARE_TIMER) {
      printPS(EditEEPROMValues_timesigis);
      if(statusByte & EEPROM_STATUS_TIME_VALID)
        printPSln(EditEEPROMValues_valid);
      else
        printPSln(EditEEPROMValues_invalid);
      printPS(EditEEPROMValues_expstat);
      if(statusByte & EEPROM_STATUS_TRIGGERED)
        printPSln(EditEEPROMValues_trig);
      else
         printPSln(EditEEPROMValues_untrig);
    }
    /* Redundancy role */
    printPS(EditEEPROMValues_redunrolebyte);
    println(redunRoleByte, HEX);
    printPS(EditEEPROMValues_interp);
    if(isSecdry)
      printPSln(EditEEPROMValues_sec);
    else
      printPSln(EditEEPROMValues_pri);
    if(hardware == HARDWARE_TIMER) {
      printPS(EditEEPROMValues_timesig);
      if(timeChksumOK) {
        hours = time/3600000;
        minutes = (time - hours*3600000)/60000;
        seconds = (time - hours*3600000 - minutes*60000)/1000;
        printPS(EditEEPROMValues_validT);
        print(time);
        print(' ');
        print(hours);
        print(':');
        print(minutes);
        print('.');
        println(seconds);
        printPSln(EditEEPROMValues_adsub_second);
        printPSln(EditEEPROMValues_adsub_minute);
        printPSln(EditEEPROMValues_adsub_hour);
        printPSln(EditEEPROMValues_zero);
        printPSln(EditEEPROMValues_delete);
      } else {
        printPSln(EditEEPROMValues_bdchksum);
      }
    }
    printPSln(EditEEPROMValues_miscopts);
    printPSln(EditEEPROMValues_selectopt);
    print('>');
    print(' ');
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
        if(hardware == HARDWARE_TIMER) {
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
        }
        return true;
      case 'x':
        return true;
      case 'r':
        statusByte = GetStatus();
        redunRoleByte = ReadEEPROM(EEPROM_IS_PRIMARY);
        isSecdry = isSecondary();
        if(hardware == HARDWARE_TIMER)
          timeChksumOK = ReadTimeFromEEPROM(&time);
        break;
      default:
        printPSln(STR_NOSUCHCOMMAND);
    }
  }
}
