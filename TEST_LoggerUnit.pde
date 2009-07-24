#define NUMBER_OF_TEMP_CONTROLLERS 5

const char LU_Menu_a[] PROGMEM = "Thermostat monitor";
const menu_item_t lu_menu[] = {
  { '0', LU_Menu_a, &ThermostatMonitor },
};

const char EnterLoggerUnitMenu_hardwarewarn[] PROGMEM = "WARNING: HARDWARE TYPE SET TO TIMER! Automatically changing to logger!";
boolean EnterLoggerUnitMenu() {
  if( hardware == HARDWARE_TIMER ) {
    printPSln(EnterLoggerUnitMenu_hardwarewarn);
    delay(1000);
    hardware = HARDWARE_LOGGER;
  }
  menu = lu_menu;
  menu_size = sizeof(lu_menu) / sizeof(menu_item_t);
  return true;
}

const char ThermostatMonitor_number[] PROGMEM = "Number of thermostats: ";
const char ThermostatMonitor_reptemp[] PROGMEM = "Reported temperatures:";
boolean ThermostatMonitor() {
  
}
