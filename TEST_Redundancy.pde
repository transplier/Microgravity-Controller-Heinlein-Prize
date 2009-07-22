#define CODE_TEST_PASSES_LONG 1000
#define CODE_TEST_PASSES_SHORT 50

#define REDUNDANCY_UNLOCK_CODE 0b11001101

const char Redundancy_Menu_a[] PROGMEM = "Test takeover code circuit";
const char Redundancy_Menu_b[] PROGMEM = "Test redundancy pulse circuit";
const char Redundancy_Menu_c[] PROGMEM = "Write code into takeover code SR";
const char Redundancy_Menu_d[] PROGMEM = "Clear code from takeover code SR";
const char Redundancy_Menu_e[] PROGMEM = "Assert reset request pin";
const char Redundancy_Menu_f[] PROGMEM = "De-assert reset request pin";
const char Redundancy_Menu_g[] PROGMEM = "All Automatic Redundancy Tests";
const menu_item_t redundancy_tests[] = {
  { '0', Redundancy_Menu_a, &TestTakeoverCodeCircuit },
  { '1', Redundancy_Menu_b, &TestRedundancyPulseCircuit },
  { 'X', Redundancy_Menu_c, &DoTakeover },
  { 'x', Redundancy_Menu_d, &DoTakeoverRelease },
  { 'R', Redundancy_Menu_e, &DoResetOn },
  { 'r', Redundancy_Menu_f, &DoResetOff },
  { '!', Redundancy_Menu_g, &AllAutoRedundancyTests },
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
  return true;
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
  return true;
}

const char DoTakeoverRelease_error[] PROGMEM = "WARNING: Takeover check pin reports we're still taking over!";
const char DoTakeoverRelease_ok[] PROGMEM = "Successfully exited takeover state.";
boolean DoTakeoverRelease() {
  init_hardware_pins();
  writeToControlSR(0xFF);
  if(queryHardwareTakeoverEnabled()) {
    printPSln(DoTakeoverRelease_error);
    delay(1000);
    return false;
  } else {
    printPSln(DoTakeoverRelease_ok);
    return true;
  }
}

const char DoTakeover_error[] PROGMEM = "WARNING: Takeover check pin reports we've failed to take over!";
const char DoTakeover_ok[] PROGMEM = "Successfully entered takeover state.";
boolean DoTakeover() {
  init_hardware_pins();
  writeToControlSR(REDUNDANCY_UNLOCK_CODE);
  if(!queryHardwareTakeoverEnabled()) {
    printPSln(DoTakeover_error);
    delay(1000);
    return false;
  } else {
    printPSln(DoTakeover_ok);
    return true;
  }
}

const char writeToControlSR_wrongunit[] PROGMEM = "WARNING: EEPROM says this is not the secondary unit. \r\nContinuing anyways, following status message likely incorrect!";
void writeToControlSR(byte value) {
  if( !isSecondary() ) {
    printPSln(writeToControlSR_wrongunit);
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

const char TestTakeoverCodeCircuit_desc[] PROGMEM = "Unlock code test 0...255, passes: ";
const char TestTakeoverCodeCircuit_erroronpass[] PROGMEM = "Error on pass ";
const char TestTakeoverCodeCircuit_arrow[] PROGMEM = " -> ";
const char TestTakeoverCodeCircuit_complete[] PROGMEM = "complete";
boolean TestTakeoverCodeCircuit() {
  init_hardware_pins();

  int num_passes = longTestsEnabled ? CODE_TEST_PASSES_LONG : CODE_TEST_PASSES_SHORT;
  printPS(TestTakeoverCodeCircuit_desc);
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
        printPS(TestTakeoverCodeCircuit_erroronpass);
        print(pass);
        print(':'); print(' ');
        print((int)i, BIN);
        printPS(TestTakeoverCodeCircuit_arrow);
        println((int) r);
      }
    }
  }
  printPSln(TestTakeoverCodeCircuit_complete);
  
  return passed;
}

const char TestRedundancyPulseCircuit_role[] PROGMEM = "Role: ";
const char TestRedundancyPulseCircuit_secdesc[] PROGMEM = "secondary (monitor pulses).";
const char TestRedundancyPulseCircuit_pridesc[] PROGMEM = "primary (send pulses).";
const char TestRedundancyPulseCircuit_pin[] PROGMEM = "Pin: ";
const char TestRedundancyPulseCircuit_pressanykey[] PROGMEM = "Press any key to exit.";
const char TestRedundancyPulseCircuit_state[] PROGMEM = "State: ";
const char TestRedundancyPulseCircuit_exiting[] PROGMEM = " Exiting.";
boolean TestRedundancyPulseCircuit() {
  init_hardware_pins();
  int redunPin = (hardware == HARDWARE_LOGGER) ? LU_INOUT_REDUNDANCY : TC_INOUT_REDUNDANCY;
  printPS(TestRedundancyPulseCircuit_role);
  boolean isSec = isSecondary();
  if(isSec) {
    pinMode(redunPin, INPUT);
    printPSln(TestRedundancyPulseCircuit_secdesc);
  }
  else {
    pinMode(redunPin, OUTPUT);
    printPSln(TestRedundancyPulseCircuit_pridesc);
  }
  
  printPS(TestRedundancyPulseCircuit_pin);
  println(redunPin);
  
  printPSln(TestRedundancyPulseCircuit_pressanykey);

  printPS(TestRedundancyPulseCircuit_state);
  
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
  printPSln(TestRedundancyPulseCircuit_exiting);
  return true;
}
