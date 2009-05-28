/**
 * @file
 * Contains definitions for EEPROM layout.
 * @author Giacomo Ferrari progman32@gmail.com
 */

#ifndef EEPROMFORMAT_H
#define EEPROMFORMAT_H
#include <WProgram.h>

#define EEPROM_STATUS 0                //Location of status byte
#define EEPROM_STATUS_RESET_VALUE 0x00 //Reset status byte to this if we're reset (with RSTPIN low).

//Status byte format:
//[Time Sig Valid|Triggered|nu|nu|nu|nu|nu]
//Bit masks for EEPROM_STATUS
#define EEPROM_STATUS_TIME_VALID 0b01
#define EEPROM_STATUS_TRIGGERED 0b10


#define EEPROM_TIME_1 2 //LSB
#define EEPROM_TIME_2 3
#define EEPROM_TIME_3 4
#define EEPROM_TIME_4 5 //MSB
#define EEPROM_TIME_CHECK 6

/**
 * Writes a byte to a memory location.
 * @param addr Address.
 * @param data Data byte to write.
 */
void WriteEEPROM(int addr, byte data);

/**
 * Reads a byte from a memory location.
 * @param addr Address.
 * @return Data read.
 */
byte ReadEEPROM(int addr);

/**
 * Shortcut to write the status byte.
 * @param status New status byte.
 */
inline void WriteStatus(byte status);

/**
 * Shortcut to read the status byte.
 * @return The status byte.
 */
inline byte GetStatus();

#endif
