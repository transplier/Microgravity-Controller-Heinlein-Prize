/**
 * @file
 * Debug defines.
 * @author Giacomo Ferrari progman32@gmail.com
 */
#ifndef DEBUG_H
#define DEBUG_H

//Comment this define to disable compilation of debug statements.
#define DODEBUG

#ifdef DODEBUG
  #define DEBUG(x) Serial.print(x)
  #define DEBUGF(x, fmt) Serial.print(x, fmt)
#else
  #define DEBUG(X)
  #define DEBUGF(X, fmt)
#endif

#endif
