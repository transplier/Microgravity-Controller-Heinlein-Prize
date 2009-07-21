/**
 * Microgravity test utility.
 */
 
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
  char* test_name;
  boolean (*func)(void);
} menu_item_t;


menu_item_t main_menu[] = {
  { 'r', "Redundancy Tests", &EnterRedundancyTestsMenu },
  { 't', "Timing Unit menu", &EnterTimingUnitMenu },
  { '!', "All Tests", &AllTests },
  { 'p', "All pins as inputs, pullup on", &DoResetPins },
  { 'T', "Toggle hardware type", &ToggleHardwareType },
  { 'L', "Toggle long tests enabled", &ToggleLongTests }
};

menu_item_t* menu;
size_t menu_size;


inline void println(char* what) { Serial.println(what); }
inline void print(char* what) { Serial.print(what); }
inline void println(char what) { Serial.println(what); }
inline void print(char what) { Serial.print(what); }
inline void println(int what) { Serial.println(what); }
inline void print(int what) { Serial.print(what); }
inline void println(int what, int fmt) { Serial.println(what, fmt); }
inline void print(int what, int fmt) { Serial.print(what, fmt); }
inline void println(byte what) { Serial.println(what); }
inline void print(byte what) { Serial.print(what); }
inline void write(char what) { Serial.write(what); }

void setup() {
  Serial.begin(9600); 
  println("Welcome to the Microgravity Controller tester.");
  println("Built from GIT commit: " GIT_REVISION);
  ReturnToMainMenu();
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
void do_menu() {
  /* Present the options. */
  println("\n");
  for( byte i = 0; i < menu_size; i++) {
    print('\t');
    print(menu[i].menu_key);
    print(": ");
    println(menu[i].test_name);
  }
  
  /* If not on the main menu, add option to return to the main menu. */
  if( menu != main_menu ) {
    println("\t.: Return to main menu");
  }
  
  /* Present some status info */
  print("Selected hardware type: ");
  if( hardware == HARDWARE_LOGGER) println("logger");
  else println("timer.");
  
  print("Long tests: ");
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
        println("FAILED.");
      else
        println("OK.");
      return;
    }
  }
  
  /* Bad menu choice. */
  println("No such command!");
  delay(1000);
}

/**
 * Make all pins inputs, with pullups on.
 */
void reset_pins() {
  for(int x=2; x<13; x++) {
    pinMode(x, INPUT);
    digitalWrite(x, HIGH);
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
boolean AllTests() {
  boolean passed = true;
  passed &= AllRedundancyTests();
  return passed;
}
