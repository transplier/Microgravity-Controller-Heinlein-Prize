/**
 * @file
 * iSeries class definition.
 * @author Giacomo Ferrari progman32@gmail.com
 */
 
#ifndef ISERIES_H
#define ISERIES_H

#include <NewSoftSerial.h>

#define ISERIES_RECOG_CHAR '*'
#define ISERIES_CMD_DELAY 100

/**
 * Implements the serial protocol of the iSeries process controllers from Omega.
 * Only tested on a CNi3243-C24-DC over RS-232.
 */
class iSeries
{
private:
  /**
   * Serial port we talk to */
  NewSoftSerial* mpCom;
public:
  /**
   * Constructor that takes in a pointer to an already-initialized serial port.
   * @param com A pointer to an already-initialized NewSoftSerial instance.
   */
  iSeries(NewSoftSerial* com);
  
  /**
   * Issues a command with a default timeout of ISERIES_CMD_DELAY. Blocks until either replyLength
   * bytes are received, or the default timeout is reached.
   * @param cmd Command to send. Null-terminated.
   * @param reply Buffer for response.
   * @param replyLength Maximum length of reply (additional bytes will be left in the buffer).
   * @return True if a reply was received within the timeout.
   */
  boolean IssueCommand(const char* cmd, byte reply[], byte replyLength);
  
  /**
   * Issues a command with a specified timeout. Blocks until either replyLength
   * bytes are received, or the given timeout is reached.
   * @param cmd Command to send. Null-terminated.
   * @param reply Buffer for response.
   * @param replyLength Maximum length of reply (additional bytes will be left in the buffer).
   * @param timeoutMillis Timeout in milliseconds.
   * @return True if a reply was received within the timeout.
   */
  boolean IssueCommand(const char* cmd, byte reply[], byte replyLength, int timeoutMillis);
  
  /**
   * Attempts to establish communications with the device, resetting it in the process.
   * @return True if the device was found and reset successfully.
   */
  boolean FindAndReset();
  
  /**
   * Gets a temperature/process reading from the device.
   * @return The absolute reading sent from the device. Units are device-configuration dependant. If an error occurred, returns NaN.
   */
  double GetReading();
  
  /**
   * Gets a temperature/process reading from the device as a string.
   * This is more efficient than GetReading(), as it directly copies the response string instead of atof()'ing.
   * @param buffer The buffer to place the reading into. Should be >= 5 bytes.
   * @return True if a reading was received.
   */
  boolean GetReadingString(byte* buffer);
};
#endif
