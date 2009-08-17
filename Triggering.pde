#include "Pins.h"

#define MOVING_AVERAGE_SIZE 100 //number of points in the moving average
#define POINT_AVERAGE_COUNT 10  //number of readings that are averaged into a point in the moving average.
                                //I believe that the limit here is 64, otherwise we may overflow. See TODO in loop.
#define MOVING_AVERAGE_DELAY_MSEC 10 //time interval between moving average points

#define POINT_AVERAGE_DELAY_MSEC MOVING_AVERAGE_DELAY_MSEC / POINT_AVERAGE_COUNT

/* Reads the accelerometer and adds the x, y, and z readings to the respective pointers. */
void AccumAccelerometerReading(unsigned short* x, unsigned short* y, unsigned short* z) {
  *x += analogRead(TC_ANALOG_ACCEL_X);
  *y += analogRead(TC_ANALOG_ACCEL_Y);
  *z += analogRead(TC_ANALOG_ACCEL_Z);
}

boolean MovingAverageTrigger() {

  //Allocate the ring buffer.
  unsigned short readings_x[MOVING_AVERAGE_SIZE];
  unsigned short readings_y[MOVING_AVERAGE_SIZE];
  unsigned short readings_z[MOVING_AVERAGE_SIZE];
  
  //Allocate the median calculation output short
  unsigned short median_x, median_y, median_z;
  
  //Start out with an empty buffer.
  memset(readings_x, 0, sizeof(readings_x));  
  memset(readings_y, 0, sizeof(readings_y));  
  memset(readings_z, 0, sizeof(readings_z));  
  
  //Start out at head of buffer.
  unsigned short current_point = 0;
  
  //Nothing has been written for now.
  unsigned short num_points_filled = 0;
  
  while(/*TODO some metric*/true) {
    readings_x[current_point] = 0;
    readings_y[current_point] = 0;
    readings_z[current_point] = 0;
    //Accumulate POINT_AVERAGE_COUNT readings.
    for(unsigned short count=0; count<POINT_AVERAGE_COUNT; count++) {
      //TODO this may overflow...
      AccumAccelerometerReading(&readings_x[current_point], &readings_y[current_point], &readings_z[current_point]);
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
    readings_x[current_point] /= POINT_AVERAGE_COUNT;
    readings_y[current_point] /= POINT_AVERAGE_COUNT;
    readings_z[current_point] /= POINT_AVERAGE_COUNT;
        
    //Advance/wrap the pointer
    current_point ++;
    if(current_point >= MOVING_AVERAGE_SIZE) {
      current_point = 0;
    }
    num_points_filled++;
    if(num_points_filled >= MOVING_AVERAGE_SIZE)
      num_points_filled=MOVING_AVERAGE_SIZE-1;
    
    
    //Calculate the median
    median_x = torben(readings_x, num_points_filled);
    median_y = torben(readings_y, num_points_filled);
    median_z = torben(readings_z, num_points_filled);
    Serial.print("AVG: (");
    Serial.print(median_x);
    Serial.print(',');
    Serial.print(median_y);
    Serial.print(',');
    Serial.print(median_z);
    Serial.println(')');
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
