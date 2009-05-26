/**
 * @file
 * Goldelox class definition.
 * @author Giacomo Ferrari progman32@gmail.com
 */
#ifndef GOLDELOX_H
#define GOLDELOX_H

#define GDLOX_DEVICE_TYPE 3
#define GDLOX_ACK 0x06
#define GDLOX_NAK 0x15

#define GDLOX_POWERUP_DELAY 500
#define GDLOX_CMD_DELAY 500

#include <SoftwareSerial.h>

/**
 * Return codes for Goldelox functions.
 */
enum GoldeloxStatus{ OK, TIMED_OUT, ERROR, NO_CARD };

/**
 * Interface for the GOLDELOX uDRIVE-uSD-G1 from 4D Tech over a serial link.
 * TODO: add support for seeks to read() and write().
 */
class Goldelox
{
private:
  /**
   * SoftwareSerial instance to use for communication.
   */
  SoftwareSerial* mpGdlox;
  /**
   * Pin number that is connected to the uDRIVE's reset pin.
   */
  byte mRstPin;
  /**
   * Holds the result of the last operation.
   */
  GoldeloxStatus mStatus;
  /**
   * Issues a command to the uDRIVE. Does not read any input.
   * @param cmd Command to send.
   * @param len The length of the command to send.
   * @param minReplyLength Minimum number of bytes that must be in the serial buffer before the method will return.
   * @return True if the command was sent OK.
   */
  boolean issueCommand(const char* cmd, byte len, byte minReplyLength);
public:
  /**
   * Constructor that takes an already-set-up SoftwareSerial instance and a reset pin number. reinit() must be called before any other method.
   */
  Goldelox(SoftwareSerial* serial, byte rst);
  /**
   * Resets and initializes the uDRIVE. Must call once before using other methods.
   */
  GoldeloxStatus reinit();
  /**
   * Gets the status of the last command (usually the same as the return value of the last method called).
   */
  GoldeloxStatus status();
  /**
   * If a card was inserted while the power was on, call this to initialize the card.
   */
  GoldeloxStatus initializeNewCard();
  /**
   * Lists the files in the root of the card.
   * @param result Buffer to place the newline-separated list into.
   * @param len Maximum number of bytes to write into the result buffer. Extra bytes will be discarded.
   */
  GoldeloxStatus ls(byte* result, int len);
  /**
   * Writes into a file.
   * @param filename The null-terminated filename.
   * @param append True to append instead of overwrite. File will be created either way.
   * @param data Data buffer to write from.
   * @param len Number of bytes to write.
   */
  GoldeloxStatus write(const char* filename, boolean append, byte* data, int len);
  /**
   * Deletes a file.
   * @param filename The null-terminated filename.
   */
  GoldeloxStatus del(const char* filename);
  /**
   * Reads a number of bytes from the beginning of the file.
   * @param filename The null-terminated filename.
   * @param data Data buffer to read into.
   * @param len Number of bytes to read.
   */
  GoldeloxStatus read(const char* filename, byte* data, int len);
};
#endif
