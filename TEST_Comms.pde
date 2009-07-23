#include "SplitComm.h"

#define BIDI_COMM_TEST_NUM_PACKETS 500

const char Comm_Menu_initialSendTest[] PROGMEM = "Bidirectional communications test (send first)";
const char Comm_Menu_initialListenTest[] PROGMEM = "Bidirectional communications test (listen first)";
const menu_item_t comm_menu[] = {
  { '0', Comm_Menu_initialSendTest, &InitialSendTest },
  { '1', Comm_Menu_initialListenTest, &InitialListenTest },
};

boolean EnterCommMenu() {
  menu = comm_menu;
  menu_size = sizeof(comm_menu) / sizeof(menu_item_t);
  return true;
}

void printPacket(byte* buf) {
  print('[');
  for(byte c=0; c<SPLIT_COMM_MSG_LENGTH; c++) {
    print(buf[c], HEX);
    print(' ');
  }
  println(']');
}

const char bidiCommTest_instructions[] PROGMEM = "Make sure you turn off the debug switch for this test.\r\nWaiting 10 seconds...";
const char bidiCommTest_rxerr[] PROGMEM = "Bad packet received! Sequence number: ";
boolean bidiCommTest(boolean listenFirst) {
  //Ports the same, intrinsic to SplitComm.
  /*int txPort = (hardware == HARDWARE_LOGGER) ? LU_OUT_TXi : TC_OUT_TXi;
  int rxPort = (hardware == HARDWARE_LOGGER) ? LU_OUT_RXi : TC_OUT_RXi;*/
  
  printPSln(bidiCommTest_instructions);
  delay(10000);
  
  byte buf[SPLIT_COMM_MSG_LENGTH];
  boolean needToListen = listenFirst;
  byte state = 0;
  for(int iter = 0; iter<BIDI_COMM_TEST_NUM_PACKETS; iter++) {
    if(needToListen) {
      //TODO: timeout while waiting.
      while(!checkForCommand(buf));
      print("Rx: ");
      printPacket(buf);
      for(byte c=0; c<SPLIT_COMM_MSG_LENGTH; c++) { 
        if(buf[c] != state) {
          printPS(bidiCommTest_rxerr);
          println(state, DEC);
          return false;
        }
        state++;
      }
    } else {
        for(byte c=0; c<SPLIT_COMM_MSG_LENGTH; c++) { 
          buf[c] = state++;
        }
        print("Tx: ");
        printPacket(buf);
        transmitCommand(buf);
    }

    needToListen = !needToListen;
  }
   
  return true;
}

const char bidiCommTest_termQW[] PROGMEM = "Press 'qw' to exit.";
const char bidiCommTest_OK[] PROGMEM = "\r\nAll packets OK.";
const char bidiCommTest_NOK[] PROGMEM = "\r\nSomething went wrong!";
boolean InitialSendTest() {
  boolean rv = bidiCommTest(false);
  if(rv) printPSln(bidiCommTest_OK);
  else printPSln(bidiCommTest_NOK);
  printPSln(bidiCommTest_termQW);
  while(true) {
    while(read_char() != 'q');
    if(read_char() == 'w') return rv;
    else continue;
  }
}

const char bidiCommTest_termAS[] PROGMEM = "Press 'as' to exit.";
boolean InitialListenTest() {
  boolean rv = bidiCommTest(true);
  if(rv) printPSln(bidiCommTest_OK);
  else printPSln(bidiCommTest_NOK);
  printPSln(bidiCommTest_termAS);
  while(true) {
    while(read_char() != 'a');
    if(read_char() == 's') return rv;
    else continue;
  }
}
