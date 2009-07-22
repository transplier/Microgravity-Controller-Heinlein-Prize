#define CODE_TEST_PASSES_LONG 1000
#define CODE_TEST_PASSES_SHORT 50

#define REDUNDANCY_UNLOCK_CODE 0b11001101

const menu_item_t redundancy_tests[] = {
  /*{ '0', "Test takeover code circuit", &TestTakeoverCodeCircuit },
  { '1', "Test redundancy pulse circuit", &TestRedundancyPulseCircuit },
  { 'X', "Write code into takeover code SR", &DoTakeover },
  { 'x', "Clear code from takeover code SR", &DoTakeoverRelease },
  { 'R', "Assert reset request pin", &DoResetOn },
  { 'r', "De-assert reset request pin", &DoResetOff },
  { '!', "All Automatic Redundancy Tests", &AllAutoRedundancyTests },*/
};

boolean EnterRedundancyTestsMenu() {
  menu = redundancy_tests;
  menu_size = sizeof(redundancy_tests) / sizeof(menu_item_t);
  return true;
}

boolean AllAutoRedundancyTests() {
  boolean passed = true;
  passed &= TestTakeoverCodeCircuit();
  return passed;
}

boolean DoResetOff() {
  //Avoid doing a pin reset, as that will mess up the code stored in the SR.
  int pin;
  if(hardware == HARDWARE_LOGGER) {
    pin = LU_OUT_RST_REQ;
  } else {
    pin = TC_OUT_RST_REQ;
  }
  pinMode(pin, OUTPUT);
  digitalWrite(pin, LOW);
}

boolean DoResetOn() {
  //Avoid doing a pin reset, as that will mess up the code stored in the SR.
  int pin;
  if(hardware == HARDWARE_LOGGER) {
    pin = LU_OUT_RST_REQ;
  } else {
    pin = TC_OUT_RST_REQ;
  }
  pinMode(pin, OUTPUT);
  digitalWrite(pin, HIGH);
}

boolean DoTakeoverRelease() {
  init_hardware_pins();
  writeToControlSR(0xFF);
  return !queryHardwareTakeoverEnabled();
}

boolean DoTakeover() {
  init_hardware_pins();
  writeToControlSR(REDUNDANCY_UNLOCK_CODE);
  return queryHardwareTakeoverEnabled();
}

void writeToControlSR(byte value) {
  if( !isSecondary() ) {
    /*println("WARNING: EEPROM says this is not the secondary unit. Continuing anyways...");*/
    delay(1000);
  }
  if(hardware == HARDWARE_LOGGER) {
    shiftOut(LU_OUT_REDUN_SR_D, LU_OUT_REDUN_SR_C, LSBFIRST, value);
  } else {
    shiftOut(TC_OUT_REDUN_SR_D, TC_OUT_REDUN_SR_C, LSBFIRST, value);
  }
}

boolean queryHardwareTakeoverEnabled() {
  if(hardware == HARDWARE_LOGGER) {
    return ( analogRead(LU_ANALOG_REDUN_TAKEOVER_CHECK) <= 400 );
  } else {
    return ( digitalRead(TC_IN_REDUN_TAKEOVER_CHECK) == LOW );
  }
}

boolean TestTakeoverCodeCircuit() {
  println("Redundancy tests..."); 
  init_hardware_pins();

  int num_passes = longTestsEnabled ? CODE_TEST_PASSES_LONG : CODE_TEST_PASSES_SHORT;
  print("Unlock code test 0...255, passes: ");
  println(num_passes);
  boolean r;
  boolean passed = true;
  for(int pass=0; pass < num_passes; pass++) {
    for(byte i = 0; i<255; i++) {
      writeToControlSR(i);
      r = queryHardwareTakeoverEnabled();
      //Was redundancy OK?
      if(r != (i == REDUNDANCY_UNLOCK_CODE)) {
        passed = false;
        print("Error on pass ");
        print(pass);
        print(": ");
        print((int)i, BIN);
        print(" -> ");
        println((int) r);
      }
    }
  }
  println("Complete");
  
  return passed;
}

boolean TestRedundancyPulseCircuit() {
  init_hardware_pins();
  int redunPin = (hardware == HARDWARE_LOGGER) ? LU_INOUT_REDUNDANCY : TC_INOUT_REDUNDANCY;
  print("Role: ");
  boolean isSec = isSecondary();
  if(isSec) {
    pinMode(redunPin, INPUT);
    println("secondary (monitor pulses).");
  }
  else {
    pinMode(redunPin, OUTPUT);
    println("primary (send pulses).");
  }
  
  print("Pin: ");
  println(redunPin);
  
  println("Press any key to exit.");

  print("State: ");
  
  boolean state = false;
  while(Serial.read() == -1) {
    if(isSec) {
      state = digitalRead(redunPin);
    } else {
      state = !state;
      digitalWrite(redunPin, state);
    }
    print((int)state);
    digitalWrite(LEDPIN, state);
    delay(isSec ? 50 : 1000);
    print('\b');
  }

  pinMode(redunPin, INPUT);
  digitalWrite(redunPin, LOW);
  digitalWrite(LEDPIN, LOW);
  println(" Exiting.");
}
