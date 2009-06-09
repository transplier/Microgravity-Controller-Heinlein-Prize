#ifndef SPIT_COMM_H
#define SPIT_COMM_H

#define SPLIT_COMM_MSG_LENGTH 8

#define SPLIT_COMM_ATTN_CHAR 27
#define SPLIT_COMM_TIMEOUT_MSEC 2000

#define SPLIT_COMM_COMMAND_EXP_TRIGGER 0xAA //On exp trigger/reset

#define SPLIT_COMM_COMMAND_COOLDOWN    0x0C //first data byte is ID of temp. controller to cool down.

boolean checkForCommand(byte* buffer);

void transmitCommand(byte* buffer);

#endif
