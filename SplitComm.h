#ifndef SPIT_COMM_H
#define SPIT_COMM_H

#define SPLIT_COMM_MSG_LENGTH 8

#define SPLIT_COMM_ATTN_CHAR 27
#define SPLIT_COMM_TIMEOUT_MSEC 2000

boolean checkForCommand(byte* buffer);

void transmitCommand(byte* buffer);

#endif
