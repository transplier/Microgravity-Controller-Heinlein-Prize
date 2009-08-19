/**
 * @file
 * Debug defines.
 * @author Giacomo Ferrari progman32@gmail.com
 */
#ifndef DEBUG_H
#define DEBUG_H

#include <HardwareSerial.h>

#include <avr/pgmspace.h>

//Comment this define to disable compilation of debug statements.
#define DODEBUG

#ifdef DODEBUG
  #define DEBUG(x) Serial.print(x)
  #define DEBUGF(x, fmt) Serial.print(x, fmt)
#else
  #define DEBUG(X)
  #define DEBUGF(X, fmt)
#endif

/*
 * Writes a string stored in program memory to the debug console only.
 */
void debugPS(const prog_char str[])
{
  char c[50];
  if(!str) return;
  strlcpy_P(c, str, sizeof(c));
  DEBUG(c);
}

/*
 * Writes a string stored in program memory to the debug console only.
 */
void debugPSln(const prog_char str[])
{
  char c[50];
  if(!str) return;
  strlcpy_P(c, str, sizeof(c));
  DEBUG(c);
  Serial.println();
}

#endif
