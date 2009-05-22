#ifndef DEBUG_H
#define DEBUG_H

#define DODEBUG

#ifdef DODEBUG
  #define DEBUG(x) Serial.print(x)
  #define DEBUGF(x, fmt) Serial.print(x, fmt)
#else
  #define DEBUG(X)
  #define DEBUGF(X, fmt)
#endif

#endif
