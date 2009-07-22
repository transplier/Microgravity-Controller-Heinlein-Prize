#include "EEPROMFormat.h"

menu_item_t eeprom_menu[] = {
  { 'f', "Show/Edit flags", &EditEEPROMFlags },
};

boolean EnterEEPROMMenu() {
  menu = eeprom_menu;
  menu_size = sizeof(eeprom_menu) / sizeof(menu_item_t);
  return true;
}

boolean EditEEPROMFlags() {
  byte statusByte = GetStatus();
  byte redunRoleByte = ReadEEPROM(EEPROM_IS_PRIMARY);
  boolean isSecdry = isSecondary();

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
      case 'w':
        WriteStatus(statusByte);
        WriteEEPROM(EEPROM_IS_PRIMARY, redunRoleByte);
        return true;
      case 'x':
        return true;
      case 'r':
        statusByte = GetStatus();
        redunRoleByte = ReadEEPROM(EEPROM_IS_PRIMARY);
        isSecdry = isSecondary();
        break;
      default:
        println("No such command!");
    }
  }
}
