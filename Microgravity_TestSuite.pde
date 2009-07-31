/**
 * Microgravity test utility.
 */
 
 
#include <avr/pgmspace.h>

#include "git_info.h"

#include "Pins.h"
#include "Debug.h"
#include "EEPROMFormat.h"

#define HARDWARE_LOGGER 0
#define HARDWARE_TIMER 1

byte hardware = HARDWARE_TIMER;

boolean longTestsEnabled = false;

typedef struct {
  char menu_key;
  const char* test_name PROGMEM;
  boolean (*func)(void);
} menu_item_t;


const char STR_FAILED[] PROGMEM = "FAILED.";
const char STR_OK[] PROGMEM = "OK.";
const char STR_NOSUCHCOMMAND[] PROGMEM = "No such command!";

const char MainMenu_redun[] PROGMEM  = "Redundancy Tests";
const char MainMenu_TUmenu[] PROGMEM = "Timing Unit menu";
const char MainMenu_LUmenu[] PROGMEM = "Logger Unit menu";
const char MainMenu_EEPROM[] PROGMEM = "EEPROM menu";
const char MainMenu_comms[] PROGMEM = "Communications menu";
const char MainMenu_auto[] PROGMEM = "All Automatic Tests";
const char MainMenu_pinreset[] PROGMEM = "All pins as inputs, pullup off";
const char MainMenu_hwtype[] PROGMEM = "Toggle hardware type";
const char MainMenu_longtest[] PROGMEM = "Toggle long tests enabled";

const menu_item_t main_menu[] = {
  { 'r', MainMenu_redun, &EnterRedundancyTestsMenu },
  { 't', MainMenu_TUmenu, &EnterTimingUnitMenu },
  { 'l', MainMenu_LUmenu, &EnterLoggerUnitMenu },
  { 'e', MainMenu_EEPROM, &EnterEEPROMMenu },
  { 'c', MainMenu_comms, &EnterCommMenu },
  { 'a', MainMenu_auto, &AllAutoTests },
  { 'p', MainMenu_pinreset, &DoResetPins },
  { 'T', MainMenu_hwtype, &ToggleHardwareType },
  { 'L', MainMenu_longtest, &ToggleLongTests }
};

const menu_item_t* menu;
size_t menu_size;


inline void println(char* what) { Serial.println(what); }
inline void print(char* what) { Serial.print(what); }
inline void println(char what) { Serial.println(what); }
inline void print(char what) { Serial.print(what); }
inline void println(int what) { Serial.println(what); }
inline void print(int what) { Serial.print(what); }
inline void println(long unsigned int what) { Serial.println(what); }
inline void print(long unsigned int what) { Serial.print(what); }
inline void println(int what, int fmt) { Serial.println(what, fmt); }
inline void print(int what, int fmt) { Serial.print(what, fmt); }
inline void println(byte what) { Serial.println(what); }
inline void print(byte what) { Serial.print(what); }
inline void write(char what) { Serial.write(what); }
void printPS(const prog_char str[])
{
  char c;
  if(!str) return;
  while((c = pgm_read_byte(str++)))
    Serial.print(c,BYTE);
}
void printPSln(const prog_char str[])
{
  printPS(str);
  Serial.println();
}

const char welcomeString[] PROGMEM = "Welcome to the Microgravity Controller tester.\r\n" "Built from GIT commit: " GIT_REVISION;
void setup() {
  Serial.begin(9600); 
  printPSln( welcomeString );  ReturnToMainMenu();
  reset_pins();
}

/*
 * Block until a char is received from the serial line. Return that char.
 */
char read_char() {
  char in;
  while( (in = Serial.read()) == -1);
  return in;
}

/**
 * Read a single char from the console in a user-friendly way. Backspace works, and
 * keys pressed after the initial character selection overwrite the last selection on-screen.
 */
char read_char_nice() {
  char in, cur;
  cur=0;
  while(true) {
    //Get a char
    while( (in = Serial.read()) == -1);
   
    /* User pressed backspace. Forget the last key, and overwrite it on the terminal. */
    if( in == '\b' ) {
      cur = 0;
      print("\b \b");
      continue;
    }
    
    /* User pressed enter after pressing another key. Return. */ 
    if( in == '\r' && cur != 0) {
      write('\r');
      write('\n');
      return cur;
    }
    
    /* User pressed enter without making a selection first. Ignore. */
    if( in == '\r' && cur == 0 ) {
      continue;
    }
    
    /* User pressed a key (other than enter) after previously pressing another key. Overwrite. */
    if(cur != 0) {
      //already seen keypress. Erase.
      write('\b');
    }
    write(in);
    cur = in;
  }
}

