/**
 * Microgravity test utility.
 */
 
#include "git_info.h"

#include "Pins.h"
#include "Debug.h"
#include "EEPROMFormat.h"

typedef struct {
  char menu_key;
  char* test_name;
  void (*func)(void);
} test_t;


test_t tests[] = {
  { '0', "Redundancy Tests", &TestRedundancy }
};

void setup() {
  Serial.begin(9600); 
  Serial.println("Welcome to the Microgravity Controller tester.");
  Serial.println("Built from GIT commit: " GIT_REVISION);
}

char read_char() {
  char in, cur;
  cur=0;
  while(true) {
    //Get a char
    while( (in = Serial.read()) == -1);
    if( in == '\r' && cur != 0) {
      Serial.write('\n');
      return cur;
    }
    if(cur != 0) {
      //already seen keypress. Erase.
      Serial.write('\b');
    }
    Serial.write(in);
    cur = in;
  }
}

void do_menu() {
  byte num_tests = sizeof(tests) / sizeof(test_t);
  Serial.println("Test menu:");
  for( byte i = 0; i < num_tests; i++) {
    Serial.print(tests[i].menu_key);
    Serial.print(": ");
    Serial.println(tests[i].test_name);
  }
  Serial.print("> ");
  char in = read_char();
  for( byte i = 0; i < num_tests; i++) {
    if(tests[i].menu_key == in) {
      tests[i].func();
      return;
    }
  }
  Serial.println("No such command!");
  delay(1000);
}

void loop() {
  do_menu();
}
