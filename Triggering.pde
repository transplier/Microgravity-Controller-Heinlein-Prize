#include "Pins.h"

#define MOVING_AVERAGE_SIZE 100 //number of points in the moving average
#define POINT_AVERAGE_COUNT 10  //number of readings that are averaged into a point in the moving average.
                                //I believe that the limit here is 64, otherwise we may overflow. See TODO in loop.
#define MOVING_AVERAGE_DELAY_MSEC 1000 //time interval between moving average points

#define POINT_AVERAGE_DELAY_MSEC MOVING_AVERAGE_DELAY_MSEC / POINT_AVERAGE_COUNT

/* Reads the accelerometer and adds the x, y, and z readings to dest. */
void AccumAccelerometerReading(unsigned short* dest) {
  dest[0] += analogRead(TC_ANALOG_ACCEL_X);
  dest[1] += analogRead(TC_ANALOG_ACCEL_Y);
  dest[2] += analogRead(TC_ANALOG_ACCEL_Z);
}

boolean MovingAverageTrigger() {

  //Allocate the ring buffer.
  unsigned short readings[MOVING_AVERAGE_SIZE*3];
  
  //Allocate the median calculation output short
  unsigned short median;
  
  //Start out with an empty buffer.
  memset(readings, 0, sizeof(readings));  
  
  //Start out at head of buffer.
  unsigned short* current_point = readings;
  
  //Nothing has been written for now.
  unsigned short num_points_filled = 0;
  
  while(/*TODO some metric*/true) {
    memset(current_point, 0, sizeof(unsigned short)*3);
    //Accumulate POINT_AVERAGE_COUNT readings.
    for(unsigned short count=0; count<POINT_AVERAGE_COUNT; count++) {
      //TODO this may overflow...
      AccumAccelerometerReading(current_point);
      delay(POINT_AVERAGE_DELAY_MSEC);
      /*Serial.print('(');
      Serial.print(current_point[0]);
      Serial.print(',');
      Serial.print(current_point[1]);  
      Serial.print(',');
      Serial.print(current_point[2]);
      Serial.print(')');*/
    }
    //Compute the average
    current_point[0] /= POINT_AVERAGE_COUNT;
    current_point[1] /= POINT_AVERAGE_COUNT;
    current_point[2] /= POINT_AVERAGE_COUNT;
        
    //Advance/wrap the pointer
    current_point = &current_point[3];
    if((int)current_point >= ((int)readings + sizeof(readings))) {
      current_point = readings;
    }
    num_points_filled++;
    if(num_points_filled >= MOVING_AVERAGE_SIZE)
      num_points_filled=MOVING_AVERAGE_SIZE-1;
    
    
    //Calculate the median
    median = torben(readings, num_points_filled*3);
    Serial.print("\r\nAVG:");
    Serial.println(median);
  }
}


/*
 * The following code is public domain.
 * Algorithm by Torben Mogensen, implementation by N. Devillard.
 * This code in public domain.
 * Calculate median.
 */

unsigned short torben(unsigned short m[], int n)
{
    int         i, less, greater, equal;
    unsigned short  min, max, guess, maxltguess, mingtguess;

    min = max = m[0] ;
    for (i=1 ; i<n ; i++) {
        if (m[i]<min) min=m[i];
        if (m[i]>max) max=m[i];
    }

    while (1) {
        guess = (min+max)/2;
        less = 0; greater = 0; equal = 0;
        maxltguess = min ;
        mingtguess = max ;
        for (i=0; i<n; i++) {
            if (m[i]<guess) {
                less++;
                if (m[i]>maxltguess) maxltguess = m[i] ;
            } else if (m[i]>guess) {
                greater++;
                if (m[i]<mingtguess) mingtguess = m[i] ;
            } else equal++;
        }
        if (less <= (n+1)/2 && greater <= (n+1)/2) break ; 
        else if (less>greater) max = maxltguess ;
        else min = mingtguess;
    }
    if (less >= (n+1)/2) return maxltguess;
    else if (less+equal >= (n+1)/2) return guess;
    else return mingtguess;
}
