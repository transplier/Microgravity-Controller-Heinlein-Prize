#include "Pins.h"

#define MOVING_AVERAGE_SIZE 100 //number of points in the moving average
#define POINT_AVERAGE_COUNT 10  //number of readings that are averaged into a point in the moving average.
                                //I believe that the limit here is 64, otherwise we may overflow. See TODO in loop.
#define MOVING_AVERAGE_DELAY_MSEC 100 //time interval between moving average points

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
  
  //Allocate the average calculation output array
  unsigned short average[3];
  
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
    
    
    //Calculate the moving average
    MovingAverage(readings, num_points_filled, average);
    Serial.print("X:");
    Serial.println(average[0]);
    Serial.print("Y:");
    Serial.println(average[1]);  
    Serial.print("Z:");
    Serial.println(average[2]);
  }
}

/* Computes the average of the first num groups of three in buffer. Outputs to dest. */
inline void MovingAverage(unsigned short* buffer, size_t num, unsigned short* dest) {
  /* We must compute the average in blocks of <64, otherwise we may overflow the short (readings are 0-1024). */
  unsigned short acc[3];
  uint8_t num_done=0;
  memset(acc, 0, sizeof(acc));
  for(unsigned short i=0; i<num; i++) {
    acc[0]+=buffer[i];
    acc[1]+=buffer[i+1];
    acc[2]+=buffer[i+2];
    num_done++;
    /* Done with block? If so, add to destination and prepare for next block. */
    if(num_done >= 64) {
      dest[0]+=acc[0]/num_done; 
      dest[1]+=acc[1]/num_done;
      dest[2]+=acc[2]/num_done;
      num_done=0;
      memset(acc, 0, sizeof(acc));
    }
  }
}
