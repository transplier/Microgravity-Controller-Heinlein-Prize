#define CODE_TEST_PASSES_LONG 1000
#define CODE_TEST_PASSES_SHORT 50

#define REDUNDANCY_UNLOCK_CODE 0b11001101

menu_item_t redundancy_tests[] = {
  { '0', "Test takeover code circuit", &TestTakeoverCodeCircuit },
  { '!', "All Redundancy Tests", &AllRedundancyTests },
};

boolean EnterRedundancyTestsMenu() {
  menu = redundancy_tests;
  menu_size = sizeof(redundancy_tests) / sizeof(menu_item_t);
  return true;
}

boolean AllRedundancyTests() {
  boolean passed = true;
  passed &= TestTakeoverCodeCircuit();
  return passed;
}

void writeToControlSR(byte value) {
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

void init_redun_pins() {
  if(hardware == HARDWARE_LOGGER) {
    pinMode(LU_OUT_RST_REQ, OUTPUT);
    pinMode(LU_OUT_REDUN_SR_D, OUTPUT);
    pinMode(LU_OUT_REDUN_SR_C, OUTPUT);
  } else {
    pinMode(TC_IN_REDUN_TAKEOVER_CHECK, INPUT);
    pinMode(TC_OUT_RST_REQ, OUTPUT);
    pinMode(TC_OUT_REDUN_SR_D, OUTPUT);
    pinMode(TC_OUT_REDUN_SR_C, OUTPUT);
  }
}

boolean TestTakeoverCodeCircuit() {
  println("Redundancy tests..."); 
  init_redun_pins();

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