/**
 * Print the menu, wait for a selection, and call the function associated with the user's selection.
 * After the function completes, show whether the function completed successfully.
 * Special case: if *menu does not point to main_menu, add an option to return to the main menu.
 */
 
const char do_menu_rettomain[] PROGMEM = "\t.: Return to main menu";
const char do_menu_selectedhardwaretype[] PROGMEM = "Selected hardware type: ";
const char do_menu_longtests[] PROGMEM = "Long tests: ";
void do_menu() {
  /* Present the options. */
  println("\n");
  for( byte i = 0; i < menu_size; i++) {
    print('\t');
    print(menu[i].menu_key);
    print(": ");
    printPSln(menu[i].test_name);
  }
  
  /* If not on the main menu, add option to return to the main menu. */
  if( menu != main_menu ) {
    printPSln(do_menu_rettomain);
  }
  
  /* Present some status info */
  printPS(do_menu_selectedhardwaretype);
  if( hardware == HARDWARE_LOGGER) println("logger");
  else println("timer.");
  
  printPS(do_menu_longtests);
  if( longTestsEnabled ) println("on.");
  else println("off.");
  
  /* Prompt. */
  print("> ");
  
  /* Read user's input */
  char in = read_char_nice();
  
  /* If not on the main menu, see if the user wishes to return to the main menu. */
  if( menu != main_menu && in == '.') {
    ReturnToMainMenu();
    return;
  }
  
  /* Try to find which menu item was selected, and invoke its associated function if successful. */
  for( byte i = 0; i < menu_size; i++) {
    if(menu[i].menu_key == in) {
      /* Invoke the function */
      boolean r = menu[i].func();
      if( r == false)
        printPSln(STR_FAILED);
      else
        printPSln(STR_OK);
      return;
    }
  }
  
  /* Bad menu choice. */
  printPSln(STR_NOSUCHCOMMAND);
  delay(1000);
}

/**
 * Make all pins inputs, with pullups on.
 */
void reset_pins() {
  for(int x=2; x<13; x++) {
    pinMode(x, INPUT);
    digitalWrite(x, LOW);
  }
}

void init_hardware_pins() {
  reset_pins();
  pinMode(LEDPIN, OUTPUT);
  digitalWrite(LEDPIN, LOW);
  if(hardware == HARDWARE_LOGGER) {
    pinMode(LU_OUT_GDLOX_TX, OUTPUT);
    pinMode(LU_OUT_GDLOX_RST, OUTPUT);
    pinMode(LU_OUT_COM1_TX, OUTPUT);
    pinMode(LU_OUT_SADDR_D, OUTPUT);
    pinMode(LU_OUT_SADDR_C, OUTPUT);
    pinMode(LU_OUT_REDUN_SR_D, OUTPUT);
    pinMode(LU_OUT_REDUN_SR_C, OUTPUT);
    pinMode(LU_OUT_RST_REQ, OUTPUT);
  } else {
    pinMode(TC_OUT_POWER_SR_D, OUTPUT);
    pinMode(TC_OUT_POWER_SR_C, OUTPUT);
    pinMode(TC_OUT_POWER_SR_L, OUTPUT);
    pinMode(TC_IN_REDUN_TAKEOVER_CHECK, INPUT);
    pinMode(TC_OUT_RST_REQ, OUTPUT);
    pinMode(TC_OUT_REDUN_SR_D, OUTPUT);
    pinMode(TC_OUT_REDUN_SR_C, OUTPUT);
    pinMode(TC_OUT_EXP_TRIGGER_RELAY_ON, OUTPUT);
    pinMode(TC_OUT_EXP_TRIGGER_RELAY_OFF, OUTPUT);
    digitalWrite(TC_OUT_EXP_TRIGGER_RELAY_ON, LOW);
    digitalWrite(TC_OUT_EXP_TRIGGER_RELAY_OFF, LOW);
  }
}

void loop() {
  do_menu();
  //reset_pins();
}

boolean DoResetPins() {
  reset_pins();
}

boolean ToggleHardwareType() {
  if( hardware == HARDWARE_LOGGER) hardware = HARDWARE_TIMER;
  else hardware = HARDWARE_LOGGER;
  return true;
}

boolean ToggleLongTests() {
  longTestsEnabled = !longTestsEnabled;
  return true;
}

boolean ReturnToMainMenu() {
  menu = main_menu;
  menu_size = sizeof(main_menu) / sizeof(menu_item_t);
  return true;
}

/**
 * Update me with all tests!
 */
boolean AllAutoTests() {
  boolean passed = true;
  passed &= AllAutoRedundancyTests();
  if(hardware == HARDWARE_LOGGER)
    passed &= AllAutoLUTests();
  passed &= AllAutoEEPROMTests();
  return passed;
}
