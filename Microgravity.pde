void setup() {
  Serial.begin(9600);
  Serial.println("Controller V.01");
  TimeSetup();
  Serial.print("Current time is: ");
  Serial.println(GetTime());
}

void loop() {
  
}
