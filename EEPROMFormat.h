#ifndef EEPROMFORMAT_H
#define EEPROMFORMAT_H
#include <WProgram.h>

#define EEPROM_STATUS 0                //Location of status byte
#define EEPROM_STATUS_RESET_VALUE 0x00 //Reset status byte to this if we're reset (with RSTPIN low).

//Status byte format:
//[Time Sig Valid|nu|nu|nu|nu|nu|nu]
//Bit masks for EEPROM_STATUS
#define EEPROM_STATUS_TIME_VALID 0x01


#define EEPROM_TIME_1 2 //LSB
#define EEPROM_TIME_2 3
#define EEPROM_TIME_3 4
#define EEPROM_TIME_4 5 //MSB
#define EEPROM_TIME_CHECK 6


void WriteEEPROM(int addr, byte data);

byte ReadEEPROM(int addr);

void WriteStatus(byte status);
byte GetStatus();

#endif
