/** @file Functions to simplify redundant access to RAM
 * These functions will also repair any fault found by refreshing the memory
 * locations on every read.
 */
 
 
unsigned long redunMemR(unsigned long* var) {
  long val;
  if(var[0]==var[1] || var[1]==var[2]) val=var[1];
  else if(var[2]==var[0]) val=var[0];
  else /* WTF none match! Guess first, simply because we don't have any clue.*/ val = var[0];
  redunMemW(var, val);
  return val;
}
unsigned long redunMemW(unsigned long* var, unsigned long dta) {
  var[0] = dta;
  var[1] = dta;
  var[2] = dta;
  return dta;
}

byte redunMemR(byte* var) {
  byte val;
  if(var[0]==var[1] || var[1]==var[2]) val=var[1];
  else if(var[2]==var[0]) val=var[0];
  else /* WTF none match! Guess first, simply because we don't have any clue.*/ val = var[0];
  redunMemW(var, val);
  return val;
}
byte redunMemW(byte* var, byte dta) {
  var[0] = dta;
  var[1] = dta;
  var[2] = dta;
  return dta;
}
