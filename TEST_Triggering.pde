#include <math.h>

const char Triggering_Menu_acceltest[] PROGMEM = "Show accelerometer readings";
const menu_item_t triggering_menu[] = {
  { '0', Triggering_Menu_acceltest, &AccelReadings },
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
  for(byte x=input; x<= 73; x++) {
    print(' ');  
  }
  /* Clear rest of line */
  write(0x1B);
  write('[');
  write('K');
  println(orig);
}

/* input is from -512 to 512 */
void bargraph_centerline(signed int input) {
  int orig=input;
  input /= 14;
  
  
  if(input < 0) {
    for(byte x=0; x< (36+input); x++) {
      print(' ');  
    }
    for(byte x=0; x< -input; x++) {
      print('#');  
    }
  } else {
    for(byte x=0; x< 36; x++) {
      print(' ');  
    }
  }
  print('|');
  if(input > 0) {
    for(byte x=0; x< input; x++) {
      print('#');  
    }
    for(byte x=0; x< (36-input); x++) {
      print(' ');  
    }

  } else {
    for(byte x=0; x< 36; x++) {
      print(' ');  
    }
  }
  /* Clear rest of line */
  write(0x1B);
  write('[');
  write('K');
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
  
  signed int accel_x, accel_y, accel_z;
  while(Serial.read() != 0x1B) {   
    accel_x = analogRead(0);
    accel_y = analogRead(1);
    accel_z = analogRead(2);
    accel_x+=(accel_x/2);
    accel_y+=(accel_y/2);
    accel_z+=(accel_z/2);
    accel_x -= 512;
    accel_y -= 512;
    accel_z -= 512;
    moveCursor(3, 3);
    bargraph_centerline(accel_x);
    moveCursor(4, 3);
    bargraph_centerline(accel_y);
    moveCursor(5, 3);
    bargraph_centerline(accel_z);
    moveCursor(6, 3);
    bargraph((int)sqrt((double)(accel_z*accel_z + accel_y*accel_y + accel_x*accel_x)));
    delay(10);
  }
}

