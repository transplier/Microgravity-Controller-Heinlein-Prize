#include <math.h>

const char Triggering_Menu_acceltest[] PROGMEM = "Show accelerometer readings";
const char Triggering_Menu_triggertest[] PROGMEM = "Run triggering code";
const menu_item_t triggering_menu[] = {
  { '0', Triggering_Menu_acceltest, &AccelReadings },
  { '1', Triggering_Menu_triggertest, &MovingAverageTrigger /* in Triggering.pde */ },
};

boolean EnterTriggeringMenu() {
  menu = triggering_menu;
  menu_size = sizeof(triggering_menu) / sizeof(menu_item_t);
  return true;
}

/* input is from 0 to 1024 */
void bargraph(int input) {
  int orig=input;
  input /= 14;
  
  for(byte x=0; x< input; x++) {
    print('#');  
  }
  /* Clear rest of line */
  write(0x1B);
  write('[');
  write('K');

  cursorRight(73-input);

  println(orig);
}

inline void cursorRight(byte howmuch) {
  write(0x1B);
  write('[');
  Serial.print(howmuch, DEC);
  write('C');
}

/* input is from -512 to 512 */
void bargraph_centerline(signed int input) {
  int orig=input;
  input /= 14;
  /* clear line */
  write(0x1B);
  write('[');
  write('K');
  
  if(input < 0) {
    cursorRight(36+input);
    for(byte x=0; x< -input; x++) {
      print('#');  
    }
  } else {
    cursorRight(36);
  }
  print('|');
  if(input > 0) {
    for(byte x=0; x< input; x++) {
      print('#');  
    }

    cursorRight(36-input);

  } else {
    cursorRight(36);
  }
  println(orig);
}


const char AccelReadings_howtoquit[] PROGMEM = "ESC to quit.";
boolean AccelReadings() {
  /* Clear screen*/
  write(0x1B);
  write('[');
  write('2');
  write('J');
  printPSln(AccelReadings_howtoquit);
  Serial.println();
  print('X');
  println(':');
  print('Y');
  println(':');
  print('Z');
  println(':');
  print('M');
  println(':');
  
  unsigned short accel[3];
  while(Serial.read() != 0x1B) {   
    memset(accel, 0, sizeof(accel));
    AccumAccelerometerReading(&accel[0], &accel[1], &accel[2]);
    accel[0]+=(accel[0]/2);
    accel[1]+=(accel[1]/2);
    accel[2]+=(accel[2]/2);
    accel[0] -= 512;
    accel[1] -= 512;
    accel[2] -= 512;
    moveCursor(3, 3);
    bargraph_centerline(accel[0]);
    moveCursor(4, 3);
    bargraph_centerline(accel[1]);
    moveCursor(5, 3);
    bargraph_centerline(accel[2]);
    moveCursor(6, 3);
    bargraph((int)sqrt((double)(accel[2]*accel[2] + accel[1]*accel[1] + accel[0]*accel[0])));
    delay(10);
  }
  return true;
}

